
import nc_common

block:
    # Test for not equal
    let a = NCNodeID(id: "100")
    let b = NCNodeID(id: "200")

    assert(a != b)

block:
    # Test for equal
    let a = NCNodeID(id: "150")
    let b = NCNodeID(id: "150")

    assert(a == b)

