## This module is part of num_crunch: https://github.com/willi-kappler/num_crunch
##
## Written by Willi Kappler, License: MIT
##
## This module contains the configuration type and two helper functions
## 

# Nim std imports
from std/parsecfg import loadConfig, getSectionValue
from std/strutils import parseUInt
from std/nativesockets import Port

type
    NCConfiguration* = object
        ## NumCrunch configuration, for the server and the nodes.
        serverAddr*: string
            ## The address of the server.
        serverPort*: Port
            ## The port to connect to.
        heartbeatTimeout*: uint16
            ## Given in seconds. If the heartbeat is not send, the server
            ## assumes that the node may be dead and gives the data to another node.
        secretKey*: string
            ## The secret key that is used for encrypted communication.

func ncNewConfig*(key: string): NCConfiguration =
    ## Creates a new configuration with default values given the encryption key.
    result.serverAddr = "127.0.0.1"
    result.serverPort = Port(3100)
    # Timeout for heartbeat messages set to 5 minutes
    result.heartbeatTimeout = 60 * 5
    result.secretKey = key
    assert(result.secretKey.len() == 32, "Key must be exactly 32 bytes long!")

proc ncLoadConfig*(path: string): NCConfiguration {.raises: [IOError, ValueError, Exception].}=
    ## Loads the configuration from the given path and returns a new configuration value.
    let settings = loadConfig(path)
    result.serverAddr = settings.getSectionValue("","server_address", "127.0.0.1")
    result.serverPort = Port(parseUInt(settings.getSectionValue("","server_port", "3100")))
    result.heartbeatTimeout = uint16(parseUInt(settings.getSectionValue("","heartbeat_timeout", "300")))
    result.secretKey = settings.getSectionValue("","secret_key")
    assert(result.secretKey.len() == 32, "Key must be exactly 32 bytes long!")
    # Show all exceptions
    #{.effects.}

