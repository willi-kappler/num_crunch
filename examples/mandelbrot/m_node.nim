

# Local imports
#import ../../src/num_crunch/nc_nodeid
#import ../../src/num_crunch/nc_array2d

type
    MandelNodeDP = object
        data: bool

proc processData*(self: var MandelNodeDP, input: seq[byte]): seq[byte] =
    result = newSeq[byte]()

proc initMandelNodeDP*(): MandelNodeDP =
    MandelNodeDP()

