
# Nim std imports
import std/net
import std/typedthreads
import std/deques
import std/atomics
import std/times

from std/os import sleep
from std/strformat import fmt
from std/random import randomize
from std/locks import withLock, Lock

# External imports
from chacha20 import Key
from flatty import fromFlatty, toFlatty

# Local imports
import private/nc_message
import private/nc_nodeid
import nc_config

type
    NCServer* = object
        serverPort: Port
        key: Key
        # In seconds
        heartbeatTimeout: uint16
        # Use a HashMap in the future
        nodes: seq[(NCNodeID, Time)]
        nodesLock: Lock
        quit: Atomic[bool]

    ClientThread = Thread[(ptr NCServer, Socket)]

proc ncCheckNodesHeartbeat(self: ptr NCServer) {.thread.} =
    echo("NCServer.ncCheckNodesHeartbeat()")

    # Convert from seconds to miliseconds
    # and add a small tolerance for the client nodes
    const tolerance: uint = 500 # 500 ms tolerance
    let timeOut = (uint(self.heartbeatTimeout) * 1000) + tolerance

    let heartbeatMessage = NCMessageToServer(kind: NCServerMsgKind.checkHeartbeat)

    while not self.quit.load():
        sleep(int(timeOut))

        # Send message to server (self) so that it can check the heartbeats for all nodes
        let serverSocket = newSocket()
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

    withLock self.nodesLock:
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

    case serverMessage.kind:
    of NCServerMsgKind.registerNewNode:
        echo("Register new node")

        # Create a new node id and send it to the node
        let newId = self.ncCreateNewNodeId()
        let data = toFlatty(newId)
        let message = NCMessageToNode(kind: NCNodeMsgKind.welcome, data: data)
        ncSendMessageToNode(client, self.key, message)

        # Add the new node id to the list of active nodes
        withLock self.nodesLock:
            self.nodes.add((newId, getTime()))

    of NCServerMsgKind.needsData:
        echo("Node needs data")

        if self.ncValidNodeId(serverMessage.id):
            echo("Node id valid: ", serverMessage.id)
            # Send new data back to node
        else:
            echo("Node id invalid: ", serverMessage.id)

    of NCServerMsgKind.processedData:
        echo("Node has processed data")

        if self.ncValidNodeId(serverMessage.id):
            echo("Node id valid: ", serverMessage.id)
            # Store processed data from node
        else:
            echo("Node id invalid: ", serverMessage.id)

    of NCServerMsgKind.heartbeat:
        echo("Node sends heartbeat")

        withLock self.nodesLock:
            for i in 0..self.nodes.len():
                if self.nodes[i][0] == serverMessage.id:
                  self.nodes[i][1] = getTime()
                  break

    of NCServerMsgKind.checkHeartbeat:
        echo("Check heartbeat times for all inodes")

        let maxDuration = initDuration(seconds = int64(self.heartbeatTimeout))

        withLock self.nodesLock:
            let currentTime = getTime()

            for i in 0..self.nodes.len():
                if currentTime - self.nodes[i][1] > maxDuration:
                    echo(fmt("Node is not sending heartbeat message: {self.nodes[i][0]}"))
                    # TODO: Disable node

    of NCServerMsgKind.getStatistics:
        echo("Send some statistics")
        # TODO: respond with some information

    of NCServerMsgKind.forceQuit:
        echo("Force quit")
        self.quit.store(true)

    client.close()

proc run*(self: var NCServer) =
    echo("NCServer.run()")

    var hbThreadId: Thread[ptr NCServer]

    createThread(hbThreadId, ncCheckNodesHeartbeat, unsafeAddr(self))

    var clientThreadId: ClientThread
    var clients: Deque[ClientThread]

    let socket = newSocket()
    socket.bindAddr(self.serverPort)
    socket.listen()

    var client: Socket
    var address = ""

    while not self.quit.load():
        socket.acceptAddr(client, address)
        createThread(clientThreadId, ncHandleClient, (unsafeAddr(self), client))
        clients.addLast(clientThreadId)

        # Wait until there are at least two nodes
        if clients.len() > 1:
            if not clients[0].running():
                # Avaoid that sequence gets too large
                joinThread(clients.popFirst())

    joinThread(hbThreadId)

    for th in clients.items():
        # If there are any other threads running, wait for them to finish
        joinThread(th)

proc init*(ncConfig: NCConfiguration): NCServer =
    echo("init(config)")

    # Initiate the random number genertator
    randomize()

    var ncServer = NCServer()

    ncServer.serverPort = ncConfig.serverPort
    # Cast key from string to array[32, byte] for chacha20 (32 bytes)
    let keyStr = ncConfig.secretKey
    echo(fmt("Key length: {keyStr.len()}"))
    assert(keyStr.len() == len(Key), "Key must be exactly 32 bytes long")
    let key = cast[ptr(Key)](unsafeAddr(keyStr[0]))

    ncServer.key = key[]
    ncServer.heartbeatTimeout = ncConfig.heartbeatTimeout

    return ncServer

proc init*(fileName: string): NCServer =
    echo(fmt("init({fileName})"))

    let config = ncLoadConfig(fileName)
    init(config)

