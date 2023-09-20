

import num_crunch/nc_array2d

block:
    const
        tileSizeX: uint32 = 10
        tileSizeY: uint32 = 10
        numTilesX: uint32  = 3
        numTilesY: uint32 = 4
        sizeX: uint32 = tileSizeX * numTilesX
        sizeY: uint32 = tileSizeY * numTilesY

    var a2d = ncNewArray2D[uint8](tileSizeX, tileSizeY, numTilesX, numTilesY)

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


