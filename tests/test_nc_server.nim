


# Nim std imports
import std/logging
from std/os import getAppDir
from std/strformat import fmt

# Local imports
import num_crunch/nc_log
import num_crunch/nc_nodeid
import num_crunch/nc_server


type
    MyDP = ref object of NCServerDataProcessor
        testCounter: uint8

method isFinished(self: var MyDP): bool =
    ncDebug(fmt("isFinished(), testcounter: {self.testCounter}"))
    if self.testcounter > 0:
        self.testCounter = self.testCounter - 1
    result = (self.testCounter == 0)

method getInitData(self: var MyDP): seq[byte] =
    @[]

method getNewData(self: var MyDP, n: NCNodeID): seq[byte] =
    @[]

method collectData(self: var MyDP, n: NCNodeID, data: seq[byte]) =
    discard

method maybeDeadNode(self: var MyDP, n: NCNodeID) =
    discard

method saveData(self: var MyDP) =
    discard

proc test1() =
    # Test init
    let currentDir = getAppDir()
    let filename = currentDir & "/config1.ini"
    let dataProcessor = MyDP()

    ncInitServer(dataProcessor, filename)

proc test2() =
    # Test init with invalid filename
    # Expect IOError, file not found
    const filename = "unknown_file.ini"
    let dataProcessor = MyDP()

    doAssertRaises(IOError):
        ncInitServer(dataProcessor, filename)

proc test3() =
    # Test with no node connected
    let currentDir = getAppDir()
    let filename = currentDir & "/config1.ini"
    let dataProcessor = MyDP(testCounter: 3)

    ncInitServer(dataProcessor, filename)
    ncRunServer()

when isMainModule:
    let logger = newFileLogger("tests/test_nc_server.log", fmtStr=verboseFmtStr)
    ncInitLogger(logger)

    test1()
    test2()
    test3()

    ncDeinitLogger()

