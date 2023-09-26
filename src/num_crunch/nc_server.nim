
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
from std/logging import debug

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
    debug("NCServer.checkNodesHeartbeat()")

    # Convert from seconds to miliseconds
    # and add a small tolerance for the client nodes
    const tolerance: uint = 500 # 500 ms tolerance
    let timeOut = (uint(self.heartbeatTimeout) * 1000) + tolerance

    let heartbeatMessage = NCMessageToServer(kind: NCServerMsgKind.checkHeartbeat)

    while not self.quit.load():
        sleep(int(timeOut))

        # Send message to server (self) so that it can check the heartbeats for all nodes
        debug("NCServer.checkNodesHeartbeat(), send heartbeat")
        let serverSocket = newSocket()
        try:
            serverSocket.connect("127.0.0.1", self.serverPort)
            ncSendMessageToServer(serverSocket, self.key, heartbeatMessage)
            serverSocket.close()
        except IOError:
            debug("NCServer.checkNodesHeartbeat(), server doesn't respond, will exit now!")
            break

proc createNewNodeId[T](self: ptr NCServer[T]): NCNodeID =
    debug("NCServer.createNewNodeId()")

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
    debug("NCServer.validNodeId(), id: ", id)

    result = false

    for (n, _) in self.nodes:
        if n == id:
            result = true
            break

proc handleClient[T](tp: (ptr NCServer[T], Socket)) {.thread.} =
    debug("NCServer.handleClient()")

    let self = tp[0]
    let client = tp[1]

    acquire(self.serverLock)

    try:
        let (clientAddr, clientPort) = client.getPeerAddr()
        debug(fmt("NCServer.handleClient(), Connection from: {clientAddr}, port: {clientPort.uint16}"))
    except OSError:
        debug("NCServer.handleClient(), socket closed, exit thread")

        if self.dataProcessor.isFinished():
            debug("NCServer.handleClient(), Work is done, exit now!")
            self.quit.store(true)

        release(self.serverLock)

        return

    let serverMessage = ncReceiveMessageFromNode(client, self.key)

    if self.dataProcessor.isFinished():
        debug("NCServer.handleClient(), Work is done, exit now!")

        let message = NCMessageToNode(kind: NCNodeMsgKind.quit)
        ncSendMessageToNode(client, self.key, message)
        self.quit.store(true)
        release(self.serverLock)
        client.close()

        return

    case serverMessage.kind:
    of NCServerMsgKind.registerNewNode:
        debug("NCServer.handleClient(), Register new node")

        # Create a new node id and send it to the node
        let newId = self.createNewNodeId()
        let data = ncStrToBytes(toFlatty(newId))
        let message = NCMessageToNode(kind: NCNodeMsgKind.welcome, data: data)
        ncSendMessageToNode(client, self.key, message)

        # Add the new node id to the list of active nodes
        self.nodes.add((newId, getTime()))

    of NCServerMsgKind.needsData:
        debug("NCServer.handleClient(), Node needs data")

        if self.validNodeId(serverMessage.id):
            debug("NCServer.handleClient(), Node id valid: ", serverMessage.id)
            # Send new data back to node
            let newData = self.dataProcessor.getNewData(serverMessage.id)
            let message = NCMessageToNode(kind: NCNodeMsgKind.newData, data: newData)
            ncSendMessageToNode(client, self.key, message)
        else:
            debug("NCServer.handleClient(), Node id invalid: ", serverMessage.id)

    of NCServerMsgKind.processedData:
        debug("NCServer.handleClient(), Node has processed data")

        if self.validNodeId(serverMessage.id):
            debug("NCServer.handleClient(), Node id valid: ", serverMessage.id)
            # Store processed data from node
            self.dataProcessor.collectData(serverMessage.data)
        else:
            debug("NCServer.handleClient(), Node id invalid: ", serverMessage.id)

    of NCServerMsgKind.heartbeat:
        debug("NCServer.handleClient(), Node sends heartbeat")

        for i in 0..<self.nodes.len():
            if self.nodes[i][0] == serverMessage.id:
                self.nodes[i][1] = getTime()
                break

    of NCServerMsgKind.checkHeartbeat:
        debug("NCServer.handleClient(), Check heartbeat times for all inodes")

        let maxDuration = initDuration(seconds = int64(self.heartbeatTimeout))

        let currentTime = getTime()

        for n in self.nodes:
            if maxDuration < (currentTime - n[1]):
                debug(fmt("NCServer.handleClient(), Node is not sending heartbeat message: {n[0]}"))
                # Let data processor know that this node seems dead
                self.dataProcessor.maybeDeadNode(n[0])

    of NCServerMsgKind.getStatistics:
        debug("NCServer.handleClient(), Send some statistics")
        # TODO: respond with some information

    of NCServerMsgKind.forceQuit:
        debug("NCServer.handleClient(), Force quit")
        self.quit.store(true)

    release(self.serverLock)
    client.close()

