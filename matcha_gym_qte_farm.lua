if _G.GymQTECleanup then pcall(_G.GymQTECleanup) end
local ScriptActive = true

local pcall  = pcall
local pairs  = pairs
local task   = task
local Drawing = Drawing

local players = game:GetService("Players")
local C0 = Color3.fromRGB

local C_A  = C0(0, 212, 170)
local C_BG = C0(14, 14, 22)
local C_TP = C0(24, 24, 38)
local C_TX = C0(225, 225, 235)
local C_DM = C0(100, 100, 115)
local C_SP = C0(30, 30, 48)

local drawObjs = {}
local function D(typ, props)
  local obj = Drawing.new(typ)
  for k, v in pairs(props) do
    obj[k] = v
  end
  table.insert(drawObjs, obj)
  return obj
end

-- UI layout
local TH = 34
local RH = 28
local SH = 12
local STH = 12
local uiS = Vector2.new(260, TH + 2 + SH + RH * 2 + SH + STH + 8)

local SHD = D("Square", {Size = Vector2.new(uiS.X + 8, uiS.Y + 8), Color = C0(0, 0, 0), Transparency = 0.35, Filled = true, Visible = true})
local BG  = D("Square", {Size = uiS, Color = C_BG, Filled = true, Visible = true})
local TB  = D("Square", {Size = Vector2.new(uiS.X, TH), Color = C_TP, Filled = true, Visible = true})
local AL  = D("Square", {Size = Vector2.new(uiS.X, 2), Color = C_A, Filled = true, Visible = true})
local TT  = D("Text",   {Text = "GYM FARM", Size = 14, Color = C_A, Outline = true, Visible = true, Font = Drawing.Fonts.System})

local SEP = D("Square", {Size = Vector2.new(uiS.X - 24, 1), Color = C_SP, Filled = true, Visible = true})

local LN1 = D("Text", {Text = "", Size = 13, Color = C_TX, Outline = true, Visible = true, Font = Drawing.Fonts.System})
local SC1 = D("Circle", {Radius = 8, Thickness = 2, Color = C_DM, Filled = false, Visible = true})
local SF1 = D("Circle", {Radius = 5, Color = C_A, Filled = true, Visible = true})

local LN2 = D("Text", {Text = "", Size = 13, Color = C_TX, Outline = true, Visible = true, Font = Drawing.Fonts.System})
local SC2 = D("Circle", {Radius = 8, Thickness = 2, Color = C_DM, Filled = false, Visible = true})
local SF2 = D("Circle", {Radius = 5, Color = C_A, Filled = true, Visible = true})

local STX = D("Text", {Text = "", Size = 11, Color = C_DM, Outline = true, Visible = true, Font = Drawing.Fonts.System})

local uiPos = Vector2.new(150, 120)
local drg, dOff, hov = false, Vector2.new(0, 0), 0

-- State
local gymRun = false
local gymCount = 0
local curlRun = false
local curlCount = 0
local CURL_ANGLE_UP = math.rad(140)
local CURL_ANGLE_DOWN = math.rad(40)
local CURL_DIST = 220
local CURL_STEPS = 18

-- Mouse functions
local function moveMouse(x, y)
  local cx, cy = 0, 0
  pcall(function()
    local m = players.LocalPlayer and players.LocalPlayer:GetMouse()
    if m then cx = m.X; cy = m.Y end
  end)
  local dx, dy = x - cx, y - cy
  local dist = math.sqrt(dx * dx + dy * dy)
  local steps = math.max(1, math.min(4, math.floor(dist / 120)))
  for i = 1, steps do
    local t = i / steps
    mousemoveabs(cx + dx * t, cy + dy * t)
    task.wait(0.003)
  end
end

local function moveMouseSlow(x, y)
  local cx, cy = 0, 0
  pcall(function()
    local m = players.LocalPlayer and players.LocalPlayer:GetMouse()
    if m then cx = m.X; cy = m.Y end
  end)
  local dx, dy = x - cx, y - cy
  local dist = math.sqrt(dx * dx + dy * dy)
  local steps = math.max(4, math.min(14, math.floor(dist / 30)))
  for i = 1, steps do
    local t = i / steps
    mousemoveabs(cx + dx * t, cy + dy * t)
    task.wait(0.012)
  end
