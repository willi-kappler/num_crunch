

# Nim std imports
import std/complex

from std/strformat import fmt
from os import sleep

# Local imports
#import num_crunch/nc_common

import ../../src/num_crunch/nc_node
import ../../src/num_crunch/nc_common
import ../../src/num_crunch/nc_log

import m_common

type
    MandelNodeDP = ref object of NCNodeDataProcessor
        initData: MandelInit
        data: MandelResult

method init(self: var MandelNodeDP, data: seq[byte]) =
    let initData = ncFromBytes(data, MandelInit)
    self.initData = initData
    self.data.pixelData = newSeq[uint32](initData.tileWidth * initData.tileHeight)

    ncDebug(fmt("MandelNodeDP.init(), initData: {initData}"))

method processData(self: var MandelNodeDP, inputData: seq[byte]): seq[byte] =
    ncDebug("processData()", 2)

    let (tx, ty) = ncFromBytes(inputData, (uint32, uint32))
    ncDebug(fmt("processData(), tx: {tx}, ty: {ty}"))

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

proc processData2(self: var MandelNodeDP, inputData: seq[byte]): seq[byte] =
    ncDebug("processData()", 2)

    let (tx, ty) = ncFromBytes(inputData, (uint32, uint32))
    ncDebug(fmt("processData(), tx: {tx}, ty: {ty}"))

    let value = (ty * 256) + (tx * 64)

    let tw = self.initData.tileWidth
    let th = self.initData.tileHeight

    for y in 0..<th:
        for x in 0..<tw:
            self.data.pixelData[(y * tw) + x] = value

    sleep(1000 * 10)

    let data = ncToBytes(self.data)
    return data

proc initMandelNodeDP*(): MandelNodeDP =
    MandelNodeDP()

