
# Nim std imports
import std/net
import std/typedthreads
import std/deques
import std/atomics
import std/times
import std/locks

from std/os import sleep
from std/strformat import fmt
from std/random import randomize

# External imports
from chacha20 import Key
from flatty import fromFlatty, toFlatty

# Local imports
import private/nc_message
import private/nc_nodeid
import nc_config

type
    NCServer*[T] = object
        serverPort: Port
        key: Key
        # In seconds
        heartbeatTimeout: uint16
        serverLock: Lock
        # Use a HashMap in the future
        nodes: seq[(NCNodeID, Time)]
        dataProcessor: T
        quit: Atomic[bool]

    ClientThread = Thread[(ptr NCServer, Socket)]

proc ncCheckNodesHeartbeat(self: ptr NCServer) {.thread.} =
    echo("NCServer.ncCheckNodesHeartbeat()")

    # Convert from seconds to miliseconds
    # and add a small tolerance for the client nodes
    const tolerance: uint = 500 # 500 ms tolerance
    let timeOut = (uint(self.heartbeatTimeout) * 1000) + tolerance

    let heartbeatMessage = NCMessageToServer(kind: NCServerMsgKind.checkHeartbeat)
    let serverSocket = newSocket()

    while not self.quit.load():
        sleep(int(timeOut))

        # Send message to server (self) so that it can check the heartbeats for all nodes
        serverSocket.connect("127.0.0.1", self.serverPort)
        ncSendMessageToServer(serverSocket, self.key, heartbeatMessage)
        serverSocket.close()

proc ncCreateNewNodeId(self: ptr NCServer): NCNodeID =
    echo("NCServer.ncCreateNewNodeId()")

    result = ncNewNodeId()
    var quit = false

    while not quit:
        quit = true
        for (n, _) in self.nodes:
            if result == n:
                # NodeId already in use, choose a new one
                result = ncNewNodeId()
                quit = false

proc ncValidNodeId(self: ptr NCServer, id: NCNodeID): bool =
    echo("NCServer.ncValidNodeId(), id: ", id)

    result = false

    for (n, _) in self.nodes:
        if n == id:
            result = true
            break

proc ncHandleClient(tp: (ptr NCServer, Socket)) {.thread.} =
    echo("NCServer.ncHandleClient()")

    let self = tp[0]
    let client = tp[1]

    let (clientAddr, clientPort) = client.getPeerAddr()
    echo(fmt("Connection from: {clientAddr}, port: {clientPort.uint16}"))

    let serverMessage = ncReceiveMessageFromNode(client, self.key)

    acquire(self.serverLock)

    if self.dataProcessor.isFinished():
        echo("Work is done, exit now!")

        let message = NCMessageToNode(kind: NCNodeMsgKind.quit)
        ncSendMessageToNode(client, self.key, message)
        self.quit.store(true)
        release(self.serverLock)
        client.close()

        return

    case serverMessage.kind:
    of NCServerMsgKind.registerNewNode:
        echo("Register new node")

        # Create a new node id and send it to the node
        let newId = self.ncCreateNewNodeId()
        let data = toFlatty(newId)
        let message = NCMessageToNode(kind: NCNodeMsgKind.welcome, data: data)
        ncSendMessageToNode(client, self.key, message)

        # Add the new node id to the list of active nodes
        self.nodes.add((newId, getTime()))

    of NCServerMsgKind.needsData:
        echo("Node needs data")

        if self.ncValidNodeId(serverMessage.id):
            echo("Node id valid: ", serverMessage.id)
            # Send new data back to node
            let newData = self.dataProcessor.getNewData(serverMessage.id)
            let message = NCMessageToNode(kind: NCNodeMsgKind.newData, data: newData)
            ncSendMessageToNode(client, self.key, message)
        else:
            echo("Node id invalid: ", serverMessage.id)

    of NCServerMsgKind.processedData:
        echo("Node has processed data")

        if self.ncValidNodeId(serverMessage.id):
            echo("Node id valid: ", serverMessage.id)
            # Store processed data from node
            self.dataProcessor.collectData(serverMessage.data)
        else:
            echo("Node id invalid: ", serverMessage.id)

    of NCServerMsgKind.heartbeat:
        echo("Node sends heartbeat")

        for i in 0..self.nodes.len():
            if self.nodes[i][0] == serverMessage.id:
                self.nodes[i][1] = getTime()
                break

    of NCServerMsgKind.checkHeartbeat:
        echo("Check heartbeat times for all inodes")

        const maxDuration = initDuration(seconds = int64(self.heartbeatTimeout))

        let currentTime = getTime()

        for n in self.nodes:
            if currentTime - n[1] > maxDuration:
                echo(fmt("Node is not sending heartbeat message: {n[0]}"))
                # Let data processor know that this node seems dead
                self.dataProcessor.maybeDeadNode(n[0])

    of NCServerMsgKind.getStatistics:
        echo("Send some statistics")
        # TODO: respond with some information

    of NCServerMsgKind.forceQuit:
        echo("Force quit")
        self.quit.store(true)

    release(self.serverLock)
    client.close()

proc runServer*(self: var NCServer) =
    echo("NCServer.runServer()")

    var hbThreadId: Thread[ptr NCServer]

    createThread(hbThreadId, ncCheckNodesHeartbeat, unsafeAddr(self))

    var clientThreadId: ClientThread
    var clients: Deque[ClientThread]

    initLock(self.serverLock)

    let serverSocket = newSocket()
    serverSocket.bindAddr(self.serverPort)
    serverSocket.listen()

    var client: Socket
    var address = ""

    while not self.quit.load():
        serverSocket.acceptAddr(client, address)
        createThread(clientThreadId, ncHandleClient, (unsafeAddr(self), client))
        clients.addLast(clientThreadId)

        # Wait until there are at least two nodes
        if clients.len() > 1:
            if not clients[0].running():
                # Avaoid that sequence gets too large
                joinThread(clients.popFirst())

    acquire(self.serverLock)
    # Save the user data as soon as possible
    self.dataProcessor.saveData()
    release(self.serverLock)

    serverSocket.close()

    joinThread(hbThreadId)

    for th in clients.items():
        # If there are any other threads running, wait for them to finish
        joinThread(th)

    deinitLock(self.serverLock)

proc initServer*[T](dataProcessor: T, ncConfig: NCConfiguration): NCServer =
    echo("initServer(config)")

    # Initiate the random number genertator
    randomize()

    var ncServer = NCServer(dataProcessor: dataProcessor)

    ncServer.serverPort = ncConfig.serverPort
    # Cast key from string to array[32, byte] for chacha20 (32 bytes)
    let keyStr = ncConfig.secretKey
    echo(fmt("Key length: {keyStr.len()}"))
    assert(keyStr.len() == len(Key), "Key must be exactly 32 bytes long")
    let key = cast[ptr(Key)](unsafeAddr(keyStr[0]))

    ncServer.key = key[]
    ncServer.heartbeatTimeout = ncConfig.heartbeatTimeout

    return ncServer

proc initServer*[T](dataProcessor: T, fileName: string): NCServer =
    echo(fmt("initServer({fileName})"))

    let config = ncLoadConfig(fileName)
    initServer(dataProcessor, config)

