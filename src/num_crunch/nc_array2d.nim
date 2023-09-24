
# Nim std imports
from std/strformat import fmt

# Local imports
import nc_nodeid

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
    echo(fmt("ncNewArray2D(), {sizeX}, {sizeY}, {tileX}, {tileY}"))
    result.tileSizeX = sizeX
    result.tileSizeY = sizeY
    result.numTilesX = tileX
    result.numTilesY = tileY
    result.data = newSeq[T](sizeX * sizeY * tileX * tileY)
    result.totalSizeX = sizeX * tileX
    result.totalSizeY = sizeY * tileY
    result.tileStatus = newSeq[NCTileStatus](tileX * tileY)

func getTileSize*[T](self: NCArray2D[T]): (uint32, uint32) =
    (self.tileSizeX, self.tileSizeY)

func getNumTiles*[T](self: NCArray2D[T]): (uint32, uint32) =
    (self.numTilesX, self.numTilesY)

func getTotalSize*[T](self: NCArray2D[T]): (uint32, uint32) =
    (self.totalSizeX, self.totalSizeY)

proc getXY*[T](self: NCArray2D[T], x: uint32, y: uint32): T =
    let offset = (y * self.totalSizeX) + x
    self.data[offset]

proc setXY*[T](self: var NCArray2D[T], x: uint32, y: uint32, v: T) =
    let offset = (y * self.totalSizeX) + x
    self.data[offset] = v

proc getData*[T](self: NCArray2D[T]): ref seq[T] =
    echo(fmt("NCArray2D.getData()"))
    addr(self.data)

proc getTileXY*[T](self: NCArray2D[T], ax: uint32, ay: uint32): seq[T] =
    echo(fmt("NCArray2D.getTileXY(), {ax}, {ay}"))
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

proc setTileXY*[T](self: var NCArray2D[T], ax: uint32, ay: uint32, tile: seq[T]) =
    echo(fmt("NCArray2D.setTileXY(), {ax}, {ay}"))
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
            self.data[j] = tile[i]

proc fillArray*[T](self: var NCArray2D[T], v: T) =
    echo("NCArray2D.fillArray()")
    for y in 0..<self.totalSizeY:
        let ii = y * self.totalSizeX
        for x in 0..<self.totalSizeX:
            let i = ii + x
            self.data[i] = v

proc fillTile*[T](self: var NCArray2D[T], ax: uint32, ay: uint32, v: T) =
    echo(fmt("NCArray2D.fillTile(), {ax}, {ay}"))
    let offsetY = self.totalSizeX * self.tileSizeY * ay
    let offsetX = self.tileSizeX * ax
    let offset = offsetX + offsetY

    for ty in 0..<self.tileSizeY:
        # Offset inside array
        let i = offset + (ty * self.totalSizeX)

        for tx in 0..<self.tileSizeX:
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

proc nextUnprocessedTile*[T](self: var NCArray2D[T], nodeId: NCNodeId): (uint32, uint32) =
    echo(fmt("NCArray2D.nextUnprocessedTile(), {nodeId}"))
    var x: uint32 = 0
    var y: uint32 = 0

    for i in 0..<self.tileStatus.len():
        if self.tileStatus[i].status == NCTileStatusKind.unprocessed:
            self.tileStatus[i].status = NCTileStatusKind.inProgress
            self.tileStatus[i].nodeId = nodeId
            self.tileStatus[i].tileX = x
            self.tileStatus[i].tileY = y
            result = (x, y)
            break

        x = x + 1
        if x == self.numTilesX:
            x = 0
            y = y + 1

proc maybeDeadNode*[T](self: var NCArray2D[T], nodeId: NCNodeId) =
    echo(fmt("NCArray2D.maybeDeadNode(), {nodeId}"))
    for i in 0..<self.tileStatus.len():
        if self.tileStatus[i].nodeId == nodeId:
            if self.tileStatus[i].status == NCTileStatusKind.inProgress:
                # This tile needs to be processed by another node
                self.tileStatus[i].status = NCTileStatusKind.unprocessed
                # Done, since a node can only process one tile at a time
                break

proc collectData*[T](self: var NCArray2D[T], nodeId: NCNodeId, data: seq[T]) =
    echo(fmt("NCArray2D.collectData(), {nodeId}"))
    for i in 0..<self.tileStatus.len():
        if self.tileStatus[i].nodeId == nodeId:
            if self.tileStatus[i].status == NCTileStatusKind.inProgress:
                self.tileStatus[i].status = NCTileStatusKind.done
                self.setTileXY(self.tileStatus[i].tileX, self.tileStatus[i].tileY, data)
                break



