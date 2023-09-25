
from std/os import getAppDir

import num_crunch/nc_node

type
    MyDP = object
        data: seq[byte]

proc processData(self: var MyDP, input: seq[byte]): seq[byte] =
    self.data

block:
    # Test init
    let currentDir = getAppDir()
    let filename = currentDir & "/config1.ini"
    let dataProcessor = MyDP()

    let node = ncInitNode(dataProcessor, filename)

block:
    # Test init with invalid filename
    # Expect IOError, file not found
    const filename = "unknown_file.ini"
    let dataProcessor = MyDP()

    doAssertRaises(IOError):
        let node = ncInitNode(dataProcessor, filename)

block:
    # Test first run without a server
    # Expect OSError, connection refused
    let currentDir = getAppDir()
    let filename = currentDir & "/config1.ini"
    let dataProcessor = MyDP()

    var node = ncInitNode(dataProcessor, filename)

    doAssertRaises(OSError):
        node.runNode()

