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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

-- UI colors
local C_ACCENT = Color3.fromRGB(0, 212, 170)
local C_ACCENT2 = Color3.fromRGB(0, 180, 140)
local C_BG = Color3.fromRGB(14, 14, 22)
local C_TOP = Color3.fromRGB(24, 24, 38)
local C_TEXT = Color3.fromRGB(225, 225, 235)
local C_DIM = Color3.fromRGB(100, 100, 115)
local C_TOFF = Color3.fromRGB(55, 55, 72)
local C_ACTN = Color3.fromRGB(255, 186, 76)
local C_SOON = Color3.fromRGB(110, 110, 126)
local C_HOV = Color3.fromRGB(28, 28, 44)
local C_SEP = Color3.fromRGB(30, 30, 48)
local C_SHD = Color3.fromRGB(0, 0, 0)

local uiPos   = Vector2.new(150, 120)
local ROW_H = 28
local TOP_H = 32
local ACC_H = 2
local SEP_H = 1
local STAT_H = 14
local MAXS = 5
local uiSize  = Vector2.new(340, TOP_H + ACC_H + MAXS * ROW_H + 6 + SEP_H + 8 + STAT_H + 6)
local dragging = false
local dragOff = Vector2.new(0, 0)
local lastM1  = false
local hoverSlot = 0
local animVal = {}

local Shadow   = D("Square", {Size = Vector2.new(uiSize.X + 8, uiSize.Y + 8), Color = C_SHD, Transparency = 0.4, Filled = true, Visible = true})
local MainBG   = D("Square", {Size = uiSize, Color = C_BG, Filled = true, Visible = true})
local BorderL  = D("Square", {Size = Vector2.new(1, uiSize.Y), Color = C_SEP, Filled = true, Visible = true})
local BorderR  = D("Square", {Size = Vector2.new(1, uiSize.Y), Color = C_SEP, Filled = true, Visible = true})
local TopBar   = D("Square", {Size = Vector2.new(uiSize.X, TOP_H), Color = C_TOP, Filled = true, Visible = true})
local AccLine  = D("Square", {Size = Vector2.new(uiSize.X, ACC_H), Color = C_ACCENT, Filled = true, Visible = true})
local TitleTxt = D("Text",   {Text = "FARM HUB v2", Size = 14, Color = C_ACCENT, Outline = true, Visible = true, Font = Drawing.Fonts.System})
local SubTxt   = D("Text",   {Text = "grow a garden 2", Size = 9, Color = C_DIM, Outline = true, Visible = true, Font = Drawing.Fonts.System})

local SLabel, SCheck, SFill = {}, {}, {}
for i = 1, MAXS do
  SLabel[i] = D("Text",   {Text = "", Size = 13, Color = C_TEXT, Outline = true, Visible = false, Font = Drawing.Fonts.System})
  SCheck[i] = D("Circle", {Radius = 8, Thickness = 2, Color = C_TOFF, Filled = false, Visible = false})
  SFill[i]  = D("Circle", {Radius = 5, Color = C_ACCENT, Filled = true, Visible = false})
  animVal[i] = 0
end
local SepLine  = D("Square", {Size = Vector2.new(uiSize.X - 24, SEP_H), Color = C_SEP, Filled = true, Visible = true})
local StatusTxt = D("Text", {Text = "", Size = 11, Color = C_DIM, Outline = true, Visible = true, Font = Drawing.Fonts.System})

local F = {}
local function feat(key, label, kind)
  local f = {key=key, label=label, kind=kind, value=false}
  table.insert(F, f)
  return f
end

feat("AutoHarvest", "AUTO HARVEST",     "toggle")
feat("AutoBuy",     "AUTO BUY",         "toggle")
feat("AutoLoot",    "AUTO LOOT",        "toggle")
feat("AutoSteal",   "AUTO STEAL (SOON)", "soon")
feat("ForceBuy",    "BUY",              "action")

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
        local targetPos = cf * CFrame.new(0, 1, 0)
        local startCF = hrp.CFrame
        for t = 0, 1, 0.1 do
          if not fVal("AutoHarvest") then break end
          hrp.CFrame = startCF:Lerp(targetPos, t)
          task.wait()
        end
        hrp.CFrame = targetPos
        keypress(VK_E)
        task.wait()
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
local function isOwnerNear(p)
  local pSp = p:FindFirstChild("SpawnPoint")
  if not pSp then return true end
  local ok, pPos = pcall(function() return pSp.Position end)
  if not ok then return true end
  for _, pl in ipairs(players:GetPlayers()) do
    if pl ~= player then
      local char = pl.Character
      if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
          local ok2, dist = pcall(function() return (hrp.Position - pPos).Magnitude end)
          if ok2 and dist < 25 then return true end
        end
      end
    end
  end
  return false
