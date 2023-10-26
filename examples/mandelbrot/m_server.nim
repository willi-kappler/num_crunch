

# Nim std imports
import std/options


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

method isFinished(self: var MandelServerDP): bool =
    self.data.isFinished()

method getInitData(self: var MandelServerDP): seq[byte] =
    return ncToBytes(self.initData)

method getNewData(self: var MandelServerDP, n: NCNodeID): seq[byte] =
    let data = self.data.nextUnprocessedTile(n)
    if data.isNone():
        return @[]
    else:
        return ncToBytes(data.get())

method collectData(self: var MandelServerDP, n: NCNodeID, data: seq[byte]) =
    if data.len() > 0:
        let processedData = ncFromBytes(data, MandelResult)
        self.data.collectData(n, processedData.pixelData)

method maybeDeadNode(self: var MandelServerDP, n: NCNodeID) =
    self.data.maybeDeadNode(n)

method saveData(self: var MandelServerDP) =
    # TODO: save pixel data to image file
    discard

proc initMandelServerDP*(): MandelServerDP =
    # TODO: read in these values from a configuration file
    let tileWidth: uint32 = 1024
    let tileHeight: uint32 = 1024
    let numTilesX: uint32 = 4
    let numTilesY: uint32 = 4
    let data = ncNewArray2D[uint32](tileWidth, tileHeight, numTilesX, numTilesY)
    let imgWidth: uint32 = tileWidth * numTilesX
    let imgHeight: uint32 = tileHeight * numTilesY
    let re1 = 0.0
    let re2 = 0.0
    let reStep = (re2 - re1) / float64(imgWidth)
    let im1 = 0.0
    let im2 = 0.0
    let imStep = (im2 - im1) / float64(imgHeight)
    let maxIter: uint32 = 1024

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

