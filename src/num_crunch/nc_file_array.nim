# Nim std imports
from std/strformat import fmt
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
    let info = NCFileInfo(path: path, nodeId: none, data: none)
    self.files.add(info)

proc ncSetData*[T](self: var NCFileArray, nodeId: NCNodeId, data: T) =
    discard

proc ncGetData*[T](self: NCFileArray): T =
    discard

proc isFinished*(self: NCFileArray): bool =
    result = true

    for info in self.files:
        if info.nodeID.isNone or info.data.isNone:
            result = false

proc nextUnprocessedFile*(self: var NCFileArray): Option[string] =
    discard

proc maybeDeadNode*(self: var NCFileArray) =
    discard

proc collectData*[T](self: var NCArray2D[T], nodeId: NCNodeId, data: seq[T]) =
    discard


