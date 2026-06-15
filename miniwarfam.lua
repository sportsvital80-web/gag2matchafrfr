if _G.MatchaCleanup then pcall(_G.MatchaCleanup) end
local ScriptActive = true

local pcall = pcall; local pairs = pairs; local ipairs = ipairs; local task = task
local players = game:GetService("Players"); local player = players.LocalPlayer

local function safeNotify(msg, title, dur)
    pcall(function() notify(tostring(msg), tostring(title or "Wheat"), dur or 3) end)
end

local function getHRP()
    local char = player.Character
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart"))
end

local VK_E = 0x45
local drawObjs = {}
local function D(typ, props)
    local obj = Drawing.new(typ)
    for k, v in pairs(props) do obj[k] = v end
    table.insert(drawObjs, obj)
    return obj
end

local uiPos = Vector2.new(150, 120)
local uiSize = Vector2.new(330, 120)
local dragging = false; local dragOff = Vector2.new(0, 0); local lastM1 = false

local Shadow  = D("Square", {Size = Vector2.new(uiSize.X+6, uiSize.Y+6), Color = Color3.fromRGB(0,0,0), Transparency = 0.35, Filled = true, Visible = true})
local MainBG  = D("Square", {Size = uiSize, Color = Color3.fromRGB(12,12,16), Filled = true, Visible = true})
local TopBar  = D("Square", {Size = Vector2.new(uiSize.X, 30), Color = Color3.fromRGB(22,22,28), Filled = true, Visible = true})
local AccLine = D("Square", {Size = Vector2.new(uiSize.X, 2), Color = Color3.fromRGB(0,212,170), Filled = true, Visible = true})
local TitleT  = D("Text", {Text = "WHEAT COLLECTOR", Size = 14, Color = Color3.fromRGB(0,212,170), Outline = true, Visible = true, Font = Drawing.Fonts.System})

local Row1Lbl  = D("Text", {Text = "> COLLECT FARMS", Size = 13, Color = Color3.fromRGB(190,190,195), Outline = true, Visible = true, Font = Drawing.Fonts.System})
local Row1Circ = D("Circle", {Radius = 6, Thickness = 2, Color = Color3.fromRGB(80,80,90), Filled = false, Visible = true})
local Row1Fill = D("Circle", {Radius = 3, Color = Color3.fromRGB(0,212,170), Filled = true, Visible = false})

local Row2Lbl  = D("Text", {Text = "> AUTO SELL", Size = 13, Color = Color3.fromRGB(190,190,195), Outline = true, Visible = true, Font = Drawing.Fonts.System})
local Row2Circ = D("Circle", {Radius = 6, Thickness = 2, Color = Color3.fromRGB(80,80,90), Filled = false, Visible = true})
local Row2Fill = D("Circle", {Radius = 3, Color = Color3.fromRGB(0,212,170), Filled = true, Visible = false})

local StatTxt = D("Text", {Text = "Detecting...", Size = 11, Color = Color3.fromRGB(70,70,80), Outline = true, Visible = true, Font = Drawing.Fonts.System})

local wheatOn = false
local sellOn = false

local function findMyPlot()
    local plots = workspace:FindFirstChild("MilitaryMap") and workspace.MilitaryMap:FindFirstChild("PlayerPlots")
    if not plots then print("[Wheat] No PlayerPlots found"); return nil end

    local localNpcs = workspace:FindFirstChild("LocalNpcs")
    if not localNpcs or #localNpcs:GetChildren() == 0 then print("[Wheat] No LocalNpcs found"); return nil end

    local npc = localNpcs:GetChildren()[1]
    local npcPos = nil
    local ok, npcCF = pcall(function() return npc:GetPrimaryPartCFrame() end)
    if ok and npcCF then
        npcPos = npcCF.Position
    else
        for _, c in ipairs(npc:GetChildren()) do
            if c:IsA("BasePart") then
                local ok2, cf2 = pcall(function() return c.CFrame end)
                if ok2 and cf2 then npcPos = cf2.Position; break end
            end
        end
    end

    if not npcPos then print("[Wheat] Can't get NPC position"); return nil end
    print("[Wheat] NPC pos: " .. tostring(npcPos))

    local bestPlot, bestDist = nil, math.huge
    for _, plot in ipairs(plots:GetChildren()) do
        local ok, dist = pcall(function()
            local assets = plot:FindFirstChild("Assets")
            if not assets then return math.huge end
            for _, c in ipairs(assets:GetChildren()) do
                if c:IsA("BasePart") then
                    local ok2, cf = pcall(function() return c.CFrame end)
                    if ok2 and cf then
                        local d = (cf.Position - npcPos).Magnitude
                        print("[Wheat] Plot " .. plot.Name .. " part " .. c.Name .. " dist=" .. math.floor(d))
                        return d
                    end
                end
            end
            return math.huge
        end)
        if ok and dist < bestDist then
            bestDist = dist
            bestPlot = plot
        end
    end

    if bestPlot then
        print("[Wheat] Found via NPC proximity: Plot " .. bestPlot.Name .. " (dist: " .. math.floor(bestDist) .. ")")
    end
    return bestPlot
