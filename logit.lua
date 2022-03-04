--[[
  Author: Miqueas Martinez (https://github.com/Miqueas)
  Co-Author: Nelson "darltrash" López (https://github.com/darltrash)
  Date: 2020/09/12
  License: zlib (see it in the repository)
  Git Repository: https://github.com/Miqueas/Logit
]]

-- 0x1b: see the Wikipedia link above
local ESC = string.char(27)
local is_win

if love then
  is_win = love.system.getOS() == "Windows"
elseif jit then
  is_win = jit.os == "Windows"
else
  -- Windows specific env var
  if os.getenv("WinDir") then
    is_win = true
  else
    is_win = false
  end
end

-- Helper function to create color escape-codes. Read this for more info:
-- https://en.wikipedia.org/wiki/ANSI_escape_code
-- One or more numbers expected
local function e(...)
  return ESC .. "[" .. table.concat({ ... }, ";") .. "m"
end

-- Return the path to the temp dir
local function get_temp_dir()
  if is_win then
    -- Windows. Same as:
    --     os.getenv("TEMP")
    --     os.getenv("TMP")
    return os.getenv("UserProfile") .. "\\AppData\\Local\\Temp"
  else
    -- Unix
    return os.getenv("TMPDIR") or "/tmp"
  end
end

-- Return `true` if `path` exists
local function dir_exists(path)
  local f = io.open(path)
  return (f and f:close()) and true or false
end

-- Appends a / or a \ (depending on the OS) at the end of a path string
local function dir_normalize(str)
  str = tostring(str or "")

  if is_win then
    -- Windows
    str = (not str:find("%\\+", -1))
      and str:gsub("/", "\\") .. "\\"
      or str:gsub("/", "\\")
  else
    -- POSIX
    str = (not str:find("%/+", -1))
      and str:gsub("\\", "/") .. "/"
      or str:gsub("\\", "/")
  end

  return str
end

function _(s)
  if s == "other"
    or s == "trace"
    or s == "debug"
    or s == "info"
    or s == "warn"
    or s == "error"
    or s == "fatal"
  then
    return true
  else
    return false
  end
end

-- String templates
local FMT = {
  Filename = "%s_%s.log",
  Time = "%H:%M:%S",
  Out = {
    File = "%s [%s %s] %s@%s: %s",
    Console = e(2) .. "%s [" .. e(0, 1) .. "%s %s%s" .. e(0, 2) .. "] %s@%s:" .. e(0) .. " %s"
    --                                         ^~ This one is used for the log level color
  },
  Header = {
    File = "\n%s [%s]\n\n",
    Console = "\n" .. e(2) .. "%s [" .. e(0, 1) .. "%s" .. e(0, 2) .. "]" .. e(0) .. "\n\n"
  },
  Quit = {
    File = "%s [QUIT]: %s\n",
    Console = e(2) .. "%s [" .. e(0, 1, 31) .. "QUIT" .. e(0, 2) .. "]: " .. e(0) .. "%s\n"
  }
}

local ASSOC = {
  [0] = { name = "OTHER", color = "30" },
  [1] = { name = "TRACE", color = "32" },
  [2] = { name = "DEBUG", color = "36" },
  [3] = { name = "INFO.", color = "34" },
  [4] = { name = "WARN.", color = "33" },
  [5] = { name = "ERROR", color = "31" },
  [6] = { name = "FATAL", color = "35" },
}

-- The Logit class
local Logit = {}

-- Public log levels
Logit.OTHER = 0
Logit.TRACE = 1
Logit.DEBUG = 2
Logit.INFO = 3
Logit.WARN = 4
Logit.ERROR = 5
Logit.FATAL = 6

-- Path where log files are saved
Logit.path = dir_normalize("./")
Logit.namespace = "Logit"
Logit.filePrefix = "%Y-%m-%d"
Logit.defaultLevel = Logit.OTHER
-- By default, Logit don't write logs to the terminal
Logit.enableConsole = false

function Logit:new(path, name, level, console, prefix, ...)
  local err = "Bad argument #%s to 'new()', '%s' expected, got '%s'"

  -- Arguments type check
  do
    assert(
      type(name) == "string" or type(name) == "nil",
      err:format(1, "string", type(name))
    )

    assert(
      type(path) == "string" or type(path) == "nil",
      err:format(2, "string", type(path))
    )

    assert(
      type(console) == "boolean" or type(console) == "nil",
      err:format(3, "boolean", type(console))
    )

    assert(
      type(suffix) == "string" or type(suffix) == "nil",
      err:format(4, "string", type(suffix))
    )

    assert(
      type(header) == "string" or type(header) == "nil",
      err:format(5, "string", type(header))
    )
  end

  local o = setmetatable({}, { __call = self.log, __index = self })
  o.namespace = name or self.namespace
  o.enableConsole = console or self.enableConsole
  o.filePrefix = prefix or self.filePrefix

  -- If 'path' is nil or an empty string, then uses the current
  -- path for the logs files
  if not path or #path == 0 then
    o.path = self.path

  -- Or converts 'path' to a valid path (if exists)
  elseif path and dir_exists(path) then
    o.path = dir_normalize(path)

  -- Or stops if the path doesn't exists
  elseif path and not dir_exists(path) then
    error("Path '" .. path .. "' doesn't exists or you don't have permissions to use it.")
  else -- Or... Idk... Unexpected errors can happen!
    error("Unknown error while checking '" .. path .. "'... (argument #2 in 'new()')")
  end

  -- Writes a header at begin of the log
  local date = os.date(o.filePrefix)
  local time = os.date(FMT.Time)
  local file = io.open(o.path .. FMT.Filename:format(date, o.namespace), "a+")

  -- The gsub at the end removes color escape-codes
  file:write(FMT.Header.File:format(time, "GENERATED BY LOGIT, DO NOT EDIT"))
  file:close()

  if o.enableConsole then
    print(FMT.Header.Console:format(time, "LOGGING LIBRARY STARTED"))
  end

  return o
end

function Logit:log(lvl, msg, ...)
  local lvlt = type(lvl)
  local err = "Bad argument #1 to 'log()', 'number' expected, got '"
    .. lvlt
    .. "'"

  -- 'lvl' isn't optional anymore and is the first argument needed
  assert(lvlt == "number", err)

  -- 'log()' assumes that 'msg' is an string
  msg = tostring(msg or LogType[lvl].Name)

  -- This prevents that 'Logit.lua' appears in the log message
  -- when 'expect()' is called.
  -- Basically it's like the ternary operator in C:
  --    (exp) ? TRUE : FALSE
  local info = (debug.getinfo(2, "Sl").short_src:find("(Logit.lua)"))
      and debug.getinfo(3, "Sl")
    or debug.getinfo(2, "Sl")

  -- The log file
  local file = io.open(
    self.Path .. FMT.FName:format(self.Namespace, os.date(self.Suffix)),
    "a+"
  )

  -- Prevents put different times in the file and the standard output
  local time = os.date(FMT.Time)
  local fout = FMT.Out.LogFile:format(
    time,
    self.Namespace,
    -- Name of the type of log
    LogType[lvl].Name,
    -- Source file from 'log()' is called
    info.short_src, -- Line where is called
    info.currentline,
    msg:format(...) -- Removes ANSI SGR codes:gsub("(" .. ESC .. "%[(.-)m)", "")
  )

  -- The '\n' makes logs divide by lines instead of accumulating
  file:write(fout .. "\n")
  file:close()

  if self.Console then
    local cout = FMT.Out.Console:format(
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
    self:header(e(31) .. "SOMETHING WENT WRONG!")

    -- For Love2D compatibility
    if love then
      love.event.quit()
    end
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

-- Write a log "header". Can be useful if you want to separate some logs
-- or create "breakpoints", etc...
function Logit:header(msg, ...)
  if type(msg) == "string" and #msg > 0 then
    msg = msg:format(...)
    local time = os.date(FMT.Time)
    local file = io.open(
      self.Path .. FMT.FName:format(self.Namespace, os.date(self.Suffix)),
      "a+"
    )

    -- The gsub at the end removes color escape-codes
    local fout = LogHeader:format(time, msg):gsub(ESC .. "%[(.-)m", "")
    file:write(fout)
    file:close()

    if self.Console then
      print(LogHeader:format(time, msg))
    end
  end
end

function Logit:set_suffix(str)
  assert(type(str) == "string")

  str = (#str > 0) and str or "%Y-%m-%d"

  self.Suffix = str
end

local function Logit__index(self, k)
  if not rawget(self, k) and _(k) then
    local l = rawget(self, k:upper())
    return function(this, ...)
      this:log(l, ...)
    end
  elseif rawget(self, k) then
    return rawget(self, k)
  else
    return nil
  end
end

return setmetatable(Logit, {
  __call = Logit.new,
  __index = Logit__index,
})