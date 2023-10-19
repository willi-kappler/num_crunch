

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
    self.data.pixelData = newSeq[uint32](initData.tileWidth * initData.tileHeight)

proc processData*(self: var MandelNodeDP, input: seq[byte]): seq[byte] =
    let (tx, ty) = ncFromBytes(input, (uint32, uint32))
    self.data.tx = tx
    self.data.ty = ty

    let tw = self.initData.tileWidth
    let th = self.initData.tileHeight
    let factorX = float64(tw * tx)
    let factorY = float64(th * ty)
    let reStep = self.initData.reStep
    let imStep = self.initData.imStep
    let maxIter = self.initData.maxIter
    var re = 0.0
    var im = self.initData.im1 + (self.initData.imStep * factorY)
    var currentIter: uint32 = 0

    for y in 0..<th:
        re = self.initData.re1 + (reStep * factorX)
        for x in 0..<tw:
            currentIter = 0
            # TODO: calculate pixel value for Mandelbrot

            self.data.pixelData[(y * tw) + x] = currentIter
            re = re + reStep
        im = im + imStep

    let data = ncToBytes(self.data)
    return data

proc initMandelNodeDP*(): MandelNodeDP =
    MandelNodeDP()

