

type
    NCArray2D*[T] = object
        data: seq[T]
        tileSizeX: uint32
        tileSizeY: uint32
        numTilesX: uint32
        numTilesY: uint32
        totalSizeX: uint32
        totalSizeY: uint32

proc ncNewArray2D*[T](sizeX: uint32, sizeY: uint32, tileX: uint32, tileY: uint32): NCArray2D[T] =
    result.tileSizeX = sizeX
    result.tileSizeY = sizeY
    result.numTilesX = tileX
    result.numTilesY = tileY
    result.data = newSeq[T](sizeX * sizeY * tileX * tileY)
    result.totalSizeX = sizeX * tileX
    result.totalSizeY = sizeY * tileY

proc getXY*[T](a: NCArray2D[T], x: uint32, y: uint32): T =
    let offset = (y * a.totalSizeX) + x
    a.data[offset]

proc setXY*[T](a: var NCArray2D[T], x: uint32, y: uint32, v: T) =
    let offset = (y * a.totalSizeX) + x
    a.data[offset] = v

proc getData*[T](a: NCArray2D[T]): ref seq[T] =
    addr(a.data)

proc getTileXY*[T](a: NCArray2D[T], ax: uint32, ay: uint32): seq[T] =
    result = newSeq(a.tileSizeX * a.tileSizeY)
    let offsetY = a.totalSizeX * a.tileSizeY * ay
    let offsetX = a.tileSizeX * ax
    let offset = offsetX + offsetY

    for ty in 0..(a.tileSizeY - 1):
        # Offset inside tile
        let ii = ty * a.tileSizeX
        # Offset inside array
        let jj = offset + (ty * a.totalSizeX)

        for tx in 0..(a.tileSizeX - 1):
            let i = ii + tx
            let j = jj + tx
            result[i] = a.data[j]

proc setTileXY*[T](a: var NCArray2D[T], ax: uint32, ay: uint32, tile: seq[T]) =
    let offsetY = a.totalSizeX * a.tileSizeY * ay
    let offsetX = a.tileSizeX * ax
    let offset = offsetX + offsetY

    for ty in 0..(a.tileSizeY - 1):
        # Offset inside tile
        let ii = ty * a.tileSizeX
        # Offset inside array
        let jj = offset + (ty * a.totalSizeX)

        for tx in 0..(a.tileSizeX - 1):
            let i = ii + tx
            let j = jj + tx
            a.data[j] = tile[i]

proc fillArray*[T](a: var NCArray2D[T], v: T) =
    for y in 0..(a.totalSizeY - 1):
        let ii = y * a.totalSizeX
        for x in 0..(a.totalSizeX - 1):
            let i = ii + x
            a.data[i] = v

proc fillTile*[T](a: var NCArray2D[T], ax: uint32, ay: uint32, v: T) =
    let offsetY = a.totalSizeX * a.tileSizeY * ay
    let offsetX = a.tileSizeX * ax
    let offset = offsetX + offsetY

    for ty in 0..(a.tileSizeY - 1):
        # Offset inside array
        let i = offset + (ty * a.totalSizeX)

        for tx in 0..(a.tileSizeX - 1):
            let i = i + tx
            a.data[i] = v


