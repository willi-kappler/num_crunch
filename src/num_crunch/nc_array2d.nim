
# Nim std imports
from std/strformat import fmt
import std/options

# Local imports
import nc_nodeid
import nc_log

type
    NCTileStatusKind = enum
        unprocessed,
        inProgress,
        done

    NCTileStatus = object
        status: NCTileStatusKind
        nodeId: NCNodeId
        tileX: uint32
        tileY: uint32

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
    ncDebug(fmt("ncNewArray2D(), {sizeX}, {sizeY}, {tileX}, {tileY}"))
    let totalSizeX = sizeX * tileX
    let totalSizeY = sizeY * tileY

    result.tileSizeX = sizeX
    result.tileSizeY = sizeY
    result.numTilesX = tileX
    result.numTilesY = tileY
    result.totalSizeX = totalSizeX
    result.totalSizeY = totalSizeY
    result.data = newSeq[T](totalSizeX * totalSizeY)
    result.tileStatus = newSeq[NCTileStatus](tileX * tileY)

func ncGetTileSize*[T](self: NCArray2D[T]): (uint32, uint32) =
    (self.tileSizeX, self.tileSizeY)

func ncGetNumTiles*[T](self: NCArray2D[T]): (uint32, uint32) =
    (self.numTilesX, self.numTilesY)

func ncGetTotalSize*[T](self: NCArray2D[T]): (uint32, uint32) =
    (self.totalSizeX, self.totalSizeY)

proc ncGetXY*[T](self: NCArray2D[T], x: uint32, y: uint32): T =
    let offset = (y * self.totalSizeX) + x
    self.data[offset]

proc ncSetXY*[T](self: var NCArray2D[T], x: uint32, y: uint32, v: T) =
    let offset = (y * self.totalSizeX) + x
    self.data[offset] = v

proc ncGetData*[T](self: NCArray2D[T]): ref seq[T] =
    ncDebug(fmt("NCArray2D.getData()"), 2)
    addr(self.data)

proc ncGetTileXY*[T](self: NCArray2D[T], ax: uint32, ay: uint32): seq[T] =
    ncDebug(fmt("NCArray2D.getTileXY(), {ax}, {ay}"), 2)
    result = newSeq[T](self.tileSizeX * self.tileSizeY)
    let offsetY = self.totalSizeX * self.tileSizeY * ay
    let offsetX = self.tileSizeX * ax
    let offset = offsetX + offsetY

    for ty in 0..<self.tileSizeY:
        # Offset inside tile
        let ii = ty * self.tileSizeX
        # Offset inside array
        let jj = offset + (ty * self.totalSizeX)

        for tx in 0..<self.tileSizeX:
            let i = ii + tx
            let j = jj + tx
            result[i] = self.data[j]

proc ncSetTileXY*[T](self: var NCArray2D[T], ax: uint32, ay: uint32, tile: seq[T]) =
    ncDebug(fmt("NCArray2D.setTileXY(), {ax}, {ay}"), 2)
    let offsetY = self.totalSizeX * self.tileSizeY * ay
    let offsetX = self.tileSizeX * ax
    let offset = offsetX + offsetY
    ncDebug(fmt("offsetX: {offsetX}, offsetY: {offsetY}, offset: {offset}"), 2)

    for ty in 0..<self.tileSizeY:
        # Offset inside tile
        let ii = ty * self.tileSizeX
        # Offset inside array
        let jj = offset + (ty * self.totalSizeX)

        for tx in 0..<self.tileSizeX:
            let i = ii + tx
            let j = jj + tx
            self.data[j] = tile[i]

proc ncFillArray*[T](self: var NCArray2D[T], v: T) =
    ncDebug("NCArray2D.fillArray()")
    for y in 0..<self.totalSizeY:
        let ii = y * self.totalSizeX
        for x in 0..<self.totalSizeX:
            let i = ii + x
            self.data[i] = v

proc ncFillTile*[T](self: var NCArray2D[T], ax: uint32, ay: uint32, v: T) =
    ncDebug(fmt("NCArray2D.fillTile(), {ax}, {ay}"))
    let offsetY = self.totalSizeX * self.tileSizeY * ay
    let offsetX = self.tileSizeX * ax
    let offset = offsetX + offsetY

    for ty in 0..<self.tileSizeY:
        # Offset inside array
        let i = offset + (ty * self.totalSizeX)

        for tx in 0..<self.tileSizeX:
            let i = i + tx
            self.data[i] = v

func ncIsFinished*[T](self: NCArray2D[T]): bool =
    result = true

    for s in self.tileStatus:
        if s.status == NCTileStatusKind.inProgress:
            result = false
            break
        elif s.status == NCTileStatusKind.unprocessed:
            result = false
            break

proc ncNextUnprocessedTile*[T](self: var NCArray2D[T], nodeId: NCNodeId): Option[(uint32, uint32)] =
    ncDebug(fmt("NCArray2D.nextUnprocessedTile(), {nodeId}"))
    var x: uint32 = 0
    var y: uint32 = 0

    result = none((uint32, uint32))

    for tile in self.tileStatus.mitems():
        if tile.status == NCTileStatusKind.unprocessed:
            tile.status = NCTileStatusKind.inProgress
            tile.nodeId = nodeId
            tile.tileX = x
            tile.tileY = y
            result = some((x, y))
            break

        inc(x)
        if x == self.numTilesX:
            x = 0
            inc(y)

proc ncMaybeDeadNode*[T](self: var NCArray2D[T], nodeId: NCNodeId) =
    ncDebug(fmt("NCArray2D.maybeDeadNode(), {nodeId}"))
    for tile in self.tileStatus.mitems():
        if tile.nodeId == nodeId:
            if tile.status == NCTileStatusKind.inProgress:
                # This tile needs to be processed by another node
                tile.status = NCTileStatusKind.unprocessed
                # Done, since a node can only process one tile at a time
                break

proc ncCollectData*[T](self: var NCArray2D[T], nodeId: NCNodeId, data: seq[T]) =
    ncDebug(fmt("NCArray2D.collectData(), {nodeId}"))
    for tile in self.tileStatus.mitems():
        if tile.nodeId == nodeId:
            if tile.status == NCTileStatusKind.inProgress:
                tile.status = NCTileStatusKind.done
                self.ncSetTileXY(tile.tileX, tile.tileY, data)
                break


