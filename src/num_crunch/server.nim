
# Nim std imports
import std/[asyncnet, asyncdispatch]
from std/strformat import fmt
from std/nativesockets import Port
from std/endians import bigEndian32

# External imports
from chacha20 import chacha20
from supersnappy import uncompress
from flatty import fromFlatty

# Local imports
import common

proc decodeNodeMessage(client: AsyncSocket, keyStr: string): Future[NCNodeMessage] {. async .} =
    echo("decodeNodeMessage")

    const
        nonceLength = 12
        keyLength = 32

    # Read the length of the whole data set (4 bytes)
    let dataLenStr = await(client.recv(4))
    var dataLen = 0
    # Convert binary data into integer value
    bigEndian32(unsafeAddr(dataLen), unsafeAddr(dataLenStr[0]))

    # Read the nonce for decrypting with chacha20 (12 bytes)
    let nonceStr = await(client.recv(nonceLength))
    # Cast nonce from string to array[12, byte] for chacha20 (12 bytes)
    let nonce = cast[ptr(array[nonceLength, byte])](unsafeAddr(nonceStr[0]))

    # Read rest of the data (encrypted)
    let dataEncrypted = await(client.recv(dataLen))

    # Cast key from string to array[32, byte] for chacha20 (32 bytes)
    assert(keyStr.len() == keyLength)
    let key = cast[ptr(array[keyLength, byte])](unsafeAddr(keyStr[0]))

    # Decrypt data using chacha20
    # https://git.sr.ht/~ehmry/chacha20
    let dataDecrypted = chacha20(dataEncrypted, key[], nonce[])

    # Decompress data using supersnappy
    # https://github.com/guzba/supersnappy
    let dataUncompressed = uncompress(dataDecrypted)

    # Deserialize data using flatty
    # https://github.com/treeform/flatty
    let nodeMessage: NCNodeMessage = fromFlatty(dataUncompressed, NCNodeMessage)

    return nodeMessage

type
    NCServer* = object
        serverPort: Port
        key: string
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
    echo(fmt("Connection from: {clientAddr}, port: {clientPort}"))

    let nodeMessage = decodeNodeMessage(client, ncServer.key)
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

proc run*(ncServer: var NCServer, config: NCConfiguration) =
    echo("Starting NCServer with port: ", config.serverPort)

    ncServer.serverPort = config.serverPort
    ncServer.key = config.secretKey
    ncServer.heartbeatTimeout = config.heartbeatTimeout

    let serverFuture = ncServer.serve()
    asyncCheck(serverFuture)
    waitFor(serverFuture)
