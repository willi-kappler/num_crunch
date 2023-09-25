
# Nim std imports
import std/parseopt
import std/logging
from std/strformat import fmt
from system import quit
from os import getAppFilename

# Local imports
import ../../src/num_crunch/nc_config
import ../../src/num_crunch/nc_node
import ../../src/num_crunch/nc_server

import m_server
import m_node

proc showHelpAndQuit() =
    let name = getAppFilename()

    echo("Use --server to start in 'server mode' otherwise start in 'node mode':")
    echo(fmt("{name} # <- this starts in 'node mode' and tries to connect to the server"))
    echo(fmt("{name} --server # <- this starts in 'server mode' and waits for nodes to connect"))

    quit()

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
                showHelpAndQuit()
        of cmdArgument:
            showHelpAndQuit()

    if runServer:
        info("Starting server")
        let dataProcessor = initMandelServerDP()
        var server = ncInitServer(dataProcessor, config)
        #server.runServer()
    else:
        info("Starting Node")
        let dataProcessor = initMandelNodeDP()
        var node = ncInitNode(dataProcessor, config)
        node.runNode()

