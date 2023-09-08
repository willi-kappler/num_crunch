
# Nim std imports
import std/[asyncnet, asyncdispatch]

# External imports
from chacha20 import chacha20, Key, Nonce
from supersnappy import uncompress
from flatty import fromFlatty
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

proc ncDecodeMessage(client: AsyncSocket, key: Key): Future[string] {. async .} =
    echo("ncDecodeNodeMessage")

    # Read the length of the whole data set (4 bytes)
    let dataLenStr = await(client.recv(4))
    var dataLen = 0
    # Convert binary data into integer value
    bigEndian32(unsafeAddr(dataLen), unsafeAddr(dataLenStr[0]))

    # Read the nonce for decrypting with chacha20 (12 bytes)
    let nonceStr = await(client.recv(12))
    # Cast nonce from string to array[12, byte] for chacha20 (12 bytes)
    let nonce = cast[ptr(Nonce)](unsafeAddr(nonceStr[0]))

    # Read rest of the data (encrypted)
    let dataEncrypted = await(client.recv(dataLen))

    # Decrypt data using chacha20
    # https://git.sr.ht/~ehmry/chacha20
    let dataDecrypted = chacha20(dataEncrypted, key, nonce[])

    # Decompress data using supersnappy
    # https://github.com/guzba/supersnappy
    let dataUncompressed = uncompress(dataDecrypted)

    return dataUncompressed

proc ncDecodeNodeMessage*(client: AsyncSocket, key: Key): Future[NCNodeMessage] {. async .} =
    echo("ncDecodeNodeMessage")

    let message = await(ncDecodeMessage(client, key))

    # Deserialize data using flatty
    # https://github.com/treeform/flatty
    let nodeMessage = fromFlatty(message, NCNodeMessage)

    return nodeMessage

proc ncDecodeServerMessage*(client: AsyncSocket, key: Key): Future[NCServerMessage] {. async .} =
    echo("ncDecodeServerMessage")

    let message = await(ncDecodeMessage(client, key))

    # Deserialize data using flatty
    # https://github.com/treeform/flatty
    let serverMessage = fromFlatty(message, NCServerMessage)

    return serverMessage

proc ncEncodeMessage*(client: AsyncSocket, key: Key, data: string) {. async .} =
    echo("ncEncodeMessage")
