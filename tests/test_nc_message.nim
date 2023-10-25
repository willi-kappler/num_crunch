

# Nim std imports
import std/assertions
import std/logging

# External imports
from chacha20 import Nonce, Key
from supersnappy import SnappyError

# Local imports
import num_crunch/private/nc_message
import num_crunch/nc_log
import num_crunch/nc_nodeid

proc test1() =
    # Check normal function
    let data = "This is a secret message"
    let keyStr = "12345678901234567890123456789012"

    var key = cast[ptr(Key)](unsafeAddr(keyStr[0]))

    let encodedData = ncEncodeMessage(data, key[])
    assert(data != encodedData)

    let decodedData = ncDecodeMessage(encodedData, key[])
    assert(data == decodedData)

proc test2() =
    # Encode server message
    let nodeId = ncNewNodeId()
    let data: seq[byte] = @[2, 9, 4, 6, 1]
    let message = NCServerMessage(id: nodeId, data: data)
    let keyStr = "12345678901234567890123456789012"

    var key = cast[ptr(Key)](unsafeAddr(keyStr[0]))

    let encodedMessage = ncEncodeServerMessage(message, key[])
    let decodedMessage = ncDecodeServerMessage(encodedMessage, key[])

    assert(nodeId == decodedMessage.id)
    assert(data == decodedMessage.data)

proc test3() =
    # Encode node message
    let messageKind = NCNodeMsgKind.newData
    let data: seq[byte] = @[5, 6, 1, 0, 9]
    let message = NCNodeMessage(kind: messageKind, data: data)
    let keyStr = "12345678901234567890123456789012"

    var key = cast[ptr(Key)](unsafeAddr(keyStr[0]))

    let encodedMessage = ncEncodeNodeMessage(message, key[])
    let decodedMessage = ncDecodeNodeMessage(encodedMessage, key[])

    assert(messageKind == decodedMessage.kind)
    assert(data == decodedMessage.data)

proc test4() =
    # Invalid key
    let data = "This is a secret message"
    let keyStr1 = "12345678901234567890123456789012"
    let keyStr2 = "12345678901234567890123456789011"

    var key1 = cast[ptr(Key)](unsafeAddr(keyStr1[0]))
    var key2 = cast[ptr(Key)](unsafeAddr(keyStr2[0]))

    let encodedData = ncEncodeMessage(data, key1[])
    assert(data != encodedData)

    doAssertRaises(SnappyError):
        let decodedData = ncDecodeMessage(encodedData, key2[])
        assert(data != decodedData)

when isMainModule:
    let logger = newFileLogger("tests/test_nc_message.log", fmtStr=verboseFmtStr)
    ncInitLogger(logger)

    test1()
    test2()
    test3()
    test4()

    ncDeinitLogger()

