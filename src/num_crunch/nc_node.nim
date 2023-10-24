
# Nim std imports
import std/typedthreads

from std/os import sleep
from std/strformat import fmt
from std/net import Port

# External imports
from chacha20 import Key

# Local imports
import private/nc_message
import nc_config
import nc_log
import nc_nodeid
import nc_common

type
    NCNode* = object
        serverAddr: string
        serverPort: Port
        key: Key
        # In seconds
        heartbeatTimeout: uint16
        nodeId: NCNodeID

    NCDPNode* = concept dp
        dp.init(type seq[byte])
        dp.processData(type seq[byte]) is seq[byte]

var ncNodeInstance: NCNode

#var ncDPInstance: ptr

proc sendHeartbeat() {.thread.} =
    ncDebug("NCNode.sendHeartbeat()", 2)
    {.cast(gcsafe).}:
        let timeOut = int(ncNodeInstance.heartbeatTimeout * 1000)
        let serverAddr = ncNodeInstance.serverAddr
        let serverPort = ncNodeInstance.serverPort
        let key = ncNodeInstance.key
        let nodeId = ncNodeInstance.nodeId

    while true:
        sleep(timeOut)

        # Send heartbeat message to server
        ncDebug(fmt("NCNode.sendHeartbeat(), Node {nodeId} sends heartbeat message to server"))
        let serverResponse = ncSendHeartbeatMessage(serverAddr, serverPort, key, nodeId)

        case serverResponse.kind:
        of NCNodeMsgKind.quit:
            ncInfo("NCNode.sendHeartbeat(), All work is done, will exit now")
            break
        of NCNodeMsgKind.ok:
            # Everything is fine, nothing more to do
            discard
        else:
            ncError(fmt("NCNode.sendHeartbeat(), Unknown response: {serverResponse.kind}"))
            break

proc runNode*() =
    ncInfo("NCNode.runNode()")

    let serverAddr = ncNodeInstance.serverAddr
    let serverPort = ncNodeInstance.serverPort
    let key = ncNodeInstance.key

    let serverResponse = ncRegisterNewNode(serverAddr, serverPort, key)

    case serverResponse.kind:
    of NCNodeMsgKind.welcome:
        let (nodeId, initData) = ncFromBytes(serverResponse.data, (NCNodeID, seq[byte]))
        ncInfo(fmt("NCNode.runNode(), Got new node id: {nodeId}"))
        ncNodeInstance.nodeId = nodeId
        #ncDPInstance.init(initData)
    of NCNodeMsgKind.quit:
        ncInfo("NCNode.runNode(), All work is done, will exit now")
        return
    else:
        ncError(fmt("NCNode.runNode(), Unknown response: {serverResponse.kind}"))
        return

    var hbThreadId: Thread[void]
    createThread(hbThreadId, sendHeartbeat)

    let nodeId = ncNodeInstance.nodeId

    while true:
        # # Do not flood the server with requests
        sleep(100)
        let serverResponse = ncNodeNeedsData(serverAddr, serverPort, key, nodeId)

        case serverResponse.kind:
        of NCNodeMsgKind.quit:
            ncInfo("NCNode.runNode(), All work is done, will exit now")
            break
        of NCNodeMsgKind.newData:
            ncDebug("NCNode.runNode(), Got new data to process")
            #let processedData = ncDPInstance.processData(serverResponse.data)
            let processedData: seq[byte] = @[]
            ncDebug("NCNode.runNode(), Processing done, send result back to server", 2)

            let serverResponse = ncSendProcessedData(serverAddr, serverPort, key, nodeId, processedData)

            case serverResponse.kind:
            of NCNodeMsgKind.quit:
                ncInfo("NCNode.runNode(), All work is done, will exit now")
                break
            of NCNodeMsgKind.ok:
                # Everything is fine, nothing more to do
                discard
            else:
                ncError(fmt("NCNode.runNode(), Unknown response: {serverResponse.kind}"))
                break
        else:
            ncError(fmt("NCNode.runNode(), Unknown response: {serverResponse.kind}"))
            break

    ncDebug("NCNode.runNode(), Waiting for other thread to finish...")

    # Try to join the heartbeat thread
    if not hbThreadId.running():
        joinThread(hbThreadId)

    ncInfo("NCNode.runNode(), Will exit now!")

proc ncInitNode*[T: NCDPNode](dataProcessor: T, ncConfig: NCConfiguration) =
    ncInfo("ncInitNode(config)")

    var ncNode = NCNode()

    ncNode.serverPort = ncConfig.serverPort
    ncNode.serverAddr = ncConfig.serverAddr
    # Cast key from string to array[32, byte] for chacha20 (32 bytes)
    let keyStr = ncConfig.secretKey
    ncDebug(fmt("ncInitNode(config), Key length: {keyStr.len()}"))
    assert(keyStr.len() == len(Key), "ncInitNode(config), Key must be exactly 32 bytes long")
    let key = cast[ptr(Key)](unsafeAddr(keyStr[0]))

    ncNode.key = key[]
    ncNode.heartbeatTimeout = ncConfig.heartbeatTimeout

    ncNodeInstance = ncNode
    #ncDPInstance = allocShared0(sizeof(T))
    #ncDPInstance = dataProcessor

proc ncInitNode*[T: NCDPNode](dataProcessor: T, filename: string) =
    ncInfo(fmt("ncInitNode({fileName})"))

    let config = ncLoadConfig(fileName)
    ncInitNode(dataProcessor, config)

