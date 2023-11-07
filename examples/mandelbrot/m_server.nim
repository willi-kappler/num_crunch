

# Nim std imports
import std/options

from std/strformat import fmt


# Local imports
#import num_crunch/nc_nodeid
#import num_crunch/nc_array2d
#import num_crunch/nc_common

import ../../src/num_crunch/nc_server
import ../../src/num_crunch/nc_nodeid
import ../../src/num_crunch/nc_array2d
import ../../src/num_crunch/nc_common

import m_common

type
    MandelServerDP = ref object of NCServerDataProcessor
        data: NCArray2D[uint32]
        re2: float64
        im2: float64
        initData: MandelInit

method ncIsFinished(self: var MandelServerDP): bool =
    self.data.ncIsFinished()

method ncGetInitData(self: var MandelServerDP): seq[byte] =
    return ncToBytes(self.initData)

method ncGetNewData(self: var MandelServerDP, n: NCNodeID): seq[byte] =
    let data = self.data.ncNextUnprocessedTile(n)
    if data.isNone():
        return @[]
    else:
        return ncToBytes(data.get())

method ncCollectData(self: var MandelServerDP, n: NCNodeID, data: seq[byte]) =
    let processedData = ncFromBytes(data, MandelResult)
    self.data.ncCollectData(n, processedData.pixelData)

method ncMaybeDeadNode(self: var MandelServerDP, n: NCNodeID) =
    self.data.ncMaybeDeadNode(n)

method ncSaveData(self: var MandelServerDP) =
    let (imgWidth, imgHeight) = self.data.ncGetTotalSize()
    let maxIter = self.initData.maxIter

    let imgFile = open("mandel_image.ppm", mode = fmWrite)

    imgFile.write("P3\n")
    imgFile.write(fmt("{imgWidth} {imgHeight}\n"))
    imgFile.write("255\n")

    for y in 0..<imgHeight:
        for x in 0..<imgWidth:
            let value = self.data.ncGetXY(x, y)

            if value == maxIter:
                imgFile.write("0 0 0 ")
            else:
                let colorValue = (value mod 16) * 16
                # let colorValue = (value * 255) div 1024
                imgFile.write(fmt("255 {colorValue} 0 "))

        imgFile.write("\n")

    imgFile.close()

proc initMandelServerDP*(): MandelServerDP =
    # TODO: read in these values from a configuration file
    let tileWidth: uint32 = 1024
    let tileHeight: uint32 = 1024
    let numTilesX: uint32 = 4
    let numTilesY: uint32 = 4
    let data = ncNewArray2D[uint32](tileWidth, tileHeight, numTilesX, numTilesY)
    let imgWidth: uint32 = tileWidth * numTilesX
    let imgHeight: uint32 = tileHeight * numTilesY
    let re1 = -2.0
    let re2 = 1.0
    let reStep = (re2 - re1) / float64(imgWidth)
    let im1 = -1.5
    let im2 = 1.5
    let imStep = (im2 - im1) / float64(imgHeight)
    let maxIter: uint32 = 2048

    let initData = MandelInit(
        tileWidth: tileWidth,
        tileHeight: tileHeight,
        re1: re1,
        im1: im1,
        reStep: reStep,
        imStep: imStep,
        maxIter: maxIter
    )

    MandelServerDP(data: data, re2: re2, im2: im2, initData: initData)

