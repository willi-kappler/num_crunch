## This module is part of num_crunch: https://github.com/willi-kappler/num_crunch
##
## Written by Willi Kappler, License: MIT
##
## This module contains a simple logger facade for num crunch.
## You just have to provide your own logger object that implements the
## std/logging/Logger interface.
##

# Nim std imports
import std/locks
import std/logging

var ncLoggerLock: Lock
var ncLoggerEnabled: bool = false
var ncLogger: ptr Logger
var ncDebugLevel: uint8 = 0

proc ncInitLogger*(newLogger: Logger, debugLevel: uint8 = 0) =
    ## Initialized the num crunch internal logger with the given logger and debug level.
    ncLoggerEnabled = true
    initLock(ncLoggerLock)

    ncLogger = createShared(Logger)
    moveMem(ncLogger, newLogger.addr, sizeof(Logger))
    ncDebugLevel = debugLevel

proc ncDeinitLogger*() =
    ## Releases the logger resources.
    ncLoggerEnabled = false
    deinitLock(ncLoggerLock)
    deallocShared(ncLogger)

proc ncLog*(level: Level, message: string) =
    ## Log the given message with the given log level.
    if ncLoggerEnabled:
        withLock ncLoggerLock:
            ncLogger[].log(level, message)

proc ncDebug*(message: string, level: uint8 = 0) =
    ## Outputs a debug message with the given debug level.
    if ncDebugLevel >= level:
        ncLog(lvlDebug, message)

proc ncInfo*(message: string) =
    ## Outputs a info message.
    ncLog(lvlInfo, message)

proc ncError*(message: string) =
    ## Outputs an error message.
    ncLog(lvlError, message)

