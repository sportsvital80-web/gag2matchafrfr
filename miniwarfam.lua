--[[
    MiniWar — Farm Teleport + UI (garden2_farm style)
]]

if _G.MatchaCleanup then pcall(_G.MatchaCleanup) end
local ScriptActive = true
local FarmLoop = false
local SpamE = false

local players = game:GetService("Players")
local player = players.LocalPlayer
local VK_E = 0x45

-- ===== DRAWING HELPERS =====
local drawObjs = {}
local function D(typ, props)
    local obj = Drawing.new(typ)
    for k, v in pairs(props) do obj[k] = v end
    table.insert(drawObjs, obj)
    return obj
end

local C0 = Color3.fromRGB
local C_A = C0(0, 212, 170); local C_BG = C0(14, 14, 22); local C_TP = C0(24, 24, 38)
local C_TX = C0(225, 225, 235); local C_DM = C0(100, 100, 115); local C_TO = C0(55, 55, 72)
local C_SP = C0(30, 30, 48)

local function lerpColor(a, b, t)
    return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

-- ===== UI LAYOUT =====
local uiPos = Vector2.new(150, 120)
local RH = 30; local TH = 46; local AH = 2; local SH = 1; local STH = 14; local MAXS = 6
local SLH = 24
local uiS = Vector2.new(390, TH + AH + MAXS * RH + SLH + 6 + SH + 8 + STH + 6)
local drg, dOff, lastM1, hov, anm = false, Vector2.new(0, 0), false, 0, {}

local SHD = D("Square", {Size = Vector2.new(uiS.X + 8, uiS.Y + 8), Color = C0(0,0,0), Transparency = 0.4, Filled = true, Visible = true})
local BG  = D("Square", {Size = uiS, Color = C_BG, Filled = true, Visible = true})
local TB  = D("Square", {Size = Vector2.new(uiS.X, TH), Color = C_TP, Filled = true, Visible = true})
local AL  = D("Square", {Size = Vector2.new(uiS.X, AH), Color = C_A, Filled = true, Visible = true})
local TT  = D("Text",   {Text = "MINIWAR v1", Size = 14, Color = C_A, Outline = true, Visible = true, Font = Drawing.Fonts.System})

local SL, SC, SF = {}, {}, {}
for i = 1, MAXS do
    SL[i] = D("Text",   {Text = "", Size = 13, Color = C_TX, Outline = true, Visible = false, Font = Drawing.Fonts.System})
    SC[i] = D("Circle", {Radius = 12, Thickness = 2, Color = C_TO, Filled = false, Visible = false})
    SF[i] = D("Circle", {Radius = 9,  Color = C_A, Filled = true, Visible = false})
    anm[i] = 0
end
local SEP = D("Square", {Size = Vector2.new(uiS.X - 24, SH), Color = C_SP, Filled = true, Visible = true})
local STX = D("Text", {Text = "", Size = 11, Color = C_DM, Outline = true, Visible = true, Font = Drawing.Fonts.System})

-- Features list
local F = {}
local function feat(key, label, kind, hotkey)
    local f = {key = key, label = label, kind = kind or "toggle", value = false, hotkey = hotkey}
    table.insert(F, f)
    return f
end

feat("FarmLoop", "   FARM LOOP [1]", "toggle", 0x31)
feat("AutoSell", "   AUTO SELL [2]", "toggle", 0x32)

-- Shared state
local FarmList = {}

-- ===== HELPERS =====
local function safeNotify(msg, title, dur)
    pcall(function() notify(tostring(msg), tostring(title or "MiniWar"), dur or 3) end)
end

local function getHRP()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function moveMouse(x, y)
    local cx, cy = 0, 0
    pcall(function() local m = player:GetMouse(); cx = m.X; cy = m.Y end)
    local dx, dy = x - cx, y - cy
    local dist = math.sqrt(dx * dx + dy * dy)
    local steps = math.max(8, math.min(20, math.floor(dist / 15)))
    for i = 1, steps do
        local t = i / steps
        mousemoveabs(cx + dx * t, cy + dy * t)
        task.wait(0.01)
    end
