
# Nim std imports
import std/parseopt
import std/logging
from std/strformat import fmt

# Local imports
import ../../src/num_crunch/nc_config
import ../../src/num_crunch/nc_node
import ../../src/num_crunch/nc_server

import m_server
import m_node

if isMainModule:
    var runServer = false
    let logger = newFileLogger("mandel.log", fmtStr=verboseFmtStr)
    addHandler(logger)

    let config = ncLoadConfig("config.ini")

    var cmdParser = initOptParser()
    while true:
        cmdParser.next()
        case cmdParser.kind:
        of cmdEnd:
            break
        of cmdShortOption, cmdLongOption:
            if cmdParser.key == "server":
                runServer = true
            else:
                raise newException(ValueError, fmt("Unknown option: '{cmdParser.key}'"))
        of cmdArgument:
            raise newException(ValueError, fmt("Unknown argument: '{cmdParser.key}'"))

    if runServer:
        info("Starting server")
        let dataProcessor = initMandelServerDP()
        var server = ncInitServer(dataProcessor, config)
        server.runServer()
    else:
        info("Starting Node")
        let dataProcessor = initMandelNodeDP()
        var node = ncInitNode(dataProcessor, config)
        node.runNode()

