
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
        heartbeatTimeout: uint16 # In seconds
        nodeId: NCNodeID

    NCNodeDataProcessor* = ref object of RootObj

var ncNodeInstance: ptr NCNode

var ncDPInstance: ptr NCNodeDataProcessor

method init(self: var NCNodeDataProcessor, data: seq[byte]) {.base.} =
    discard

method processData(self: var NCNodeDataProcessor, data: seq[byte]): seq[byte] {.base.} =
    quit("You must override this method: processData")

proc sendHeartbeat() {.thread.} =
    ncDebug("sendHeartbeat()", 2)
    let timeOut = int(ncNodeInstance.heartbeatTimeout * 1000)
    let serverAddr = ncNodeInstance.serverAddr
    let serverPort = ncNodeInstance.serverPort
    let key = ncNodeInstance.key
    let nodeId = ncNodeInstance.nodeId

    while true:
        sleep(timeOut)

        # Send heartbeat message to server
        ncDebug(fmt("sendHeartbeat(), Node {nodeId} sends heartbeat message to server"))
        let serverResponse = ncSendHeartbeatMessage(serverAddr, serverPort, key, nodeId)

        case serverResponse.kind:
            of NCNodeMsgKind.quit:
                ncInfo("sendHeartbeat(), All work is done, will exit now")
                break
            of NCNodeMsgKind.ok:
                # Everything is fine, nothing more to do
                discard
            else:
                ncError(fmt("sendHeartbeat(), Unknown response: {serverResponse.kind}"))
                break

proc ncRunNode*() =
    let serverAddr = ncNodeInstance.serverAddr
    let serverPort = ncNodeInstance.serverPort
    let key = ncNodeInstance.key

    let serverResponse = ncRegisterNewNode(serverAddr, serverPort, key)

    case serverResponse.kind:
        of NCNodeMsgKind.welcome:
            let (nodeId, initData) = ncFromBytes(serverResponse.data, (NCNodeID, seq[byte]))
            ncInfo(fmt("ncRunNode(), Got new node id: {nodeId}"))
            ncNodeInstance.nodeId = nodeId
            ncDPInstance[].init(initData)
        of NCNodeMsgKind.quit:
            ncInfo("ncRunNode(), All work is done, will exit now")
            return
        else:
            ncError(fmt("ncRunNode(), Unknown response: {serverResponse.kind}"))
            return

    var hbThreadId: Thread[void]
    createThread(hbThreadId, sendHeartbeat)

    let nodeId = ncNodeInstance.nodeId

    while true:
        # Do not flood the server with requests
        sleep(100)
        let serverResponse = ncNodeNeedsData(serverAddr, serverPort, key, nodeId)

        case serverResponse.kind:
            of NCNodeMsgKind.quit:
                ncInfo("ncRunNode(), All work is done, will exit now")
                break
            of NCNodeMsgKind.newData:
                ncDebug("ncRunNode(), Got new data to process")
                let processedData = ncDPInstance[].processData(serverResponse.data)
                ncDebug("ncRunNode(), Processing done, send result back to server", 2)

                let serverResponse = ncSendProcessedData(serverAddr, serverPort, key, nodeId, processedData)

                case serverResponse.kind:
                    of NCNodeMsgKind.quit:
                        ncInfo("ncRunNode(), All work is done, will exit now")
                        break
                    of NCNodeMsgKind.ok:
                        # Everything is fine, nothing more to do
                        discard
                    else:
                        ncError(fmt("ncRunNode(), Unknown response: {serverResponse.kind}"))
                        break
            else:
                ncError(fmt("ncRunNode(), Unknown response: {serverResponse.kind}"))
                break

    ncDebug("ncRunNode(), Waiting for other thread to finish...")

    # Try to join the heartbeat thread
    if not hbThreadId.running():
        joinThread(hbThreadId)

    ncInfo("ncRunNode(), free memory")

    reset(ncNodeInstance.serverAddr)
    reset(ncNodeInstance.key)
    deallocShared(ncNodeInstance)
    deallocShared(ncDPInstance)

    ncInfo("ncRunNode(), Will exit now!")

proc ncInitNode*(dataProcessor: NCNodeDataProcessor, ncConfig: NCConfiguration) =
    ncInfo("ncInitNode(config)")

    ncNodeInstance = createShared(NCNode)
    ncNodeInstance.serverPort = ncConfig.serverPort
    ncNodeInstance.serverAddr = ncConfig.serverAddr
    # Cast key from string to array[32, byte] for chacha20 (32 bytes)
    let keyStr = ncConfig.secretKey
    ncDebug(fmt("ncInitNode(config), Key length: {keyStr.len()}"))
    assert(keyStr.len() == len(Key), "ncInitNode(config), Key must be exactly 32 bytes long")
    let key = cast[ptr(Key)](unsafeAddr(keyStr[0]))

    ncNodeInstance.key = key[]
    ncNodeInstance.heartbeatTimeout = ncConfig.heartbeatTimeout

    ncDPInstance = createShared(NCNodeDataProcessor)
    moveMem(ncDPInstance, dataProcessor.addr, sizeof(NCNodeDataProcessor))

proc ncInitNode*(dataProcessor: NCNodeDataProcessor, filename: string) =
    ncInfo(fmt("ncInitNode({fileName})"))

    let config = ncLoadConfig(fileName)
    ncInitNode(dataProcessor, config)

