# Common helper functions and types
from flatty import fromFlatty, toFlatty

func ncStrToBytes*(s: string): seq[byte] =
    @(s.toOpenArrayByte(0, s.high()))

func ncBytesToStr*(s: seq[byte]): string =
    let l = s.len()
    result = newString(l)

    if l > 0:
        copyMem(unsafeAddr(result[0]), unsafeAddr(s[0]), l)

proc ncToBytes*[T](data: T): seq[byte] =
    let encStr = toFlatty(data)
    return ncStrToBytes(encStr)

proc ncFromBytes*[T](data: seq[byte], x: typedesc[T]): T =
    let encStr = ncBytesToStr(data)
    return fromFlatty(encStr, T)

