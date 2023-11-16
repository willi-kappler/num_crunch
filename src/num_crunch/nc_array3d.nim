## This module is part of num_crunch: https://github.com/willi-kappler/num_crunch
##
## Written by Willi Kappler, License: MIT
##


# TODO: Implement Array 3D

type
    NCArray3D[T] = object
        data: seq[T]
        tileSizeX: uint32
        tileSizeY: uint32
        tileSizeZ: uint32
        numTilesX: uint32
        numTilesY: uint32
        numTilesZ: uint32
        lineWidth: uint32

proc ncNewArray*[T](w: uint32, h: uint32, nx: uint32, ny: uint32): NCArray3D[T] =
    result.tileWidth = w
    result.tileHeight = h
    result.numTileX = nx
    result.numTileY = ny
    result.data = newSeq[T](w*h*nx*ny)
    result.lineWidth = w*nx

proc ncGetXY*[T](a: NCArray3D[T], x: uint32, y: uint32): T =
    let offset = (y * a.lineWidth) + x
    a.data[offset]

proc ncSetXY*[T](a: NCArray3D[T], x: uint32, y: uint32, v: T) =
    let offset = (y * a.lineWidth) + x
    a.data[offset] = v

