#[
  Author: Miqueas Martínez (https://github.com/Miqueas)
  Co-Author: Nelson "darltrash" López (https://github.com/darltrash)
  Date: 2020/09/12
  License: zlib (see it in the repository)
  Git Repository: https://github.com/Miqueas/Logit
]#

import std/times
import std/strformat
from std/os import dirExists, getTempDir, getAppFilename, `/`
from std/strutils import join, format

#[======== PRIVATE ========]#

proc e(n: varargs[int]): string = return '\e' & '[' & join(n, ";") & 'm'

const
  FMT = (
    Filename: "$1_$2.log",
    Time: "HH:mm:ss",
    Out: (
      File: "$1 [$2 $3] $4@$5: $6\n",
      Console: e(2) & "$1 [" & e(0,1) & "$2 $3$4" & e(0,2) & "] $5@$6:" & e(0) & " $7"
      #                                     ^~ This one is used for the log level color
    ),
    Header: (
      File: "\n$1 [$2]\n\n",
      Console: '\n' & e(2) & "$1 [" & e(0, 1) & "$2" & e(0, 2) & "]" & e(0) & '\n'
    ),
    Quit: (
      File: "$1 [QUIT]: $2\n",
      Console: e(2) & "$1 [" & e(0, 1) & "$2QUIT" & e(0, 2) & "]: " & e(0) & "$3\n"
      #                                   ^~ This one is used for the log level color
    )
  )

  ASSOC = [
    ( name: "OTHER", color: 30 ),
    ( name: "TRACE", color: 32 ),
    ( name: "INFO.", color: 34 ),
    ( name: "DEBUG", color: 36 ),
    ( name: "WARN.", color: 33 ),
    ( name: "ERROR", color: 31 ),
    ( name: "FATAL", color: 35 )
  ]

#[======== PUBLIC ========]#

type
  LogLevel* = enum
    OTHER,
    TRACE,
    INFO,
    DEBUG,
    WARN,
    ERROR,
    FATAL

  Logit* = object
    file: File
    path: string
    autoExit*: bool
    namespace*: string
    filePrefix*: TimeFormat
    defaultLevel*: LogLevel
    enableConsole*: bool

# Prepares Logit for logging using the given `Logit` instance.
# This function assumes that `Logit` has everything ready to
# start logging, that means you must have set the `path` property
proc prepare*(self: var Logit) {.raises: [IOError, ValueError].} =
  let
    dt = now()
    date = dt.format(self.filePrefix)
    filename = FMT.Filename.format(date, self.namespace)

  try:
    self.file = open(self.path / filename, fmAppend)
  except:
    raise newException(IOError, fmt"can't open/write file {filename}")

# Creates a new `Logit` instance using the given properties
# or fallback to default values if not arguments
# given
proc initLogit*(path = getTempDir(),
                name = "Logit",
                lvl = OTHER,
                console = false,
                exit = true,
                prefix = initTimeFormat("YYYY-MM-dd")
               ): Logit {.raises: [IOError, ValueError].} =
  if not dirExists(path):
    raise newException(IOError, fmt"`{path}` isn't a valid path or doesn't exists")
  
  var self = Logit(
    path: path,
    autoExit: exit,
    namespace: name,
    filePrefix: prefix,
    defaultLevel: lvl,
    enableConsole: console
  )

  self.prepare()
  return self

# Logging API
template log*(self: Logit, lvl: LogLevel, logMsg = "", quitMsg = "") =
  let
    time = now().format(FMT.Time)
    msg =
      if logMsg == "": ASSOC[ord(lvl)].name
      else: logMsg
    exitMsg =
      if quitMsg == "": msg
      else: quitMsg
    info = instantiationInfo(0)

  self.file.write(FMT.Out.File.format(
    time,
    self.namespace,
    ASSOC[ord(lvl)].name,
    info.filename,
    info.line,
    msg
  ))

  if self.enableConsole:
    echo FMT.Out.Console.format(
      time,
      self.namespace,
      e(ASSOC[ord(lvl)].color),
      ASSOC[ord(lvl)].name,
      info.filename,
      info.line,
      msg
    )

  if ord(lvl) > 4 and self.autoExit:
    self.file.write(FMT.Quit.File.format(time, exitMsg))
    self.file.close()

    if self.enableConsole:
      quit(FMT.Quit.Console.format(time, e(ASSOC[ord(lvl)].color), exitMsg), 1)
    else:
      quit(1)

# Some "shortcuts"
{.push inline.}
template log*(self: Logit, msg = "", quitMsg = "") =
  self.log(self.defaultLevel, msg, quitMsg)

template `()`*(self: Logit, msg = "", quitMsg = "") =
  self.log(self.defaultLevel, msg, quitMsg)

template `()`*(self: Logit, lvl: LogLevel, msg = "", quitMsg = "") =
  self.log(lvl, msg, quitMsg)
{.pop.}

# Automatically logs an error if `exp` is `false`. If autoExit is
# `false` you may don't need/want to use this proc
template expect*(self: Logit, exp: bool, msg = "", lvl = ERROR, quitMsg = ""): untyped =
  if not exp: self.log(lvl, msg, quitMsg)

# Writes a "header"
proc header*(self: Logit, msg: string) =
  let time = now().format(FMT.Time)
  
  self.file.write(FMT.Header.File.format(time, msg))

  if self.enableConsole:
    echo FMT.Header.Console.format(time, msg)

# Closes the internal file. Call this proc if you're sure you'll
# not need to use a `Logit` instance anymore
proc done*(self: var Logit) {.inline.} =
  self.file.close()

# Getter for `path`
proc path*(self: Logit): string {.inline.} =
  return self.path

# Setter for `path`
proc `path=`*(self: var Logit, newPath: string) {.raises: [IOError, ValueError].} =
  if not dirExists(newPath):
    raise newException(IOError, fmt"`{newPath}` isn't a valid path or doesn't exists")
  self.path = newPath