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
local RS = game:GetService("ReplicatedStorage")
local player    = players.LocalPlayer



-- Auto-restart support - find script source
local RSRC
local RPA = {"matcha_garden2_farm.lua","C:\\Users\\Administrator\\Desktop\\PROYECTOMATCHA\\matcha_garden2_farm.lua","C:/Users/Administrator/Desktop/PROYECTOMATCHA/matcha_garden2_farm.lua"}
for _, p in ipairs(RPA) do local ok, s = pcall(readfile, p); if ok and s and #s > 100 then RSRC = s; break end end
if not RSRC then print("[Farm] WARNING: auto-restart unavailable") end

local hCyc = 0; local MCYC = 2

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
local C0 = Color3.fromRGB
local C_A = C0(0, 212, 170); local C_BG = C0(14, 14, 22); local C_TP = C0(24, 24, 38)
local C_TX = C0(225, 225, 235); local C_DM = C0(100, 100, 115); local C_TO = C0(55, 55, 72)
local C_AC = C0(255, 186, 76); local C_SN = C0(110, 110, 126); local C_SP = C0(30, 30, 48)

local function lerpColor(a, b, t)
  return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local uiPos = Vector2.new(150, 120)
local RH = 28; local TH = 32; local AH = 2; local SH = 1; local STH = 14; local MAXS = 5
local uiS = Vector2.new(340, TH + AH + MAXS * RH + 6 + SH + 8 + STH + 6)
local drg, dOff, lastM1, hov, anm = false, Vector2.new(0, 0), false, 0, {}

local SHD = D("Square", {Size = Vector2.new(uiS.X + 8, uiS.Y + 8), Color = C0(0,0,0), Transparency = 0.4, Filled = true, Visible = true})
local BG  = D("Square", {Size = uiS, Color = C_BG, Filled = true, Visible = true})
local TB  = D("Square", {Size = Vector2.new(uiS.X, TH), Color = C_TP, Filled = true, Visible = true})
local AL  = D("Square", {Size = Vector2.new(uiS.X, AH), Color = C_A, Filled = true, Visible = true})
local TT  = D("Text",   {Text = "FARM HUB v2", Size = 14, Color = C_A, Outline = true, Visible = true, Font = Drawing.Fonts.System})
local TAB_F = D("Text", {Text = "FARM", Size = 12, Color = C_A, Outline = true, Visible = true, Font = Drawing.Fonts.System})
local TAB_P = D("Text", {Text = "PETS", Size = 12, Color = C_DM, Outline = true, Visible = true, Font = Drawing.Fonts.System})
local SCR_U = D("Text", {Text = "▲", Size = 12, Color = C_A, Outline = true, Visible = false, Font = Drawing.Fonts.System})
local SCR_D = D("Text", {Text = "▼", Size = 12, Color = C_A, Outline = true, Visible = false, Font = Drawing.Fonts.System})

local SL, SC, SF = {}, {}, {}
for i = 1, MAXS do
  SL[i] = D("Text",   {Text = "", Size = 13, Color = C_TX, Outline = true, Visible = false, Font = Drawing.Fonts.System})
  SC[i] = D("Circle", {Radius = 8, Thickness = 2, Color = C_TO, Filled = false, Visible = false})
  SF[i] = D("Circle", {Radius = 5, Color = C_A, Filled = true, Visible = false})
  anm[i] = 0
end
local SEP = D("Square", {Size = Vector2.new(uiS.X - 24, SH), Color = C_SP, Filled = true, Visible = true})
local STX = D("Text", {Text = "", Size = 11, Color = C_DM, Outline = true, Visible = true, Font = Drawing.Fonts.System})

local F = {}
local function feat(key, label, kind)
  local f = {key=key, label=label, kind=kind, value=false}
  table.insert(F, f)
  return f
end

feat("AutoHarvest", "AUTO HARVEST",     "toggle")
feat("AutoBuy",     "AUTO BUY",         "toggle")
feat("AutoLoot",    "AUTO LOOT",        "toggle")
feat("AutoSell",     "AUTO SELL",  "toggle")
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

