# Common helper functions and types
from flatty import fromFlatty, toFlatty

from private/nc_message import ncStrToBytes, ncBytesToStr

proc ncToBytes*[T](data: T): seq[byte] =
    let encStr = toFlatty(data)
    return ncStrToBytes(encStr)

proc ncFromBytes*[T](data: seq[byte]): T =
    let encStr = ncBytesToStr(data)
    return fromFlatty(encStr, T)

