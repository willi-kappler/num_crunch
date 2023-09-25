
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
import nc_nodeid
import nc_config

type
    NCServer*[T: NCDPServer] = object
        serverPort: Port
        key: Key
        # In seconds
        heartbeatTimeout: uint16
        serverLock: Lock
        # Use a HashMap in the future
        nodes: seq[(NCNodeID, Time)]
        dataProcessor: T
        quit: Atomic[bool]

    ClientThread[T] = Thread[(ptr NCServer[T], Socket)]

    NCDPServer = concept dp
        dp.isFinished() is bool
        dp.getNewData(type NCNodeID) is seq[byte]
        dp.collectData(type seq[byte])
        dp.maybeDeadNode(type NCNodeID)
        dp.saveData()


proc checkNodesHeartbeat[T](self: ptr NCServer[T]) {.thread.} =
    echo("NCServer.checkNodesHeartbeat()")

    # Convert from seconds to miliseconds
    # and add a small tolerance for the client nodes
    const tolerance: uint = 500 # 500 ms tolerance
    let timeOut = (uint(self.heartbeatTimeout) * 1000) + tolerance

    let heartbeatMessage = NCMessageToServer(kind: NCServerMsgKind.checkHeartbeat)

    while not self.quit.load():
        sleep(int(timeOut))

        # Send message to server (self) so that it can check the heartbeats for all nodes
        echo("NCServer.checkNodesHeartbeat(), send heartbeat")
        let serverSocket = newSocket()
        try:
            serverSocket.connect("127.0.0.1", self.serverPort)
            ncSendMessageToServer(serverSocket, self.key, heartbeatMessage)
            serverSocket.close()
            echo("NCServer.checkNodesHeartbeat(), done")
        except IOError:
            echo("NCServer.checkNodesHeartbeat(), server doesn't respond, will exit now!")
            break

proc createNewNodeId[T](self: ptr NCServer[T]): NCNodeID =
    echo("NCServer.createNewNodeId()")

    result = ncNewNodeId()
    var quit = false

    while not quit:
        quit = true
        for (n, _) in self.nodes:
            if result == n:
                # NodeId already in use, choose a new one
                result = ncNewNodeId()
                quit = false

proc validNodeId[T](self: ptr NCServer[T], id: NCNodeID): bool =
    echo("NCServer.validNodeId(), id: ", id)

    result = false

    for (n, _) in self.nodes:
        if n == id:
            result = true
            break

proc handleClient[T](tp: (ptr NCServer[T], Socket)) {.thread.} =
    echo("NCServer.handleClient()")

    let self = tp[0]
    let client = tp[1]

    echo("NCServer.handleClient(), check pointers")

    assert(self != nil)
    assert(client != nil)

    echo("NCServer.handleClient(), pointers OK")

    let (clientAddr, clientPort) = client.getPeerAddr()
    echo(fmt("NCServer.handleClient(), Connection from: {clientAddr}, port: {clientPort.uint16}"))

    let serverMessage = ncReceiveMessageFromNode(client, self.key)


    acquire(self.serverLock)

    if self.dataProcessor.isFinished():
        echo("NCServer.handleClient(), Work is done, exit now!")

        let message = NCMessageToNode(kind: NCNodeMsgKind.quit)
        ncSendMessageToNode(client, self.key, message)
        self.quit.store(true)
        release(self.serverLock)
        client.close()

        return

    case serverMessage.kind:
    of NCServerMsgKind.registerNewNode:
        echo("NCServer.handleClient(), Register new node")

        # Create a new node id and send it to the node
        let newId = self.createNewNodeId()
        let data = ncStrToBytes(toFlatty(newId))
        let message = NCMessageToNode(kind: NCNodeMsgKind.welcome, data: data)
        ncSendMessageToNode(client, self.key, message)

        # Add the new node id to the list of active nodes
        self.nodes.add((newId, getTime()))

    of NCServerMsgKind.needsData:
        echo("NCServer.handleClient(), Node needs data")

        if self.validNodeId(serverMessage.id):
            echo("NCServer.handleClient(), Node id valid: ", serverMessage.id)
            # Send new data back to node
            let newData = self.dataProcessor.getNewData(serverMessage.id)
            let message = NCMessageToNode(kind: NCNodeMsgKind.newData, data: newData)
            ncSendMessageToNode(client, self.key, message)
        else:
            echo("NCServer.handleClient(), Node id invalid: ", serverMessage.id)

    of NCServerMsgKind.processedData:
        echo("NCServer.handleClient(), Node has processed data")

        if self.validNodeId(serverMessage.id):
            echo("NCServer.handleClient(), Node id valid: ", serverMessage.id)
            # Store processed data from node
            self.dataProcessor.collectData(serverMessage.data)
        else:
            echo("NCServer.handleClient(), Node id invalid: ", serverMessage.id)

    of NCServerMsgKind.heartbeat:
        echo("NCServer.handleClient(), Node sends heartbeat")

        for i in 0..<self.nodes.len():
            if self.nodes[i][0] == serverMessage.id:
                self.nodes[i][1] = getTime()
                break

    of NCServerMsgKind.checkHeartbeat:
        echo("NCServer.handleClient(), Check heartbeat times for all inodes")

        let maxDuration = initDuration(seconds = int64(self.heartbeatTimeout))

        let currentTime = getTime()

        for n in self.nodes:
            if maxDuration < (currentTime - n[1]):
                echo(fmt("NCServer.handleClient(), Node is not sending heartbeat message: {n[0]}"))
                # Let data processor know that this node seems dead
                self.dataProcessor.maybeDeadNode(n[0])

    of NCServerMsgKind.getStatistics:
        echo("NCServer.handleClient(), Send some statistics")
        # TODO: respond with some information

    of NCServerMsgKind.forceQuit:
        echo("NCServer.handleClient(), Force quit")
        self.quit.store(true)

    release(self.serverLock)
    client.close()

