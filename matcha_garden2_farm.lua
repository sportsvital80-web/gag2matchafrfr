if _G.MatchaCleanup then pcall(_G.MatchaCleanup) end
local ScriptActive = true

local pcall    = pcall
local pairs    = pairs
local ipairs   = ipairs
local tostring = tostring
local task     = task
local Vector2  = Vector2
local Vector3  = Vector3
local Color3   = Color3
local Drawing  = Drawing

local players   = game:GetService("Players")
local workspace = game:GetService("Workspace")
local player    = players.LocalPlayer



-- Auto-restart support - find script source
local RESTART_SOURCE = nil
local RESTART_PATHS = {
  "C:\\Users\\Administrator\\Desktop\\PROYECTOMATCHA\\matcha_garden2_farm.lua",
  "C:/Users/Administrator/Desktop/PROYECTOMATCHA/matcha_garden2_farm.lua",
  "matcha_garden2_farm.lua",
}
for _, p in ipairs(RESTART_PATHS) do
  local ok, src = pcall(readfile, p)
  if ok and src and type(src) == "string" and #src > 100 then
    RESTART_SOURCE = src
    break
  end
end
if not RESTART_SOURCE then
  print("[Farm] WARNING: auto-restart unavailable (can't read source)")
end

local harvestCycles = 0
local MAX_CYCLES = 2

local function safeNotify(msg, title, dur)
  pcall(function() notify(tostring(msg), tostring(title or "Farm"), dur or 3) end)
end

local function getHRP()
  local char = player.Character
  if not char then return nil end
  return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
end

local drawObjs = {}
local function D(typ, props)
  local obj = Drawing.new(typ)
  for k, v in pairs(props) do obj[k] = v end
  table.insert(drawObjs, obj)
  return obj
end

local uiPos   = Vector2.new(150, 120)
local uiSize  = Vector2.new(330, 196)
local dragging = false
local dragOff = Vector2.new(0, 0)
local lastM1  = false

local Shadow   = D("Square", {Size = Vector2.new(uiSize.X+6, uiSize.Y+6), Color = Color3.fromRGB(0,0,0), Transparency = 0.35, Filled = true, Visible = true})
local MainBG   = D("Square", {Size = uiSize, Color = Color3.fromRGB(12,12,16), Filled = true, Visible = true})
local TopBar   = D("Square", {Size = Vector2.new(uiSize.X, 30), Color = Color3.fromRGB(22,22,28), Filled = true, Visible = true})
local AccLine  = D("Square", {Size = Vector2.new(uiSize.X, 2), Color = Color3.fromRGB(0,200,120), Filled = true, Visible = true})
local TitleTxt = D("Text",   {Text = "FARM // GROW A GARDEN 2", Size = 13, Color = Color3.fromRGB(0,200,120), Outline = true, Visible = true, Font = Drawing.Fonts.System})

local MAXS = 5
local SLabel, SCheck, SFill = {}, {}, {}
for i = 1, MAXS do
  SLabel[i] = D("Text",   {Text = "", Size = 13, Color = Color3.fromRGB(190,190,195), Outline = true, Visible = false, Font = Drawing.Fonts.System})
  SCheck[i] = D("Circle", {Radius = 6, Thickness = 2, Color = Color3.fromRGB(0,200,120), Filled = false, Visible = false})
  SFill[i]  = D("Circle", {Radius = 3, Color = Color3.fromRGB(0,200,120), Filled = true, Visible = false})
end
local StatusTxt = D("Text", {Text = "", Size = 11, Color = Color3.fromRGB(70,70,80), Outline = true, Visible = true, Font = Drawing.Fonts.System})

local F = {}
local function feat(key, label, kind)
  local f = {key=key, label=label, kind=kind, value=false}
  table.insert(F, f)
  return f
end