end

-- FATIGUE CHECK
local function getFatigue()
  local lp = players.LocalPlayer
  if not lp then return nil, nil end
  local pg = lp:FindFirstChild("PlayerGui")
  if not pg then return nil, nil end
  local fatigue = pg:FindFirstChild("Fatigue")
  if not fatigue then return nil, nil end
  local prog = fatigue:FindFirstChild("Progress")
  if not prog then return nil, nil end
  local txt = prog:FindFirstChild("ProgressionText")
  if not txt then return nil, nil end
  local val = txt.Text
  if not val or val == "" then return nil, nil end
  local cur, mx = val:match("(%d+)/(%d+)")
  if cur and mx then
    return tonumber(cur), tonumber(mx)
  end
  return nil, nil
end

local function isFatigueMaxed()
  local cur, mx = getFatigue()
  if cur and mx and cur >= mx then return true end
  return false
end

local function isFatigueEmpty()
  local cur, mx = getFatigue()
  if cur == nil then return false end
  if cur == 0 then return true end
  return false
end

-- GYM
local function getGymBtn()
  local lp = players.LocalPlayer
  if not lp then return nil end
  local pg = lp:FindFirstChild("PlayerGui")
  if not pg then return nil end
  local gym = pg:FindFirstChild("Gym")
  if not gym then return nil end
  local cb = gym:FindFirstChild("ClickBar")
  if not cb then return nil end
  return cb:FindFirstChild("ClickButton")
end

local function gymClick()
  local btn = getGymBtn()
  if not btn then return end
  local p, s = btn.AbsolutePosition, btn.AbsoluteSize
  if not p or not s then return end
  local cx = p.X + s.X / 2
  local cy = p.Y + s.Y / 2
  moveMouse(cx + 5, cy)
  task.wait(0.01)
  moveMouse(cx - 5, cy)
  task.wait(0.01)
  moveMouse(cx, cy)
  task.wait(0.01)
  mouse1click()
  task.wait(0.01)
end

local function gymLoop()
  while gymRun do
    if isFatigueMaxed() then
      while gymRun and not isFatigueEmpty() do
        task.wait(0.1)
      end
    end
    local btn = getGymBtn()
    if btn then
      gymClick()
      gymCount = gymCount + 1
    end
    task.wait(0.02)
  end
end

-- CURL / LAT PULLDOWN
local function getCurlBtn()
  local lp = players.LocalPlayer
  if not lp then return nil end
  local pg = lp:FindFirstChild("PlayerGui")
  if not pg then return nil end
  local gym = pg:FindFirstChild("Gym")
  if not gym then return nil end
  local db = gym:FindFirstChild("DragBar")
  if not db then return nil end
  local inner = db:FindFirstChild("InnerFrame")
  if not inner then return nil end
  local drag = inner:FindFirstChild("DragButton")
  if not drag then return nil end
  return drag:FindFirstChild("text")
end

local curlLocked = false
local curlUseUp = true

local function autoCurlLoop()
  curlLocked = false
  while curlRun do
    if isFatigueMaxed() then
      while curlRun and not isFatigueEmpty() do
        task.wait(0.1)
      end
    end
    local btn = getCurlBtn()
    if btn then
      local p, s = btn.AbsolutePosition, btn.AbsoluteSize
      if p and s then
        local cx = p.X + s.X / 2
        local cy = p.Y + s.Y / 2
        if not curlLocked then
          curlUseUp = cy > 500
          curlLocked = true
        end
        local angle = curlUseUp and CURL_ANGLE_UP or CURL_ANGLE_DOWN
        local ySign = curlUseUp and -1 or 1
        moveMouseSlow(cx, cy)
        task.wait(0.02)
        mouse1press()
        for i = 1, CURL_STEPS do
          if not curlRun then break end
          local t = i / CURL_STEPS
          local nx = cx + math.cos(angle) * CURL_DIST * t
          local ny = cy + ySign * math.abs(math.sin(angle)) * CURL_DIST * t
          mousemoveabs(nx, ny)
          task.wait(0.008)
        end
        task.wait(0.02)
        mouse1release()
        curlCount = curlCount + 1
      end
      task.wait(0.05)
    else
      task.wait(0.1)
    end
  end
  curlLocked = false
