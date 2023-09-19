

type
    NCArray2D[T] = object
        data: seq[T]
        tileWidth: uint32
        tileHeight: uint32
        numTilesX: uint32
        numTileY: uint32
        lineWidth: uint32

proc ncNewArray*(w: uint32, h: uint32, nx: uint32, ny: uint32): NCArray2D =
    result.tileWidth = w
    result.tileHeight = h
    result.numTileX = nx
    result.numTileY = ny
    result.data = newSeq(w*h*nx*ny)
    result.lineWidth = w*nx

proc getXY*[T](a: NCArray2D[T], x: uint32, y: uint32): T =
    let offset = (y * a.lineWidth) + x
    a.data[offset]

proc setXY*[T](a: NCArray2D[T], x: uint32, y: uint32, v: T) =
    let offset = (y * a.lineWidth) + x
    a.data[offset] = v

