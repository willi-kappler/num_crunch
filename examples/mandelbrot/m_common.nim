

type
    MandelInit* = object
        tileWidth*: uint32
        tileHeight*: uint32
        re1*: float64
        im1*: float64
        reStep*: float64
        imStep*: float64
        maxIter*: uint32

    MandelResult* = object
        tx*: uint32
        ty*: uint32
        pixelData*: seq[uint32]

