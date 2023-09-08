

# Nim std imports
from std/parsecfg import loadConfig, getSectionValue
from std/strutils import parseUInt
from std/nativesockets import Port

type
    NCConfiguration* = object
        serverAddr*: string
        serverPort*: Port
        # In seconds
        heartbeatTimeout*: uint16
        secretKey*: string

func ncNewConfig*(): NCConfiguration =
    result.serverAddr = "127.0.0.1"
    result.serverPort = Port(3100)
    # Timeout for heartbeat messages set to 5 minutes
    result.heartbeatTimeout = 60 * 5
    result.secretKey = ""

proc ncLoadConfig*(path: string): NCConfiguration {. raises: [IOError, ValueError, Exception] .}=
    let settings = loadConfig(path)
    result.serverAddr = settings.getSectionValue("","server_address")
    result.serverPort = Port(parseUInt(settings.getSectionValue("","server_port")))
    result.heartbeatTimeout = uint16(parseUInt(settings.getSectionValue("","heartbeat_timeout")))
    result.secretKey = settings.getSectionValue("","secret_key")
    # Show all exceptions
    #{.effects.}
