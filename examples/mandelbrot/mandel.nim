
# Nim std imports
import std/parseopt
import std/logging
from std/strformat import fmt

# Local imports
import ../../src/num_crunch/nc_config

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
        #let server = ncInitServer(config)
    else:
        info("Starting Node")
        #let node = initNode(config)

