

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

func ncNewConfig*(key: string): NCConfiguration =
    result.serverAddr = "127.0.0.1"
    result.serverPort = Port(3100)
    # Timeout for heartbeat messages set to 5 minutes
    result.heartbeatTimeout = 60 * 5
    result.secretKey = key
    assert(result.secretKey.len() == 32, "Key must be exactly 32 bytes long!")

proc ncLoadConfig*(path: string): NCConfiguration {.raises: [IOError, ValueError, Exception].}=
    let settings = loadConfig(path)
    result.serverAddr = settings.getSectionValue("","server_address", "127.0.0.1")
    result.serverPort = Port(parseUInt(settings.getSectionValue("","server_port", "3100")))
    result.heartbeatTimeout = uint16(parseUInt(settings.getSectionValue("","heartbeat_timeout", "300")))
    result.secretKey = settings.getSectionValue("","secret_key")
    assert(result.secretKey.len() == 32, "Key must be exactly 32 bytes long!")
    # Show all exceptions
    #{.effects.}