local function tp(cf) local h = getHRP(); if h then h.CFrame = cf end end

local harvestCache = {}
local function scanHarvest(plot)
  harvestCache = {}
  local plants = plot and plot:FindFirstChild("Plants")
  if not plants then return end
  for _, pl in ipairs(plants:GetChildren()) do
    local fs = pl:FindFirstChild("Fruits")
    if fs then for _, f in ipairs(fs:GetChildren()) do
      local b = f:FindFirstChild("Base")
      if b and b:IsA("BasePart") then table.insert(harvestCache, b) end
    end end
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
        local tp = cf * CFrame.new(0, 1, 0)
        local sc = hrp.CFrame
        for t = 0, 1, 0.1 do
          if not fVal("AutoHarvest") then break end
          hrp.CFrame = sc:Lerp(tp, t); task.wait()
        end
        hrp.CFrame = tp; keypress(VK_E); task.wait(); keyrelease(VK_E)
      end
    end
  end
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

local phase = "?"; local stolenCount = 0
local function getPhase() local v = workspace:GetAttribute("ActivePhase"); if v then phase = tostring(v) end return phase end

-- Pets
local activeTab = "farm"
local ALL_PETS = {"Frog","Bunny","Owl","Deer","Robin","Bee","Monkey","GoldenDragonfly","Unicorn","Raccoon","IceSerpent","BlackDragon","Golden Dragonfly","Ice Serpent","Black Dragon"}
local petSpawned = {}; local petSelected = {}; local petScroll = 0
local ptRun = false; local ptTh = nil; local ptCount = 0; local autoPet = false
local function petCount() local c=0; for _,v in pairs(petSelected) do if v then c=c+1 end end return c end
local function scanPets()
  local sp = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("WildPetSpawns")
  for _, nm in ipairs(ALL_PETS) do petSpawned[nm] = nil end
  if not sp then return end
  for _, inst in ipairs(sp:GetChildren()) do
    local n = inst.Name
    for _, nm in ipairs(ALL_PETS) do
      local p = nm:gsub("%s+", "")
      local q = nm:gsub("%s+", "_")
      if n:find("WildPet_" .. p .. "_") or n:find("WildPet_" .. q .. "_") or n:find(p) or n:find(q) then
        petSpawned[nm] = inst
        if petSelected[nm] == nil then petSelected[nm] = true end
        break
      end
    end
  end
  for _, inst in ipairs(sp:GetChildren()) do
    if inst.ClassName ~= "Model" then
      local n = inst.Name
      for _, nm in ipairs(ALL_PETS) do
        if n == nm or n == nm:gsub("%s+", "") then
          petSpawned[nm] = inst
          break
        end
      end
    end
  end
end
local function getPetPart(petInst)
  if petInst.ClassName ~= "Model" then return petInst end
  local pp = petInst.PrimaryPart; if pp then return pp end
  local pa = petInst:FindFirstChild("PromptAnchor"); if pa then return pa end
  for _, c in ipairs(petInst:GetChildren()) do
    if c.ClassName ~= "Model" then return c end
  end
  return nil
end
local function doPetBuy(name)
  local inst = petSpawned[name]
  if not inst then return end
  local hrp = getHRP(); if not hrp then return end
  local part = getPetPart(inst)
  if not part then return end
  local ok, cf = pcall(function() return part.CFrame end)
  if not ok or not cf then return end
  hrp.CFrame = cf * CFrame.new(0, 1, 0); task.wait(0.15)
  keypress(VK_E); task.wait(1.2); keyrelease(VK_E)
  ptCount = ptCount + 1; print("[PET] bought " .. name)
end
local function petBuyLoop()
  safeNotify("AutoPet started!", "AutoPet", 3)
  while ptRun do
    scanPets()
    for _, nm in ipairs(ALL_PETS) do
      if not ptRun then break end
      if petSelected[nm] and petSpawned[nm] then doPetBuy(nm) end
    end
    task.wait(5)
  end
  ptRun = false; ptTh = nil
  safeNotify("AutoPet stopped!", "AutoPet", 3)
