
# Nim std imports
import std/net
import std/typedthreads
import std/times
import std/locks
import std/atomics

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
        # In seconds
        heartbeatTimeout: uint16
        serverLock: Lock
        # Use a HashMap in the future
        nodes: seq[(NCNodeID, Time)]
        quit: Atomic[bool]

    ClientThread[T] = Thread[Socket]

    NCServerDataProcessor = ref object of RootObj

var ncServerInstance: NCServer

var ncDPInstance: NCServerDataProcessor

method isFinished(self: NCServerDataProcessor): bool {.base.} =
    quit("You must override this method")

method getInitData(self: NCServerDataProcessor): seq[byte] {.base.} =
    quit("You must override this method")

method getNewData(self: NCServerDataProcessor, id: NCNodeID) {.base.} =
    quit("You must override this method")

method collectData(self: NCServerDataProcessor, id: NCNodeID, data: seq[byte]) {.base.} =
    quit("You must override this method")

method maybeDeadNode(self: NCServerDataProcessor, id: NCNodeID) {.base.} =
    quit("You must override this method")

method saveData(self: NCServerDataProcessor) {.base.} =
    quit("You must override this method")

proc checkNodesHeartbeat() {.thread.} =
    ncDebug("NCServer.checkNodesHeartbeat()")

    # Convert from seconds to miliseconds
    # and add a small tolerance for the client nodes
    const tolerance: uint = 500 # 500 ms tolerance

    # TODO: New implementation

proc createNewNodeId(): NCNodeID =
    ncDebug("NCServer.createNewNodeId()", 2)

    result = ncNewNodeId()
    var quit = false

    while not quit:
        quit = true
        for (n, _) in ncServerInstance.nodes:
            if result == n:
                # NodeId already in use, choose a new one
                result = ncNewNodeId()
                quit = false

    ncDebug(fmt("NCServer.createNewNodeId(), id: {result}"))

proc validNodeId(id: NCNodeID): bool =
    ncDebug(fmt("NCServer.validNodeId(), id: {id}"), 2)

    result = false

    for (n, _) in ncServerInstance.nodes:
        if n == id:
            result = true
            break

proc handleClientInner(client: Socket) =
    ncDebug("NCServer.handleClientInner()", 2)

    # TODO: New implementation

proc handleClient(client: Socket) {.thread.} =
    ncDebug("NCServer.handleClient()", 2)

    # TODO: New implementation

proc runServer*() =
    ncInfo("NCServer.runServer()")

    var hbThreadId: Thread[void]

    createThread(hbThreadId, checkNodesHeartbeat)

    # TODO: New implementation

proc ncInitServer*(dataProcessor: NCServerDataProcessor, ncConfig: NCConfiguration) =
    ncInfo("ncInitServer(config)")

    # Initiate the random number genertator
    randomize()

    var ncServer = NCServer()

    ncServer.serverPort = ncConfig.serverPort
    # Cast key from string to array[32, byte] for chacha20 (32 bytes)
    let keyStr = ncConfig.secretKey
    ncDebug(fmt("ncInitServer(), key length: {keyStr.len()}"))
    assert(keyStr.len() == len(Key), "ncInitServer(), key must be exactly 32 bytes long")
    let key = cast[ptr(Key)](unsafeAddr(keyStr[0]))

    ncServer.key = key[]
    ncServer.heartbeatTimeout = ncConfig.heartbeatTimeout
    #ncServer.nodes = newSeqOfCap[(NCNodeID, Time)](10)
    ncServer.nodes = @[]

    ncServerInstance = ncServer

    ncDPInstance = dataProcessor

proc ncInitServer*(dataProcessor: NCServerDataProcessor, fileName: string) =
    ncInfo(fmt("ncInitServer({fileName})"))

    let config = ncLoadConfig(fileName)
    ncInitServer(dataProcessor, config)

