
# Nim std imports
import std/net
import std/typedthreads
import std/atomics

from std/os import sleep
from std/strformat import fmt

# External imports
from chacha20 import Key

# Local imports
import private/nc_message
import nc_config
import nc_log
import nc_nodeid
import nc_common

type
    NCNode*[T: NCDPNode] = object
        serverAddr: string
        serverPort: Port
        key: Key
        # In seconds
        heartbeatTimeout: uint16
        nodeId: NCNodeID
        dataProcessor: T
        quit: Atomic[bool]

    NCDPNode* = concept dp
        dp.init(type seq[byte])
        dp.processData(type seq[byte]) is seq[byte]

proc sendHeartbeat(self: ptr NCNode) {.thread.} =
    ncDebug("NCNode.sendHeartbeat()", 2)

    let timeOut = uint(self.heartbeatTimeout * 1000)

    let heartbeatMessage = NCMessageToServer(
        kind: NCServerMsgKind.heartbeat,
        id: self.nodeId)

    while not self.quit.load():
        sleep(int(timeOut))

        # Send heartbeat message to server
        ncDebug(fmt("Node {self.nodeId} sends heartbeat message to server"))
        let nodeSocket = newSocket()
        nodeSocket.connect(self.serverAddr, self.serverPort)
        ncSendMessageToServer(nodeSocket, self.key, heartbeatMessage)
        nodeSocket.close()

proc runNode*(self: var NCNode) =
    ncInfo("NCNode.runNode()")

    let nodeSocket = newSocket()
    let registerMessage = NCMessageToServer(kind: NCServerMsgKind.registerNewNode)
    nodeSocket.connect(self.serverAddr, self.serverPort)
    ncSendMessageToServer(nodeSocket, self.key, registerMessage)
    let serverResponse = ncReceiveMessageFromServer(nodeSocket, self.key)
    nodeSocket.close()

    case serverResponse.kind:
    of NCNodeMsgKind.welcome:
        let (nodeId, initData) = ncFromBytes(serverResponse.data, (NCNodeID, seq[byte]))
        ncInfo(fmt("Got new node id: {nodeId}"))
        self.nodeId = nodeId
        self.dataProcessor.init(initData)

    of NCNodeMsgKind.quit:
        ncInfo("All work is done, will exit now")
        self.quit.store(true)
        return

    else:
        ncError(fmt("Unknown response: {serverResponse.kind}"))
        return

    var hbThreadId: Thread[ptr NCNode]
    createThread(hbThreadId, sendHeartbeat, unsafeAddr(self))

    let needDataMessage = NCMessageToServer(
        kind: NCServerMsgKind.needsData,
        id: self.nodeId)

    while not self.quit.load():
        ncDebug("Send message to server: need new data")
        let nodeSocket = newSocket()
        nodeSocket.connect(self.serverAddr, self.serverPort)
        ncSendMessageToServer(nodeSocket, self.key, needDataMessage)
        let serverResponse = ncReceiveMessageFromServer(nodeSocket, self.key)
        nodeSocket.close()

        case serverResponse.kind:
        of NCNodeMsgKind.quit:
            ncInfo("All work is done, will exit now")
            self.quit.store(true)

        of NCNodeMsgKind.newData:
            ncDebug("Got new data to process")
            let processedData = self.dataProcessor.processData(serverResponse.data)
            ncDebug("Processing done, send result back to server", 2)
            let processedDataMessage = NCMessageToServer(
                kind: NCServerMsgKind.processedData,
                data: processedData,
                id: self.nodeId)
            let nodeSocket = newSocket()
            nodeSocket.connect(self.serverAddr, self.serverPort)
            ncSendMessageToServer(nodeSocket, self.key, processedDataMessage)
            # Wait for server to receive data
            sleep(100)
            nodeSocket.close()

        else:
            ncError(fmt("Unknown response: {serverResponse.kind}"))
            self.quit.store(true)

    ncDebug("Waiting for other thread to finish...")
    # Try to join the heartbeat thread

    if not hbThreadId.running():
        joinThread(hbThreadId)

    ncInfo("Will exit now!")

proc ncInitNode*[T: NCDPNode](dataProcessor: T, ncConfig: NCConfiguration): NCNode[T] =
    ncInfo("ncInitNode(config)")

    var ncNode = NCNode[T](dataProcessor: dataProcessor)

    ncNode.serverPort = ncConfig.serverPort
    ncNode.serverAddr = ncConfig.serverAddr
    # Cast key from string to array[32, byte] for chacha20 (32 bytes)
    let keyStr = ncConfig.secretKey
    ncDebug(fmt("Key length: {keyStr.len()}"))
    assert(keyStr.len() == len(Key), "Key must be exactly 32 bytes long")
    let key = cast[ptr(Key)](unsafeAddr(keyStr[0]))

    ncNode.key = key[]
    ncNode.heartbeatTimeout = ncConfig.heartbeatTimeout

    return ncNode

proc ncInitNode*[T: NCDPNode](dataProcessor: T, filename: string): NCNode[T] =
    ncInfo(fmt("ncInitNode({fileName})"))

    let config = ncLoadConfig(fileName)
    ncInitNode(dataProcessor, config)

