

import private/nc_nodeid

type
    NCTileStatusKind = enum
        unprocessed,
        inProgress,
        done

    NCTileStatus = object
        status: NCTileStatusKind
        nodeId: NCNodeId

    NCArray2D*[T] = object
        data: seq[T]
        tileSizeX: uint32
        tileSizeY: uint32
        numTilesX: uint32
        numTilesY: uint32
        totalSizeX: uint32
        totalSizeY: uint32
        tileStatus: seq[NCTileStatus]

proc ncNewArray2D*[T](sizeX: uint32, sizeY: uint32, tileX: uint32, tileY: uint32): NCArray2D[T] =
    result.tileSizeX = sizeX
    result.tileSizeY = sizeY
    result.numTilesX = tileX
    result.numTilesY = tileY
    result.data = newSeq[T](sizeX * sizeY * tileX * tileY)
    result.totalSizeX = sizeX * tileX
    result.totalSizeY = sizeY * tileY
    result.tileStatus = newSeq[NCTileStatus](sizeX * sizeY)

proc getXY*[T](self: NCArray2D[T], x: uint32, y: uint32): T =
    let offset = (y * self.totalSizeX) + x
    self.data[offset]

proc setXY*[T](self: var NCArray2D[T], x: uint32, y: uint32, v: T) =
    let offset = (y * self.totalSizeX) + x
    self.data[offset] = v

proc getData*[T](self: NCArray2D[T]): ref seq[T] =
    addr(self.data)

proc getTileXY*[T](self: NCArray2D[T], ax: uint32, ay: uint32): seq[T] =
    result = newSeq(self.tileSizeX * self.tileSizeY)
    let offsetY = self.totalSizeX * self.tileSizeY * ay
    let offsetX = self.tileSizeX * ax
    let offset = offsetX + offsetY

    for ty in 0..(self.tileSizeY - 1):
        # Offset inside tile
        let ii = ty * self.tileSizeX
        # Offset inside array
        let jj = offset + (ty * self.totalSizeX)

        for tx in 0..(self.tileSizeX - 1):
            let i = ii + tx
            let j = jj + tx
            result[i] = self.data[j]

proc setTileXY*[T](self: var NCArray2D[T], ax: uint32, ay: uint32, tile: seq[T]) =
    let offsetY = self.totalSizeX * self.tileSizeY * ay
    let offsetX = self.tileSizeX * ax
    let offset = offsetX + offsetY

    for ty in 0..(self.tileSizeY - 1):
        # Offset inside tile
        let ii = ty * self.tileSizeX
        # Offset inside array
        let jj = offset + (ty * self.totalSizeX)

        for tx in 0..(self.tileSizeX - 1):
            let i = ii + tx
            let j = jj + tx
            self.data[j] = tile[i]

proc fillArray*[T](self: var NCArray2D[T], v: T) =
    for y in 0..(self.totalSizeY - 1):
        let ii = y * self.totalSizeX
        for x in 0..(self.totalSizeX - 1):
            let i = ii + x
            self.data[i] = v

proc fillTile*[T](self: var NCArray2D[T], ax: uint32, ay: uint32, v: T) =
    let offsetY = self.totalSizeX * self.tileSizeY * ay
    let offsetX = self.tileSizeX * ax
    let offset = offsetX + offsetY

    for ty in 0..(self.tileSizeY - 1):
        # Offset inside array
        let i = offset + (ty * self.totalSizeX)

        for tx in 0..(self.tileSizeX - 1):
            let i = i + tx
            self.data[i] = v

func isFinished*[T](self: NCArray2D[T]): bool =
    result = true

    for s in self.tileStatus:
        if s.status == NCTileStatusKind.inProgress:
            result = false
            break
        elif s.status == NCTileStatusKind.unprocessed:
            result = false
            break



