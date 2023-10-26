

# Nim std imports
import std/locks
import std/logging

var ncLoggerLock: Lock
var ncLoggerEnabled: bool = false
var ncLogger: ptr Logger
var ncDebugLevel: uint8 = 0

proc ncInitLogger*(newLogger: Logger, debugLevel: uint8 = 0) =
    ncLoggerEnabled = true
    initLock(ncLoggerLock)

    ncLogger = createShared(Logger)
    moveMem(ncLogger, newLogger.addr, sizeof(Logger))
    ncDebugLevel = debugLevel

proc ncDeinitLogger*() =
    ncLoggerEnabled = false
    deinitLock(ncLoggerLock)
    deallocShared(ncLogger)

proc ncLog*(level: Level, message: string) =
    if ncLoggerEnabled:
        withLock ncLoggerLock:
            ncLogger[].log(level, message)

proc ncDebug*(message: string, level: uint8 = 0) =
    if ncDebugLevel >= level:
        ncLog(lvlDebug, message)

proc ncInfo*(message: string) =
    ncLog(lvlInfo, message)

proc ncError*(message: string) =
    ncLog(lvlError, message)