end

-- UI loop
task.spawn(function()
  while ScriptActive do
    task.wait(0.016)
    local mx, my = 0, 0
    pcall(function()
      local m = players.LocalPlayer and players.LocalPlayer:GetMouse()
      if m then mx = m.X; my = m.Y end
    end)
    local m1 = false
    pcall(function() m1 = ismouse1pressed() end)
    local x0, y0 = uiPos.X, uiPos.Y

    -- Hit areas
    local inX = mx >= x0 and mx <= x0 + uiS.X
    local ly1 = y0 + TH + 2 + SH
    local ly2 = ly1 + RH
    local hit1 = inX and my >= ly1 and my <= ly1 + RH
    local hit2 = inX and my >= ly2 and my <= ly2 + RH

    hov = hit1 and 1 or hit2 and 2 or 0

    -- Click toggle
    if m1 and not _G._glm1 then
      if hit1 then
        gymRun = not gymRun
        if gymRun then task.spawn(gymLoop) end
      elseif hit2 then
        curlRun = not curlRun
        if curlRun then task.spawn(autoCurlLoop) end
      end
    end

    -- Drag
    if m1 and not _G._glm1 and inX and my >= y0 and my <= y0 + TH then
      drg = true
      dOff = Vector2.new(mx - x0, my - y0)
    end
    if drg then
      if m1 then
        uiPos = Vector2.new(mx - dOff.X, my - dOff.Y)
      else
        drg = false
      end
    end

    -- Hotkeys
    if iskeypressed(0x31) and not _G._gk1 then
      _G._gk1 = true
      gymRun = not gymRun
      if gymRun then task.spawn(gymLoop) end
    end
    if not iskeypressed(0x31) then _G._gk1 = false end

    if iskeypressed(0x32) and not _G._gk2 then
      _G._gk2 = true
      curlRun = not curlRun
      if curlRun then task.spawn(autoCurlLoop) end
    end
    if not iskeypressed(0x32) then _G._gk2 = false end

    _G._glm1 = m1

    -- Render
    SHD.Position = Vector2.new(x0 - 4, y0 - 4)
    BG.Position = uiPos
    TB.Position = uiPos
    AL.Position = Vector2.new(x0, y0 + TH)
    TT.Position = Vector2.new(x0 + 12, y0 + 10)

    SEP.Position = Vector2.new(x0 + 12, ly1 - SH / 2)

    LN1.Text = "[1] BENCH / SQUAT"
    LN1.Color = gymRun and C_A or (hov == 1 and C_TX or C_DM)
    LN1.Position = Vector2.new(x0 + 34, ly1 + 7)
    SC1.Position = Vector2.new(x0 + 16, ly1 + RH / 2)
    SC1.Color = gymRun and C_A or C_DM
    SF1.Position = Vector2.new(x0 + 16, ly1 + RH / 2)
    SF1.Visible = gymRun

    LN2.Text = "[2] CURL / LAT PULLDOWN"
    LN2.Color = curlRun and C_A or (hov == 2 and C_TX or C_DM)
    LN2.Position = Vector2.new(x0 + 34, ly2 + 7)
    SC2.Position = Vector2.new(x0 + 16, ly2 + RH / 2)
    SC2.Color = curlRun and C_A or C_DM
    SF2.Position = Vector2.new(x0 + 16, ly2 + RH / 2)
    SF2.Visible = curlRun

    STX.Text = "Gym: " .. gymCount .. "   Curl: " .. curlCount
    STX.Position = Vector2.new(x0 + 12, ly2 + RH + SH)
  end
end)

_G.GymQTECleanup = function()
  ScriptActive = false
  gymRun = false
  curlRun = false
  for _, obj in ipairs(drawObjs) do
    pcall(function() obj:Remove() end)
  end
  print("[Gym] Cleanup done")
end

print("Gym loaded - Keys 1/2 toggle Bench/Squat & Curl/Lat")