end

local function scanStealCache()
  stealCache = {}
  if not gardens then return end
  local myPlot = findPlot()
  if not myPlot then return end
  local sp = myPlot:FindFirstChild("SpawnPoint")
  local spawnCF = sp and pcall(function() return sp.CFrame end) and sp.CFrame or nil
  for _, p in ipairs(gardens:GetChildren()) do
    if p ~= myPlot and not isOwnerNear(p) then
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
      local targetPos = cf * CFrame.new(0, 1, 0)
      local startCF = hrp.CFrame
      for t = 0, 1, 0.1 do
        if not fVal("AutoSteal") then break end
        hrp.CFrame = startCF:Lerp(targetPos, t)
        task.wait()
      end
      hrp.CFrame = targetPos
      keypress(VK_E)
      task.wait()
      keyrelease(VK_E)
      stolenCount = stolenCount + 1
      if i % 2 == 0 and target.spawn then
        hrp.CFrame = target.spawn * CFrame.new(0, 3, 0)
      end
    end
  end
  print("[Steal] +" .. #stealCache .. " (total " .. stolenCount .. ")")
end

-- Auto Buy
local autoBuyRunning = false
local autoBuyThread = nil

local function num(t)
  if not t or type(t) ~= "string" then return 0 end
  local k = t:match("(%d+%.?%d*)K")
  if k then return math.floor(tonumber(k) * 1000) end
  local n = t:match("%d+")
  return n and tonumber(n) or 0
end

local function coins()
  local ok, t = pcall(function() return player.PlayerGui.HUD.Currencies.CoinsCounter.TextLabel.Text end)
  return ok and num(t) or 0
end

local function stk(mf)
  local ok, t = pcall(function() return mf.Stock_Text.Text end)
  return ok and num(t) or 0
end

local function prix(mf)
  local ok, t = pcall(function() return mf.Cost_Text.Text end)
  return ok and num(t) or 0
end

local function gClk(o)
  if not o then return end
  local p, s = o.AbsolutePosition, o.AbsoluteSize
  mousemoveabs(p.X + s.X / 2, p.Y + s.Y / 2)
  task.wait(0.05); mouse1click()
end

local function rScrl(sh)
  local ok = pcall(function() sh.CanvasPosition = Vector2.new(0, 0) end)
  if not ok then
    local p, s = sh.AbsolutePosition, sh.AbsoluteSize
    if s.X > 0 and s.Y > 0 then
      mousemoveabs(p.X + s.X / 2, p.Y + s.Y / 2)
      task.wait(0.1)
      for _ = 1, 20 do mousescroll(10); task.wait(0.05) end
    end
  end
end

local function sclv(sh, it)
  pcall(function()
    local y = sh.CanvasPosition.Y + (it.AbsolutePosition.Y - sh.AbsolutePosition.Y)
    sh.CanvasPosition = Vector2.new(0, math.max(0, y))
  end)
  task.wait(0.15)
end

local function ferm(fr)
  if not fr then return end
  local ok, b = pcall(function() return fr.Header.ExitButton end)
  if ok and b then gClk(b) end
end

local function attRst()
  local ok, v = pcall(function() return ReplicatedStorage.StockValues.SeedShop.UnixNextRestock end)
  if not ok or not v then
    local t = 0; while t < 300 and autoBuyRunning do task.wait(1); t = t + 1 end
    return
  end
  local nxt = v.Value
  local rst = nxt - os.time()
  if rst > 0 then
    safeNotify("Restock in " .. math.floor(rst / 60) .. "m " .. rst % 60 .. "s", "AutoBuy", 5)
    local t = 0; while t < rst + 2 and autoBuyRunning do task.wait(1); t = t + 1 end
  end
  while v.Value == nxt and autoBuyRunning do task.wait(0.5) end
  if autoBuyRunning then safeNotify("Restock! Restarting...", "AutoBuy", 3); task.wait(2) end
end

local function achtt(fr)
  local tot = 0
  for _, nm in pairs({"NormalShop", "ExclusiveShop"}) do
    if not autoBuyRunning then return tot end
    local sh = fr:FindFirstChild(nm)
    if not sh then continue end
    local ok, bb = pcall(function() return sh.Sheckles_Shelf.Main_Frame.Buttons.BuyButton end)
    if not ok or not bb then continue end
    task.wait(0.3); rScrl(sh)
    for _, it in pairs(sh:GetChildren()) do
      if not autoBuyRunning then ferm(fr); return tot end
      if it.Name == "Sheckles_Shelf" or it.Name == "Robux_Shelf" or it.Name == "ItemTemplate" then continue end
      local mf = it:FindFirstChild("Main_Frame")
      if not mf then continue end
      local sb = mf:FindFirstChild("TextButton")
      if not sb then continue end
      sclv(sh, it); gClk(sb); task.wait(0.1)
      if not autoBuyRunning then ferm(fr); return tot end
      local px, sk = prix(mf), stk(mf)
      if px <= 0 or sk <= 0 then continue end
      if coins() < px then ferm(fr); safeNotify("Not enough coins! " .. tot .. " seeds bought.", "AutoBuy", 5); return tot end
      for _ = 1, sk do
        if not autoBuyRunning then ferm(fr); return tot end
        if coins() < px then ferm(fr); safeNotify("Not enough coins! " .. tot .. " seeds bought.", "AutoBuy", 5); return tot end
        gClk(bb); tot = tot + 1; task.wait(0.03)
      end
    end
  end
  ferm(fr); safeNotify("Cycle done! " .. tot .. " seeds bought.", "AutoBuy", 5)
  return tot
end

local function ouvr()
  local sam = workspace:FindFirstChild("NPCS") and workspace.NPCS:FindFirstChild("Sam")
  if not sam or not sam.PrimaryPart then return nil end
  local sp = sam.PrimaryPart.Position
  local hrp = getHRP()
  if not hrp then return nil end
  hrp.CFrame = CFrame.new(sp.X, sp.Y + 1, sp.Z + 3)
  local fr, att = nil, 0
  repeat
    if not autoBuyRunning then return nil end
    att = att + 1
    for _ = 1, 3 do keypress(VK_E); keyrelease(VK_E) end
    task.wait(0.3)
    local sg = player.PlayerGui:FindFirstChild("SeedShop")
    if sg then fr = sg:FindFirstChild("Frame") end
    if not fr then
      hrp.CFrame = CFrame.new(sp.X, sp.Y + 1, sp.Z + 3)
    end
  until fr ~= nil or att >= 3
  task.wait(0.5)
  return fr
end

local function autoBuyLoop()
  safeNotify("AutoBuy started!", "AutoBuy", 3)
  while autoBuyRunning do
    local fr = ouvr()
    if not autoBuyRunning then break end
    if fr then achtt(fr); if not autoBuyRunning then break end; attRst()
    else task.wait(5) end
  end
  autoBuyRunning = false
  autoBuyThread = nil
  safeNotify("AutoBuy stopped!", "AutoBuy", 3)
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
      if fVal("AutoBuy") and not autoBuyRunning then
        autoBuyRunning = true
        autoBuyThread = task.spawn(autoBuyLoop)
      elseif not fVal("AutoBuy") and autoBuyRunning then
        autoBuyRunning = false
        if autoBuyThread then task.cancel(autoBuyThread); autoBuyThread = nil end
      end
      if fVal("AutoLoot") then doLoot() end
      if fVal("AutoSteal") and getPhase() == "Night" then doSteal() end
    end
  end
end)

