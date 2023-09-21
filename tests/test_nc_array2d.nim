


# Nim std imports
from std/strformat import fmt

# Local imports
import num_crunch/nc_array2d
import num_crunch/nc_nodeid

block:
    const
        tileSizeX: uint32 = 10
        tileSizeY: uint32 = 10
        numTilesX: uint32  = 3
        numTilesY: uint32 = 4
        sizeX: uint32 = tileSizeX * numTilesX
        sizeY: uint32 = tileSizeY * numTilesY

    var a2d = ncNewArray2D[uint8](tileSizeX, tileSizeY, numTilesX, numTilesY)

    # Test simple getters
    assert(a2d.getTileSize() == (tileSizeX, tileSizeY))
    assert(a2d.getNumTiles() == (numTilesX, numTilesY))
    assert(a2d.getTotalSize() == (sizeX, sizeY))

    # Test array fill
    a2d.fillArray(5)
    for y in 0..(sizeY - 1):
        for x in 0..(sizeX - 1):
            assert(a2d.getXY(x, y) == 5)

    # Test setting single value
    a2d.setXY(0, 0, 12)
    assert(a2d.getXY(0, 0) == 12)
    for x in 1..(sizeX - 1):
        assert(a2d.getXY(x, 0) == 5)
    for y in 1..(sizeY - 1):
        for x in 0..(sizeX - 1):
            assert(a2d.getXY(x, y) == 5)

    # Test filling tile
    a2d.fillTile(0, 0, 133)
    # Check the tile
    for y in 0..(tileSizeY - 1):
        for x in 0..(tileSizeX - 1):
            assert(a2d.getXY(x, y) == 133)
    # Check the rest
    for y in 0..(tileSizeY - 1):
        for x in tileSizeX..(sizeX - 1):
            assert(a2d.getXY(x, y) == 5)

    for y in tileSizeY..(sizeY - 1):
        for x in 0..(sizeX - 1):
            assert(a2d.getXY(x, y) == 5)

block:
    const
        tileSizeX: uint32 = 12
        tileSizeY: uint32 = 13
        numTilesX: uint32  = 4
        numTilesY: uint32 = 5
        numTiles: uint32 = numTilesX * numTilesY

    var a2d = ncNewArray2D[uint8](tileSizeX, tileSizeY, numTilesX, numTilesY)

    # Ensure that the array is not finished yet
    assert(not a2d.isFinished())

    # Now let's do some work:
    # Create some test node id
    let nodeId = ncNewNodeId()

    for i in 1..numTiles:
        discard a2d.nextUnprocessedTile(nodeId)

    # Still not finished yet:
    assert(not a2d.isFinished())

    let firstTile = a2d.getTileXY(0, 0)

    for i in 1..numTiles:
        a2d.collectData(nodeId, firstTile)

    # Now the work is done:
    assert(a2d.isFinished())

