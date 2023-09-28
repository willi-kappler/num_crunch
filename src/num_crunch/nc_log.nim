

# Nim std imports
import std/locks
import std/logging

var ncLoggerLock: Lock
var ncLoggerEnabled: bool = false
var ncLogger: Logger

proc ncInitLogger*(newLogger: Logger) =
    ncLoggerEnabled = true
    initLock(ncLoggerLock)
    ncLogger = newLogger

proc ncDeinitLogger*() =
    ncLoggerEnabled = false
    deinitLock(ncLoggerLock)

proc ncLog*(level: Level, message: string) =
    if ncLoggerEnabled:
        withLock ncLoggerLock:
            {.cast(gcsafe).}:
                ncLogger.log(level, message)

proc ncDebug*(message: string) =
    ncLog(lvlDebug, message)

proc ncInfo*(message: string) =
    ncLog(lvlInfo, message)

proc ncError*(message: string) =
    ncLog(lvlError, message)

