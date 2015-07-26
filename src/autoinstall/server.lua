#! /usr/bin/env lua5.1

local copas   = require "copas"
local socket  = require "socket"

do
  local command = "sudo apt-file update"
  assert (os.execute (command))
end
local port    = os.getenv "AUTOINSTALL_PORT" or 0
local server  = assert (socket.bind ("*", port))

local connections = 0

local function perform (filename)
  local file = io.open (filename, "r")
  if file then
    file:close ()
  elseif  filename:sub (1, 1) == "/"
  and not filename:match "^/home"
  and not filename:match "^/tmp"
  and not filename:match "^/run"
  and not filename:match "^/var/run"
  and not filename:match "^/var/lock"
  then
    local command = "apt-file search --fixed-string --package-only " .. filename
    local handle  = assert (io.popen (command, "r"))
    local output  = assert (handle:read "*all")
    handle:close ()
    local results = {}
    for line in output:gmatch "[^\r\n]*" do
      if line:match "%w+" then
        results [#results+1] = line
      end
    end
    if #results > 0 then
      command = "sudo apt-get install -y " .. results [1]
      os.execute (command)
    end
  end
  return true
end

copas.addserver (server, function (skt)
  connections = connections+1
  skt = copas.wrap (skt)
  repeat
    local line = skt:receive "*l"
    if line then
      skt:send (tostring (perform (line)) .. "\r\n")
    else
      skt:send "false\r\n"
    end
  until not line
  connections = connections-1
  if connections == 0 then
    copas.removeserver (server)
  end
end)

if port == 0 then
  local _, p = server:getsockname ()
  local file  = io.open ("autoinstall.port", "w")
  file:write (p)
  file:close ()
end
copas.loop ()