local function forceBuyNow()
  local hrp = getHRP()
  if not hrp then safeNotify("No character", "Error", 2); return end
  local savedPos = hrp.CFrame
  local seeds = workspace:FindFirstChild("Teleports") and workspace.Teleports:FindFirstChild("Seeds")
  if not seeds or not seeds:IsA("BasePart") then safeNotify("Seeds teleport not found", "Error", 2); return end
  local ok, cf = pcall(function() return seeds.CFrame end)
  if not ok or not cf then safeNotify("Bad CFrame", "Error", 2); return end
  hrp.CFrame = cf
  for _ = 1, 5 do
    keypress(VK_E)
    task.wait(0.02)
    keyrelease(VK_E)
    task.wait(0.02)
  end
  hrp.CFrame = savedPos
  safeNotify("Buy menu opened", "BUY", 2)
end

local ActionMap = {
  ForceBuy = forceBuyNow,
}

local function Render()
  local x0, y0 = uiPos.X, uiPos.Y
  Shadow.Position  = Vector2.new(x0 - 4, y0 - 4)
  MainBG.Position  = Vector2.new(x0, y0)
  BorderL.Position = Vector2.new(x0 - 1, y0)
  BorderR.Position = Vector2.new(x0 + uiSize.X, y0)
  TopBar.Position  = Vector2.new(x0, y0)
  AccLine.Position = Vector2.new(x0, y0 + TOP_H)
  TitleTxt.Position = Vector2.new(x0 + 14, y0 + 8)
  SubTxt.Position   = Vector2.new(x0 + 14, y0 + 22)

  local yy0 = y0 + TOP_H + ACC_H + 3
  for slot = 1, MAXS do
    local f = F[slot]
    if not f then
      SLabel[slot].Visible = false; SCheck[slot].Visible = false; SFill[slot].Visible = false
      continue
    end
    local yy = yy0 + (slot - 1) * ROW_H

    local isHover = (hoverSlot == slot)
    local lblColor = C_TEXT
    if f.kind == "action" then lblColor = C_ACTN
    elseif f.kind == "soon" then lblColor = C_SOON
    elseif f.value then lblColor = C_ACCENT
    end

    local txt = "   " .. f.label
    if f.kind == "action" then txt = ">> " .. f.label end

    SLabel[slot].Text = txt
    SLabel[slot].Position = Vector2.new(x0 + 16, yy)
    if isHover then
      if f.kind == "action" then SLabel[slot].Color = Color3.fromRGB(255, 210, 120)
      elseif f.value then SLabel[slot].Color = C_ACCENT2
      else SLabel[slot].Color = C_TEXT end
    else
      SLabel[slot].Color = lblColor
    end
    SLabel[slot].Visible = true

    if f.kind == "toggle" then
      SCheck[slot].Position = Vector2.new(x0 + uiSize.X - 26, yy + 7)
      SCheck[slot].Color = f.value and C_ACCENT or C_TOFF
      SCheck[slot].Visible = true
      SFill[slot].Position = Vector2.new(x0 + uiSize.X - 26, yy + 7)
      if f.value then
        animVal[slot] = math.min(1, animVal[slot] + 0.08)
      else
        animVal[slot] = math.max(0, animVal[slot] - 0.08)
      end
      if animVal[slot] > 0.01 then
        SFill[slot].Visible = true
        SFill[slot].Radius = 1 + animVal[slot] * 4
        SFill[slot].Color = C_ACCENT:Lerp(C_TOFF, 1 - animVal[slot])
      else
        SFill[slot].Visible = false
      end
    else
      SCheck[slot].Visible = false; SFill[slot].Visible = false
    end
  end

  SepLine.Position = Vector2.new(x0 + 12, y0 + uiSize.Y - STAT_H - 10)
  local hrp = getHRP()
  local yStr = hrp and tostring(math.floor(hrp.Position.Y)) or "?"
  local phaseIcon = (currentPhase == "Night") and "~" or (currentPhase == "Day") and "#" or "?"
  StatusTxt.Text = "Y " .. yStr .. "  |  L " .. lootCount .. "  S " .. stolenCount .. "  B " .. (autoBuyRunning and "ON" or "OFF") .. "  " .. phaseIcon
  StatusTxt.Position = Vector2.new(x0 + 14, y0 + uiSize.Y - STAT_H - 4)
