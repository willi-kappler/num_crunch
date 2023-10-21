

# Local imports
#import num_crunch/nc_nodeid
#import num_crunch/nc_array2d
#import num_crunch/nc_common

import ../../src/num_crunch/nc_nodeid
import ../../src/num_crunch/nc_array2d
import ../../src/num_crunch/nc_common

import m_common

type
    MandelServerDP = object
        data: NCArray2D[uint32]
        re2: float64
        im2: float64
        initData: MandelInit

proc isFinished*(self: MandelServerDP): bool =
    self.data.isFinished()

proc getInitData*(self: var MandelServerDP): seq[byte] =
    return ncToBytes(self.initData)

proc getNewData*(self: var MandelServerDP, n: NCNodeID): seq[byte] =
    return ncToBytes(self.data.nextUnprocessedTile(n))

proc collectData*(self: var MandelServerDP, data: seq[byte]) =
    let processedData = ncFromBytes(data, MandelResult)
    self.data.setTileXY(processedData.tx, processedData.ty, processedData.pixelData)

proc maybeDeadNode*(self: var MandelServerDP, n: NCNodeID) =
    self.data.maybeDeadNode(n)

proc saveData*(self: var MandelServerDP) =
    # TODO: save pixel data to image file
    discard

proc initMandelServerDP*(): MandelServerDP =
    # Image size: 512 x 512
    # Number of tiles: 4 * 4 = 16

    # TODO: read in these values from a configuration file
    let imgWidth: uint32 = 512
    let imgHeight: uint32 = 512
    let numTilesX: uint32 = 4
    let numTilesY: uint32 = 4
    let pixelPerTileX: uint32 = imgWidth div numTilesX
    let pixelPerTileY: uint32 = imgHeight div numTilesY
    let data = ncNewArray2D[uint32](imgWidth, imgHeight, numTilesX, numTilesY)
    let re1 = 0.0
    let re2 = 0.0
    let reStep = (re2 - re1) / float64(imgWidth)
    let im1 = 0.0
    let im2 = 0.0
    let imStep = (im2 - im1) / float64(imgHeight)
    let maxIter: uint32 = 1024

    let initData = MandelInit(
        tileWidth: pixelPerTileX,
        tileHeight: pixelPerTileY,
        re1: re1,
        im1: im1,
        reStep: reStep,
        imStep: imStep,
        maxIter: maxIter
    )

    MandelServerDP(data: data, re2: re2, im2: im2, initData: initData)

