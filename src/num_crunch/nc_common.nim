
# Nim std imports
import std/[asyncnet, asyncdispatch]
from std/random import rand

# External imports
from chacha20 import chacha20, Key, Nonce
from supersnappy import uncompress, compress
from flatty import fromFlatty, toFlatty
from std/endians import bigEndian32

type
    NCNodeID* = object
        id*: string

func `==`*(left, right: NCNodeID): bool =
    left.id == right.id

type
    NCNodeMessage* = object
        kind*: string # TODO: use enum
        id*: NCNodeID
        data*: string

type
    NCServerMessage* = object
        kind*: string # TODO: use enum
        data*: string

proc ncReceiveMessage(socket: AsyncSocket, key: Key): Future[string] {. async .} =
    echo("ncReceiveMessage")

    # Read the length of the whole data set (4 bytes)
    let dataLenStr = await(socket.recv(4))
    var dataLen = 0
    # Convert binary data into integer value
    bigEndian32(unsafeAddr(dataLen), unsafeAddr(dataLenStr[0]))

    # Read the nonce for decrypting with chacha20 (12 bytes)
    let nonceStr = await(socket.recv(len(Nonce)))
    # Cast nonce from string to array[12, byte] for chacha20 (12 bytes)
    let nonce = cast[ptr(Nonce)](unsafeAddr(nonceStr[0]))

    # Read rest of the data (encrypted)
    let dataEncrypted = await(socket.recv(dataLen))

    # Decrypt data using chacha20
    # https://git.sr.ht/~ehmry/chacha20
    let dataDecrypted = chacha20(dataEncrypted, key, nonce[])

    # Decompress data using supersnappy
    # https://github.com/guzba/supersnappy
    let dataUncompressed = uncompress(dataDecrypted)

    return dataUncompressed

proc ncReceiveNodeMessage*(nodeSocket: AsyncSocket, key: Key): Future[NCNodeMessage] {. async .} =
    echo("ncReceiveNodeMessage")

    let message = await(ncReceiveMessage(nodeSocket, key))

    # Deserialize data using flatty
    # https://github.com/treeform/flatty
    let nodeMessage = fromFlatty(message, NCNodeMessage)

    return nodeMessage

proc ncReceiveServerMessage*(serverSocket: AsyncSocket, key: Key): Future[NCServerMessage] {. async .} =
    echo("ncReceiveServerMessage")

    let message = await(ncReceiveMessage(serverSocket, key))

    # Deserialize data using flatty
    # https://github.com/treeform/flatty
    let serverMessage = fromFlatty(message, NCServerMessage)

    return serverMessage

proc ncSendMessage(socket: AsyncSocket, key: Key, data: string) {. async .} =
    echo("ncSendMessage")

    # Compress data using supersnappy
    # https://github.com/guzba/supersnappy
    let dataCompressed = compress(data)

    var nonce: Nonce

    for i in 0..nonce.len():
        nonce[i] = byte(rand(255))

    # Encrypt data using chacha20
    # https://git.sr.ht/~ehmry/chacha20
    let dataEncrypted = chacha20(dataCompressed, key, nonce)

    let dataLen = dataEncrypted.len()
    let dataLenStr = newString(4)

    # Convert binary data into integer value
    bigEndian32(unsafeAddr(dataLenStr), unsafeAddr(dataLen))

    # Send data length to socket
    await(socket.send(dataLenStr))

    let nonceStr = newString(nonce.len())
    copyMem(unsafeAddr(nonceStr[0]), unsafeAddr(nonce), nonce.len())

    # Send nonce to socket
    await(socket.send(nonceStr))

    # Send the encrypted data to socket
    await(socket.send(dataEncrypted))

proc ncSendNodeMessage*(nodeSocket: AsyncSocket, key: Key, nodeMessage: NCNodeMessage) {. async .} =
    echo("ncSendNodeMessage")

    # Serialize using Flatty
    # https://github.com/treeform/flatty
    let data = toFlatty(nodeMessage)

    await(ncSendMessage(nodeSocket, key, data))

proc ncSendServerMessage*(serverSocket: AsyncSocket, key: Key, serverMessage: NCServerMessage) {. async .} =
    echo("ncSendServerMessage")

    # Serialize using Flatty
    # https://github.com/treeform/flatty
    let data = toFlatty(serverMessage)

    await(ncSendMessage(serverSocket, key, data))
