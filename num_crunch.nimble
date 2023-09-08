# Package
version       = "0.1.0"
author        = "Willi Kappler"
description   = "Distributed number crunching with nim"
license       = "MIT"
srcDir        = "src"

# Dependencies
requires "nim >= 1.6.14"
requires "supersnappy >= 2.1.3"
requires "flatty >= 0.3.4"
requires "chacha20 >= 0.1.0"

# Tasks

task(testAll, "Run all test cases in tests/"):
    exec("testament --print --verbose c /")

task(checkAll, "run 'nim check' on the main source file"):
    cd("src/")
    exec("nim check num_crunch.nim")
