

# Nim std imports
import std/complex

from std/strformat import fmt

# Local imports
import ../../src/num_crunch

import m_common

type
    MandelNodeDP = ref object of NCNodeDataProcessor
        initData: MandelInit
        data: MandelResult

method ncInit(self: var MandelNodeDP, data: seq[byte]) =
    let initData = ncFromBytes(data, MandelInit)
    self.initData = initData
    self.data.pixelData = newSeq[uint32](initData.tileWidth * initData.tileHeight)

    ncDebug(fmt("MandelNodeDP.init(), initData: {initData}"))

method ncProcessData(self: var MandelNodeDP, inputData: seq[byte]): seq[byte] =
    ncDebug("ncProcessData()", 2)

    let (tx, ty) = ncFromBytes(inputData, (uint32, uint32))
    ncDebug(fmt("ncProcessData(), tx: {tx}, ty: {ty}"))

    let tw = self.initData.tileWidth
    let th = self.initData.tileHeight
    let factorX = float64(tw * tx)
    let factorY = float64(th * ty)
    let reStep = self.initData.reStep
    let imStep = self.initData.imStep
    let re = self.initData.re1 + (reStep * factorX)
    let im = self.initData.im1 + (imStep * factorY)
    let maxIter = self.initData.maxIter

    var currentIter: uint32 = 0
    var z = complex64(0.0, 0.0)

    for y in 0..<th:
        for x in 0..<tw:
            currentIter = 0
            let c = complex64(re + (float64(x) * reStep), im + (float64(y) * imStep))
            z = c

            while (z.abs2() <= 4.0) and (currentIter < maxIter):
                z = c + (z * z)
                inc(currentIter)

            self.data.pixelData[(y * tw) + x] = currentIter

    let data = ncToBytes(self.data)
    return data

proc initMandelNodeDP*(): MandelNodeDP =
    MandelNodeDP()