feat("AutoHarvest", "AUTO HARVEST",     "toggle")
feat("AutoSell",    "AUTO SELL (SOON)", "soon")
feat("AutoLoot",    "AUTO LOOT",        "toggle")
feat("AutoSteal",   "AUTO STEAL",       "toggle")

local function fVal(key)
  for _, f in ipairs(F) do if f.key == key then return f.value end end
  return false
end

-- Farm logic
local VK_E = 0x45
local gardens = workspace:FindFirstChild("Gardens")

local function findPlot()
  for _, p in ipairs(gardens:GetChildren()) do
    if tostring(p:GetAttribute("Owner")) == player.Name then return p end
  end
end

local function tp(cf)
  local hrp = getHRP()
  if hrp then hrp.CFrame = cf end
end

local function tryCollect(hp)
  local hrp = getHRP()
  if not hrp then return end
  local ok, cf = pcall(function() return hp.CFrame end)
  if not ok or not cf then return end
  hrp.CFrame = cf * CFrame.new(0, 0.3, 0)
  keypress(VK_E); keyrelease(VK_E)
end

local function getSellButton()
  local pg = player:FindFirstChild("PlayerGui")
  if not pg then return nil end
  local tb = pg:FindFirstChild("TeleportButtons")
  if not tb then return nil end
  local inner = tb:FindFirstChild("TeleportButtons")
  if not inner then return nil end
  return inner:FindFirstChild("SellButton")
end

local function clickButton(btn, offX, offY)
  if not btn then return end
  local pos = btn.AbsolutePosition
  local size = btn.AbsoluteSize
  if not pos or not size then return end
  mousemoveabs(pos.X + size.X / 2 + (offX or 0), pos.Y + size.Y / 2 + (offY or 0))
  task.wait(0.15)
  mouse1click()
  task.wait(0.3)
end

local harvestCache = {}

local function scanHarvestCache(plot)
  harvestCache = {}
  local plants = plot and plot:FindFirstChild("Plants")
  if not plants then return end
  for _, plant in ipairs(plants:GetChildren()) do
    local fruits = plant:FindFirstChild("Fruits")
    if fruits then
      for _, fruit in ipairs(fruits:GetChildren()) do
        local base = fruit:FindFirstChild("Base")
        if base and base:IsA("BasePart") then
          table.insert(harvestCache, base)
        end
      end
    end
  end
end

local function doHarvest()
  local hrp = getHRP()
  if not hrp then return end
  for _, hp in ipairs(harvestCache) do
    if not fVal("AutoHarvest") then break end
    if hp and hp.Parent then
      local ok, cf = pcall(function() return hp.CFrame end)
      if ok and cf then
        local standPos = cf * CFrame.new(0, 0.5, -2)
        hrp.CFrame = standPos
        keypress(VK_E)
        for _ = 1, 8 do
          if not fVal("AutoHarvest") then break end
          hrp.CFrame = standPos
          task.wait(0.01)
        end
        keyrelease(VK_E)
      end
    end
  end
end

local function doSell()
  -- 1. Click SellButton → teleport to sell area
  local sb = getSellButton()
  if not sb then return end
  local pos = sb.AbsolutePosition
  local size = sb.AbsoluteSize
  if not pos or not size then return end
  local cx = pos.X + size.X / 2
  local cy = pos.Y + size.Y / 2
  task.wait(0.05)
  mousemoveabs(cx, cy)
  mousemoveabs(cx, cy + 12)
  task.wait(0.05)
  mouse1click(); mouse1click(); mouse1click()
  task.wait(2)

  -- 2. Press E to interact with NPC
  keypress(VK_E)
  task.wait(0.15)
  keyrelease(VK_E)
  task.wait(1)

  -- 3. Find Billboard_UI > Objects > Option_UI > Frame > Frame > TextLabel with "Sell Inventory!"
  local function findAndClickSellOption()
    local billboardUI = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("Billboard_UI")
    if not billboardUI then return false end
    local objects = billboardUI:FindFirstChild("Objects")
    if not objects then return false end
    for _, option in ipairs(objects:GetChildren()) do
      if option:IsA("GuiObject") and (option.Name == "Option_UI" or option.Name:find("Option")) then
        local f1 = option:FindFirstChild("Frame")
        local f2 = f1 and f1:FindFirstChild("Frame")
        local label = f2 and f2:FindFirstChild("TextLabel")
        if label and label:IsA("TextLabel") then
          local txt = (label.Text or "")
          if txt:find("#1") then
            local p = label.AbsolutePosition
            local s = label.AbsoluteSize
            if p and s and s.X > 0 then
              mousemoveabs(p.X + s.X/2, p.Y + s.Y/2)
              task.wait(0.15)
              mouse1click()
              return true
            end
          end
        end
      end
    end
    return false
  end
  if not findAndClickSellOption() then
    print("[Farm] Billboard_UI/Option with 'Sell Inventory' not found")
  end

  -- 4. Wait for NPC to finish and give money
  task.wait(2)
