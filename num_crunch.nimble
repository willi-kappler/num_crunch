# Package
version       = "0.1.0"
author        = "Willi Kappler"
description   = "Distributed number crunching with nim"
license       = "MIT"
srcDir        = "src"

# Dependencies
requires "nim >= 2.0.0"
requires "supersnappy >= 2.1.3"
requires "flatty >= 0.3.4"
requires "chacha20 >= 0.1.0"

# Tasks
task(testAll, "Run all test cases in tests/"):
    exec("testament --print --verbose c /")

task(checkAll, "run 'nim check' on all source files"):
    cd("src/")
    exec("nim check num_crunch.nim")

    cd("num_crunch/")
    exec("nim check nc_array2d.nim")
    exec("nim check nc_array3d.nim")
    exec("nim check nc_common.nim")
    exec("nim check nc_config.nim")
    exec("nim check nc_node.nim")
    exec("nim check nc_nodeid.nim")
    exec("nim check nc_server.nim")

    cd("private/")
    # Check private modules:
    exec("nim check nc_message.nim")

