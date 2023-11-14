## This module is part of num_crunch: https://github.com/willi-kappler/num_crunch
## Written by Willi Kappler, License: MIT
##
## This module contains helper functions to convert string to and from bytes.
## And helper functions to convert any given value of any type to a sequence of bytes and back.
##


# External import
from flatty import fromFlatty, toFlatty

func ncStrToBytes*(s: string): seq[byte] =
    ## Convert the given a string to a sequence of bytes.
    @(s.toOpenArrayByte(0, s.high()))

func ncBytesToStr*(s: seq[byte]): string =
    ## Convert the given sequence of bytes to a string.
    let l = s.len()
    result = newString(l)

    if l > 0:
        copyMem(unsafeAddr(result[0]), unsafeAddr(s[0]), l)

proc ncToBytes*[T](data: T): seq[byte] =
    ## Converts the given data (of any type) to a sequence of bytes.
    let encStr = toFlatty(data)
    return ncStrToBytes(encStr)

proc ncFromBytes*[T](data: seq[byte], x: typedesc[T]): T =
    ## Converts the given sequence of bytes to a value of the given Type T.
    let encStr = ncBytesToStr(data)
    return fromFlatty(encStr, T)