end

-- Auto Buy
local abRun = false
local abTh = nil
local asRun = false
local asTh = nil

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

local function moveMouse(x, y)
  local cx, cy = 0, 0
  pcall(function() local m = player:GetMouse(); cx = m.X; cy = m.Y end)
  local dx, dy = x - cx, y - cy
  local dist = math.sqrt(dx * dx + dy * dy)
  local steps = math.max(3, math.min(12, math.floor(dist / 40)))
  for i = 1, steps do
    local t = i / steps
    mousemoveabs(cx + dx * t, cy + dy * t)
    task.wait(0.008)
  end
end

local function clk(o)
  if not o then return end
  local p, s = o.AbsolutePosition, o.AbsoluteSize
  moveMouse(p.X + s.X / 2, p.Y + s.Y / 2)
  task.wait(0.05); mouse1click(); task.wait(0.05)
end

local function rScrl(sh)
  if not sh then return end
  local ok = pcall(function() sh.CanvasPosition = Vector2.new(0, 0) end)
  if not ok then
    local p, s = sh.AbsolutePosition, sh.AbsoluteSize
    mousemoveabs(p.X + s.X / 2, p.Y + s.Y / 2)
    task.wait(0.1)
    for _ = 1, 20 do mousescroll(10); task.wait(0.03) end
  end
end

local function scrlv(sh, it)
  pcall(function()
    local y = sh.CanvasPosition.Y + (it.AbsolutePosition.Y - sh.AbsolutePosition.Y)
    sh.CanvasPosition = Vector2.new(0, math.max(0, y))
  end)
  task.wait(0.1)
end

local function ferm(fr)
  if not fr then return end
  local ok, b = pcall(function() return fr.Header.ExitButton end)
  if ok and b then
    local p, s = b.AbsolutePosition, b.AbsoluteSize
    moveMouse(p.X + s.X / 2, p.Y + s.Y / 2 + 8)
    task.wait(0.05); mouse1click(); task.wait(0.05)
  end
end

local function attRst()
  local ok, v = pcall(function() return RS.StockValues.SeedShop.UnixNextRestock end)
  if not ok or not v then
    local t = 0; while t < 300 and abRun do task.wait(1); t = t + 1 end
    return
  end
  local nxt = v.Value
  local rst = nxt - os.time()
  if rst > 0 then
    safeNotify("Restock in " .. math.floor(rst / 60) .. "m " .. rst % 60 .. "s", "AutoBuy", 5)
    local t = 0; while t < rst + 2 and abRun do task.wait(1); t = t + 1 end
  end
  while v.Value == nxt and abRun do task.wait(0.5) end
  if abRun then safeNotify("Restock! Restarting...", "AutoBuy", 3); task.wait(2) end
end

