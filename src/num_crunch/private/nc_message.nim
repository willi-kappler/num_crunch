
# Nim std imports
import std/net
from std/random import rand

# External imports
from chacha20 import chacha20, Key, Nonce
from supersnappy import uncompress, compress
from flatty import fromFlatty, toFlatty
from std/endians import bigEndian32

# Internal imports
import ../nc_nodeid
import nc_log

type
    NCNodeMsgKind* = enum
        welcome, newData, quit
    NCNodeMessage* = object
        kind*: NCNodeMsgKind
        data*: seq[byte]
    NCMessageToNode* = NCNodeMessage
    NCMessageFromServer* = NCNodeMessage

type
    NCServerMsgKind* = enum
        registerNewNode, needsData, processedData, heartbeat, checkHeartbeat, getStatistics,
        forceQuit
    NCServerMessage* = object
        kind*: NCServerMsgKind
        id*: NCNodeID
        data*: seq[byte]
    NCMessageToServer* = NCServerMessage
    NCMessageFromNode* = NCServerMessage

func ncStrToInt*(s: string): uint32 =
    assert(s.len() == 4)
    result = 0
    bigEndian32(unsafeAddr(result), unsafeAddr(s[0]))

func ncIntToStr*(i: uint32): string =
    result = newString(4)
    bigEndian32(unsafeAddr(result[0]), unsafeAddr(i))

func ncStrToBytes*(s: string): seq[byte] =
    @(s.toOpenArrayByte(0, s.high()))

func ncBytesToStr*(s: seq[byte]): string =
    let l = s.len()
    result = newString(l)

    if l > 0:
        copyMem(unsafeAddr(result[0]), unsafeAddr(s[0]), l)

func ncNonceToStr(n: Nonce): string =
    let l = n.len()
    result = newString(l)
    copyMem(unsafeAddr(result[0]), unsafeAddr(n[0]), l)

func ncStrToNonce(s: string): ptr Nonce =
    assert(s.len() == len(Nonce))
    result = cast[ptr(Nonce)](unsafeAddr(s[0]))

proc ncDecodeMessage*(data: string, key: Key, nonce: Nonce): string =
    ncDebug("ncDecodeMessage()")
    #echo("ncDecodeMessage(), data len: ", data.len())

    # Decrypt data using chacha20
    # https://git.sr.ht/~ehmry/chacha20
    let dataDecrypted = chacha20(data, key, nonce)
    #echo("ncDecodeMessage(), data decrypted")

    # Decompress data using supersnappy
    # https://github.com/guzba/supersnappy
    let dataUncompressed = uncompress(dataDecrypted)
    #echo("ncDecodeMessage(), data uncompressed")

    return dataUncompressed

proc ncReceiveMessage(socket: Socket, key: Key): string =
    ncDebug("ncReceiveMessage()")

    # Read the length of the whole data set (4 bytes)
    let dataLenStr = socket.recv(4)
    # Convert binary data into integer value
    var dataLen = ncStrToInt(dataLenStr)
    # bigEndian32(unsafeAddr(dataLen), unsafeAddr(dataLenStr[0]))

    # Read the nonce for decrypting with chacha20 (12 bytes)
    let nonceStr = socket.recv(len(Nonce))
    # Cast nonce from string to array[12, byte] for chacha20 (12 bytes)
    let nonce = ncStrToNonce(nonceStr)

    # Read rest of the data (encrypted)
    let dataEncrypted = socket.recv(int(dataLen))

    return ncDecodeMessage(dataEncrypted, key, nonce[])

proc ncReceiveMessageFromNode*(nodeSocket: Socket, key: Key): NCMessageFromNode =
    ncDebug("ncReceiveNodeMessage()")

    let message = ncReceiveMessage(nodeSocket, key)

    # Deserialize data using flatty
    # https://github.com/treeform/flatty
    let nodeMessage = fromFlatty(message, NCMessageFromNode)

    return nodeMessage

proc ncReceiveMessageFromServer*(serverSocket: Socket, key: Key): NCMessageFromServer =
    ncDebug("ncReceiveServerMessage()")

    let message = ncReceiveMessage(serverSocket, key)

    # Deserialize data using flatty
    # https://github.com/treeform/flatty
    let serverMessage = fromFlatty(message, NCMessageFromServer)

    return serverMessage

proc ncEncodeMessage*(data: string, key: Key, nonce: Nonce): string =
    ncDebug("ncEncodeMessage()")
    #echo("ncEncodeMessage(), data len: ", data.len())
    #echo("ncEncodeMessage(), key: ", key)
    #echo("ncEncodeMessage(), nonce: ", nonce)

    # Compress data using supersnappy
    # https://github.com/guzba/supersnappy
    let dataCompressed = compress(data)
    #echo("ncEncodeMessage(), data compressed")
    #echo("ncEncodeMessage(), dataCompressed, type: ", type(dataCompressed))
    #echo("ncEncodeMessage(), data len: ", dataCompressed.len())

    # Encrypt data using chacha20
    # https://git.sr.ht/~ehmry/chacha20
    result = chacha20(dataCompressed, key, nonce)
    #echo("ncEncodeMessage(), data encrypted")

proc ncSendMessage(socket: Socket, key: Key, data: string) =
    ncDebug("ncSendMessage()")
    #echo("ncSendMessage(), data len: ", data.len())

    var nonce: Nonce

    for i in 0..<nonce.len():
        nonce[i] = byte(rand(255))

    #echo("ncSendMessage(), nonce is ready")
    let dataEncrypted = ncEncodeMessage(data, key, nonce)
    #echo("ncSendMessage(), data encrypted")

    let dataLen = uint32(dataEncrypted.len())
    # Convert binary data into integer value
    let dataLenStr = ncIntToStr(dataLen)
    # bigEndian32(unsafeAddr(dataLenStr), unsafeAddr(dataLen))
    #echo("ncSendMessage(), string conversion done")

    # Send data length to socket
    socket.send(dataLenStr)
    #echo("ncSendMessage(), data length sent")

    let nonceStr = ncNonceToStr(nonce)

    # Send nonce to socket
    socket.send(nonceStr)
    #echo("ncSendMessage(), nonce sent")

    # Send the encrypted data to socket
    socket.send(dataEncrypted)
    #echo("ncSendMessage(), encrypted data sent")

proc ncSendMessageToNode*(nodeSocket: Socket, key: Key, nodeMessage: NCMessageToNode) =
    ncDebug("ncSendNodeMessage()")

    # Serialize using Flatty
    # https://github.com/treeform/flatty
    let data = toFlatty(nodeMessage)

    ncSendMessage(nodeSocket, key, data)

proc ncSendMessageToServer*(serverSocket: Socket, key: Key, serverMessage: NCMessageToServer) =
    ncDebug("ncSendServerMessage()")

    # Serialize using Flatty
    # https://github.com/treeform/flatty
    let data = toFlatty(serverMessage)

    ncSendMessage(serverSocket, key, data)


