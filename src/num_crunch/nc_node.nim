
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
import private/nc_nodeid
import nc_config

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
        dp.processData(type seq[byte]) is seq[byte]

proc ncSendHeartbeat(self: ptr NCNode) {.thread.} =
    echo("NCNode.ncSendHeartbeat()")

    let timeOut = uint(self.heartbeatTimeout)

    let heartbeatMessage = NCMessageToServer(kind: NCServerMsgKind.heartbeat)
    let nodeSocket = newSocket()

    while not self.quit.load():
        sleep(int(timeOut))

        # Send heartbeat message to server
        nodeSocket.connect(self.serverAddr, self.serverPort)
        ncSendMessageToServer(nodeSocket, self.key, heartbeatMessage)
        nodeSocket.close()

proc ncRunNode*(self: var NCNode) =
    echo("NCNode.ncRunNode()")

    var hbThreadId: Thread[ptr NCNode]
    var nodeId: NCNodeID

    createThread(hbThreadId, ncSendHeartbeat, unsafeAddr(self))

    let nodeSocket = newSocket()
    let registerMessage = NCMessageToServer(kind: NCServerMsgKind.registerNewNode)
    nodeSocket.connect(self.serverAddr, self.serverPort)
    ncSendMessageToServer(nodeSocket, self.key, registerMessage)
    let serverResponse = ncReceiveMessageFromServer(nodeSocket, self.key)
    nodeSocket.close()

    case serverResponse.kind:
    of NCNodeMsgKind.welcome:
        echo("Got new node id: ", serverResponse.id)
        nodeId = serverResponse.id

    of NCNodeMsgKind.quit:
        echo("All work is done, will exit now")
        self.quit.store(true)
        return

    else:
        echo("Unknown response: ", serverResponse.kind)
        return

    let needDataMessage = NCMessageToServer(kind: NCServerMsgKind.needsData, id = nodeId)

    while not self.quit.load():
        nodeSocket.connect(self.serverAddr, self.serverPort)
        ncSendMessageToServer(nodeSocket, self.key, needDataMessage)
        let serverResponse = ncReceiveMessageFromServer(nodeSocket, self.key)
        nodeSocket.close()

        case serverResponse.kind:
        of NCNodeMsgKind.quit:
            echo("All work is done, will exit now")
            self.quit.store(true)

        of NCNodeMsgKind.newData:
            echo("Got new data to process")
            let processedData = self.dataProcessor.processData(serverResponse.data)
            let processedDataMessage = NCMessageToServer(kind: NCServerMsgKind.processedData, data: processedData)
            nodeSocket.connect(self.serverAddr, self.serverPort)
            ncSendMessageToServer(nodeSocket, self.key, processedDataMessage)
            nodeSocket.close()

        else:
            echo("Unknown response: ", serverResponse.kind)
            self.quit.store(true)

    echo("Waiting for other thread to finish...")
    # Try to join the heartbeat thread
    sleep(10*1000) # Wait 10 seconds to give the thread a chance to finish

    if not hbThreadId.running():
        joinThread(hbThreadId)

    echo("Will exit now!")

proc ncInitNode*[T: NCDPNode](dataProcessor: T, ncConfig: NCConfiguration): NCNode[T] =
    echo("ncInitNode(config)")

    var ncNode = NCNode[T](dataProcessor: dataProcessor)

    ncNode.serverPort = ncConfig.serverPort
    ncNode.serverAddr = ncConfig.serverAddr
    # Cast key from string to array[32, byte] for chacha20 (32 bytes)
    let keyStr = ncConfig.secretKey
    echo(fmt("Key length: {keyStr.len()}"))
    assert(keyStr.len() == len(Key), "Key must be exactly 32 bytes long")
    let key = cast[ptr(Key)](unsafeAddr(keyStr[0]))

    ncNode.key = key[]
    ncNode.heartbeatTimeout = ncConfig.heartbeatTimeout

    return ncNode

proc ncInitNode*[T: NCDPNode](dataProcessor: T, filename: string): NCNode[T] =
    echo(fmt("ncInitNode({fileName})"))

    let config = ncLoadConfig(fileName)
    ncInitNode(dataProcessor, config)

