

# Local imports
import num_crunch/nc_nodeid
import num_crunch/nc_array2d
import num_crnuch/nc_common

import m_common

type
    MandelServerDP = object
        data: NCArray2D[uint32]
        re1: float64
        re2: float64
        reStep: float64
        im1: float64
        im2: float64
        imStep: float64
        pixelPerTileX: uint32
        pixelPerTileY: uint32

proc isFinished*(self: MandelServerDP): bool =
    self.data.isFinished()

proc getNewData*(self: var MandelServerDP, n: NCNodeID): seq[byte] =
    let (tx, ty) = self.data.nextUnprocessedTile(n)
    @[]

proc collectData*(self: var MandelServerDP, data: seq[byte]) =
    discard

proc maybeDeadNode*(self: var MandelServerDP, n: NCNodeID) =
    self.data.maybeDeadNode(n)

proc saveData*(self: var MandelServerDP) =
    discard

proc initMandelServerDP*(): MandelServerDP =
    # Image size: 512 x 512
    # Number of tiles: 4 * 4 = 16
    let imgWidth = 512
    let imgHeight = 512
    let numTilesX = 4
    let numTilesY = 4
    let pixelPerTileX = imgWidth / numTilesX
    let pixelPerTiley = imgHeight /numTilesY
    let data = ncNewArray2D[uint32](imgWidth, imgHeight, numTilesX, numTilesY)
    let re1 = 0.0
    let re2 = 0.0
    let reStep = (re2 - re1) / imgWidth
    let im1 = 0.0
    let im2 = 0.0
    let imStep = (im2 - im1) / imgHeight

    MandelServerDP(data: data, re1: re1, re2: re2, reStep: reStep,
                   im1: im1, im2: im2, imStep: imStep,
                   pixelPerTileX: pixelPerTileX,
                   pixelPerTileY: pixelPerTileY)

