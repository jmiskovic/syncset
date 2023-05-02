-- receive headset data from syncset server and inject it into simulator
local enet = require 'lua-enet'
local serpent = require 'serpent'

local headset_ip = '192.168.0.22'
local port = 8091
local wrap_update = true  -- to use, place the require'syncset' at the end of main!
local verbose = false     -- prints out all the received data!
local offset = Vec3(0, 0.2, -0.7) -- applied on top of tracked positions

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

local device_map = {
  [''] = 'head',
  ['head'] = 'head',
  ['left'] = 'hand/left',
  ['hand/left'] = 'hand/left',
  ['left/point'] = 'hand/left/point',
  ['hand/left/point'] = 'hand/left/point',
  ['right'] = 'hand/right',
  ['hand/right'] = 'hand/right',
  ['right/point'] = 'hand/right/point',
  ['hand/right/point'] = 'hand/right/point',
}


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
  local dev = device_map[device or '']
  return headsetData.tracked[dev] or false
end
lovr.headset.getPose = function(device)
  local dev = device_map[device or '']
  if headsetData.pose[dev] then
    local x, y, z, angle, ax, ay, az = unpack(headsetData.pose[dev])
    x = x + offset.x
    y = y + offset.y
    z = z + offset.z
    return x, y, z, angle, ax, ay, az
  else
    return 0,0,0,0,0,0,0
  end
end
lovr.headset.getPosition = function(device)
  local dev = device_map[device or '']
  if headsetData.pose[dev] then
    local x, y, z = unpack(headsetData.pose[dev])
    x = x + offset.x
    y = y + offset.y
    z = z + offset.z
    return x, y, z
  else
    return 0,0,0
  end
end
lovr.headset.getOrientation = function(device)
  local dev = device_map[device or '']
  if headsetData.pose[dev] then
    local angle, ax, ay, az = select(7, unpack(headsetData.pose[dev]))
    return angle, ax, ay, az
  else
    return 0,0,0,0
  end
end
lovr.headset.getVelocity = function(device)
  local dev = device_map[device or '']
  return unpack(headsetData.velocity[dev] or {0,0,0})
end
lovr.headset.getAngularVelocity = function(device)
  local dev = device_map[device or '']
  return unpack(headsetData.angularVelocity[dev] or {0,0,0})
end
lovr.headset.getSkeleton = function(device)
  local dev = device_map[device or '']
  return headsetData.skeleton[dev]
end
lovr.headset.isTouched = function(device, button)
  local dev = device_map[device or '']
  return headsetData.isTouched[dev] and (headsetData.isTouched[dev][button] or false)
end
lovr.headset.isDown = function(device, button)
  local dev = device_map[device or '']
  return headsetData.isDown[dev] and (headsetData.isDown[dev][button] or false)
end
lovr.headset.wasPressed = function(device, button)
  local dev = device_map[device or '']
  return headsetData.wasPressed[dev] and (headsetData.wasPressed[dev][button] or false)
end
lovr.headset.wasReleased = function(device, button)
  local dev = device_map[device or '']
  return headsetData.wasReleased[dev] and (headsetData.wasReleased[dev][button] or false)
end
lovr.headset.getAxis = function(device, axis)
  local dev = device_map[device or '']
  if headsetData.axes[dev] then
    return unpack(headsetData.axes[dev] and headsetData.axes[dev][axis] or {})
  end
end
lovr.headset.vibrate = function(device, strength, duration, frequency)
  local dev = device_map[device or '']
  local command = serpent.dump({'vibrate', dev, strength, duration, frequency})
  server:send(command)
end

function update(dt)
  -- reset the button changes that are only supposed to be active for a single frame
  for hand, buttons in pairs(headsetData.wasPressed) do
    for button, state in pairs(buttons) do
      headsetData.wasPressed[hand][button] = false
    end
  end
  for hand, buttons in pairs(headsetData.wasReleased) do
    for button, state in pairs(buttons) do
      headsetData.wasReleased[hand][button] = false
    end
  end
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
