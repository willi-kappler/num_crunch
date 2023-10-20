

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

    var currentIter: uint32 = 0
    var re: float64 = 0.0
    var im: float64 = self.initData.im1 + (self.initData.imStep * factorY)
    var zre: float64 = 0.0
    var zim: float64 = 0.0
    var tmp: float64 = 0.0
    var a: float64 = 0.0
    var b: float64 = 0.0

    for y in 0..<th:
        re = self.initData.re1 + (reStep * factorX)
        for x in 0..<tw:
            currentIter = 0
            zre = 0.0
            zim = 0.0
            a = 0.0
            b = 0.0
            while (a + b <= 4.0) and (currentIter < maxIter):
                a = zre * zre
                b = zim * zim
                tmp = a - b + re
                zim = (2.0 * b) + im
                zre = tmp
                currentIter = currentIter + 1

            self.data.pixelData[(y * tw) + x] = currentIter
            re = re + reStep
        im = im + imStep

    let data = ncToBytes(self.data)
    return data

proc initMandelNodeDP*(): MandelNodeDP =
    MandelNodeDP()