end

task.spawn(function()
  print("[UI] Input loop ready")
  while ScriptActive do
    task.wait(0.016)
    local mx, my = 0, 0
    pcall(function() local m = player:GetMouse(); mx = m.X; my = m.Y end)
    local m1 = false
    pcall(function() m1 = ismouse1pressed() end)

    local yy0 = uiPos.Y + TOP_H + ACC_H + 3
    hoverSlot = 0
    for slot = 1, MAXS do
      local yy = yy0 + (slot - 1) * ROW_H
      if mx >= uiPos.X + 8 and mx <= uiPos.X + uiSize.X - 8 and my >= yy - 4 and my <= yy + ROW_H then
        hoverSlot = slot
        break
      end
    end

    if m1 and not lastM1 then
      for slot = 1, MAXS do
        local f = F[slot]
        local yy = yy0 + (slot - 1) * ROW_H
        if mx >= uiPos.X + 8 and mx <= uiPos.X + uiSize.X - 8 and my >= yy - 4 and my <= yy + ROW_H then
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
      if mx >= uiPos.X and mx <= uiPos.X + uiSize.X and my >= uiPos.Y and my <= uiPos.Y + TOP_H then
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
  autoBuyRunning = false
  if autoBuyThread then task.cancel(autoBuyThread); autoBuyThread = nil end
  pcall(function() workspace.CurrentCamera.CameraType = Enum.CameraType.Custom end)
  for _, obj in ipairs(drawObjs) do pcall(function() obj:Remove() end) end
  print("[Farm] Cleanup done")
end

safeNotify("Farm Hub loaded!", "Garden 2", 3)
print("[Farm] AUTO HARVEST + AUTO BUY + AUTO LOOT + AUTO STEAL ready")
