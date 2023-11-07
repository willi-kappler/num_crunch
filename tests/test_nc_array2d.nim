


# Nim std imports
from std/strformat import fmt
import std/logging

# Local imports
import num_crunch/nc_array2d
import num_crunch/nc_nodeid
import num_crunch/nc_log

proc test1() =
    const
        tileSizeX: uint32 = 10
        tileSizeY: uint32 = 10
        numTilesX: uint32  = 3
        numTilesY: uint32 = 4
        sizeX: uint32 = tileSizeX * numTilesX
        sizeY: uint32 = tileSizeY * numTilesY

    var a2d = ncNewArray2D[uint8](tileSizeX, tileSizeY, numTilesX, numTilesY)

    # Test simple getters
    assert(a2d.ncGetTileSize() == (tileSizeX, tileSizeY))
    assert(a2d.ncGetNumTiles() == (numTilesX, numTilesY))
    assert(a2d.ncGetTotalSize() == (sizeX, sizeY))

    # Test array fill
    a2d.ncFillArray(5)
    for y in 0..<sizeY:
        for x in 0..<sizeX:
            assert(a2d.ncGetXY(x, y) == 5)

    # Test setting single value
    a2d.ncSetXY(0, 0, 12)
    assert(a2d.ncGetXY(0, 0) == 12)
    for x in 1..<sizeX:
        assert(a2d.ncGetXY(x, 0) == 5)
    for y in 1..<sizeY:
        for x in 0..<sizeX:
            assert(a2d.ncGetXY(x, y) == 5)

    # Test filling tile
    a2d.ncFillTile(0, 0, 133)
    # Check the tile
    for y in 0..<tileSizeY:
        for x in 0..<tileSizeX:
            assert(a2d.ncGetXY(x, y) == 133)
    # Check the rest
    for y in 0..<tileSizeY:
        for x in tileSizeX..<sizeX:
            assert(a2d.ncGetXY(x, y) == 5)

    for y in tileSizeY..<sizeY:
        for x in 0..<sizeX:
            assert(a2d.ncGetXY(x, y) == 5)

proc test2() =
    const
        tileSizeX: uint32 = 12
        tileSizeY: uint32 = 13
        numTilesX: uint32  = 4
        numTilesY: uint32 = 5
        numTiles: uint32 = numTilesX * numTilesY

    var a2d = ncNewArray2D[uint8](tileSizeX, tileSizeY, numTilesX, numTilesY)

    # Ensure that the array is not finished yet
    assert(not a2d.ncIsFinished())

    # Now let's do some work:
    # Create some test node id
    let nodeId = ncNewNodeId()

    for i in 0..<numTiles:
        discard a2d.ncNextUnprocessedTile(nodeId)

    # Still not finished yet:
    assert(not a2d.ncIsFinished())

    let firstTile = a2d.ncGetTileXY(0, 0)

    for i in 0..<numTiles:
        a2d.ncCollectData(nodeId, firstTile)

    # Now the work is done:
    assert(a2d.ncIsFinished())

when isMainModule:
    let logger = newFileLogger("tests/test_nc_array2d.log", fmtStr=verboseFmtStr)
    ncInitLogger(logger)

    test1()
    test2()

    ncDeinitLogger()

