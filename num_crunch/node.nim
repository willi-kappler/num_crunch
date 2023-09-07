
# Nim std imports
import std/[asyncnet, asyncdispatch]
from std/strformat import fmt
from std/nativesockets import Port

# Local imports
import common

type
    NCNode* = object
        serverAddr: string
        serverPort: Port
        # In seconds
        heartbeatTimeout: uint16
        nodeId: NCNodeID

proc run*(server: var NCNode, config: NCConfiguration) =
    echo(fmt("Starting NCNode, connecting to '{config.serverAddr}', using port: {config.serverPort}"))

    server.serverAddr = config.serverAddr
    server.serverPort = config.serverPort
    server.heartbeatTimeout = config.heartbeatTimeout
