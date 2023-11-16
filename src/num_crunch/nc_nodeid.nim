## This module is part of num_crunch: https://github.com/willi-kappler/num_crunch
##
## Written by Willi Kappler, License: MIT
##
## This module contains the NCNodeID data type and some helper functions.
##

# Nim std imports
from std/strutils import join
from std/random import sample

const ID_LENGTH = 32
const ID_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

type
    NCNodeID* = object
        ## The node id data structure.
        id: string

func `==`*(left, right: NCNodeID): bool =
    ## Compare two node ids if they are equal.
    left.id == right.id

func len*(id: NCNodeID): int =
    ## The length of the nodeid value.
    id.id.len()

func ncNodeWithId*(id: string): NCNodeID =
    ## Create a new node id with the given value.
    NCNodeID(id: id)

proc ncNewNodeId*(): NCNodeID =
    ## Creates a new random node id.
    var id = newSeq[char]()

    for i in 1..ID_LENGTH:
        let c = sample(ID_CHARS)
        id.add(c)

    result.id = join(id)

