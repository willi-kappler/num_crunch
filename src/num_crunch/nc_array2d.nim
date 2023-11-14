## This module is part of num_crunch: https://github.com/willi-kappler/num_crunch
## Written by Willi Kappler, License: MIT
##
## NCArray2D is a generic container for two dimensional data of type T.
## It has a bunch of helper functions that allow for easy integration with NCServerDataProcessor.
##


# Nim std imports
from std/strformat import fmt
import std/options

# Local imports
import nc_nodeid
import nc_log

type
    NCTileStatusKind = enum
        ## Each tile of the 2D array can be in one of three states: unprocessed, inProgress or done.
        ## If the tile is unprocessed it will be given to the next node that needs work.
        ## If it is inProgress that means that is has been assigned to a node already.
        ## If it is done, that means that the node has processed all the data for this tile.
        unprocessed,
        inProgress,
        done

    NCTileStatus = object
        ## Information about one tile.
        status: NCTileStatusKind
        nodeId: NCNodeId
        tileX: uint32
        tileY: uint32

    NCArray2D*[T] = object
        ## The 2D array object containing the data and the information about each tile.
        data: seq[T]
        tileSizeX: uint32
        tileSizeY: uint32
        numTilesX: uint32
        numTilesY: uint32
        totalSizeX: uint32
        totalSizeY: uint32
        tileStatus: seq[NCTileStatus]

proc ncNewArray2D*[T](sizeX: uint32, sizeY: uint32, tileX: uint32, tileY: uint32): NCArray2D[T] =
    ## Creates a new 2D array given the properties.
    ## sizeX: the site in x direction of one tile.
    ## sizeY: the size in y direction of one tile.
    ## tileX: number of tiles in x direction.
    ## tileY: number of tiles in y direction.

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
    ## Returns the size of each tile as tuple: (sizeX, sizeY).
    (self.tileSizeX, self.tileSizeY)

func ncGetNumTiles*[T](self: NCArray2D[T]): (uint32, uint32) =
    ## Returns the number of tiles as tuple: (tileX, tileY).
    (self.numTilesX, self.numTilesY)

func ncGetTotalSize*[T](self: NCArray2D[T]): (uint32, uint32) =
    ## Returns the total site as tuple: (totalSizeX, totalSizeY).
    (self.totalSizeX, self.totalSizeY)

proc ncGetXY*[T](self: NCArray2D[T], x: uint32, y: uint32): T =
    ## Returns the element at the given element position (x, y).
    let offset = (y * self.totalSizeX) + x
    self.data[offset]

proc ncSetXY*[T](self: var NCArray2D[T], x: uint32, y: uint32, v: T) =
    ## Sets the given element v at the given element position (x, y).
    let offset = (y * self.totalSizeX) + x
    self.data[offset] = v

proc ncGetData*[T](self: NCArray2D[T]): ref seq[T] =
    ## Returns a view into the data.
    ncDebug(fmt("NCArray2D.getData()"), 2)
    addr(self.data)

proc ncGetTileXY*[T](self: NCArray2D[T], ax: uint32, ay: uint32): seq[T] =
    ## Returns a copy of the tile at tile position (ax, ay).
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
    ## Sets the given tile at given tile position (ax, ay).
    ## The tile must have the size (tileX, tileY).
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
    ## Fills the whole 2d array with the given value v.
    ncDebug("NCArray2D.fillArray()")
    for y in 0..<self.totalSizeY:
        let ii = y * self.totalSizeX
        for x in 0..<self.totalSizeX:
            let i = ii + x
            self.data[i] = v

proc ncFillTile*[T](self: var NCArray2D[T], ax: uint32, ay: uint32, v: T) =
    ## Fills the specific tile (ax, ay) with the given value v.
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
    ## Returns true if all tiles are processed.
    result = true

    for s in self.tileStatus:
        if s.status == NCTileStatusKind.inProgress:
            result = false
            break
        elif s.status == NCTileStatusKind.unprocessed:
            result = false
            break

proc ncNextUnprocessedTile*[T](self: var NCArray2D[T], nodeId: NCNodeId): Option[(uint32, uint32)] =
    ## Returns the tile position of the next unprocessed tile: some(tx, ty).
    ## If all tiles are processed return none.
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
    ## Notifys the 2d array that the node with the given nodeid may be dead and
    ## the coresponding tile will be marked as unprocessed.
    ## Now another node can process the tile.
    ncDebug(fmt("NCArray2D.maybeDeadNode(), {nodeId}"))
    for tile in self.tileStatus.mitems():
        if tile.nodeId == nodeId:
            if tile.status == NCTileStatusKind.inProgress:
                # This tile needs to be processed by another node.
                tile.status = NCTileStatusKind.unprocessed
                # Done, since a node can only process one tile at a time.
                break

proc ncCollectData*[T](self: var NCArray2D[T], nodeId: NCNodeId, data: seq[T]) =
    ## Replaces the processed tile from the given node inside the 2d array.
    ncDebug(fmt("NCArray2D.collectData(), {nodeId}"))
    for tile in self.tileStatus.mitems():
        if tile.nodeId == nodeId:
            if tile.status == NCTileStatusKind.inProgress:
                tile.status = NCTileStatusKind.done
                self.ncSetTileXY(tile.tileX, tile.tileY, data)
                break

