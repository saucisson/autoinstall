local socket = require "socket"
local port   = assert (os.getenv "AUTOINSTALL_PORT")
local client = socket.tcp ()
assert (client:connect ("localhost", port))

function _G.install (filename)
  assert (type (filename) == "string")
  assert (client:send (filename .. "\r\n"))
  return client:receive "*l" == "true"
end
