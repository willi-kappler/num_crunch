
import num_crunch/private/nc_nodeid

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

block:
    # Test new node id
    let id = ncNewNodeId()
    echo("New node id: ", id)
    assert(id.len() == 32)
