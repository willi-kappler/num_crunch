

# Local imports
import ../../src/num_crunch/nc_nodeid
import ../../src/num_crunch/nc_array2d

type
    MandelServerDP = object
        data: NCArray2D[uint32]

proc isFinished*(self: MandelServerDP): bool =
    true

proc getNewData*(self: var MandelServerDP, n: NCNodeID): seq[byte] =
    @[]

proc collectData*(self: var MandelServerDP, data: seq[byte]) =
    discard

proc maybeDeadNode*(self: var MandelServerDP, n: NCNodeID) =
    discard

proc saveData*(self: var MandelServerDP) =
    discard

proc initMandelServerDP*(): MandelServerDP =
    # Tilesize: 512 x 512
    # Number of tiles: 4 * 4 = 16
    let data = ncNewArray2D[uint32](512, 512, 4, 4)
    MandelServerDP(data: data)

