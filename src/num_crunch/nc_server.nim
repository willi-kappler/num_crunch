
# Nim std imports
import std/net
import std/times
import std/locks
import std/asyncdispatch
import std/asynchttpserver

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

method ncIsFinished*(self: var NCServerDataProcessor): bool {.base, gcsafe.} =
    quit("You must override this method: isFinished")

method ncGetInitData*(self: var NCServerDataProcessor): seq[byte] {.base, gcsafe.} =
    quit("You must override this method: getInitData")

method ncGetNewData*(self: var NCServerDataProcessor, id: NCNodeID): seq[byte] {.base, gcsafe.} =
    quit("You must override this method: getNewData")

method ncCollectData*(self: var NCServerDataProcessor, id: NCNodeID, data: seq[byte]) {.base, gcsafe.} =
    quit("You must override this method: collectData")

method ncMaybeDeadNode*(self: var NCServerDataProcessor, id: NCNodeID) {.base, gcsafe.} =
    quit("You must override this method: maybeDeadNode")

method ncSaveData*(self: var NCServerDataProcessor) {.base, gcsafe.} =
    quit("You must override this method: saveData")

proc ncAwaitLock() {.async.} =
    ncDebug("ncAwaitLock()", 2)

    while true:
        if tryAcquire(ncServerLock):
            ncDebug("ncAwaitLock(), success", 2)
            break
        else:
            await sleepAsync(100)

proc ncCreateNewNodeId(): NCNodeID =
    ncDebug("ncCreateNewNodeId()", 2)

    result = ncNewNodeId()
    var quit = false

    while not quit:
        quit = true
        for (n, _) in ncServerInstance.nodes:
            if result == n:
                # NodeId already in use, choose a new one
                result = ncNewNodeId()
                quit = false

    ncDebug(fmt("ncCreateNewNodeId(), id: {result}"))

proc ncValidNodeId(id: NCNodeID): bool =
    ncDebug(fmt("ncValidNodeId(), id: {id}"), 2)

    result = false

    for (n, _) in ncServerInstance.nodes:
        if n == id:
            result = true
            break

proc ncCheckNodeHeartbeat() {.async.} =
    ncDebug("ncCheckNodeHeartbeat()")

    await ncAwaitLock()

    let maxDuration = initDuration(seconds = int64(ncServerInstance.heartbeatTimeout))
    let currentTime = getTime()

    for n in ncServerInstance.nodes:
        if maxDuration < (currentTime - n[1]):
            ncInfo(fmt("ncCheckNodeHeartbeat(), node is not sending heartbeat message: {n[0]}"))
            # Let data processor know that this node seems dead
            ncDPInstance[].ncMaybeDeadNode(n[0])

    release(ncServerLock)
    ncDebug("ncCheckNodeHeartbeat(), done", 2)

