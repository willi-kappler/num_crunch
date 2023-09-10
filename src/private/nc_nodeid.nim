
type
    NCNodeID* = object
        id*: string

func `==`*(left, right: NCNodeID): bool =
    left.id == right.id