end

local function findCountryButton()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil end
    local mainUI = gui:FindFirstChild("MainUI")
    if not mainUI then return nil end
    local hud = mainUI:FindFirstChild("HUD")
    if not hud then return nil end
    local topUI = hud:FindFirstChild("TopUI")
    if not topUI then return nil end
    local btn = topUI:FindFirstChild("Country")
    if not btn then return nil end
    local ok, pos = pcall(function() return btn.AbsolutePosition end)
    local ok2, size = pcall(function() return btn.AbsoluteSize end)
    if ok and ok2 and pos and size and size.X > 0 and size.Y > 0 then
        return btn, pos, size
    end
    return nil
end

local function clickCountry()
    local btn, pos, size = findCountryButton()
    if not btn then return false end
    moveMouse(pos.X + size.X / 2, pos.Y + size.Y / 2)
    task.wait(0.15)
    mouse1press()
    task.wait(0.05)
    mouse1release()
    task.wait(0.2)
    return true
end

local function findClosestPlot()
    local root = getHRP()
    if not root then return nil end
    local rootPos = root.Position
    local mm = workspace:FindFirstChild("MilitaryMap")
    if not mm then return nil end
    local plots = mm:FindFirstChild("PlayerPlots")
    if not plots then return nil end
    local bestPlot, bestDist = nil, math.huge
    for _, plot in ipairs(plots:GetChildren()) do
        local sp = plot:FindFirstChild("SpawnPart")
        if sp then
            local part = sp:FindFirstChild("Part")
            if part then
                local ok, cf = pcall(function() return part.CFrame end)
                if ok and cf then
                    local d = (cf.Position - rootPos).Magnitude
                    if d < bestDist then bestDist = d; bestPlot = plot end
                end
            end
        end
    end
    return bestPlot, bestDist
end

