
from std/os import getAppDir

import num_crunch/nc_server
import num_crunch/private/nc_nodeid

type
    MyDP = object
        data: seq[byte]

proc isFinished(self: MyDP): bool =
    true

proc getNewData(self: var MyDP, n: NCNodeID): seq[byte] =
    @[]

proc collectData(self: var MyDP, data: seq[byte]) =
    self.data = data

proc maybeDeadNode(self: var MyDP, n: NCNodeID) =
    discard

proc saveData(self: var MyDP) =
    discard

block:
    # Test init
    let currentDir = getAppDir()
    let filename = currentDir & "/config1.ini"
    let dataProcessor = MyDP()

    let node = ncInitServer(dataProcessor, filename)

block:
    # Test init with invalid filename
    const filename = "unknown_file.ini"
    let dataProcessor = MyDP()

    doAssertRaises(IOError):
        let node = ncInitServer(dataProcessor, filename)