proc runServer*[T](self: var NCServer[T]) =
    echo("NCServer.runServer()")

    var hbThreadId: Thread[ptr NCServer[T]]

    createThread(hbThreadId, checkNodesHeartbeat, unsafeAddr(self))

    var clientThreadId: ClientThread[T]
    var clients: Deque[ClientThread[T]]

    initLock(self.serverLock)

    let serverSocket = newSocket()
    serverSocket.bindAddr(self.serverPort)
    serverSocket.listen()

    var client: Socket
    var address = ""

    while not self.quit.load():
        serverSocket.acceptAddr(client, address)
        echo("runServer(), got new connection from node")
        let selfPtr = unsafeAddr(self)
        assert(selfPtr != nil)
        createThread(clientThreadId, handleClient, (selfPtr, client))
        echo("runServer(), new thread created")
        let newThread = move(clientThreadId)
        clients.addLast(newThread)
        echo("runServer(), thread added to client list")

        # Wait until there are at least two nodes
        if clients.len() > 1:
            if not clients[0].running():
                # Avoid that sequence gets too large
                joinThread(clients.popFirst())

    acquire(self.serverLock)
    # Save the user data as soon as possible
    self.dataProcessor.saveData()
    release(self.serverLock)

    serverSocket.close()

    echo("Waiting for other threads to finish...")
    sleep(10*1000) # Wait 10 seconds to give the other threads a chance to finish

    if not running(hbThreadId):
        joinThread(hbThreadId)

    for th in clients.items():
        if not running(th):
            joinThread(th)

    deinitLock(self.serverLock)
    echo("Will exit now!")

proc ncInitServer*[T: NCDPServer](dataProcessor: T, ncConfig: NCConfiguration): NCServer[T] =
    echo("ncInitServer(config)")

    # Initiate the random number genertator
    randomize()

    var ncServer = NCServer[T](dataProcessor: dataProcessor)

    ncServer.serverPort = ncConfig.serverPort
    # Cast key from string to array[32, byte] for chacha20 (32 bytes)
    let keyStr = ncConfig.secretKey
    echo(fmt("Key length: {keyStr.len()}"))
    assert(keyStr.len() == len(Key), "Key must be exactly 32 bytes long")
    let key = cast[ptr(Key)](unsafeAddr(keyStr[0]))

    ncServer.key = key[]
    ncServer.heartbeatTimeout = ncConfig.heartbeatTimeout

    return ncServer

proc ncInitServer*[T: NCDPServer](dataProcessor: T, fileName: string): NCServer[T] =
    echo(fmt("ncInitServer({fileName})"))

    let config = ncLoadConfig(fileName)
    ncInitServer(dataProcessor, config)