local function scanFarms(plot)
    FarmList = {}
    if not plot then return end
    local b = plot:FindFirstChild("Plot")
    b = b and b:FindFirstChild("Buildings")
    if not b then b = plot:FindFirstChild("Buildings") end
    if not b then return end
    for _, model in ipairs(b:GetChildren()) do
        local ok, tp = pcall(function() return model:GetAttribute("type") end)
        if ok and tp == "Farm" then
            local part = model:FindFirstChildWhichIsA("BasePart")
            if not part then
                for _, c in ipairs(model:GetChildren()) do
                    if c:IsA("BasePart") then part = c; break end
                end
            end
            if not part then
                for _, c in ipairs(model:GetDescendants()) do
                    if c:IsA("BasePart") then part = c; break end
                end
            end
            if part then
                local ok2, cf = pcall(function() return part.CFrame end)
                if ok2 and cf then
                    table.insert(FarmList, {cf = CFrame.new(cf.X, cf.Y + 3, cf.Z), name = model.Name})
                end
            end
        end
    end
    print("[Farm] Scanned " .. #FarmList .. " farms")
end

-- ===== BACKGROUND LOOPS =====
local function startESpam()
    SpamE = true
    task.spawn(function()
        while SpamE and ScriptActive do
            pcall(function() keypress(VK_E) end)
            task.wait(0.05)
            pcall(function() keyrelease(VK_E) end)
            task.wait(0.05)
        end
    end)
end

local function stopESpam()
    SpamE = false
    pcall(function() keyrelease(VK_E) end)
end

local function doSell()
    local sellTP = workspace:FindFirstChild("Teleports")
    sellTP = sellTP and sellTP:FindFirstChild("sell")
    if not sellTP then print("[Sell] No sell teleport"); return end
    local ok, cf = pcall(function() return sellTP.CFrame end)
    if not ok or not cf then print("[Sell] Bad CFrame"); return end
    pcall(function()
        local root = getHRP()
        if root then root.CFrame = cf end
    end)
    task.wait(0.3)

    -- Press E once to open dialog
    pcall(function() keypress(VK_E) end)
    task.wait(0.05)
    pcall(function() keyrelease(VK_E) end)
    task.wait(1.2)

    -- Click "Sell all Crops" button
    local gui = player:FindFirstChild("PlayerGui")
    if gui then
        local dialog = gui:FindFirstChild("DialogOptions")
        if dialog then
            local holder = dialog:FindFirstChild("Holder")
            if holder then
                local inside = holder:FindFirstChild("Inside")
                if inside then
                    local btn = inside:FindFirstChild("Sell all Crops")
                    if btn then
                        local okP, pos = pcall(function() return btn.AbsolutePosition end)
                        local okS, size = pcall(function() return btn.AbsoluteSize end)
                        if okP and okS and pos and size and size.X > 0 then
                            local cx = pos.X + size.X / 2
                            local cy = pos.Y + size.Y / 2
                            moveMouse(cx, cy)
                            task.wait(0.05)
                            mouse1click()
                            task.wait(0.1)
                            print("[Sell] Clicked Sell all Crops")
                        end
                    else
                        print("[Sell] Button 'Sell all Crops' not found")
                        task.wait(1)
                        local btn2 = inside:FindFirstChild("Sell all Crops")
                        if btn2 then
                            local okP2, pos2 = pcall(function() return btn2.AbsolutePosition end)
                            local okS2, size2 = pcall(function() return btn2.AbsoluteSize end)
                            if okP2 and okS2 and pos2 and size2 and size2.X > 0 then
                                moveMouse(pos2.X + size2.X / 2, pos2.Y + size2.Y / 2)
                                task.wait(0.05)
                                mouse1click()
                                print("[Sell] Clicked on retry")
                            end
                        end
                    end
                end
            end
        end
    end

    task.wait(0.5)
    print("[Sell] Done")
end

local function startFarmLoop()
    if #FarmList == 0 then
        safeNotify("No farms found — click Country first", "MiniWar", 3)
        return
    end
    FarmLoop = true
    print("[Farm] Loop started (" .. #FarmList .. " farms)")
    startESpam()

    task.spawn(function()
        local cycle = 0
        while FarmLoop and ScriptActive do
            for i, farm in ipairs(FarmList) do
                if not FarmLoop or not ScriptActive then break end
                pcall(function()
                    local root = getHRP()
                    if root then root.CFrame = farm.cf end
                end)
                task.wait(0.1)
            end
            if not FarmLoop or not ScriptActive then break end
            cycle = cycle + 1

            -- Check auto sell after every 2 full cycles
            local autoSellOn = false
            for _, f in ipairs(F) do
                if f.key == "AutoSell" and f.value then autoSellOn = true; break end
            end
            if autoSellOn and cycle % 2 == 0 then
                doSell()
            end

            task.wait(0.1)
        end
        stopESpam()
    end)
end

local function stopFarmLoop()
    FarmLoop = false
    stopESpam()
end

-- ===== RENDER =====
local function Render()
    local x0, y0 = uiPos.X, uiPos.Y
    SHD.Position = Vector2.new(x0 - 4, y0 - 4)
    BG.Position  = Vector2.new(x0, y0)
    TB.Position  = Vector2.new(x0, y0)
    AL.Position  = Vector2.new(x0, y0 + TH)
    TT.Text = "MINIWAR v1"
    TT.Position = Vector2.new(x0 + uiS.X - TT.Text:len() * 7 - 8, y0 + (TH - 14) / 2)

    local yy0 = y0 + TH + AH + 3

    for s = 1, MAXS do
        local f = F[s]
        if not f then
            SL[s].Visible = false; SC[s].Visible = false; SF[s].Visible = false
        else
            local yy = yy0 + (s - 1) * RH
            local txt = "   " .. f.label
            SL[s].Text = txt; SL[s].Position = Vector2.new(x0 + 16, yy)
            if hov == s then
                SL[s].Color = f.value and C_A or C_TX
            else
                SL[s].Color = f.value and C_A or C_DM
            end
            SL[s].Visible = true
            SC[s].Position = Vector2.new(x0 + uiS.X - 44, yy + 8)
            SC[s].Color = f.value and C_A or C_TO; SC[s].Visible = true
            SF[s].Position = Vector2.new(x0 + uiS.X - 44, yy + 8)
            if f.value then anm[s] = math.min(1, anm[s] + 0.08) else anm[s] = math.max(0, anm[s] - 0.08) end
            if anm[s] > 0.01 then
                SF[s].Visible = true; SF[s].Radius = 1 + anm[s] * 5
                SF[s].Color = lerpColor(C_A, C_TO, 1 - anm[s])
            else SF[s].Visible = false end
        end
    end

    SEP.Position = Vector2.new(x0 + 12, y0 + uiS.Y - STH - 10)
    local asOn = false
    for _, f in ipairs(F) do if f.key == "AutoSell" and f.value then asOn = true; break end end
    STX.Text = "Farms: " .. #FarmList .. "  Loop: " .. (FarmLoop and "ON" or "OFF") .. "  Sell: " .. (asOn and "ON" or "OFF")
    STX.Position = Vector2.new(x0 + 14, y0 + uiS.Y - STH - 4)
end

-- ===== INPUT LOOP =====
task.spawn(function()
    while ScriptActive do
        task.wait(0.033)
        local mx, my = 0, 0; pcall(function() local m = player:GetMouse(); mx = m.X; my = m.Y end)
        local m1 = false; pcall(function() m1 = ismouse1pressed() end)
        local yy0 = uiPos.Y + TH + AH + 3; hov = 0

        for s = 1, MAXS do
            local yy = yy0 + (s - 1) * RH
            if mx >= uiPos.X + 8 and mx <= uiPos.X + uiS.X - 8 and my >= yy - 4 and my <= yy + RH then hov = s; break end
        end

        if m1 and not lastM1 then
            for s = 1, MAXS do
                local f = F[s]
                if f then
                    local yy = yy0 + (s - 1) * RH
                    if mx >= uiPos.X + 8 and mx <= uiPos.X + uiS.X - 8 and my >= yy - 4 and my <= yy + RH then
                        f.value = not f.value
                        print("[UI] " .. f.key .. " = " .. tostring(f.value))
                        if f.key == "FarmLoop" then
                            if f.value then startFarmLoop() else stopFarmLoop() end
                        elseif f.key == "AutoSell" then
                            safeNotify("AutoSell: " .. (f.value and "ON" or "OFF"), "MiniWar", 2)
                        end
                    end
                end
            end
            -- Drag
            if mx >= uiPos.X and mx <= uiPos.X + uiS.X and my >= uiPos.Y and my <= uiPos.Y + TH then
                drg = true; dOff = Vector2.new(mx - uiPos.X, my - uiPos.Y)
            end
        end

        if drg then
            if m1 then uiPos = Vector2.new(mx - dOff.X, my - dOff.Y) else drg = false end
        end
        lastM1 = m1
        pcall(Render)
    end
end)

-- ===== INIT =====
task.spawn(function()
    task.wait(1.5)
    clickCountry()
    task.wait(0.5)
    local myPlot = findClosestPlot()
    if myPlot then
        print("[MiniWar] Plot: " .. myPlot.Name)
        safeNotify("Plot: " .. myPlot.Name, "Plot", 3)
        scanFarms(myPlot)
    else
        print("[MiniWar] No plot found")
    end
    safeNotify("MiniWar Ready — " .. #FarmList .. " farms", "MiniWar", 3)
end)

_G.MatchaCleanup = function()
    FarmLoop = false; SpamE = false; ScriptActive = false
    pcall(function() keyrelease(VK_E) end)
    for _, obj in ipairs(drawObjs) do pcall(function() obj:Remove() end) end
end

safeNotify("MiniWar Loaded", "MiniWar", 3)
