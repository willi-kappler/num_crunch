

# Nim std imports
import std/assertions
import std/logging

# External imports
from chacha20 import Nonce, Key
from supersnappy import SnappyError

# Local imports
import num_crunch/private/nc_message
import num_crunch/nc_log

proc test1() =
    # Check normal function
    let data = "This is a secret message"
    let nonceStr = "123456789012"
    let keyStr = "12345678901234567890123456789012"

    var nonce = cast[ptr(Nonce)](unsafeAddr(nonceStr[0]))
    var key = cast[ptr(Key)](unsafeAddr(keyStr[0]))

    let encodedData = ncEncodeMessage(data, key[], nonce[])
    assert(data != encodedData)

    let decodedData = ncDecodeMessage(encodedData, key[], nonce[])
    assert(data == decodedData)

proc test2() =
    # Invalid nonce
    let data = "This is a secret message"
    let nonceStr1 = "123456789012"
    let nonceStr2 = "123456789011"
    let keyStr = "12345678901234567890123456789012"

    var nonce1 = cast[ptr(Nonce)](unsafeAddr(nonceStr1[0]))
    var nonce2 = cast[ptr(Nonce)](unsafeAddr(nonceStr2[0]))
    var key = cast[ptr(Key)](unsafeAddr(keyStr[0]))

    let encodedData = ncEncodeMessage(data, key[], nonce1[])
    assert(data != encodedData)

    doAssertRaises(SnappyError):
        let decodedData = ncDecodeMessage(encodedData, key[], nonce2[])
        assert(data != decodedData)

proc test3() =
    # Invalid key
    let data = "This is a secret message"
    let nonceStr = "123456789012"
    let keyStr1 = "12345678901234567890123456789012"
    let keyStr2 = "12345678901234567890123456789011"

    var nonce = cast[ptr(Nonce)](unsafeAddr(nonceStr[0]))
    var key1 = cast[ptr(Key)](unsafeAddr(keyStr1[0]))
    var key2 = cast[ptr(Key)](unsafeAddr(keyStr2[0]))

    let encodedData = ncEncodeMessage(data, key1[], nonce[])
    assert(data != encodedData)

    doAssertRaises(SnappyError):
        let decodedData = ncDecodeMessage(encodedData, key2[], nonce[])
        assert(data != decodedData)

proc test4() =
    # Test integer conversion:
    let i: uint32 = 35
    let s = ncIntToStr(i)
    assert(s.len() == 4)

    let j = ncStrToInt(s)
    assert(j == i)

when isMainModule:
    let logger = newFileLogger("tests/test_nc_message.log", fmtStr=verboseFmtStr)
    ncInitLogger(logger)

    test1()
    test2()
    test3()
    test4()

    ncDeinitLogger()