local function achtt(fr)
  local tot = 0
  for _, nm in pairs({"NormalShop", "ExclusiveShop"}) do
    if not abRun then return tot end
    local sh = fr:FindFirstChild(nm)
    if not sh then continue end
    local ok, bb = pcall(function() return sh.Sheckles_Shelf.Main_Frame.Buttons.BuyButton end)
    if not ok or not bb then continue end
    rScrl(sh); task.wait(0.2)
    for _, it in pairs(sh:GetChildren()) do
      if not abRun then ferm(fr); return tot end
      if it.Name == "Sheckles_Shelf" or it.Name == "Robux_Shelf" or it.Name == "ItemTemplate" then continue end
      local mf = it:FindFirstChild("Main_Frame")
      if not mf then continue end
      local sb = mf:FindFirstChild("TextButton")
      if not sb then continue end
      scrlv(sh, it); clk(sb); task.wait(0.5)
      if not abRun then ferm(fr); return tot end
      local px, sk = prix(mf), stk(mf)
      if px <= 0 or sk <= 0 then task.wait(0.15); continue end
      if coins() < px then ferm(fr); safeNotify("Not enough coins! " .. tot .. " seeds bought.", "AutoBuy", 5); return tot end
      for _ = 1, sk do
        if not abRun then ferm(fr); return tot end
        if coins() < px then ferm(fr); safeNotify("Not enough coins! " .. tot .. " seeds bought.", "AutoBuy", 5); return tot end
        local bp, bs = bb.AbsolutePosition, bb.AbsoluteSize
        moveMouse(bp.X + bs.X / 2, bp.Y + bs.Y / 2 + 10)
        task.wait(0.05); mouse1click(); task.wait(0.15)
        tot = tot + 1
      end
      task.wait(0.2)
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
    if not abRun then return nil end
    att = att + 1
    keypress(VK_E); keyrelease(VK_E)
    task.wait(0.6)
    local sg = player.PlayerGui:FindFirstChild("SeedShop")
    if sg then fr = sg:FindFirstChild("Frame") end
    if not fr then
      hrp.CFrame = CFrame.new(sp.X, sp.Y + 1, sp.Z + 3)
    end
  until fr ~= nil or att >= 3
  task.wait(1)
  return fr
end

local function autoBuyLoop()
  safeNotify("AutoBuy started!", "AutoBuy", 3)
  while abRun do
    local fr = ouvr()
    if not abRun then break end
    if fr then achtt(fr); if not abRun then break end; attRst()
    else task.wait(5) end
  end
  abRun = false
  abTh = nil
  safeNotify("AutoBuy stopped!", "AutoBuy", 3)
end

