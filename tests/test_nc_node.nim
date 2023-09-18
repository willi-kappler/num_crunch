
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

    let node = initNode(dataProcessor, filename)

block:
    # Test init with invalid filename
    const filename = "unknown_file.ini"
    let dataProcessor = MyDP()

    doAssertRaises(IOError):
        let node = initNode(dataProcessor, filename)

