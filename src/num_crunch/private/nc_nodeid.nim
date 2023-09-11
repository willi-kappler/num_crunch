
# Nim std imports
from std/strutils import join
from std/random import sample

const ID_LENGTH = 32
const ID_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

type
    NCNodeID* = object
        id*: string

func `==`*(left, right: NCNodeID): bool =
    left.id == right.id

proc ncNewNodeId*(): NCNodeID =
    var id: seq[char] = @[]

    for i in 0..ID_LENGTH:
        let c = sample(ID_CHARS)
        id.add(c)

    result.id = join(id)
