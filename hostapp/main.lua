local enet = require 'lua-enet'
local serpent = require("serpent")

local port = 8091
local sleep_period = 0.02  -- make syncing less battery draining

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

---[[ disable logging here
local function log() end
--]]

local url = '*:' .. port
log('starting server on', url)
local host = enet.host_create(url)
log('server', host and 'started' or 'failed to start')
local clients = {} -- keeping track of connected clients

local buttons = {'trigger', 'thumbstick', 'touchpad', 'grip', 'menu', 'a', 'b', 'x', 'y', 'proximity'}
local axes = {'trigger', 'thumbstick', 'touchpad', 'grip'}
local headsetData = {
  hands = {},
  tracked = {},
  velocity = {},
  angularVelocity = {},
  pose = {},
  isTouched = {},
  isDown = {},
  wasPressed = {},
  wasReleased = {},
  axes = {},
  skeleton = {},
}

local function eventLoop(host)
  while host do
    local event = host:service()
    if not event then break end
    if event.type == "receive" then
      local ok, command = serpent.load(event.data)
      if ok and command[1] == 'vibrate' then
        lovr.headset.vibrate(select(2, unpack(command)))
      end
    elseif event.type == "connect" then
      log(tostring("client connected", event.peer))
      clients[event.peer] = tostring(event.peer)
    elseif event.type == "disconnect" then
      log(tostring("client disconnected", event.peer))
      clients[event.peer] = nil
    end
  end
end

local function collectHeadsetData()
  headsetData.hands = lovr.headset.getHands()
  headsetData.tracked = {}
  headsetData.velocity['head'] = {lovr.headset.getVelocity('head')}
  headsetData.angularVelocity['head'] = {lovr.headset.getAngularVelocity('head')}
  headsetData.pose['head'] = {lovr.headset.getPose('head')}
  for i, hand in ipairs(headsetData.hands) do
    headsetData.tracked[hand] = lovr.headset.isTracked(hand) or nil
    headsetData.velocity[hand] = {lovr.headset.getVelocity(hand)}
    headsetData.angularVelocity[hand] = {lovr.headset.getAngularVelocity(hand)}
    headsetData.pose[hand] = {lovr.headset.getPose(hand)}
    local handpoint = hand .. '/point'
    headsetData.pose[handpoint] = {lovr.headset.getPose(handpoint)}
    headsetData.isTouched[hand] = {}
    headsetData.isDown[hand] = {}
    headsetData.wasPressed[hand] = {}
    headsetData.wasReleased[hand] = {}
    for _, button in ipairs(buttons) do
      headsetData.isTouched[hand][button] = lovr.headset.isTouched(hand, button) or nil
      headsetData.isDown[hand][button] = lovr.headset.isDown(hand, button) or nil
      headsetData.wasPressed[hand][button] = lovr.headset.wasPressed(hand, button) or nil
      headsetData.wasReleased[hand][button]= lovr.headset.wasReleased(hand, button) or nil
    end
    headsetData.axes[hand] = {}
    for _, axis in ipairs(axes) do
      headsetData.axes[hand][axis] = {lovr.headset.getAxis(hand, axis)}
    end
    headsetData.skeleton[hand] = lovr.headset.getSkeleton(hand)
  end
  return serpent.dump(headsetData)
end


function lovr.update(dt)
  eventLoop(host)
  local serializedData = collectHeadsetData()
  for client, _ in pairs(clients) do
    client:send(serializedData)
  end
  lovr.timer.sleep(sleep_period)
end


function lovr.draw(pass)
  local state = host and 'started' or 'failed to start'
  local y = 1
  pass:setColor(host and 0x535c89 or 0xb25e46)
  local pose = mat4(lovr.headset.getPose('head')):translate(0, 0, -4):scale(0.2)
  pass:text(state, pose)
  pass:setColor(0xcc925e)
  for _, peer in pairs(clients) do
    pose:translate(0, -1, 0)
    pass:text(peer, pose)
  end
end

return update
