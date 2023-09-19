
import std/parseopt
import std/logging
from std/strformat import fmt

if isMainModule:
    var runServer = false
    let logger = newFileLogger("mandel.log", fmtStr=verboseFmtStr)
    addHandler(logger)

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
    else:
        info("Starting Node")