end

local cachedFarms = {}

local function buildFarmCache(plot)
    cachedFarms = {}
    local b = plot:FindFirstChild("Plot") and plot.Plot:FindFirstChild("Buildings")
    if not b then
        print("[Wheat] No Buildings in plot.Plot, trying alternatives...")
        b = plot:FindFirstChild("Buildings")
        if not b then
            for _, child in ipairs(plot:GetChildren()) do
                print("[Wheat] Plot child:", child.Name, child.ClassName)
                if child:IsA("Folder") or child:IsA("Model") then
                    local bb = child:FindFirstChild("Buildings")
                    if bb then b = bb; print("[Wheat] Found Buildings in:", child.Name); break end
                end
            end
        end
    end
    if not b then print("[Wheat] No Buildings folder found!"); return end
    print("[Wheat] Buildings found:", b:GetFullName())
    for _, model in ipairs(b:GetChildren()) do
        local tp = tostring(model:GetAttribute("type"))
        local res = tonumber(model:GetAttribute("ResourcesToCollect")) or 0
        if tp == "Farm" and res > 0 then
            local floor = model:FindFirstChild("BuildingFloor10")
            if not floor then
                for _, child in ipairs(model:GetChildren()) do
                    if child:IsA("BasePart") then floor = child; break end
                end
            end
            if floor then
                local okCf, cf = pcall(function() return floor.CFrame end)
                if okCf and cf then
                    table.insert(cachedFarms, {model = model, pos = CFrame.new(cf.X, cf.Y + 3, cf.Z), name = model.Name, res = res})
                    print("[Wheat] Cached:", model.Name, "res:", res)
                end
            end
        end
    end
end

local myPlot = findMyPlot()
if myPlot then
    buildFarmCache(myPlot)
    StatTxt.Text = "Plot: " .. myPlot.Name .. " | Farms: " .. #cachedFarms
else
    StatTxt.Text = "No plot found!"
end

local sellTP = nil
local sellFolder = workspace:FindFirstChild("Teleports")
if sellFolder then
    sellTP = sellFolder:FindFirstChild("sell") or sellFolder:FindFirstChild("Sell")
end
if sellTP then
    local ok, cf = pcall(function() return sellTP.CFrame end)
    if ok and cf then sellTP = CFrame.new(cf.X, cf.Y + 3, cf.Z) end
else
    print("[Wheat] No sell teleport found")
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

local function doSell()
    local root = getHRP()
    if not root or not sellTP then return end
    root.CFrame = sellTP
    task.wait(0.3)
    pcall(function() keypress(VK_E) end)
    task.wait(0.2)
    pcall(function() keyrelease(VK_E) end)
    task.wait(1)

    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return end
    local dialog = gui:FindFirstChild("DialogOptions")
    if not dialog then return end
    local holder = dialog:FindFirstChild("Holder")
    if not holder then return end
    local inside = holder:FindFirstChild("Inside")
    if not inside then return end

    for _, btn in ipairs(inside:GetChildren()) do
        local okName = pcall(function() return btn.Name end)
        if okName and btn.Name:lower():find("sell") then
            print("[Wheat] Found sell button by name: " .. btn.Name)
            clk(btn)
            task.wait(0.5)
            return
        end
    end

    for _, btn in ipairs(inside:GetChildren()) do
        if btn:IsA("GuiButton") then
            local ok, txt = pcall(function() return btn.Text end)
            if ok and txt and txt:lower():find("sell") then
                print("[Wheat] Clicking: " .. txt)
                clk(btn)
                task.wait(0.5)
                return
            end
        end
    end

    for _, btn in ipairs(inside:GetChildren()) do
        if btn:IsA("TextButton") or btn:IsA("ImageButton") then
            print("[Wheat] Clicking first button in dialog")
            clk(btn)
            task.wait(0.5)
            return
        end
    end
end

