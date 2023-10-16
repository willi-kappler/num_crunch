

type
    MandelParams* = object
        tx*: uint32
        ty*: uint32
        re1*: float64
        reStep*: float64
        img1*: float64
        imStep*: float64

    MandelResult* = object
        tx*: uint32
        ty*: uint32
        pixelData*: seq[uint32]

