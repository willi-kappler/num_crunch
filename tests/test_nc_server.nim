


# Nim std imports
import std/logging
from std/os import getAppDir

# Local imports
import num_crunch/nc_server
import num_crunch/nc_nodeid

type
    MyDP = object
        testCounter: uint8

proc isFinished(self: var MyDP): bool =
    echo("isFinished(), testcounter: ", self.testCounter)
    if self.testcounter > 0:
        self.testCounter = self.testCounter - 1
    result = (self.testCounter == 0)

proc getNewData(self: var MyDP, n: NCNodeID): seq[byte] =
    @[]

proc collectData(self: var MyDP, data: seq[byte]) =
    discard

proc maybeDeadNode(self: var MyDP, n: NCNodeID) =
    discard

proc saveData(self: var MyDP) =
    discard

proc test1() =
    # Test init
    let currentDir = getAppDir()
    let filename = currentDir & "/config1.ini"
    let dataProcessor = MyDP()

    let server = ncInitServer(dataProcessor, filename)
    discard server

proc test2() =
    # Test init with invalid filename
    # Expect IOError, file not found
    const filename = "unknown_file.ini"
    let dataProcessor = MyDP()

    doAssertRaises(IOError):
        let node = ncInitServer(dataProcessor, filename)
        discard node

proc test3() =
    # Test with no node connected
    let currentDir = getAppDir()
    let filename = currentDir & "/config1.ini"
    let dataProcessor = MyDP(testCounter: 3)

    var server = ncInitServer(dataProcessor, filename)
    server.runServer()

when isMainModule:
    let logger = newFileLogger("tests/test_nc_server.log", fmtStr=verboseFmtStr)
    addHandler(logger)

    test1()
    test2()
    test3()


