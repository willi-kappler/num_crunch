## This module is part of num_crunch: https://github.com/willi-kappler/num_crunch
## Written by Willi Kappler, License: MIT
##
## NCFileArray is a data structure that holds multiple paths to files that need to be processed
## by the nodes. Usually the files themselves are distributed via a network file system and
## only the path is given to the nodes from the server.
## The nodes then will load the given file and process the data and return the data to the server.
## (Or they save the data directly on the network file system).
##

# Nim std imports
from std/strformat import fmt
from std/dirs import walkDir, PathComponent

import std/options


# Local imports
import nc_nodeid
import nc_log


type NCFileInfo[T] = object
    ## Contains information about a file path.
    path: string
    nodeId: Option[NCNodeId]
    data: Option[T]

type NCFileArray*[T] = object
    ## Collection of all the file paths.
    files: seq[NCFileInfo[T]]

proc ncNewFileArray*[T](): NCFileArray[T] =
    ## Creates a new and empty file array.
    ncDebug("ncFileArray()")
    NCFileArray(files: @[])

proc ncAddFile*(self: var NCFileArray, path: string) =
    ## Adds a file path to the file array.
    ncDebug(fmt("NCFileArray, ncAddFile(), path: {path}"))
    let info = NCFileInfo(path: path, nodeId: none, data: none)
    self.files.add(info)

proc ncAddFolder*(self: var NCFileArray, path: string) =
    ## Adds all the files of the given folder to the file array.
    ncDebug(fmt("NCFileArray, ncAddFolder(), path: {path}"))

    for (pc, p) in walkDir(path):
        case pc:
            of PathComponent.pcFile:
                self.ncAddFile(p)
            else:
                discard

proc ncSetData*[T](self: var NCFileArray, nodeId: NCNodeId, data: T) =
    ## Sets the data for the given node id.
    for item in self.files.mitems():
        if item.nodeId.isSome and item.nodeId.get() == nodeId:
            item.data = data

proc ncGetData*[T](self: NCFileArray, nodeId: NCNodeId): Option[T] =
    ## Returns the data for the given node id.
    for item in self.files.mitems():
        if item.nodeId.isSome and item.nodeId.get() == nodeId:
            return item.data

    return none

func ncIsFinished*(self: NCFileArray): bool =
    ## Returns true if all file paths have been processed.
    for item in self.files:
        if item.nodeID.isNone or item.data.isNone:
            return false

    return true

proc ncNextUnprocessedFile*(self: var NCFileArray, nodeId: NCNodeId): Option[string] =
    ## Returns the next unprocessed file path.
    ## If no more file needs to be processed then return node
    for item in self.files.mitems():
        if item.nodeId.isNone:
            item.nodeId = some(nodeId)
            return some(item.path)

    return none

proc ncMaybeDeadNode*(self: var NCFileArray, nodeId: NCNodeId) =
    ## Notifies the file array that the given node may be dead.
    ## Sets the node id to none so that another node can process the file.
    for item in self.files.mitems():
        if item.nodeId.isSome and item.nodeId.get() == nodeId:
            item.nodeId = none
            return