proc ncHandleClient(req: Request) {.async.} =
    ncDebug("ncHandleClient()", 2)

    let path = req.url.path
    let body = req.body
    let hostname = req.hostname

    ncDebug(fmt("ncHandleClient(), connection from: {hostname}, path: {path}"))

    await ncAwaitLock()

    let key = ncServerInstance.key
    let message = ncDecodeServerMessage(body, key)

    var nodeMessage = NCNodeMessage(kind: NCNodeMsgKind.unknown)

    if ncDPInstance[].ncIsFinished():
        nodeMessage = NCNodeMessage(kind: NCNodeMsgKind.quit)
    else:
        case path:
            of "/heartbeat":
                ncDebug(fmt("ncHandleClient(), node sends heartbeat: {message.id}"))

                var valid = false

                for i in 0..<ncServerInstance.nodes.len():
                    if ncServerInstance.nodes[i][0] == message.id:
                        ncServerInstance.nodes[i][1] = getTime()
                        valid = true
                        break

                if valid:
                    nodeMessage = NCNodeMessage(kind: NCNodeMsgKind.ok)
                else:
                    ncError(fmt("ncHandleClient(), node id invalid: {message.id}"))
            of "/node_needs_data":
                ncDebug(fmt("ncHandleClient(), node needs data: {message.id}"))

                if ncValidNodeId(message.id):
                    let newData = ncDPInstance[].ncGetNewData(message.id)
                    nodeMessage = NCNodeMessage(kind: NCNodeMsgKind.newData, data: newData)
                else:
                    ncError(fmt("ncHandleClient(), node id invalid: {message.id}"))
            of "/processed_data":
                ncDebug(fmt("ncHandleClient(), node has processed data: {message.id}"))

                if ncValidNodeId(message.id):
                    ncDPInstance[].ncCollectData(message.id, message.data)
                    nodeMessage = NCNodeMessage(kind: NCNodeMsgKind.ok)
                else:
                    ncError(fmt("ncHandleClient(), node id invalid: {message.id}"))
            of "/register_new_node":
                let newId = ncCreateNewNodeId()
                ncServerInstance.nodes.add((newId, getTime()))

                ncInfo(fmt("ncHandleClient(), register new node: {newId}"))

                let initData = ncDPInstance[].ncGetInitData()
                let data = ncToBytes((newId, initData))

                nodeMessage = NCNodeMessage(kind: NCNodeMsgKind.welcome, data: data)
            else:
                ncError(fmt("ncHandleClient(), unknown path: {path}"))

    release(ncServerLock)

    let encodedMessage = ncEncodeNodeMessage(nodeMessage, key)
    let headers = {"Content-type": "application/data"}
    await req.respond(Http200, encodedMessage, headers.newHttpHeaders())

    ncDebug("ncHandleClient(), done", 2)

proc ncStartHttpServer(port: Port) {.async.} =
    ncInfo("ncStartHttpServer()")
    var server = newAsyncHttpServer()
    server.listen(port)

    var quitCounter = 3

    # Add a small tolerance to the timeout value
    let hbTimeout: int = (int(ncServerInstance.heartbeatTimeout) * 1000) + 500
    var hbTimer = sleepAsync(hbTimeout)
    var serverFuture = server.acceptRequest(ncHandleClient)
    var jobFinished = false

    while true:
        ncDebug("ncStartHttpServer(), enter loop", 2)
        jobFinished = ncDPInstance[].ncIsFinished()
        ncDebug(fmt("ncStartHttpServer(), jobFinished: {jobFinished}"), 2)

        if server.shouldAcceptRequest():
            ncDebug("ncStartHttpServer(), server accept request", 2)
            await (serverFuture or hbTimer)
            ncDebug("ncStartHttpServer(), await done, check hbTimer", 2)

            if hbTimer.finished():
                ncDebug("ncStartHttpServer(), hbTimer finished", 2)
                hbTimer = sleepAsync(hbTimeout)
                if jobFinished:
                    ncDebug(fmt("ncStartHttpServer(), work is done will exit soon... ({quitCounter})"))
                    dec(quitCounter)
                    if quitCounter == 0:
                        break
                else:
                    await ncCheckNodeHeartbeat()

            if serverFuture.finished():
                # Only when the current future is done a new one can be created
                serverFuture = server.acceptRequest(ncHandleClient)
        else:
            await sleepAsync(100)

    server.close()

proc ncRunServer*() =
    ncInfo("ncRunServer()")

    let startTime = getTime()

    initLock(ncServerLock)

    waitFor ncStartHttpServer(ncServerInstance.serverPort)

    ncInfo("ncRunServer(), save all user data!")
    ncDPInstance[].ncSaveData()

    deinitLock(ncServerLock)

    ncInfo("ncRunServer(), free memory")
    reset(ncServerInstance.key)
    reset(ncServerInstance.nodes)
    deallocShared(ncServerInstance)
    deallocShared(ncDPInstance)

    let endTime = getTime()
    let jobDurationSec = float64((endTime - startTime).inMilliseconds()) / 1000.0
    let jobDurationMin = jobDurationSec / 60.0
    let jobDurationHour = jobDurationMin / 60.0

    ncInfo(fmt("ncRunServer(), time taken: {jobDurationSec} [s], {jobDurationMin} [min], {jobDurationHour} [h]"))

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

