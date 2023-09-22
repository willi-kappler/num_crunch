

# Local imports
import ../../src/num_crunch/nc_nodeid
import ../../src/num_crunch/nc_array2d

type
    MandelDP = object
        data: NCArray2D[uint32]

proc isFinished(self: MandelDP): bool =
    true

proc getNewData(self: var MandelDP, n: NCNodeID): seq[byte] =
    @[]

proc collectData(self: var MandelDP, data: seq[byte]) =
    self.data = data

proc maybeDeadNode(self: var MandelDP, n: NCNodeID) =
    discard

proc saveData(self: var MandelDP) =
    discard


