
# Nim std imports
import std/net
import std/typedthreads
import std/times
import std/locks
import std/atomics
import std/asyncdispatch
import std/asynchttpserver

from std/os import sleep
from std/strformat import fmt
from std/random import randomize

# External imports
from chacha20 import Key

# Local imports
import private/nc_message
import nc_config
import nc_log
import nc_nodeid
import nc_common

type
    NCServer* = object
        serverPort: Port
        key: Key
        heartbeatTimeout: uint16 # In seconds
        serverLock: Lock
        # Use a HashMap in the future
        nodes: seq[(NCNodeID, Time)]

    NCServerDataProcessor* = ref object of RootObj

var ncServerInstance: NCServer

var ncDPInstance: NCServerDataProcessor

var ncQuit: Atomic[bool]

var ncServerLock: Lock

method isFinished*(self: var NCServerDataProcessor): bool {.base.} =
    quit("You must override this method: isFinished")

method getInitData*(self: var NCServerDataProcessor): seq[byte] {.base.} =
    quit("You must override this method: getInitData")

method getNewData*(self: var NCServerDataProcessor, id: NCNodeID): seq[byte] {.base.} =
    quit("You must override this method: getNewData")

method collectData*(self: var NCServerDataProcessor, id: NCNodeID, data: seq[byte]) {.base.} =
    quit("You must override this method: collectData")

method maybeDeadNode*(self: var NCServerDataProcessor, id: NCNodeID) {.base.} =
    quit("You must override this method: maybeDeadNode")

method saveData*(self: var NCServerDataProcessor) {.base.} =
    quit("You must override this method: saveData")

proc checkNodesHeartbeat() {.thread.} =
    ncDebug("checkNodesHeartbeat()")

    # Convert from seconds to miliseconds
    # and add a small tolerance for the client nodes
    const tolerance: uint = 500 # 500 ms tolerance

    var exitCounter = 0

    {.cast(gcsafe).}:
        let timeOut = int((ncServerInstance.heartbeatTimeout * 1000) + tolerance)
        let serverPort = ncServerInstance.serverPort
        let key = ncServerInstance.key

    while true:
        sleep(timeOut)

        if exitCounter == 2:
            ncQuit.store(true)
        elif exitCounter == 3:
            break

        # Send heartbeat message to server
        ncDebug(fmt("checkNodesHeartbeat(), send check heartbeat message to self"))
        let serverResponse = ncSendCheckHeartbeatMessage(serverPort, key)

        case serverResponse.kind:
            of NCNodeMsgKind.quit:
                ncInfo("checkNodesHeartbeat(), All work is done, will exit soon")
                inc(exitCounter)
                ncDebug(fmt("checkNodesHeartbeat(), exitCounter: {exitCounter}"))
            of NCNodeMsgKind.ok:
                # Everything is fine, nothing more to do
                discard
            else:
                ncError(fmt("checkNodesHeartbeat(), Unknown response: {serverResponse.kind}"))
                break

    ncInfo("checkNodesHeartbeat(), heartbeat thread finished")

proc createNewNodeId(): NCNodeID =
    ncDebug("createNewNodeId()", 2)

    result = ncNewNodeId()
    var quit = false

    while not quit:
        quit = true
        for (n, _) in ncServerInstance.nodes:
            if result == n:
                # NodeId already in use, choose a new one
                result = ncNewNodeId()
                quit = false

    ncDebug(fmt("createNewNodeId(), id: {result}"))

proc validNodeId(id: NCNodeID): bool =
    ncDebug(fmt("validNodeId(), id: {id}"), 2)

    result = false

    for (n, _) in ncServerInstance.nodes:
        if n == id:
            result = true
            break

