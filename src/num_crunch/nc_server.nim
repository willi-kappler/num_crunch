
# Nim std imports
import std/[asyncnet, asyncdispatch]
from std/strformat import fmt
from std/nativesockets import Port
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
        quit: bool

proc ncCheckNodesHeartbeat(ncServer: NCServer) {. async .} =
    echo("NCServer.ncCheckNodesHeartbeat()")

    # Convert from seconds to miliseconds
    # and add a small tolerance for the client nodes
    const tolerance: uint = 200 # 200 ms tolerance
    let timeOut = (uint(ncServer.heartbeatTimeout) * 1000) + tolerance

    await(sleepAsync(int(timeOut)))
    # TODO: check the heartbeat messages and times for each node
    echo("Check heartbeat for all nodes")

proc ncCreateNewNodeId(ncServer: NCServer): NCNodeID =
    echo("NCServer.ncCreateNewNodeId()")

    result = ncNewNodeId()
    var quit = false

    while not quit:
        quit = true
        for n in ncServer.nodes:
            if result == n:
                # NodeId already in use, choose a new one
                result = ncNewNodeId()
                quit = false

proc ncSendNewNodeId(ncServer: NCServer, client: AsyncSocket, newId: NCNodeID) {. async .} =
    echo("NCServer.ncSendNewNodeId()")

    let message = ncWelcomeMessage(newId)
    await(ncSendMessageToNode(client, ncServer.key, message))

proc ncValidNodeId(ncServer: NCServer, id: NCNodeID) =
    echo("NCServer.ncValidNodeId(), id: ", id)

proc ncHandleClient(ncServer: NCServer, client: AsyncSocket) {. async .} =
    echo("NCServer.ncHandleClient()")

    let (clientAddr, clientPort) = client.getPeerAddr()
    echo(fmt("Connection from: {clientAddr}, port: {clientPort.uint16}"))

    let serverMessage = await(ncReceiveMessageFromNode(client, ncServer.key))

    # TODO: write code to handle clients
    case serverMessage.kind:
    of NCServerMsgKind.registerNewNode:
        # Create a new node id and send it to the node
        let newId = ncServer.ncCreateNewNodeId()
        await(ncServer.ncSendNewNodeId(client, newId))
    of NCServerMsgKind.needsData:
        discard
        # asyncdispatch: hasPendingOperations(), poll(10)
        # if ncServer.ncValidNodeId(serverMessage.id):
        # if ncServer.dataManager.ncIsDone():
        #
        # else:
        # let newData = toFlatty(ncServer.dataManader.ncGetNewData())
        # let message = NCMessageToNode(NCNodeMsgKind.newData, newData)
        # await(ncSendMessageToNode)
    of NCServerMsgKind.processedData:
        discard
        # if ncServer.ncValidNodeId(serverMessage.id):
        # ncServer.dataManager.ncCollectData(serverMessage.data)
    of NCServerMsgKind.heartbeat:
        discard
        # if ncServer.ncValidNodeId(serverMessage.id):
        # ncServer.ncProcessHearbeat(serverMessage.data)


proc ncServe(ncServer: NCServer) {. async .} =
    echo("NCServer.ncServe()")

    let server = newAsyncSocket()
    server.setSockOpt(OptReuseAddr, true)
    server.bindAddr(ncServer.serverPort)
    server.listen()

    # Create futures outside the while loop once
    # and then create new futures inside the loop
    var hbFuture = ncServer.ncCheckNodesHeartbeat()
    var srvFuture = server.accept()

    while not ncServer.quit:
        asyncCheck(hbFuture)
        asyncCheck(srvFuture)
        await(hbFuture or srvFuture)

        if srvFuture.finished() and not srvFuture.failed():
            let client = srvFuture.read()
            let clientFuture = ncServer.ncHandleClient(client)

            # Create a new fresh future here since
            # the old one is already done
            srvFuture = server.accept()
            #srvFuture.clean()

            asyncCheck(clientFuture)
            await(clientFuture)

        if hbFuture.finished() and not hbFuture.failed():
            # Create a new fresh future here since
            # the old one is already done
            hbFuture = ncServer.ncCheckNodesHeartbeat()
            #bhFuture.clean()

proc ncRun*(config: NCConfiguration) =
    echo("Starting NCServer with port: ", config.serverPort.uint16)

    # Initiate the random number genertator
    randomize()

    var ncServer = NCServer()

    ncServer.serverPort = config.serverPort

    # Cast key from string to array[32, byte] for chacha20 (32 bytes)
    let keyStr = config.secretKey
    assert(keyStr.len() == len(Key))
    let key = cast[ptr(Key)](unsafeAddr(keyStr[0]))

    ncServer.key = key[]
    ncServer.heartbeatTimeout = config.heartbeatTimeout

    let serverFuture = ncServer.ncServe()
    asyncCheck(serverFuture)
    waitFor(serverFuture)

proc ncRun*(fileName: string) =
    echo("Load configration from file: ", fileName)

    let config = ncLoadConfig(fileName)
    ncRun(config)
