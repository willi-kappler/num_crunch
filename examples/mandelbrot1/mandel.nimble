# Package
version       = "0.1.0"
author        = "Willi Kappler"
description   = "Distributed Mandelbrot with nim"
license       = "MIT"
srcDir        = "src"
bin           = @["mandel"]

# Dependencies
requires "nim >= 2.0.0"
#requires "num_crunch >= 0.1.0"
#requires "https://github.com/willi-kappler/num_crunch#head"

# Tasks
task checkAll, "run 'nim check' on all source files":
    exec "nim check m_common.nim"
    exec "nim check m_node.nim"
    exec "nim check m_server.nim"
    exec "nim check mandel.nim"

task runMandel, "Runs the mandelbrot example":
    exec "nim c -d:release mandel.nim"
    exec "./mandel --server &"
    exec "sleep 5"

    # Start four nodes
    exec "./mandel &"
    exec "sleep 1"

    exec "./mandel &"
    exec "sleep 1"

    exec "./mandel &"
    exec "sleep 1"

    exec "./mandel &"

task cleanMandel, "Clean up after calculation":
    exec "rm -f mandel"
    exec "rm -f *.log"
    exec "rm -f *.ppm"