proc handleClient(req: Request) {.async.} =
    ncDebug("handleClient()", 2)

    let path = req.url.path
    let body = req.body
    let hostname = req.hostname

    ncDebug(fmt("handleClient(), connection from: {hostname}, path: {path}"))

    {.cast(gcsafe).}:
        while true:
            if tryAcquire(ncServerLock):
                break
            else:
                await sleepAsync(100)

        let key = ncServerInstance.key
        let message = ncDecodeServerMessage(body, key)

        var nodeMessage = NCNodeMessage(kind: NCNodeMsgKind.unknown)

        if ncDPInstance.isFinished():
            nodeMessage = NCNodeMessage(kind: NCNodeMsgKind.quit)
        else:
            case path:
                of "/heartbeat":
                    ncDebug(fmt("handleClient(), node sends heartbeat: {message.id}"))

                    var valid = false

                    for i in 0..<ncServerInstance.nodes.len():
                        if ncServerInstance.nodes[i][0] == message.id:
                            ncServerInstance.nodes[i][1] = getTime()
                            valid = true
                            break

                    if valid:
                        nodeMessage = NCNodeMessage(kind: NCNodeMsgKind.ok)
                    else:
                        ncError(fmt("handleClient(), node id invalid: {message.id}"))
                of "/check_heartbeat":
                    ncDebug("handleClient(), check heartbeat of all nodes")

                    let maxDuration = initDuration(seconds = int64(ncServerInstance.heartbeatTimeout))
                    let currentTime = getTime()

                    for (nId, hbTime) in ncServerInstance.nodes:
                        if maxDuration < (currentTime - hbTime):
                            ncInfo(fmt("handleClient(), node is not sending heartbeat message: {nId}"))
                            # Let data processor know that this node seems dead
                            ncDPInstance.maybeDeadNode(nId)

                    nodeMessage = NCNodeMessage(kind: NCNodeMsgKind.ok)
                of "/node_needs_data":
                    ncDebug(fmt("handleClient(), node needs data:{message.id}"))

                    if validNodeId(message.id):
                        let newData = ncDPInstance.getNewData(message.id)
                        nodeMessage = NCNodeMessage(kind: NCNodeMsgKind.newData, data: newData)
                    else:
                        ncError(fmt("handleClient(), node id invalid: {message.id}"))
                of "/processed_data":
                    ncDebug(fmt("handleClient(), node has processed data: {message.id}"))
                    
                    if validNodeId(message.id):
                        ncDPInstance.collectData(message.id, message.data)
                        nodeMessage = NCNodeMessage(kind: NCNodeMsgKind.ok)
                    else:
                        ncError(fmt("handleClient(), node id invalid: {message.id}"))
                of "/register_new_node":
                    let newId = createNewNodeId()
                    ncServerInstance.nodes.add((newId, getTime()))

                    ncInfo(fmt("handleClient(), register new node: {newId}"))

                    let initData = ncDPInstance.getInitData()
                    let data = ncToBytes((newId, initData))

                    nodeMessage = NCNodeMessage(kind: NCNodeMsgKind.welcome, data: data)
                else:
                    ncError(fmt("handleClient(), unknown path: {path}"))

        release(ncServerLock)

        let encodedMessage = ncEncodeNodeMessage(nodeMessage, key)
        let headers = {"Content-type": "application/data"}
        await req.respond(Http200, encodedMessage, headers.newHttpHeaders())

proc startHttpServer(port: Port) {.async.} =
    ncInfo("startHttpServer()")
    var server = newAsyncHttpServer()

    server.listen(port)

    while not ncQuit.load():
        if server.shouldAcceptRequest():
            await server.acceptRequest(handleClient)
        else:
            await sleepAsync(100)

    # Wait for heartbeat thread to finish
    await sleepAsync(100)
    server.close()

proc ncRunServer*() =
    ncInfo("ncRunServer()")

    var hbThreadId: Thread[void]

    createThread(hbThreadId, checkNodesHeartbeat)

    initLock(ncServerLock)

    waitFor startHttpServer(ncServerInstance.serverPort)

    ncInfo("ncRunServer(), save all user data!")
    ncDPInstance.saveData()

    joinThread(hbThreadId)
    ncDebug("ncRunServer(), hearbeat thread finished")

    deinitLock(ncServerLock)

proc ncInitServer*(dataProcessor: NCServerDataProcessor, ncConfig: NCConfiguration) =
    ncInfo("ncInitServer(config)")

    # Initiate the random number genertator
    randomize()

    ncServerInstance.serverPort = ncConfig.serverPort
    # Cast key from string to array[32, byte] for chacha20 (32 bytes)
    let keyStr = ncConfig.secretKey
    ncDebug(fmt("ncInitServer(), key length: {keyStr.len()}"))
    assert(keyStr.len() == len(Key), "ncInitServer(), key must be exactly 32 bytes long")
    let key = cast[ptr(Key)](unsafeAddr(keyStr[0]))

    ncServerInstance.key = key[]
    ncServerInstance.heartbeatTimeout = ncConfig.heartbeatTimeout
    #ncServer.nodes = newSeqOfCap[(NCNodeID, Time)](10)
    ncServerInstance.nodes = @[]

    ncDPInstance = dataProcessor

proc ncInitServer*(dataProcessor: NCServerDataProcessor, fileName: string) =
    ncInfo(fmt("ncInitServer({fileName})"))

    let config = ncLoadConfig(fileName)
    ncInitServer(dataProcessor, config)

