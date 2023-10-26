
# Nim std imports
import std/net
import std/times
import std/locks
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

var ncServerInstance: ptr NCServer

var ncDPInstance: ptr NCServerDataProcessor

var ncServerLock: Lock

method isFinished*(self: var NCServerDataProcessor): bool {.base, gcsafe.} =
    quit("You must override this method: isFinished")

method getInitData*(self: var NCServerDataProcessor): seq[byte] {.base, gcsafe.} =
    quit("You must override this method: getInitData")

method getNewData*(self: var NCServerDataProcessor, id: NCNodeID): seq[byte] {.base, gcsafe.} =
    quit("You must override this method: getNewData")

method collectData*(self: var NCServerDataProcessor, id: NCNodeID, data: seq[byte]) {.base, gcsafe.} =
    quit("You must override this method: collectData")

method maybeDeadNode*(self: var NCServerDataProcessor, id: NCNodeID) {.base, gcsafe.} =
    quit("You must override this method: maybeDeadNode")

method saveData*(self: var NCServerDataProcessor) {.base, gcsafe.} =
    quit("You must override this method: saveData")

proc awaitLock() {.async.} =
    while true:
        if tryAcquire(ncServerLock):
            break
        else:
            await sleepAsync(100)

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

proc checkNodeHearbeat() {.async.} =
    ncDebug("checkNodeHearbeat()")

    await awaitLock()

    let maxDuration = initDuration(seconds = int64(ncServerInstance.heartbeatTimeout))
    let currentTime = getTime()

    for n in ncServerInstance.nodes:
        if maxDuration < (currentTime - n[1]):
            ncInfo(fmt("checkNodeHearbeat(), node is not sending heartbeat message: {n[0]}"))
            # Let data processor know that this node seems dead
            ncDPInstance[].maybeDeadNode(n[0])

    release(ncServerLock)

proc handleClient(req: Request) {.async.} =
    ncDebug("handleClient()", 2)

    let path = req.url.path
    let body = req.body
    let hostname = req.hostname

    ncDebug(fmt("handleClient(), connection from: {hostname}, path: {path}"))

    await awaitLock()

    let key = ncServerInstance.key
    let message = ncDecodeServerMessage(body, key)

    var nodeMessage = NCNodeMessage(kind: NCNodeMsgKind.unknown)

    if ncDPInstance[].isFinished():
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
                        ncDPInstance[].maybeDeadNode(nId)

                nodeMessage = NCNodeMessage(kind: NCNodeMsgKind.ok)
            of "/node_needs_data":
                ncDebug(fmt("handleClient(), node needs data: {message.id}"))

                if validNodeId(message.id):
                    let newData = ncDPInstance[].getNewData(message.id)
                    nodeMessage = NCNodeMessage(kind: NCNodeMsgKind.newData, data: newData)
                else:
                    ncError(fmt("handleClient(), node id invalid: {message.id}"))
            of "/processed_data":
                ncDebug(fmt("handleClient(), node has processed data: {message.id}"))

                if validNodeId(message.id):
                    ncDPInstance[].collectData(message.id, message.data)
                    nodeMessage = NCNodeMessage(kind: NCNodeMsgKind.ok)
                else:
                    ncError(fmt("handleClient(), node id invalid: {message.id}"))
            of "/register_new_node":
                let newId = createNewNodeId()
                ncServerInstance.nodes.add((newId, getTime()))

                ncInfo(fmt("handleClient(), register new node: {newId}"))

                let initData = ncDPInstance[].getInitData()
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

    var quitCounter = 3

    # Add a small tolerance to the timeout value
    let hbTimeout: int = (int(ncServerInstance.heartbeatTimeout) * 1000) + 500

    while true:
        if server.shouldAcceptRequest():
            let hbTimer = sleepAsync(hbTimeout)
            await (server.acceptRequest(handleClient) or hbTimer)

            if hbTimer.finished():
                await checkNodeHearbeat()
        else:
            await sleepAsync(100)

        if ncDPInstance[].isFinished():
            ncDebug(fmt("startHttpServer(), work is done will exit soon... ({quitCounter})"))
            dec(quitCounter)
            if quitCounter == 0:
                break

    server.close()

proc ncRunServer*() =
    ncInfo("ncRunServer()")

    initLock(ncServerLock)

    waitFor startHttpServer(ncServerInstance.serverPort)

    ncInfo("ncRunServer(), save all user data!")
    ncDPInstance[].saveData()

    deinitLock(ncServerLock)

    ncInfo("ncRunServer(), free memory")
    reset(ncServerInstance.key)
    reset(ncServerInstance.nodes)
    deallocShared(ncServerInstance)
    deallocShared(ncDPInstance)

    ncInfo("ncRunServer(), will exit now")

proc ncInitServer*(dataProcessor: NCServerDataProcessor, ncConfig: NCConfiguration) =
    ncInfo("ncInitServer(config)")

    # Initiate the random number genertator
    randomize()

    ncServerInstance = createShared(NCServer)
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

    ncDPInstance = createShared(NCServerDataProcessor)
    moveMem(ncDPInstance, dataProcessor.addr, sizeof(NCServerDataProcessor))

proc ncInitServer*(dataProcessor: NCServerDataProcessor, fileName: string) =
    ncInfo(fmt("ncInitServer({fileName})"))

    let config = ncLoadConfig(fileName)
    ncInitServer(dataProcessor, config)

