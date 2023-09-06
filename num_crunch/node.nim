
import common

type
    NCNode* = object
        serverAddr: string
        serverPort: uint16
        heartbeatTimeout: uint16
        nodeId: NCNodeID

proc run*(server: NCNode, config: NCConfiguration) =
    echo(fmt()"Starting NCNode, connecting to '{config.serverAddr}', using port: {config.serverPort}"))

    server.serverAddr = config.serverAddr
    server.serverPort = config.serverPort
    server.heartbeatTimeout = config.heartbeatTimeout