end

local lootCount = 0
local function doLoot()
  local di = workspace:FindFirstChild("DroppedItems")
  if not di then return end
  local hrp = getHRP()
  if not hrp then return end
  for _, item in ipairs(di:GetChildren()) do
    if not fVal("AutoLoot") then break end
    local anchor = item:FindFirstChild("PromptAnchor")
    if anchor and anchor:IsA("BasePart") then
      local ok, cf = pcall(function() return anchor.CFrame end)
      if ok and cf then
        hrp.CFrame = cf * CFrame.new(0, 1, 0)
        task.wait(0.1)
        keypress(VK_E)
        for _ = 1, 24 do
          if not fVal("AutoLoot") then break end
          task.wait(0.05)
        end
        keyrelease(VK_E)
        lootCount = lootCount + 1
      end
    end
  end
end

-- Auto Steal
local stolenCount = 0
local currentPhase = "?"

local function getPhase()
  local val = workspace:GetAttribute("ActivePhase")
  if val and val ~= "?" then currentPhase = tostring(val) end
  return currentPhase
end

local stealCache = {}
local function getPlotOwner(plot)
  local attrs = plot:GetAttributes()
  if attrs then return attrs["Owner"] end
  return nil
end

local function isPlayerInsidePlot(plr, plot)
  local char = plr.Character
  if not char then return false end
  local hrp = char:FindFirstChild("HumanoidRootPart")
  if not hrp then return false end
  local visual = plot:FindFirstChild("Visual")
  if not visual then return false end
  local sizeRef = visual:FindFirstChild("PlotSizeReference")
  if not sizeRef or not sizeRef:IsA("BasePart") then return false end
  local okPos, pos = pcall(function() return sizeRef.Position end)
  local okSz, sz = pcall(function() return sizeRef.Size end)
  if not okPos or not okSz then return false end
  local plrPos = hrp.Position
  local dx = math.abs(plrPos.X - pos.X)
  local dy = math.abs(plrPos.Y - pos.Y)
  local dz = math.abs(plrPos.Z - pos.Z)
  return dx <= sz.X/2 and dy <= sz.Y/2 and dz <= sz.Z/2
end

local function isOwnerOutside(plot)
  local owner = getPlotOwner(plot)
  if not owner then return true end
  local plr = players:FindFirstChild(owner)
  if not plr then print("[Steal] " .. owner .. " offline"); return true end
  local inside = isPlayerInsidePlot(plr, plot)
  if inside then return false end
  print("[Steal] " .. owner .. " outside plot")
  return true
end