proc runServer*[T](self: var NCServer[T]) =
    debug("NCServer.runServer()")

    var hbThreadId: Thread[ptr NCServer[T]]

    createThread(hbThreadId, checkNodesHeartbeat, unsafeAddr(self))

    const maxThreads = 16
    var clientThreads: array[0..maxThreads, ClientThread[T]]
    var assignedThreads: array[0..maxThreads, bool]

    initLock(self.serverLock)

    let serverSocket = newSocket()
    serverSocket.bindAddr(self.serverPort)
    serverSocket.listen()

    var client: Socket
    var address = ""

    while not self.quit.load():
        serverSocket.acceptAddr(client, address)
        debug("NCServer.runServer(), got new connection from node")

        let selfPtr = unsafeAddr(self)

        # Check if some threads are already done
        # and mark them as not assigned
        for i in 0..<maxThreads:
            if assignedThreads[i]:
                if not running(clientThreads[i]):
                    joinThread(clientThreads[i])
                    assignedThreads[i] = false

        # Check if some threads are not assigned yet
        # and use them to process the new client connection
        for i in 0..<maxThreads:
            if not assignedThreads[i]:
                createThread(clientThreads[i], handleClient, (selfPtr, client))
                assignedThreads[i] = true
                break

        debug("NCServer.runServer(), new thread created")

    acquire(self.serverLock)
    # Save the user data as soon as possible
    self.dataProcessor.saveData()
    release(self.serverLock)

    serverSocket.close()

    debug("NCServer.runServer(), Waiting for other threads to finish...")

    joinThread(hbThreadId)
    debug("NCServer.runServer(), hearbeat thread finished")

    for i in 0..<maxThreads:
        if assignedThreads[i]:
            joinThread(clientThreads[i])
    debug("NCServer.runServer(), other threads finished")

    deinitLock(self.serverLock)
    debug("NCServer.runServer(), Will exit now!")

proc ncInitServer*[T: NCDPServer](dataProcessor: T, ncConfig: NCConfiguration): NCServer[T] =
    debug("ncInitServer(config)")

    # Initiate the random number genertator
    randomize()

    var ncServer = NCServer[T](dataProcessor: dataProcessor)

    ncServer.serverPort = ncConfig.serverPort
    # Cast key from string to array[32, byte] for chacha20 (32 bytes)
    let keyStr = ncConfig.secretKey
    debug(fmt("Key length: {keyStr.len()}"))
    assert(keyStr.len() == len(Key), "Key must be exactly 32 bytes long")
    let key = cast[ptr(Key)](unsafeAddr(keyStr[0]))

    ncServer.key = key[]
    ncServer.heartbeatTimeout = ncConfig.heartbeatTimeout

    return ncServer

proc ncInitServer*[T: NCDPServer](dataProcessor: T, fileName: string): NCServer[T] =
    debug(fmt("ncInitServer({fileName})"))

    let config = ncLoadConfig(fileName)
    ncInitServer(dataProcessor, config)

