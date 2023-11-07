# Nim std imports
from std/strformat import fmt
from std/dirs import walkDir, PathComponent

import std/options


# Local imports
import nc_nodeid
import nc_log


type NCFileInfo[T] = object
    path: string
    nodeId: Option[NCNodeId]
    data: Option[T]

type NCFileArray*[T] = object
    files: seq[NCFileInfo[T]]

proc ncNewFileArray*[T](): NCFileArray[T] =
    ncDebug("ncFileArray()")
    NCFileArray(files: @[])

proc ncAddFile*(self: var NCFileArray, path: string) =
    ncDebug(fmt("NCFileArray, ncAddFile(), path: {path}"))
    let info = NCFileInfo(path: path, nodeId: none, data: none)
    self.files.add(info)

proc ncAddFolder*(self: var NCFileArray, path: string) =
    ncDebug(fmt("NCFileArray, ncAddFolder(), path: {path}"))

    for (pc, p) in walkDir(path):
        case pc:
            of PathComponent.pcFile:
                self.ncAddFile(p)
            else:
                discard

proc ncSetData*[T](self: var NCFileArray, nodeId: NCNodeId, data: T) =
    for item in self.files.mitems():
        if item.nodeId.isSome and item.nodeId.get() == nodeId:
            item.data = data

proc ncGetData*[T](self: NCFileArray, nodeId: NCNodeId): Option[T] =
    for item in self.files.mitems():
        if item.nodeId.isSome and item.nodeId.get() == nodeId:
            return item.data

    return none

func ncIsFinished*(self: NCFileArray): bool =
    for item in self.files:
        if item.nodeID.isNone or item.data.isNone:
            return false

    return true

proc ncNextUnprocessedFile*(self: var NCFileArray, nodeId: NCNodeId): Option[string] =
    for item in self.files.mitems():
        if item.nodeId.isNone:
            item.nodeId = some(nodeId)
            return some(item.path)

    return none

proc ncMaybeDeadNode*(self: var NCFileArray, nodeId: NCNodeId) =
    for item in self.files.mitems():
        if item.nodeId.isSome and item.nodeId.get() == nodeId:
            item.nodeId = none
            return

