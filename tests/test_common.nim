
from chacha20 import Nonce, Key

import private/nc_message

block:
    let data = "This is a secret message"
    let nonceStr = "123456789012"
    let keyStr = "12345678901234567890123456789012"

    var nonce = cast[ptr(Nonce)](unsafeAddr(nonceStr[0]))
    var key = cast[ptr(Key)](unsafeAddr(keyStr[0]))

    let encodedData = ncEncodeMessage(data, key[], nonce[])
    let decodedData = ncDecodeMessage(encodedData, key[], nonce[])

    assert(data == decodedData)

