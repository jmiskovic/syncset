local buttons = { 'trigger', 'thumbstick', 'b', 'y', 'a', 'x', 'touchpad', 'menu', 'grip' }
local axes_in_button = { trigger = 1, thumbstick = 2, touchpad = 2, grip = 1 }

local palette = { 0xfbbbad,  -- https://lospec.com/palette-list/twilight-5
                  0xee8695,  -- 2
                  0x4a7a96,  -- 3
                  0x333f58,  -- 4
                  0x292831 } -- 5

lovr.graphics.setBackgroundColor(palette[5])

function lovr.draw(pass)
  pass:translate(0, 1, -0)
  local pose = mat4()
  for i, hand in ipairs(lovr.headset.getHands()) do
    local side = hand == 'hand/left' and 1 or -1
    -- hand pose block
    pose:set(lovr.headset.getPose(hand))
    pass:setColor(palette[4])
    local block_pose = mat4(pose):scale(0.08)
    block_pose:rotate(math.pi/6,  1,0,0)
    block_pose:translate(0, 0, 0.5)
    block_pose:rotate(-math.pi / 2,  0,0,1)
    block_pose:scale(0.2, 0.2, 0.4)
    pass:cylinder(block_pose, true)
    local bones = lovr.headset.getSkeleton(hand)
    if bones then -- hand bones
      pass:setColor(palette[3])
      for j, bone in ipairs(bones) do
        pose:set(unpack(bone)):scale(0.005, 0.003, 0.010)
        pass:sphere(pose)
      end
    else -- controller buttons bones
      local button_pose = mat4()
      local count = 0
      for j, button in ipairs(buttons) do
        button_pose:set(pose)
        button_pose:rotate(-math.pi / 3,  1,0,0)
        button_pose:translate(side * 0.05, 0, 0)
        button_pose:rotate(math.pi / 8,  0,side,0)
        button_pose:translate(0, -0.01 * count, 0)
        local touched = lovr.headset.isTouched(hand, button)
        local down = lovr.headset.isDown(hand, button)
        local axes = axes_in_button[button]
        if down ~= nil then
          count = count + 1
          if axes and axes == 1 then -- displace text by one or two axes
            local a = lovr.headset.getAxis(hand, button)
            if a then
              button_pose:translate(0, 0, a * -0.02)
              button_pose:rotate(a * math.pi / 6,  0,side,0)
            end
          elseif axes and axes == 2 then
            if x and y then
              local x, y = lovr.headset.getAxis(hand, button)
              button_pose:translate(0, 0, -0.01)
              button_pose:rotate( x * math.pi / 4,  0,1,0)
              button_pose:rotate(-y * math.pi / 4,  1,0,0)
              button_pose:translate(0, 0, 0.01)
            end
          end
          if down then
            button_pose:translate(0, 0, -0.005):scale(1.2)
            pass:setColor(palette[1])
          elseif touched then
            button_pose:scale(1.2)
            pass:setColor(palette[3])
          else -- idle
            pass:setColor(palette[3])
          end
          pass:text(string.upper(button), mat4(button_pose):scale(0.01))
        end
      end
    end
  end
end


require 'syncset'
