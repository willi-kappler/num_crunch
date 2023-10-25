

# Nim std imports
import std/logging

from std/os import getAppDir

# Local imports
import num_crunch/nc_log
import num_crunch/nc_node

type
    MyDP = ref object of NCNodeDataProcessor
        data: seq[byte]

method processData(self: var MyDP, input: seq[byte]): seq[byte] =
    self.data

proc test1() =
    # Test init
    let currentDir = getAppDir()
    let filename = currentDir & "/config1.ini"
    let dataProcessor = MyDP()

    ncInitNode(dataProcessor, filename)

proc test2() =
    # Test init with invalid filename
    # Expect IOError, file not found
    const filename = "unknown_file.ini"
    let dataProcessor = MyDP()

    doAssertRaises(IOError):
        ncInitNode(dataProcessor, filename)

proc test3() =
    # Test first run without a server
    # Expect OSError, connection refused
    let currentDir = getAppDir()
    let filename = currentDir & "/config1.ini"
    let dataProcessor = MyDP()

    ncInitNode(dataProcessor, filename)

    doAssertRaises(OSError):
        ncRunNode()

when isMainModule:
    let logger = newFileLogger("tests/test_nc_node.log", fmtStr=verboseFmtStr)
    ncInitLogger(logger)

    test1()
    test2()
    test3()

    ncDeinitLogger()

