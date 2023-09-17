
from std/os import getAppDir

import num_crunch/nc_node

block:
    # Test init
    let currentDir = getAppDir()
    let filename = currentDir & "/config1.ini"
    let dataProcessor = false

    let node = initNode(dataProcessor, filename)

block:
    # Test init with invalid filename
    const filename = "unknown_file.ini"
    let dataProcessor = false

    doAssertRaises(IOError):
        let node = initNode(dataProcessor, filename)
