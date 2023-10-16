

# Local imports
import num_crunch/nc_nodeid
import num_crunch/nc_array2d
import num_crunch/nc_common

type
    MandelNodeDP = object
        data: bool

proc processData*(self: var MandelNodeDP, input: seq[byte]): seq[byte] =
    result = newSeq[byte]()

proc initMandelNodeDP*(): MandelNodeDP =
    MandelNodeDP()