local function scanStealCache()
  stealCache = {}
  if not gardens then return end
  local myPlot = findPlot()
  if not myPlot then return end
  local myOwner = getPlotOwner(myPlot)
  local sp = myPlot:FindFirstChild("SpawnPoint")
  local spawnCF = sp and pcall(function() return sp.CFrame end) and sp.CFrame or nil
  for _, p in ipairs(gardens:GetChildren()) do
    if getPlotOwner(p) ~= myOwner and isOwnerOutside(p) then
      local plants = p:FindFirstChild("Plants")
      if plants then
        for _, plant in ipairs(plants:GetChildren()) do
          local fruits = plant:FindFirstChild("Fruits")
          if fruits then
            for _, fruit in ipairs(fruits:GetChildren()) do
              local base = fruit:FindFirstChild("Base")
              if base and base:IsA("BasePart") then
                table.insert(stealCache, {part = base, spawn = spawnCF})
              end
            end
          end
        end
      end
    end
  end
end

local function doSteal()
  scanStealCache()
  if #stealCache == 0 then print("[Steal] 0 fruits on other plots"); return end
  print("[Steal] " .. #stealCache .. " fruits found on other plots")
  local hrp = getHRP()
  if not hrp then return end
  for i, target in ipairs(stealCache) do
    if not fVal("AutoSteal") then break end
    local ok, cf = pcall(function() return target.part.CFrame end)
    if ok and cf then
      local standPos = cf * CFrame.new(0, 0.5, -2)
      hrp.CFrame = standPos
      keypress(VK_E)
      for _ = 1, 8 do
        if not fVal("AutoSteal") then break end
        hrp.CFrame = standPos
        task.wait(0.01)
      end
      keyrelease(VK_E)
      stolenCount = stolenCount + 1
      if i % 20 == 0 and target.spawn then
        hrp.CFrame = target.spawn * CFrame.new(0, 3, 0)
      end
    end
  end
  print("[Steal] +" .. #stealCache .. " (total " .. stolenCount .. ")")
end

-- Farm loop
task.spawn(function()
  print("[Farm] Waiting 3s before starting...")
  task.wait(3)
  mouse1click()
  task.wait(0.3)

  local plot = findPlot()
  if not plot then print("[Farm] No plot found"); return end
  print("[Farm] Plot: " .. plot.Name)
  scanHarvestCache(plot)
  print("[Farm] Cached " .. #harvestCache .. " harvest targets")

  local prevHarvest = false
  local cam = workspace.CurrentCamera
  while ScriptActive do
    local harvesting = fVal("AutoHarvest")
    if harvesting then
      pcall(function() cam.CameraType = Enum.CameraType.Scriptable end)
      pcall(function() cam.CFrame = CFrame.new(Vector3.new(0, 75, 0), Vector3.new(0, 0, 0)) end)
      task.wait(0.08)
    else
      if prevHarvest then pcall(function() cam.CameraType = Enum.CameraType.Custom end) end
      task.wait(0.5)
    end
    if not plot or not plot.Parent then plot = findPlot() end
    if plot then
      if prevHarvest and not harvesting then
        local sp = plot:FindFirstChild("SpawnPoint")
        if sp then tp(sp.CFrame * CFrame.new(0, 3, 0)) end
      end
      prevHarvest = harvesting
      local selling = fVal("AutoSell")
      if harvesting then
        scanHarvestCache(plot); doHarvest()
        harvestCycles = harvestCycles + 1
        if harvestCycles >= MAX_CYCLES and RESTART_SOURCE then
          print("[Farm] Auto-restart after " .. harvestCycles .. " cycles")
          _G.MatchaCleanup()
          task.wait(1)
          task.spawn(loadstring(RESTART_SOURCE))
          return
        end
      end
      if selling and false then doSell() end
      if fVal("AutoLoot") then doLoot() end
      if fVal("AutoSteal") and getPhase() == "Night" then doSteal() end
    end
  end
end)

local ActionMap = {}

local function Render()
  Shadow.Position  = Vector2.new(uiPos.X - 3, uiPos.Y - 3)
  MainBG.Position  = uiPos
  TopBar.Position  = uiPos
  AccLine.Position = Vector2.new(uiPos.X, uiPos.Y + 30)
  TitleTxt.Position = Vector2.new(uiPos.X + 10, uiPos.Y + 8)

  local slot = 0
  for _, f in ipairs(F) do
    slot = slot + 1
    if slot <= MAXS then
      local yy = uiPos.Y + 38 + ((slot-1) * 28)
      SLabel[slot].Text = (f.kind == "action") and (">> " .. f.label) or ("> " .. f.label)
      SLabel[slot].Position = Vector2.new(uiPos.X + 16, yy)
      SLabel[slot].Color = (f.kind == "action") and Color3.fromRGB(255,200,80) or (f.kind == "soon") and Color3.fromRGB(120,120,120) or ((f.value) and Color3.fromRGB(120,255,120) or Color3.fromRGB(190,190,195))
      SLabel[slot].Visible = true
      SCheck[slot].Position = Vector2.new(uiPos.X + uiSize.X - 22, yy + 7)
      SCheck[slot].Visible = (f.kind == "toggle")
      SFill[slot].Position = SCheck[slot].Position
      SFill[slot].Visible = (f.kind == "toggle" and f.value == true)
    end
  end
  for i = slot + 1, MAXS do
    SLabel[i].Visible = false; SCheck[i].Visible = false; SFill[i].Visible = false
  end

  local hrp = getHRP()
  local yStr = hrp and tostring(math.floor(hrp.Position.Y)) or "?"
  StatusTxt.Text = "Y:" .. yStr .. " | Loot:" .. lootCount .. " Steal:" .. stolenCount .. " | " .. currentPhase
  StatusTxt.Position = Vector2.new(uiPos.X + 10, uiPos.Y + uiSize.Y - 16)
end

task.spawn(function()
  print("[UI] Input loop ready")
  while ScriptActive do
    task.wait(0.016)
    local mx, my = 0, 0
    pcall(function() local m = player:GetMouse(); mx = m.X; my = m.Y end)
    local m1 = false
    pcall(function() m1 = ismouse1pressed() end)

    if m1 and not lastM1 then
      local slot = 0
      for _, f in ipairs(F) do
        slot = slot + 1
        if slot <= MAXS then
          local yy = uiPos.Y + 38 + ((slot-1) * 28)
          if mx >= uiPos.X + 10 and mx <= uiPos.X + uiSize.X - 10 and my >= yy - 2 and my <= yy + 22 then
            if f.kind == "toggle" then
              f.value = not f.value
              local extra = ""
              if f.key == "AutoSteal" and f.value then extra = " [" .. getPhase() .. "]" end
              print("[UI] TOGGLED: " .. f.key .. " = " .. tostring(f.value) .. extra)
              safeNotify(f.label .. ": " .. (f.value and "ON" or "OFF") .. extra, "Toggle", 2)
            elseif f.kind == "soon" then
              safeNotify("Coming soon!", "WIP", 2)
            elseif f.kind == "action" then
              print("[UI] ACTION: " .. f.key)
              local handler = ActionMap[f.key]
              if handler then task.spawn(handler) end
            end
          end
        end
      end
      if mx >= uiPos.X and mx <= uiPos.X + uiSize.X and my >= uiPos.Y and my <= uiPos.Y + 30 then
        dragging = true
        dragOff = Vector2.new(mx - uiPos.X, my - uiPos.Y)
      end
    end

    if dragging then
      if m1 then uiPos = Vector2.new(mx - dragOff.X, my - dragOff.Y)
      else dragging = false end
    end

    lastM1 = m1
    pcall(Render)
  end
end)

_G.MatchaCleanup = function()
  ScriptActive = false
  pcall(function() workspace.CurrentCamera.CameraType = Enum.CameraType.Custom end)
  for _, obj in ipairs(drawObjs) do pcall(function() obj:Remove() end) end
  print("[Farm] Cleanup done")
end

safeNotify("Farm Hub loaded!", "Garden 2", 3)
print("[Farm] AUTO HARVEST + AUTO SELL + AUTO LOOT + AUTO STEAL ready")
