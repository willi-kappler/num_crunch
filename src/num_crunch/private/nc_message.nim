
# Nim std imports
import std/base64
import std/httpclient

from std/random import rand
from std/strformat import fmt
from std/net import Port
from std/streams import readAll

# External imports
from chacha20 import chacha20, Key, Nonce
from supersnappy import uncompress, compress
from flatty import fromFlatty, toFlatty

# Internal imports
import ../nc_nodeid
import ../nc_log

type
    NCNodeMsgKind* = enum
        welcome, newData, quit, ok
    NCNodeMessage* = object
        kind*: NCNodeMsgKind
        data*: seq[byte]
    NCMessageToNode* = NCNodeMessage
    NCMessageFromServer* = NCNodeMessage

type
    NCServerMessage* = object
        id*: NCNodeID
        data*: seq[byte]
    NCMessageToServer* = NCServerMessage
    NCMessageFromNode* = NCServerMessage

proc ncEncodeMessage*(message: string, key: Key): string =
    var nonce: Nonce

    for i in 0..<nonce.len():
        nonce[i] = byte(rand(255))

    let message1 = compress(message)
    let message2 = chacha20(message1, key, nonce)
    let message3 = toFlatty((message2, nonce))

    #return encode(message3)
    return message3

proc ncDecodeMessage*(message: string, key: Key): string =
    let (message1, nonce) = fromFlatty(message, (string, Nonce))
    let message2 = chacha20(message1, key, nonce)
    let message3 = uncompress(message2)

    return message3

proc ncEncodeServerMessage*(message: NCServerMessage, key: Key): string =
    return ncEncodeMessage(toFlatty(message), key)

proc ncDecodeServerMessage*(message: string, key: Key): NCServerMessage =
    return fromFlatty(ncDecodeMessage(message, key), NCServerMessage)

proc ncEncodeNodeMessage*(message: NCNodeMessage, key: Key): string =
    return ncEncodeMessage(toFlatty(message), key)

proc ncDecodeNodeMessage*(message: string, key: Key): NCNodeMessage =
    return fromFlatty(ncDecodeMessage(message, key), NCNodeMessage)

proc ncSendMessageToServer(serverAddr: string, serverPort: Port, key: Key, message: NCServerMessage, path: string): string =
    let message = ncEncodeServerMessage(message, key)

    var client = newHttpClient()
    client.headers = newHttpHeaders({ "Content-Type": "application/data" })
    let response = client.request(fmt("http://{serverAddr}:{serverPort.uint16}/{path}"), httpMethod = HttpPost, body = message)
    client.close()

    return response.bodyStream.readAll()

proc ncSendHeartbeatMessage*(serverAddr: string, serverPort: Port, key: Key, nodeId: NCNodeID): NCNodeMessage =
    let message = NCServerMessage(id: nodeId)
    let response = ncSendMessageToServer(serverAddr, serverPort, key, message, "heartbeat")

    discard

proc ncRegisterNewNode*(serverAddr: string, serverPort: Port, key: Key): NCNodeMessage =
    let message = NCServerMessage()
    let response = ncSendMessageToServer(serverAddr, serverPort, key, message, "register_new_node")

    discard

proc ncNodeNeedsData*(serverAddr: string, serverPort: Port, key: Key, nodeId: NCNodeID): NCNodeMessage =
    let message = NCServerMessage(id: nodeId)
    let response = ncSendMessageToServer(serverAddr, serverPort, key, message, "node_needs_data")

    discard

proc ncSendProcessedData*(serverAddr: string, serverPort: Port, key: Key, nodeId: NCNodeID, processData: seq[byte]): NCNodeMessage =
    let message = NCServerMessage(id: nodeId, data: processData)
    let response = ncSendMessageToServer(serverAddr, serverPort, key, message, "processed_data")

    discard