task.spawn(function()
    print("[Wheat] Collector started | Farms cached:", #cachedFarms)
    while ScriptActive do
        if wheatOn and #cachedFarms > 0 then
            local root = getHRP()
            if root then
                local collected = 0
                for i, farm in ipairs(cachedFarms) do
                    if not ScriptActive then break end
                    local res = tonumber(farm.model:GetAttribute("ResourcesToCollect")) or 0
                    if res > 0 then
                        root.CFrame = farm.pos
                        task.wait(0.04)
                        pcall(function() keypress(VK_E) end)
                        task.wait(0.02)
                        pcall(function() keyrelease(VK_E) end)
                        task.wait(0.04)
                        collected = collected + 1
                    end
                end
                if sellOn and sellTP and collected > 0 then
                    doSell()
                end
                if collected > 0 then print("[Wheat] Round:", collected .. "/" .. #cachedFarms) end
            end
        end
        task.wait(0.1)
    end
end)

task.spawn(function()
    while ScriptActive do
        task.wait(0.016)
        local mx, my = 0, 0
        pcall(function() local m = player:GetMouse(); mx = m.X; my = m.Y end)
        local m1 = false
        pcall(function() m1 = ismouse1pressed() end)

        local yy1 = uiPos.Y + 38
        local yy2 = uiPos.Y + 66

        if m1 and not lastM1 then
            if mx >= uiPos.X + 10 and mx <= uiPos.X + uiSize.X - 10 and my >= yy1 - 2 and my <= yy1 + 22 then
                wheatOn = not wheatOn
                safeNotify("Wheat: " .. (wheatOn and "ON" or "OFF"), "Toggle", 2)
            end
            if mx >= uiPos.X + 10 and mx <= uiPos.X + uiSize.X - 10 and my >= yy2 - 2 and my <= yy2 + 22 then
                sellOn = not sellOn
                safeNotify("Sell: " .. (sellOn and "ON" or "OFF"), "Toggle", 2)
            end
            if mx >= uiPos.X and mx <= uiPos.X + uiSize.X and my >= uiPos.Y and my <= uiPos.Y + 30 then
                dragging = true; dragOff = Vector2.new(mx - uiPos.X, my - uiPos.Y)
            end
        end
        if dragging then
            if m1 then uiPos = Vector2.new(mx - dragOff.X, my - dragOff.Y)
            else dragging = false end
        end
        lastM1 = m1

        Shadow.Position  = Vector2.new(uiPos.X - 3, uiPos.Y - 3)
        MainBG.Position  = uiPos
        TopBar.Position  = uiPos
        AccLine.Position = Vector2.new(uiPos.X, uiPos.Y + 30)
        TitleT.Position  = Vector2.new(uiPos.X + 10, uiPos.Y + 8)

        local over1 = mx >= uiPos.X + 10 and mx <= uiPos.X + uiSize.X - 10 and my >= yy1 - 2 and my <= yy1 + 22
        Row1Lbl.Position = Vector2.new(uiPos.X + 16, yy1)
        Row1Lbl.Color = over1 and Color3.fromRGB(255,255,255) or (wheatOn and Color3.fromRGB(0,212,170) or Color3.fromRGB(190,190,195))
        Row1Circ.Position = Vector2.new(uiPos.X + uiSize.X - 22, yy1 + 7)
        Row1Circ.Color = wheatOn and Color3.fromRGB(0,212,170) or Color3.fromRGB(80,80,90)
        Row1Fill.Position = Row1Circ.Position
        Row1Fill.Visible = wheatOn

        local over2 = mx >= uiPos.X + 10 and mx <= uiPos.X + uiSize.X - 10 and my >= yy2 - 2 and my <= yy2 + 22
        Row2Lbl.Position = Vector2.new(uiPos.X + 16, yy2)
        Row2Lbl.Color = over2 and Color3.fromRGB(255,255,255) or (sellOn and Color3.fromRGB(0,212,170) or Color3.fromRGB(190,190,195))
        Row2Circ.Position = Vector2.new(uiPos.X + uiSize.X - 22, yy2 + 7)
        Row2Circ.Color = sellOn and Color3.fromRGB(0,212,170) or Color3.fromRGB(80,80,90)
        Row2Fill.Position = Row2Circ.Position
        Row2Fill.Visible = sellOn

        StatTxt.Text = (wheatOn and "Collecting... " or "") .. (sellOn and "Selling " or "") .. "Plot: " .. (myPlot and myPlot.Name or "?")
        StatTxt.Position = Vector2.new(uiPos.X + 10, uiPos.Y + uiSize.Y - 16)
    end
end)

_G.MatchaCleanup = function()
    ScriptActive = false
    for _, obj in ipairs(drawObjs) do pcall(function() obj:Remove() end) end
end

safeNotify("Wheat Collector Loaded!", "Wheat", 3)
print("[Wheat] plot:", myPlot and myPlot.Name or "NONE")
