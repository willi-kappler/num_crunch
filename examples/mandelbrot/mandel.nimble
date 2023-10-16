# Package
version       = "0.1.0"
author        = "Willi Kappler"
description   = "Distributed Mandelbrot with nim"
license       = "MIT"
srcDir        = "src"

# Dependencies
requires "nim >= 2.0.0"
#requires "num_crunch >= 0.1.0"
requires "https://github.com/willi-kappler/num_crunch"

# Tasks
task runMandelbrot, "Runs the mandelbrot example":
    exec "nim c mandel.nim"
    exec "./mandel --server &"
    # Start four nodes
    exec "./mandel &"
    exec "./mandel &"
    exec "./mandel &"
    exec "./mandel &"


