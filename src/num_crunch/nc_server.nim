
# Nim std imports
import std/net
import std/locks
import std/typedthreads
import std/deques
import std/atomics

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
    NCServer* = object
        serverPort: Port
        key: Key
        # In seconds
        heartbeatTimeout: uint16
        nodes: seq[NCNodeID]
        quit: Atomic[bool]

    ClientThread = Thread[(NCServer, Socket)]

proc ncCheckNodesHeartbeat(self: ptr NCServer) {.thread.} =
    echo("NCServer.ncCheckNodesHeartbeat()")

    # Convert from seconds to miliseconds
    # and add a small tolerance for the client nodes
    const tolerance: uint = 500 # 500 ms tolerance
    let timeOut = (uint(self.heartbeatTimeout) * 1000) + tolerance

    while not self.quit.load():
        sleep(int(timeOut))
        echo("Check heartbeat for all nodes")
        # TODO: send message to server on the same host

proc ncCreateNewNodeId(self: NCServer): NCNodeID =
    echo("NCServer.ncCreateNewNodeId()")

    result = ncNewNodeId()
    var quit = false

    while not quit:
        quit = true
        for n in self.nodes:
            if result == n:
                # NodeId already in use, choose a new one
                result = ncNewNodeId()
                quit = false

proc ncSendNewNodeId(self: NCServer, client: Socket, newId: NCNodeID) =
    echo("NCServer.ncSendNewNodeId()")

    let data = toFlatty(newId)
    let message = NCNodeMessage(kind: NCNodeMsgKind.welcome, data: data)

    ncSendMessageToNode(client, self.key, message)

proc ncValidNodeId(self: NCServer, id: NCNodeID): bool =
    echo("NCServer.ncValidNodeId(), id: ", id)
    # TODO: check if node id is valid

    return true

proc ncHandleClient(tp: (NCServer, Socket)) =
    echo("NCServer.ncHandleClient()")

    let (self, client) = tp

    let (clientAddr, clientPort) = client.getPeerAddr()
    echo(fmt("Connection from: {clientAddr}, port: {clientPort.uint16}"))

    let serverMessage = ncReceiveMessageFromNode(client, self.key)

    # TODO: write code to handle clients
    case serverMessage.kind:
    of NCServerMsgKind.registerNewNode:
        # Create a new node id and send it to the node
        let newId = self.ncCreateNewNodeId()
        self.ncSendNewNodeId(client, newId)
    of NCServerMsgKind.needsData:
        if self.ncValidNodeId(serverMessage.id):
            echo("Node id valid: ", serverMessage.id)
            # asyncdispatch: hasPendingOperations(), poll(10)
            # if self.dataManager.ncIsDone():
            #
            # else:
            # let newData = toFlatty(self.dataManader.ncGetNewData())
            # let message = NCMessageToNode(NCNodeMsgKind.newData, newData)
            # await(ncSendMessageToNode)
        else:
            echo("Node id invalid: ", serverMessage.id)
    of NCServerMsgKind.processedData:
        discard
        # if ncServer.ncValidNodeId(serverMessage.id):
        # ncServer.dataManager.ncCollectData(serverMessage.data)
    of NCServerMsgKind.heartbeat:
        discard
        # if ncServer.ncValidNodeId(serverMessage.id):
        # ncServer.ncProcessHearbeat(serverMessage.data)
    of NCServerMsgKind.checkHeartbeat:
        discard
    of NCServerMsgKind.getStatistics:
        discard
    of NCServerMsgKind.forceQuit:
        discard


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
        createThread(clientThreadId, ncHandleClient, (self, client))
        clients.addLast(clientThreadId)
        if clients.len() > 1:
            if not clients[0].running():
                joinThread(clients.popFirst())

    joinThread(hbThreadId)

    for th in clients.items():
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
