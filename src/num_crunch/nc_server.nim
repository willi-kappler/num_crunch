
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

# Local imports
import private/nc_message
import nc_config
import nc_log
import nc_nodeid
import nc_common

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
        dp.getInitData() is seq[byte]
        dp.getNewData(type NCNodeID) is seq[byte]
        dp.collectData(type seq[byte])
        dp.maybeDeadNode(type NCNodeID)
        dp.saveData()


proc checkNodesHeartbeat[T](self: ptr NCServer[T]) {.thread.} =
    ncDebug("  NCServer.checkNodesHeartbeat()")

    # Convert from seconds to miliseconds
    # and add a small tolerance for the client nodes
    const tolerance: uint = 500 # 500 ms tolerance
    let timeOut = (uint(self.heartbeatTimeout) * 1000) + tolerance

    let heartbeatMessage = NCMessageToServer(kind: NCServerMsgKind.checkHeartbeat)

    while not self.quit.load():
        sleep(int(timeOut))

        # Send message to server (self) so that it can check the heartbeats for all nodes
        ncDebug("  NCServer.checkNodesHeartbeat(), send heartbeat")
        let serverSocket = newSocket()
        try:
            serverSocket.connect("127.0.0.1", self.serverPort)
            ncSendMessageToServer(serverSocket, self.key, heartbeatMessage)
            serverSocket.close()
        except IOError:
            ncError("  NCServer.checkNodesHeartbeat(), server doesn't respond, will exit now!")
            break

proc createNewNodeId[T](self: ptr NCServer[T]): NCNodeID =
    ncInfo("      NCServer.createNewNodeId()")

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
    ncDebug(fmt("      NCServer.validNodeId(), id: {id}"))

    result = false

    for (n, _) in self.nodes:
        if n == id:
            result = true
            break

proc handleClientInner[T](self: ptr NCServer[T], client: Socket) =
    ncInfo("    NCServer.handleClientInner()")

    let (clientAddr, clientPort) = client.getPeerAddr()
    ncDebug(fmt("    NCServer.handleClientInner(), connection from: {clientAddr}, port: {clientPort.uint16}"))

    let serverMessage = ncReceiveMessageFromNode(client, self.key)

    if self.dataProcessor.isFinished():
        ncInfo("    NCServer.handleClientInner(), work is done, exit now!")
        self.quit.store(true)

        let message = NCMessageToNode(kind: NCNodeMsgKind.quit)
        ncSendMessageToNode(client, self.key, message)
        return

    case serverMessage.kind:
    of NCServerMsgKind.registerNewNode:
        ncInfo("    NCServer.handleClientInner(), register new node")

        # Create a new node id and send it to the node
        let newId = self.createNewNodeId()
        let initData = self.dataProcessor.getInitData()
        let data = ncToBytes((newId, initData))
        let message = NCMessageToNode(kind: NCNodeMsgKind.welcome, data: data)
        ncSendMessageToNode(client, self.key, message)

        # Add the new node id to the list of active nodes
        self.nodes.add((newId, getTime()))

    of NCServerMsgKind.needsData:
        ncDebug("    NCServer.handleClientInner(), node needs data")

        if self.validNodeId(serverMessage.id):
            ncDebug(fmt("    NCServer.handleClientInner(), node id valid: {serverMessage.id}"))
            # Send new data back to node
            let newData = self.dataProcessor.getNewData(serverMessage.id)
            let message = NCMessageToNode(kind: NCNodeMsgKind.newData, data: newData)
            ncSendMessageToNode(client, self.key, message)
        else:
            ncDebug(fmt("    NCServer.handleClientInner(), node id invalid: {serverMessage.id}"))

    of NCServerMsgKind.processedData:
        ncDebug("    NCServer.handleClientInner(), node has processed data")

        if self.validNodeId(serverMessage.id):
            ncDebug(fmt("    NCServer.handleClientInner(), node id valid: {serverMessage.id}"))
            # Store processed data from node
            self.dataProcessor.collectData(serverMessage.data)
        else:
            ncDebug(fmt("    NCServer.handleClientInner(), node id invalid: {serverMessage.id}"))

    of NCServerMsgKind.heartbeat:
        ncDebug("    NCServer.handleClientInner(), node sends heartbeat")

        for i in 0..<self.nodes.len():
            if self.nodes[i][0] == serverMessage.id:
                self.nodes[i][1] = getTime()
                break

    of NCServerMsgKind.checkHeartbeat:
        ncDebug("    NCServer.handleClientInner(), check heartbeat times for all inodes")

        let maxDuration = initDuration(seconds = int64(self.heartbeatTimeout))

        let currentTime = getTime()

        for n in self.nodes:
            if maxDuration < (currentTime - n[1]):
                ncDebug(fmt("    NCServer.handleClientInner(), node is not sending heartbeat message: {n[0]}"))
                # Let data processor know that this node seems dead
                self.dataProcessor.maybeDeadNode(n[0])

    of NCServerMsgKind.getStatistics:
        ncDebug("    NCServer.handleClientInner(), send some statistics")
        # TODO: respond with some information

    of NCServerMsgKind.forceQuit:
        ncInfo("    NCServer.handleClientInner(), force quit")
        self.quit.store(true)

