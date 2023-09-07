# Package
version       = "0.1.0"
author        = "Willi Kappler"
description   = "Distributed number crunching with nim"
license       = "MIT"
srcDir        = "src"

# Dependencies
requires "nim >= 1.6.14"

# Tasks

task testAll, "Run all test cases in tests/":
    exec "testament --print --verbose c /"