local function autoSellLoop()
  safeNotify("AutoSell started!", "AutoSell", 3)
  local sellTp = workspace:FindFirstChild("Teleports") and workspace.Teleports:FindFirstChild("Sell")
  while asRun do
    if not asRun then break end
    local hrp = getHRP()
    if hrp and sellTp then
      hrp.CFrame = CFrame.new(sellTp.Position.X, sellTp.Position.Y + 3, sellTp.Position.Z)
      task.wait(0.5)
      keypress(VK_E); task.wait(0.2); keyrelease(VK_E)
      task.wait(0.8)
      for _ = 1, 20 do mousescroll(120); task.wait(0.02) end
      task.wait(0.3)
      moveMouse(960, 740)
      task.wait(0.2)
      mousescroll(-2)
      task.wait(0.3)
      moveMouse(1776, 172)
      task.wait(0.05); mouse1click(); task.wait(0.3)
    end
    task.wait(2)
  end
  asRun = false
  asTh = nil
  safeNotify("AutoSell stopped!", "AutoSell", 3)
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
  scanHarvest(plot)
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
        scanHarvest(plot); doHarvest()
        hCyc = hCyc + 1
        if hCyc >= MCYC and RSRC then
          print("[Farm] Auto-restart after " .. hCyc .. " cycles")
          _G.MatchaCleanup()
          task.wait(1)
          task.spawn(loadstring(RSRC))
          return
        end
      end
      if fVal("AutoBuy") and not abRun then
        abRun = true
        abTh = task.spawn(autoBuyLoop)
      elseif not fVal("AutoBuy") and abRun then
        abRun = false
        if abTh then task.cancel(abTh); abTh = nil end
      end
      if fVal("AutoSell") and not asRun then
        asRun = true
        asTh = task.spawn(autoSellLoop)
      elseif not fVal("AutoSell") and asRun then
        asRun = false
        if asTh then task.cancel(asTh); asTh = nil end
      end
      if autoPet and not ptRun then
        scanPets(); ptRun = true; ptTh = task.spawn(petBuyLoop)
      elseif not autoPet and ptRun then
        ptRun = false; if ptTh then task.cancel(ptTh); ptTh = nil end
      end
      if fVal("AutoLoot") then doLoot() end
      getPhase()
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
  SHD.Position = Vector2.new(x0 - 4, y0 - 4)
  BG.Position  = Vector2.new(x0, y0)
  TB.Position  = Vector2.new(x0, y0)
  AL.Position  = Vector2.new(x0, y0 + TH)
  TT.Text = (activeTab == "farm") and "FARM HUB v2" or "PETS HUB v2"
  TT.Position  = Vector2.new(x0 + 14, y0 + 8)

  TAB_F.Position = Vector2.new(x0 + uiS.X - 72, y0 + 9)
  TAB_P.Position = Vector2.new(x0 + uiS.X - 40, y0 + 9)
  TAB_F.Color = (activeTab == "farm") and C_A or C_DM
  TAB_P.Color = (activeTab == "pets") and C_A or C_DM

  local yy0 = y0 + TH + AH + 3
  if activeTab == "farm" then
    for s = 1, MAXS do
      local f = F[s]
      if not f then SL[s].Visible = false; SC[s].Visible = false; SF[s].Visible = false; continue end
      local yy = yy0 + (s - 1) * RH
      local ih = (hov == s)
      local lc = C_TX
      if f.kind == "action" then lc = C_AC elseif f.kind == "soon" then lc = C_SN elseif f.value then lc = C_A end
      local txt = "   " .. f.label; if f.kind == "action" then txt = ">> " .. f.label end
      SL[s].Text = txt; SL[s].Position = Vector2.new(x0 + 16, yy)
      if ih then
        if f.kind == "action" then SL[s].Color = C0(255, 210, 120)
        elseif f.value then SL[s].Color = C_A
        else SL[s].Color = C_TX end
      else SL[s].Color = lc end
      SL[s].Visible = true
      if f.kind == "toggle" then
        SC[s].Position = Vector2.new(x0 + uiS.X - 26, yy + 7)
        SC[s].Color = f.value and C_A or C_TO; SC[s].Visible = true
        SF[s].Position = Vector2.new(x0 + uiS.X - 26, yy + 7)
        if f.value then anm[s] = math.min(1, anm[s] + 0.08) else anm[s] = math.max(0, anm[s] - 0.08) end
        if anm[s] > 0.01 then
          SF[s].Visible = true; SF[s].Radius = 1 + anm[s] * 4
          SF[s].Color = lerpColor(C_A, C_TO, 1 - anm[s])
        else SF[s].Visible = false end
      else SC[s].Visible = false; SF[s].Visible = false end
    end
    SEP.Position = Vector2.new(x0 + 12, y0 + uiS.Y - STH - 10)
    local hrp = getHRP()
    local yS = hrp and tostring(math.floor(hrp.Position.Y)) or "?"
    local pi = (phase == "Night") and "~" or (phase == "Day") and "#" or "?"
    STX.Text = "Y " .. yS .. "  |  L " .. lootCount .. "  S " .. stolenCount .. "  B " .. (abRun and "ON" or "OFF") .. "  Se " .. (asRun and "ON" or "OFF") .. "  " .. pi
    STX.Position = Vector2.new(x0 + 14, y0 + uiS.Y - STH - 4)
    SCR_U.Visible = false; SCR_D.Visible = false
  else
    -- pets tab: hide all slots first, then render pets
    for s = 1, MAXS do SL[s].Visible = false; SC[s].Visible = false; SF[s].Visible = false end
    for s = 1, MAXS do
      local yy = yy0 + (s - 1) * RH
      if s == 1 then
        local on = autoPet
        SL[s].Text = "   AUTO PET"; SL[s].Position = Vector2.new(x0 + 16, yy)
        SL[s].Color = (hov == s) and (on and C_A or C_TX) or (on and C_A or C_DM)
        SL[s].Visible = true
        SC[s].Position = Vector2.new(x0 + uiS.X - 26, yy + 7)
        SC[s].Color = on and C_A or C_TO; SC[s].Visible = true
        SF[s].Position = Vector2.new(x0 + uiS.X - 26, yy + 7)
        if on then anm[s] = math.min(1, anm[s] + 0.08) else anm[s] = math.max(0, anm[s] - 0.08) end
        if anm[s] > 0.01 then
          SF[s].Visible = true; SF[s].Radius = 1 + anm[s] * 4
          SF[s].Color = lerpColor(C_A, C_TO, 1 - anm[s])
        else SF[s].Visible = false end
      else
        local pi = petScroll + s - 1
        local nm = ALL_PETS[pi]
        if nm then
          local ok2 = pcall(function()
            local sel = petSelected[nm]; local spawned = petSpawned[nm] ~= nil
            local prefix = spawned and "* " or "  "
            SL[s].Text = prefix .. nm; SL[s].Position = Vector2.new(x0 + 16, yy)
            if hov == s then
              SL[s].Color = sel and C_A or C_TX
            elseif sel then
              SL[s].Color = spawned and C_A or C_DM
            else
              SL[s].Color = spawned and C_TX or C_DM
            end
            SL[s].Visible = true
            SC[s].Position = Vector2.new(x0 + uiS.X - 26, yy + 7)
            SC[s].Color = sel and C_A or C_TO; SC[s].Visible = true
            SF[s].Position = Vector2.new(x0 + uiS.X - 26, yy + 7)
            if sel then anm[s] = math.min(1, anm[s] + 0.08) else anm[s] = math.max(0, anm[s] - 0.08) end
            if anm[s] > 0.01 then
              SF[s].Visible = true; SF[s].Radius = 1 + anm[s] * 4
              SF[s].Color = lerpColor(C_A, C_TO, 1 - anm[s])
            else SF[s].Visible = false end
          end)
        end
      end
    end
    SEP.Position = Vector2.new(x0 + 12, y0 + uiS.Y - STH - 10)
    local spawnedCount = 0; for _, v in pairs(petSpawned) do if v then spawnedCount = spawnedCount + 1 end end
    STX.Text = "Spawned: " .. spawnedCount .. "  Sel: " .. petCount() .. "  P " .. (ptRun and "ON" or "OFF")
    STX.Position = Vector2.new(x0 + 14, y0 + uiS.Y - STH - 4)
    SCR_U.Position = Vector2.new(x0 + uiS.X - 22, y0 + TH + AH + 6)
    SCR_U.Visible = petScroll > 0
    SCR_D.Position = Vector2.new(x0 + uiS.X - 22, y0 + uiS.Y - STH - 24)
    SCR_D.Visible = petScroll + 4 < #ALL_PETS
  end
