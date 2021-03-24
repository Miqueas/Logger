--[[
  Author: Miqueas Martinez (https://github.com/Miqueas)
  Co-Author: Nelson "darltrash" López (https://github.com/darltrash)
  Date: 2020/09/12
  License: MIT (see it in the repository)
  Git Repository: https://github.com/Miqueas/Logit
]]

-- 0x1b: see the Wikipedia link above
local ESC = string.char(27)

-- Helper function to create color escape-codes. Read this for more info:
-- https://en.wikipedia.org/wiki/ANSI_escape_code
-- One or more numbers expected
local function e(...)
  return ESC.."["..table.concat({...}, ";").."m"
end

-- Return true if 'path' exists or false if not
local function DirExists(path)
  local f = io.open(path)
  return (f and f:close()) and true or false
end

-- Appends a / or a \ (depending on the OS's directory system) at the end of a path string
local function DirNormalize(str)
  local str = tostring(str or "")
  local posix = (jit) and not (jit.os == "Windows") or os.getenv("HOME")

  if posix then
    -- POSIX
    str = (not str:find("%/+", -1))
      and str:gsub("\\", "/") .. "/"
       or str:gsub("\\", "/")
  else
    -- Windows
    str = (not str:find("%\\+", -1))
      and str:gsub("/", "\\") .. "\\"
       or str:gsub("/", "\\")
  end

  return str
end

function _(s)
  if
    s == "other" or
    s == "trace" or
    s == "debug" or
    s == "info" or
    s == "warn" or
    s == "error" or
    s == "fatal"
  then
    return true
  else
    return false
  end
end

-- String templates
local Fmt = {
  Out = {
    Console  = e(2).."%s ["..e(0,1).."%s %s%s"..e(0,2).."] %s@%s:"..e(0).." %s",
    LogFile  = "%s [%s %s] %s@%s: %s"
  },
  FName = "%s_%s.log",
  Time = "%H:%M:%S"
}

local LogType = {
  [0] = { Name = "OTHER", Color = "30" },
  [1] = { Name = "TRACE", Color = "32" },
  [2] = { Name = "DEBUG", Color = "36" },
  [3] = { Name = "INFO.", Color = "34" },
  [4] = { Name = "WARN.", Color = "33" },
  [5] = { Name = "ERROR", Color = "31" },
  [6] = { Name = "FATAL", Color = "35" }
}

local unp       = table.unpack or unpack
-- Header template
local LogHeader = "\n"..e(2).."%s ["..e(0,1).."%s"..e(0,2).."]"..e(0).."\n"

-- The Logit class
local Logit = {}

-- Path where log files are saved
Logit.Path      = DirNormalize("./")
Logit.Namespace = "Logit"
-- By default, Logit don't write logs to the terminal
Logit.Console   = false
Logit.Suffix    = "%Y-%m-%d"

-- Public log types
Logit.OTHER = 0
Logit.TRACE = 1
Logit.DEBUG = 2
Logit.INFO  = 3
Logit.WARN  = 4
Logit.ERROR = 5
Logit.FATAL = 6

function Logit:new(name, dir, console, suffix, header, ...)
  local err = "Bad argument #%s to 'new()', '%s' expected, got '%s'"

  -- Arguments type check
  assert(
    type(name) == "string" or type(name) == "nil",
    err:format(1, "string", type(name))
  )

  assert(
    type(dir) == "string" or type(dir) == "nil",
    err:format(2, "string",  type(dir))
  )

  assert(
    type(console) == "boolean" or type(console) == "nil",
    err:format(3, "boolean", type(console))
  )

  assert(
    type(suffix) == "string" or type(suffix) == "nil",
    err:format(4, "string",  type(suffix))
  )

  assert(
    type(header) == "string" or type(header) == "nil",
    err:format(5, "string",  type(header))
  )
  -- End Arguments type check

  local o = setmetatable({}, { __call = self.log, __index = self })
  o.Namespace = name    or self.Namespace
  o.Console   = console or self.Console
  o.Suffix    = suffix  or self.Suffix

  -- If 'dir' is nil or an empty string, then uses the current
  -- path for the logs files
  if not dir or #dir == 0 then
    o.Path = self.Path

  -- Or converts 'dir' to a valid path (if exists)
  elseif dir and DirExists(dir) then
    o.Path = DirNormalize(dir)

  -- Or stops if the path doesn't exists
  elseif dir and not DirExists(dir) then
    error("Path '"..dir.."' doesn't exists or you don't have permissions to use it.")

  -- Or... Idk... Unexpected errors can happen!
  else
    error("Unknown error while checking (and/or loading) '"..dir.."'... (argument #2 in 'new()')")
  end

  -- Writes a header at begin of the log
  local header = header and header:format(...) or "AUTOGENERATED BY LOGGER"
  local time = os.date(Fmt.Time)
  local file = io.open(
    o.Path..Fmt.FName:format(
      o.Namespace,
      os.date(o.Suffix)
    ),
    "a+"
  )

  -- The gsub at the end removes color escape-codes
  local fout = LogHeader:format(time, header):gsub(ESC.."%[(.-)m", "")
  file:write(fout)
  file:close()

  -- Header is written, so... Returns the new Logit instance!
  return o
end

function Logit:log(lvl, msg, ...)
  local lvlt = type(lvl)
  local err = "Bad argument #1 to 'log()', 'number' expected, got '"..lvlt.."'"

  -- 'lvl' isn't optional anymore and is the first argument needed
  assert(lvlt == "number", err)

  -- 'log()' assumes that 'msg' is an string
  local msg = tostring(msg or LogType[lvl].Name)

  -- This prevents that 'Logit.lua' appears in the log message when 'expect()' is called.
  -- Basically it's like the ternary operator in C:
  --    (exp) ? TRUE : FALSE
  local info = (debug.getinfo(2, "Sl").short_src:find("(Logit.lua)"))
    and debug.getinfo(3, "Sl")
     or debug.getinfo(2, "Sl")

  -- The log file
  local file = io.open(
    self.Path .. Fmt.FName:format(
      self.Namespace,
      os.date(self.Suffix)
    ),
    "a+"
  )

  -- Prevents put different times in the file and the standard output
  local time = os.date(Fmt.Time)
  local fout = Fmt.Out.LogFile:format(
    time,
    self.Namespace,
    -- Name of the type of log
    LogType[lvl].Name,
    -- Source file from 'log()' is called
    info.short_src, -- Line where is called
    info.currentline,
    msg:format(...)
      -- Removes ANSI SGR codes
      :gsub("("..ESC.."%[(.-)m)", "")
  )

  -- The '\n' makes logs divide by lines instead of accumulating
  file:write(fout.."\n")
  file:close()

  if self.Console then
    local cout = Fmt.Out.Console:format(
      time,
      self.Namespace,
      -- Uses the correct color for differents logs
      e(LogType[lvl].Color),
      LogType[lvl].Name,
      info.short_src,
      info.currentline,
      -- Here we don't remove ANSI codes because we want a colored output
      msg:format(...)
    )
    print(cout)
  end

  if lvl > 4 then
    -- A log level major to 4 causes the program to stop
    self:header(e(31).."SOMETHING WENT WRONG!")

    -- For Love2D compatibility
    if love then love.event.quit() end
    os.exit(1)
  end
end

function Logit:expect(exp, msg, ...)
  -- 'expect()' is mainly for errors
  if not exp then
    self:log(self.ERROR, msg, ...)
  else
    return exp
  end
end

-- Write a log "header". Can be useful if you want to separate some logs or create "breakpoints", etc...
function Logit:header(msg, ...)
  if type(msg) == "string" and #msg > 0 then
    local msg  = msg:format(...)
    local time = os.date(Fmt.Time)
    local file = io.open(
      self.Path..Fmt.FName:format(
        self.Namespace,
        os.date(self.Suffix)
      ),
      "a+"
    )

    -- The gsub at the end removes color escape-codes
    local fout = LogHeader:format(time, msg):gsub(ESC.."%[(.-)m", "")
    file:write(fout)
    file:close()

    if self.Console then
      print(LogHeader:format(time, msg))
    end
  end
end

function Logit:set_suffix(str)
  local strt = type(str)
  local err  = "Bad argument for 'set_suffix()', 'string' expected, got '" .. strt .. "'"

  assert(strt == "string")

  local str = (#str > 0)
    and str
     or "%Y-%m-%d"

  self.Suffix = str
end

function Logit__index(self, k)
  if not rawget(self, k) and _(k) then
    local l = rawget(self, k:upper())
    return function (self, ...)
      self:log(l, ...)
    end
  elseif rawget(self, k) then
    return rawget(self, k)
  else
    return nil
  end
end

return setmetatable(Logit, {
  __call = Logit.new,
  __index = Logit__index
})
