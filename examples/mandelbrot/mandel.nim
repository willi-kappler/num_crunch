
# Nim std imports
import std/parseopt
import std/logging
from std/strformat import fmt
from system import quit
from os import getAppFilename, splitPath, fileExists

# Local imports
#import num_crunch/nc_config
#import num_crunch/nc_node
#import num_crunch/nc_server
#import num_crunch/nc_log

import ../../src/num_crunch/nc_config
import ../../src/num_crunch/nc_node
import ../../src/num_crunch/nc_server
import ../../src/num_crunch/nc_log

import m_server
import m_node

proc showHelpAndQuit() =
    let path = getAppFilename()
    let name = splitPath(path)[1]

    echo("Use --server to start in 'server mode' otherwise start in 'node mode':")
    echo(fmt("{name} # <- this starts in 'node mode' and tries to connect to the server"))
    echo(fmt("{name} --server # <- this starts in 'server mode' and waits for nodes to connect"))

    quit()

when isMainModule:
    var runServer = false
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
        let logger = newFileLogger("mandel_server.log", fmtStr=verboseFmtStr)
        ncInitLogger(logger)

        ncInfo("Starting server")
        let dataProcessor = initMandelServerDP()
        var server = ncInitServer(dataProcessor, config)
        server.runServer()
    else:
        var nameCounter = 1
        var logFilename = ""

        while true:
            logFilename = fmt("mandel_node{nameCounter}.log")

            if fileExists(logFilename):
                nameCounter += 1
                continue
            else:
                let logger = newFileLogger(logFilename, fmtStr=verboseFmtStr)
                ncInitLogger(logger)
                break

        ncInfo("Starting Node")
        let dataProcessor = initMandelNodeDP()
        var node = ncInitNode(dataProcessor, config)
        node.runNode()

