
import common

type
    NCServer* = object
        serverPort: uint16
        heartbeatTimeout: uint16
        nodes: seq[NCNodeID]

proc run*(server: NCServer, config: NCConfiguration) =
    echo("Starting NCServer with port: ", config.serverPort)

    server.serverPort = config.serverPort
    server.heartbeatTimeout = config.heartbeatTimeout

