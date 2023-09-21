
import num_crunch/nc_nodeid

block:
    # Test for not equal
    let a = ncNodeWithId("100")
    let b = ncNodeWithId("200")

    assert(a != b)

block:
    # Test for equal
    let a = ncNodeWithId("150")
    let b = ncNodeWithId("150")

    assert(a == b)

block:
    # Test new node id
    let id = ncNewNodeId()
    echo("New node id: ", id)
    assert(id.len() == 32)
