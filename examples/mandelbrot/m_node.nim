

# Local imports
import num_crunch/nc_common

import m_common

type
    MandelNodeDP = object
        initData: MandelInit
        data: MandelResult

proc init*(self: var MandelNodeDP, data: seq[byte]) =
    let initData = ncFromBytes(data, MandelInit)
    self.initData = initData

proc processData*(self: var MandelNodeDP, input: seq[byte]): seq[byte] =
    let (tx, ty) = ncFromBytes(input, (uint32, uint32))
    self.data.tx = tx
    self.data.ty = ty

    # TODO: calculate pixel value for Mandelbrot

    let data = ncToBytes(self.data)
    return data

proc initMandelNodeDP*(): MandelNodeDP =
    MandelNodeDP()

