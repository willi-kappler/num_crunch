
# Nim std imports
import std/[asyncnet, asyncdispatch]
from std/strformat import fmt
from std/nativesockets import Port
from std/random import randomize

# External imports
from chacha20 import Key

# Local imports
import nc_common
import nc_config

type
    NCServer* = object
        serverPort: Port
        key: Key
        # In seconds
        heartbeatTimeout: uint16
        nodes: seq[NCNodeID]
        quit: bool

proc checkHeartbeat(ncServer: NCServer) {. async .} =
    echo("NCServer.checkHeartbeat()")
    # Convert from seconds to miliseconds
    # and add a small tolerance for the client nodes
    let tolerance: uint = 100 # 100 ms tolerance
    let timeOut = (uint(ncServer.heartbeatTimeout) * 1000) + tolerance

    await(sleepAsync(int(timeOut)))
    # TODO: check the heartbeat messages and times for each node
    echo("Check heartbeat for all nodes")

proc handleClient(ncServer: NCServer, client: AsyncSocket) {. async .} =
    echo("NCServer.handleClient()")
    let (clientAddr, clientPort) = client.getPeerAddr()
    echo(fmt("Connection from: {clientAddr}, port: {clientPort.uint16}"))

    let nodeMessage = ncReceiveNodeMessage(client, ncServer.key)
    # TODO: write code to handle clients

proc serve(ncServer: NCServer) {. async .} =
    let server = newAsyncSocket()
    server.setSockOpt(OptReuseAddr, true)
    server.bindAddr(ncServer.serverPort)
    server.listen()

    # Create futures outside the while loop once
    # and then create new futures inside the loop
    var hbFuture = ncServer.checkHeartbeat()
    var srvFuture = server.accept()

    while not ncServer.quit:
        asyncCheck(hbFuture)
        asyncCheck(srvFuture)
        await(hbFuture or srvFuture)

        if srvFuture.finished() and not srvFuture.failed():
            let client = srvFuture.read()
            let clientFuture = ncServer.handleClient(client)

            # Create a new fresh future here since
            # the old one is already done
            srvFuture = server.accept()

            asyncCheck(clientFuture)
            await(clientFuture)

        if hbFuture.finished() and not hbFuture.failed():
            # Create a new fresh future here since
            # the old one is already done
            hbFuture = ncServer.checkHeartbeat()

proc run*(config: NCConfiguration) =
    echo("Starting NCServer with port: ", config.serverPort.uint16)

    # Initiate the random number genertator
    randomize()

    var ncServer = NCServer()

    ncServer.serverPort = config.serverPort

    # Cast key from string to array[32, byte] for chacha20 (32 bytes)
    let keyStr = config.secretKey
    assert(keyStr.len() == 32)
    let key = cast[ptr(Key)](unsafeAddr(keyStr[0]))

    ncServer.key = key[]
    ncServer.heartbeatTimeout = config.heartbeatTimeout

    let serverFuture = ncServer.serve()
    asyncCheck(serverFuture)
    waitFor(serverFuture)

proc run*(fileName: string) =
    echo("Load configration from file: ", fileName)

    let config = ncLoadConfig(fileName)
    run(config)
