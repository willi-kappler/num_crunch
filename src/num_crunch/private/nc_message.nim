
# Nim std imports
import std/net
from std/random import rand
from std/strformat import fmt

# External imports
from chacha20 import chacha20, Key, Nonce
from supersnappy import uncompress, compress
from flatty import fromFlatty, toFlatty
from std/endians import bigEndian32

# Internal imports
import ../nc_nodeid
import ../nc_log

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
    ncDebug("ncDecodeMessage()", 2)

    # Decrypt data using chacha20
    # https://git.sr.ht/~ehmry/chacha20
    ncDebug("ncDecodeMessage(), decrypt message", 2)
    let dataDecrypted = chacha20(data, key, nonce)

    # Decompress data using supersnappy
    # https://github.com/guzba/supersnappy
    ncDebug("ncDecodeMessage(), decompress message", 2)
    let dataUncompressed = uncompress(dataDecrypted)
    ncDebug("ncDecodeMessage(), message decompressed", 2)

    return dataUncompressed

proc ncReceiveMessage(socket: Socket, key: Key): string =
    ncDebug("ncReceiveMessage()", 2)
    # Read the length of the whole data set (4 bytes)
    let dataLenStr = socket.recv(4)
    # Convert binary data into integer value
    let dataLen = int(ncStrToInt(dataLenStr))
    ncDebug(fmt("ncReceiveMessage(), dataLen: {dataLen}"), 2)

    # Read the nonce for decrypting with chacha20 (12 bytes)
    ncDebug("ncReceiveMessage(), receive nonce", 2)
    let nonceStr = socket.recv(len(Nonce))
    # Cast nonce from string to array[12, byte] for chacha20 (12 bytes)
    let nonce = ncStrToNonce(nonceStr)

    # Read rest of the data (encrypted)
    ncDebug("ncReceiveMessage(), receive data", 2)
    let dataEncrypted = socket.recv(dataLen)
    assert(dataEncrypted.len() == dataLen)
    ncDebug("ncReceiveMessage(), data received", 2)

    return ncDecodeMessage(dataEncrypted, key, nonce[])

proc ncReceiveMessageFromNode*(nodeSocket: Socket, key: Key): NCMessageFromNode =
    ncDebug("ncReceiveMessageFromNode()", 2)
    let message = ncReceiveMessage(nodeSocket, key)

    # Deserialize data using flatty
    # https://github.com/treeform/flatty
    ncDebug("ncReceiveMessageFromNode(), de-serialize data", 2)
    let nodeMessage = fromFlatty(message, NCMessageFromNode)
    ncDebug("ncReceiveMessageFromNode(), message ready", 2)

    return nodeMessage

proc ncReceiveMessageFromServer*(serverSocket: Socket, key: Key): NCMessageFromServer =
    ncDebug("ncReceiveMessageFromServer()", 2)
    let message = ncReceiveMessage(serverSocket, key)

    # Deserialize data using flatty
    # https://github.com/treeform/flatty
    ncDebug("ncReceiveMessageFromServer(), de-serialize data", 2)
    let serverMessage = fromFlatty(message, NCMessageFromServer)
    ncDebug("ncReceiveMessageFromServer(), message ready", 2)

    return serverMessage

proc ncEncodeMessage*(data: string, key: Key, nonce: Nonce): string =
    ncDebug("ncEncodeMessage()", 2)

    # Compress data using supersnappy
    # https://github.com/guzba/supersnappy
    ncDebug("ncEncodeMessage(), compress message", 2)
    let dataCompressed = compress(data)

    # Encrypt data using chacha20
    # https://git.sr.ht/~ehmry/chacha20
    ncDebug("ncEncodeMessage(), encrypt message", 2)
    let encryptedMessage = chacha20(dataCompressed, key, nonce)
    ncDebug("ncEncodeMessage(), message encrypted", 2)
    return encryptedMessage

proc ncSendMessage(socket: Socket, key: Key, data: string) =
    ncDebug("ncSendMessage()", 2)
    var nonce: Nonce

    for i in 0..<nonce.len():
        nonce[i] = byte(rand(255))

    ncDebug("ncSendMessage(), encode message", 2)
    let dataEncrypted = ncEncodeMessage(data, key, nonce)

    let dataLen = uint32(dataEncrypted.len())
    ncDebug(fmt("ncSendMessage(), dataLen: {dataLen}"), 2)
    # Convert integer value to binary data
    let dataLenStr = ncIntToStr(dataLen)

    # Send data length to socket
    ncDebug("ncSendMessage(), send message length", 2)
    socket.send(dataLenStr)

    let nonceStr = ncNonceToStr(nonce)

    # Send nonce to socket
    ncDebug("ncSendMessage(), send nonce", 2)
    socket.send(nonceStr)

    # Send the encrypted data to socket
    ncDebug("ncSendMessage(), send message", 2)
    socket.send(dataEncrypted)
    ncDebug("ncSendMessage(), message sent", 2)

proc ncSendMessageToNode*(nodeSocket: Socket, key: Key, nodeMessage: NCMessageToNode) =
    ncDebug("ncSendNodeMessage()", 2)
    # Serialize using Flatty
    # https://github.com/treeform/flatty
    let data = toFlatty(nodeMessage)

    ncSendMessage(nodeSocket, key, data)

proc ncSendMessageToServer*(serverSocket: Socket, key: Key, serverMessage: NCMessageToServer) =
    ncDebug("ncSendServerMessage()", 2)
    # Serialize using Flatty
    # https://github.com/treeform/flatty
    let data = toFlatty(serverMessage)

    ncSendMessage(serverSocket, key, data)