end

task.spawn(function()
  print("[UI] Input loop ready")
  while ScriptActive do
    task.wait(0.016)
    local mx, my = 0, 0; pcall(function() local m = player:GetMouse(); mx = m.X; my = m.Y end)
    local m1 = false; pcall(function() m1 = ismouse1pressed() end)
    local yy0 = uiPos.Y + TH + AH + 3; hov = 0

    if activeTab == "farm" then
      for s = 1, MAXS do
        local yy = yy0 + (s - 1) * RH
        if mx >= uiPos.X + 8 and mx <= uiPos.X + uiS.X - 8 and my >= yy - 4 and my <= yy + RH then hov = s; break end
      end
      if m1 and not lastM1 then
        for s = 1, MAXS do
          local f = F[s]; local yy = yy0 + (s - 1) * RH
          if mx >= uiPos.X + 8 and mx <= uiPos.X + uiS.X - 8 and my >= yy - 4 and my <= yy + RH then
            if f.kind == "toggle" then
              f.value = not f.value
              print("[UI] TOGGLED: " .. f.key .. " = " .. tostring(f.value))
              safeNotify(f.label .. ": " .. (f.value and "ON" or "OFF"), "Toggle", 2)
            elseif f.kind == "soon" then safeNotify("Coming soon!", "WIP", 2)
            elseif f.kind == "action" then
              print("[UI] ACTION: " .. f.key)
              local h = ActionMap[f.key]; if h then task.spawn(h) end
            end
          end
        end
      end
    else
      for s = 1, MAXS do
        local yy = yy0 + (s - 1) * RH
        if mx >= uiPos.X + 8 and mx <= uiPos.X + uiS.X - 8 and my >= yy - 4 and my <= yy + RH then hov = s; break end
      end
      if m1 and not lastM1 then
        for s = 1, MAXS do
          local yy = yy0 + (s - 1) * RH
          if mx >= uiPos.X + 8 and mx <= uiPos.X + uiS.X - 8 and my >= yy - 4 and my <= yy + RH then
            if s == 1 then
              autoPet = not autoPet
              print("[UI] TOGGLED: AutoPet = " .. tostring(autoPet))
              safeNotify("AutoPet: " .. (autoPet and "ON" or "OFF"), "Toggle", 2)
              if autoPet and not ptRun then
                scanPets(); ptRun = true; ptTh = task.spawn(petBuyLoop)
              elseif not autoPet and ptRun then
                ptRun = false; if ptTh then task.cancel(ptTh); ptTh = nil end
              end
            else
              local pi = petScroll + s - 1
              local nm = ALL_PETS[pi]
              if nm then
                petSelected[nm] = not petSelected[nm]
                print("[UI] Pet " .. nm .. " = " .. tostring(petSelected[nm]))
              end
            end
          end
        end
        -- arrow clicks
        if mx >= uiPos.X + uiS.X - 30 and mx <= uiPos.X + uiS.X - 10 and my >= uiPos.Y + TH + AH + 3 and my <= uiPos.Y + TH + AH + 20 then
          if petScroll > 0 then petScroll = petScroll - 1 end
        end
        if mx >= uiPos.X + uiS.X - 30 and mx <= uiPos.X + uiS.X - 10 and my >= uiPos.Y + uiS.Y - STH - 30 and my <= uiPos.Y + uiS.Y - STH - 15 then
          if petScroll + 4 < #ALL_PETS then petScroll = petScroll + 1 end
        end
      end
    end

    -- tab switch click
    if m1 and not lastM1 then
      local tx = uiPos.X + uiS.X - 72; local ty = uiPos.Y + 9; local tabHit = false
      if mx >= tx and mx <= tx + 30 and my >= ty - 4 and my <= ty + 14 then activeTab = "farm"; petScroll = 0; scanPets(); tabHit = true end
      tx = uiPos.X + uiS.X - 40
      if mx >= tx and mx <= tx + 30 and my >= ty - 4 and my <= ty + 14 then activeTab = "pets"; petScroll = 0; scanPets(); tabHit = true end

      if not tabHit and mx >= uiPos.X and mx <= uiPos.X + uiS.X and my >= uiPos.Y and my <= uiPos.Y + TH then
        drg = true; dOff = Vector2.new(mx - uiPos.X, my - uiPos.Y)
      end
    end

    -- pet scroll via arrow keys
    pcall(function()
      if activeTab == "pets" and iskeypressed(0x28) then
        if petScroll + 4 < #ALL_PETS then petScroll = petScroll + 1; task.wait(0.12) end
      elseif activeTab == "pets" and iskeypressed(0x26) then
        if petScroll > 0 then petScroll = petScroll - 1; task.wait(0.12) end
      end
    end)

    if drg then
      if m1 then uiPos = Vector2.new(mx - dOff.X, my - dOff.Y) else drg = false end
    end
    lastM1 = m1; local rok, rerr = pcall(Render); if not rok then print("[UI] Render error:", tostring(rerr)) end
  end
end)

_G.MatchaCleanup = function()
  ScriptActive = false
  abRun = false
  if abTh then task.cancel(abTh); abTh = nil end
  asRun = false
  if asTh then task.cancel(asTh); asTh = nil end
  ptRun = false
  if ptTh then task.cancel(ptTh); ptTh = nil end
  pcall(function() workspace.CurrentCamera.CameraType = Enum.CameraType.Custom end)
  for _, obj in ipairs(drawObjs) do pcall(function() obj:Remove() end) end
  print("[Farm] Cleanup done")
end

safeNotify("Farm loaded!", "Garden 2", 3)
print("ready")