proc handleClient[T](tp: (ptr NCServer[T], Socket)) {.thread.} =
    ncInfo("  NCServer.handleClient()")

    let self = tp[0]
    let client = tp[1]

    acquire(self.serverLock)

    if self.dataprocessor.isfinished():
        ncinfo("  NCServer.handleclient(), work is done, exit now!")
        self.quit.store(true)
    else:
        try:
            handleClientInner(self, client)
        except CatchableError:
            let msg = getCurrentExceptionMsg()
            ncError(fmt("  NCServer.handleClient(), an error occurred: {msg}, exit thread"))

    release(self.serverLock)
    client.close()

proc runServer*[T](self: var NCServer[T]) =
    ncInfo("NCServer.runServer()")

    var hbThreadId: Thread[ptr NCServer[T]]

    createThread(hbThreadId, checkNodesHeartbeat, unsafeAddr(self))

    # This is a poor thread pool implementation...
    # Maybe use s.th. better:
    # https://github.com/Araq/malebolgia
    # https://github.com/mratsim/weave
    # https://github.com/status-im/nim-taskpools

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
        ncDebug("NCServer.runServer(), got new connection from node")

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

        ncDebug("NCServer.runServer(), new thread created")

    acquire(self.serverLock)
    # Save the user data as soon as possible
    ncInfo("NCServer.runServer(), save all user data!")
    self.dataProcessor.saveData()
    release(self.serverLock)

    serverSocket.close()

    ncDebug("NCServer.runServer(), waiting for other threads to finish...")
    # Sleep 5 seconds and give other threads a chance to finish...
    sleep(5000) 

    if not running(hbThreadId):
        joinThread(hbThreadId)
        ncDebug("NCServer.runServer(), hearbeat thread finished")

    for i in 0..<maxThreads:
        if assignedThreads[i]:
            if not running(clientThreads[i]):
                joinThread(clientThreads[i])
                ncDebug("NCServer.runServer(), client thread finished")

    deinitLock(self.serverLock)
    ncInfo("NCServer.runServer(), will exit now!")

proc ncInitServer*[T: NCDPServer](dataProcessor: T, ncConfig: NCConfiguration): NCServer[T] =
    ncInfo("ncInitServer(config)")

    # Initiate the random number genertator
    randomize()

    var ncServer = NCServer[T](dataProcessor: dataProcessor)

    ncServer.serverPort = ncConfig.serverPort
    # Cast key from string to array[32, byte] for chacha20 (32 bytes)
    let keyStr = ncConfig.secretKey
    ncDebug(fmt("ncInitServer(), key length: {keyStr.len()}"))
    assert(keyStr.len() == len(Key), "ncInitServer(), key must be exactly 32 bytes long")
    let key = cast[ptr(Key)](unsafeAddr(keyStr[0]))

    ncServer.key = key[]
    ncServer.heartbeatTimeout = ncConfig.heartbeatTimeout

    return ncServer

proc ncInitServer*[T: NCDPServer](dataProcessor: T, fileName: string): NCServer[T] =
    ncInfo(fmt("ncInitServer({fileName})"))

    let config = ncLoadConfig(fileName)
    ncInitServer(dataProcessor, config)

