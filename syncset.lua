-- receive headset data from syncset server and inject it into simulator
local enet = require 'lua-enet'
local serpent = require 'serpent'

local headset_ip = '192.168.0.42'
local port = 8091
local wrap_update = true  -- to use, place the require'syncset' at the end of main!
local verbose = false     -- prints out all the received data!
local offset = Vec3(0, 0.2, -0.7)

local logbook = {}

local function log(text, ...)
  for i,v in ipairs({...}) do
    text = text .. ' ' .. tostring(v)
  end
  print(text)
  table.insert(logbook, text)
  if #logbook > 30 then
    table.remove(logbook, 1)
  end
end

--[[ disable logging here
local function log() end
--]]

local host = enet.host_create()
local url = headset_ip .. ':' .. port
log('connecting to ', url)
local server = host:connect(url)
local headsetData = {
    hands = {},
    tracked = {},
    angularVelocity = {
      head           = {0,0,0},
    },
    pose = {
      head           = {0,0,0,0,0,0,0},
    },
    velocity = {
      head           = {0,0,0,0,0,0,0},
    },
    isTouched = {},
    isDown = {},
    wasPressed = {},
    wasReleased = {},
    axes = {},
    skeleton = {},
  }

function eventLoop(host)
  while true and host do
    local event = host:service()
    if not event then break end
    if event.type == "receive" then
      local ok, freshData = serpent.load(event.data)
      if ok then
        --log('headset data update received') -- too noisy
        headsetData = freshData
      else
        log('headset data deserialization error')
      end
    elseif event.type == "connect" then
      log(tostring(event.peer) .. " connected")
    elseif event.type == "disconnect" then
      log(tostring(event.peer) .. " disconnected")
    end
  end
end

-- monkey-patch LOVR headset functions so they return data from actual headset
lovr.headset.getHands = function()
  return headsetData.hands
end
lovr.headset.isTracked = function(device)
  return headsetData.tracked[device] or false
end
lovr.headset.getPose = function(device)
  local x, y, z, angle, ax, ay, az = unpack(headsetData.pose[device or 'head'])
  x = x + offset.x
  y = y + offset.y
  z = z + offset.z
  return x, y, z, angle, ax, ay, az
end
lovr.headset.getPosition = function(device)
  local x, y, z = unpack(headsetData.pose[device or 'head'])
  x = x + offset.x
  y = y + offset.y
  z = z + offset.z
  return x, y, z
end
lovr.headset.getVelocity = function(device)
  return unpack(headsetData.velocity[device or 'head'])
end
lovr.headset.getAngularVelocity = function(device)
  return unpack(headsetData.angularVelocity[device or 'head'])
end
lovr.headset.getSkeleton = function(hand)
  return headsetData.skeleton[hand]
end
lovr.headset.isTouched = function(hand, button)
  return headsetData.isTouched[hand][button] or false
end
lovr.headset.isDown = function(hand, button)
  return headsetData.isDown[hand][button] or false
end
lovr.headset.wasPressed = function(hand, button)
  return headsetData.wasPressed[hand][button] or false
end
lovr.headset.wasReleased = function(hand, button)
  return headsetData.wasReleased[hand][button] or false
end
lovr.headset.getAxis = function(hand, axis)
  if headsetData.axes[hand] then
    return unpack(headsetData.axes[hand][axis])
  end
end
lovr.headset.vibrate = function(device, strength, duration, frequency)
  local command = serpent.dump({'vibrate', device, strength, duration, frequency})
  server:send(command)
end

function update(dt)
  eventLoop(host)
  if verbose then
    log(serpent.block(headsetData))
  end
end

-- automate lovr.update() calling so that the syncset can be used by simply requiring it at the end of main
if wrap_update then
  local existing_update = lovr.update

  if existing_update then
    lovr.update = function(dt)
      update(dt)
      existing_update(dt)
    end
  else
    lovr.update = update
  end
end


return update
