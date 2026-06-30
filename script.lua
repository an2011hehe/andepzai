getgenv().AimbotEnabled = false
getgenv().ESPEnabled = false
getgenv().AimbotSmoothness = 0.3
getgenv().AimbotFOV = 500
getgenv().ESPDistance = 5000
getgenv().AimbotTarget = nil
getgenv().TeamCheck = true
getgenv().VisibleCheck = false
getgenv().ShowTracers = true
getgenv().ShowBox = true
getgenv().ShowName = true
getgenv().ShowDistance = true
getgenv().ShowHealth = true
getgenv().ChamsEnabled = true
getgenv().AimbotKey = Enum.UserInputType.MouseButton2

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

if not LocalPlayer.Character then LocalPlayer.CharacterAdded:Wait() end
if not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then LocalPlayer.Character:WaitForChild("HumanoidRootPart") end

local HighlightFolder = Instance.new("Folder")
HighlightFolder.Name = "Andepzai_Chams"
HighlightFolder.Parent = Workspace

local DrawingPool = {}
local ActiveHighlights = {}
local TeamCache = {}
local PlayerCache = {}
local LastUpdate = {aim = 0, esp = 0, highlight = 0, cleanup = 0}
local UpdateIntervals = {aim = 1/60, esp = 1/30, highlight = 0.2, cleanup = 5}

local function AcquireDrawing(classType)
    local pool = DrawingPool[classType]
    if not pool then pool = {} DrawingPool[classType] = pool end
    if #pool > 0 then return table.remove(pool) end
    return Drawing.new(classType)
end

local function ReleaseDrawing(drawing)
    drawing.Visible = false
    local pool = DrawingPool[drawing.__type]
    if pool and #pool < 200 then table.insert(pool, drawing) end
end

local function ReleaseAllDrawings(drawings)
    for i = 1, #drawings do ReleaseDrawing(drawings[i]) end
    table.clear(drawings)
end

local function QuickEnemyCheck(plr)
    if TeamCache[plr] ~= nil then return TeamCache[plr] end
    if plr == LocalPlayer then TeamCache[plr] = false return false end
    local myTeam, theirTeam = nil, nil
    pcall(function() myTeam = LocalPlayer.Team end)
    pcall(function() theirTeam = plr.Team end)
    if myTeam and theirTeam then TeamCache[plr] = (myTeam ~= theirTeam) return myTeam ~= theirTeam end
    pcall(function() myTeam = LocalPlayer.TeamColor end)
    pcall(function() theirTeam = plr.TeamColor end)
    if myTeam and theirTeam then TeamCache[plr] = (myTeam ~= theirTeam) return myTeam ~= theirTeam end
    TeamCache[plr] = true
    return true
end

local function IsEnemy(plr)
    if not getgenv().TeamCheck then return plr ~= LocalPlayer end
    return QuickEnemyCheck(plr)
end

local function UpdatePlayerCache()
    local now = tick()
    if now - LastUpdate.cleanup < UpdateIntervals.cleanup then return end
    LastUpdate.cleanup = now
    local list = Players:GetPlayers()
    local newCache = {}
    for i = 1, #list do
        local plr = list[i]
        local char = plr.Character
        local head = char and char:FindFirstChild("Head")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")
        if head and root and hum and hum.Health > 0 then
            newCache[plr] = {plr = plr, head = head, root = root, hum = hum, alive = true}
        else
            newCache[plr] = {plr = plr, alive = false}
        end
    end
    PlayerCache = newCache
end

local function GetCachedPlayers()
    if tick() - LastUpdate.cleanup > UpdateIntervals.cleanup then UpdatePlayerCache() end
    return PlayerCache
end

local function AddHighlight(plr)
    if ActiveHighlights[plr] then return end
    if not getgenv().ChamsEnabled then return end
    local char = plr.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return end
    if not char:FindFirstChild("Head") then return end
    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(0, 255, 0)
    hl.FillTransparency = 0.5
    hl.OutlineColor = Color3.fromRGB(0, 255, 0)
    hl.OutlineTransparency = 0.2
    hl.Adornee = char
    hl.Parent = HighlightFolder
    ActiveHighlights[plr] = hl
end

local function RemoveHighlight(plr)
    local hl = ActiveHighlights[plr]
    if hl then hl:Destroy() ActiveHighlights[plr] = nil end
end

local function GetClosestEnemy()
    local char = LocalPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local pos = root.Position
    local best, bestDist = nil, getgenv().AimbotFOV
    local cache = GetCachedPlayers()
    for _, data in pairs(cache) do
        if data.plr == LocalPlayer or not data.alive then continue end
        if not IsEnemy(data.plr) then continue end
        local d = (data.head.Position - pos).Magnitude
        if d < bestDist then bestDist = d best = data.plr end
    end
    return best
end

local function IsValid(plr)
    if not plr then return false end
    if not IsEnemy(plr) then return false end
    local data = GetCachedPlayers()[plr]
    return data and data.alive
end

local function AimbotStep(dt)
    local now = tick()
    if now - LastUpdate.aim < UpdateIntervals.aim then return end
    LastUpdate.aim = now

    if not getgenv().AimbotEnabled then
        getgenv().AimbotTarget = nil
        return
    end

    if not getgenv().AimbotTarget or not IsValid(getgenv().AimbotTarget) then
        getgenv().AimbotTarget = GetClosestEnemy()
    end

    local t = getgenv().AimbotTarget
    if not t or not IsValid(t) then
        getgenv().AimbotTarget = nil
        return
    end

    local hp = t.Character.Head.Position
    local cp = Camera.CFrame.Position
    local dir = (hp - cp).Unit
    local cur = Camera.CFrame.LookVector
    local s = math.clamp(getgenv().AimbotSmoothness * dt * 60, 0.08, 1)
    local nd = (cur + (dir - cur) * s).Unit
    Camera.CFrame = CFrame.new(cp, cp + nd)
end

local ActiveESPDrawings = {}

local function ESPStep()
    local now = tick()
    if now - LastUpdate.esp < UpdateIntervals.esp then return end
    LastUpdate.esp = now

    ReleaseAllDrawings(ActiveESPDrawings)

    if not getgenv().ESPEnabled then
        if now - LastUpdate.highlight > 1 then
            for plr, _ in pairs(ActiveHighlights) do RemoveHighlight(plr) end
            LastUpdate.highlight = now
        end
        return
    end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local cache = GetCachedPlayers()
    local espDist = getgenv().ESPDistance

    for _, data in pairs(cache) do
        local plr = data.plr
        if plr == LocalPlayer or not data.alive then
            RemoveHighlight(plr)
            continue
        end
        if not IsEnemy(plr) then RemoveHighlight(plr) continue end

        local h, r = data.head, data.root
        local dist = myRoot and (myRoot.Position - r.Position).Magnitude or 99999

        if dist > espDist then RemoveHighlight(plr) continue end

        if getgenv().ChamsEnabled then AddHighlight(plr) end

        local ts, tv = Camera:WorldToScreenPoint(h.Position + Vector3.new(0, 0.6, 0))
        local bs, bv = Camera:WorldToScreenPoint(r.Position - Vector3.new(0, 2.8, 0))
        if not tv or not bv or ts.Z <= 0 or bs.Z <= 0 then continue end

        local bh = math.abs(bs.Y - ts.Y)
        local bw = bh * 0.6
        local cx = (ts.X + bs.X) / 2
        local l, ri, t, b = cx - bw/2, cx + bw/2, ts.Y, bs.Y

        if getgenv().ShowBox then
            local cl = math.clamp(bh * 0.22, 6, 18)
            local corners = {
                {l, t, l, t+cl}, {l, t, l+cl, t}, {ri, t, ri, t+cl}, {ri, t, ri-cl, t},
                {l, b, l, b-cl}, {l, b, l+cl, b}, {ri, b, ri, b-cl}, {ri, b, ri-cl, b}
            }
            for j = 1, #corners do
                local v = corners[j]
                local ln = AcquireDrawing("Line")
                ln.From = Vector2.new(v[1], v[2])
                ln.To = Vector2.new(v[3], v[4])
                ln.Color = Color3.fromRGB(0, 255, 0)
                ln.Thickness = 2
                ln.Visible = true
                ActiveESPDrawings[#ActiveESPDrawings + 1] = ln
            end
        end

        local yOffset = t - 12

        if getgenv().ShowName or getgenv().ShowDistance then
            local nameText = plr.Name
            if getgenv().ShowDistance then nameText = nameText .. " [" .. math.floor(dist) .. "m]" end
            if getgenv().ShowName then
                local nt = AcquireDrawing("Text")
                nt.Text = nameText
                nt.Position = Vector2.new(cx, yOffset)
                nt.Size = 13
                nt.Color = Color3.new(1, 1, 1)
                nt.Center = true
                nt.Outline = true
                nt.OutlineColor = Color3.new(0, 0, 0)
                nt.Visible = true
                ActiveESPDrawings[#ActiveESPDrawings + 1] = nt
                yOffset = yOffset - 14
            end
        end

        if getgenv().ShowHealth then
            local hp = data.hum.Health / data.hum.MaxHealth
            local barW = bw
            local barH = 3
            local barY = b + 3

            local bg = AcquireDrawing("Square")
            bg.Position = Vector2.new(l, barY)
            bg.Size = Vector2.new(barW, barH)
            bg.Color = Color3.fromRGB(20, 20, 20)
            bg.Filled = true
            bg.Visible = true
            ActiveESPDrawings[#ActiveESPDrawings + 1] = bg

            local hc = hp > 0.6 and Color3.fromRGB(0, 255, 0) or hp > 0.3 and Color3.fromRGB(255, 255, 0) or Color3.fromRGB(255, 0, 0)
            local fg = AcquireDrawing("Square")
            fg.Position = Vector2.new(l, barY)
            fg.Size = Vector2.new(barW * hp, barH)
            fg.Color = hc
            fg.Filled = true
            fg.Visible = true
            ActiveESPDrawings[#ActiveESPDrawings + 1] = fg
        end

        if getgenv().ShowTracers and myRoot then
            local mySP, myV = Camera:WorldToScreenPoint(myRoot.Position)
            local headSP, headV = Camera:WorldToScreenPoint(h.Position)
            if myV and headV and mySP.Z > 0 and headSP.Z > 0 then
                local ln = AcquireDrawing("Line")
                ln.From = Vector2.new(mySP.X, mySP.Y)
                ln.To = Vector2.new(headSP.X, headSP.Y)
                ln.Color = Color3.fromRGB(0, 255, 0, 0.6)
                ln.Thickness = 1
                ln.Visible = true
                ActiveESPDrawings[#ActiveESPDrawings + 1] = ln
            end
        end
    end
end

RunService:BindToRenderStep("AndepzaiAimbot", 199, function(dt) AimbotStep(dt) end)
RunService:BindToRenderStep("AndepzaiESP", 200, function() ESPStep() end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if getgenv().AimbotEnabled and input.UserInputType == getgenv().AimbotKey then
        getgenv().AimbotTarget = GetClosestEnemy()
    end
end)

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        TeamCache[plr] = nil
        LastUpdate.cleanup = 0
    end)
end)
Players.PlayerRemoving:Connect(function(plr)
    TeamCache[plr] = nil
    PlayerCache[plr] = nil
    RemoveHighlight(plr)
end)

local gui = Instance.new("ScreenGui")
gui.Name = "AndepzaiHub"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LocalPlayer.PlayerGui

local AccentColor = Color3.fromRGB(0, 230, 120)

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 230, 0, 44)
mainFrame.Position = UDim2.new(0, 12, 0, 200)
mainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = gui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 9)
Instance.new("UIStroke", mainFrame).Color = Color3.fromRGB(45, 45, 52)

local headerBar = Instance.new("Frame")
headerBar.Size = UDim2.new(1, 0, 0, 44)
headerBar.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
headerBar.BorderSizePixel = 0
headerBar.Parent = mainFrame
Instance.new("UICorner", headerBar).CornerRadius = UDim.new(0, 9)

local accentLine = Instance.new("Frame")
accentLine.Size = UDim2.new(1, 0, 0, 2)
accentLine.Position = UDim2.new(0, 0, 1, -2)
accentLine.BackgroundColor3 = AccentColor
accentLine.BorderSizePixel = 0
accentLine.Parent = headerBar

local menuBtn = Instance.new("TextButton")
menuBtn.Size = UDim2.new(0, 28, 0, 24)
menuBtn.Position = UDim2.new(0, 8, 0.5, -12)
menuBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
menuBtn.Text = "☰"
menuBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
menuBtn.Font = Enum.Font.GothamBold
menuBtn.TextSize = 14
menuBtn.BorderSizePixel = 0
menuBtn.AutoButtonColor = false
menuBtn.Parent = headerBar
Instance.new("UICorner", menuBtn).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", menuBtn).Color = Color3.fromRGB(52, 52, 60)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 140, 1, 0)
titleLabel.Position = UDim2.new(0, 44, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "ANDEPZAI HUB"
titleLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = 12
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = headerBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 24)
closeBtn.Position = UDim2.new(1, -36, 0.5, -12)
closeBtn.BackgroundColor3 = Color3.fromRGB(235, 55, 65)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
closeBtn.BorderSizePixel = 0
closeBtn.AutoButtonColor = false
closeBtn.Parent = headerBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
closeBtn.MouseButton1Click:Connect(function()
    ReleaseAllDrawings(ActiveESPDrawings)
    for _, hl in pairs(ActiveHighlights) do hl:Destroy() end
    table.clear(ActiveHighlights)
    pcall(function() HighlightFolder:Destroy() end)
    RunService:UnbindFromRenderStep("AndepzaiAimbot")
    RunService:UnbindFromRenderStep("AndepzaiESP")
    gui:Destroy()
end)

local contentPanel = Instance.new("Frame")
contentPanel.Size = UDim2.new(0, 230, 0, 210)
contentPanel.Position = UDim2.new(0, 0, 0, 48)
contentPanel.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
contentPanel.BorderSizePixel = 0
contentPanel.ClipsDescendants = true
contentPanel.Visible = false
contentPanel.Parent = mainFrame
Instance.new("UICorner", contentPanel).CornerRadius = UDim.new(0, 9)

local contentScroll = Instance.new("ScrollingFrame")
contentScroll.Size = UDim2.new(1, -14, 1, -8)
contentScroll.Position = UDim2.new(0, 7, 0, 4)
contentScroll.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
contentScroll.BorderSizePixel = 0
contentScroll.ScrollBarThickness = 2
contentScroll.ScrollBarImageColor3 = AccentColor
contentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
contentScroll.Parent = contentPanel

local contentList = Instance.new("UIListLayout")
contentList.Padding = UDim.new(0, 5)
contentList.SortOrder = Enum.SortOrder.LayoutOrder
contentList.HorizontalAlignment = Enum.HorizontalAlignment.Center
contentList.Parent = contentScroll

local function updateScroll()
    contentScroll.CanvasSize = UDim2.new(0, 0, 0, contentList.AbsoluteContentSize.Y + 8)
end

local function makeSectionLabel(text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -4, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = AccentColor
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = contentScroll
    updateScroll()
end

local function makeToggle(name, def, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -4, 0, 32)
    f.BackgroundColor3 = Color3.fromRGB(22, 22, 27)
    f.BorderSizePixel = 0
    f.Parent = contentScroll
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 7)
    Instance.new("UIStroke", f).Color = Color3.fromRGB(38, 38, 44)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 100, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = Color3.fromRGB(240, 240, 245)
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f

    local sw = Instance.new("TextButton")
    sw.Size = UDim2.new(0, 38, 0, 20)
    sw.Position = UDim2.new(1, -48, 0.5, -10)
    sw.BackgroundColor3 = def and AccentColor or Color3.fromRGB(32, 32, 38)
    sw.Text = ""
    sw.BorderSizePixel = 0
    sw.AutoButtonColor = false
    sw.Parent = f
    Instance.new("UICorner", sw).CornerRadius = UDim.new(0, 10)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(def and 1 or 0, def and -19 or 3, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = sw
    Instance.new("UICorner", knob).CornerRadius = UDim.new(0, 8)

    local on = def
    sw.MouseButton1Click:Connect(function()
        on = not on
        local tc = on and AccentColor or Color3.fromRGB(32, 32, 38)
        local tp = on and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        TweenService:Create(sw, TweenInfo.new(0.15), {BackgroundColor3 = tc}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {Position = tp}):Play()
        cb(on)
    end)
    updateScroll()
end

local function makeSlider(name, def, min, max, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -4, 0, 48)
    f.BackgroundColor3 = Color3.fromRGB(22, 22, 27)
    f.BorderSizePixel = 0
    f.Parent = contentScroll
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 7)
    Instance.new("UIStroke", f).Color = Color3.fromRGB(38, 38, 44)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -16, 0, 16)
    lbl.Position = UDim2.new(0, 8, 0, 3)
    lbl.BackgroundTransparency = 1
    lbl.Text = name .. ": " .. tostring(def)
    lbl.TextColor3 = Color3.fromRGB(170, 170, 175)
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f

    local inp = Instance.new("TextBox")
    inp.Size = UDim2.new(1, -16, 0, 24)
    inp.Position = UDim2.new(0, 8, 0, 22)
    inp.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
    inp.Text = tostring(def)
    inp.TextColor3 = Color3.fromRGB(240, 240, 245)
    inp.PlaceholderColor3 = Color3.fromRGB(110, 110, 120)
    inp.Font = Enum.Font.Gotham
    inp.TextSize = 10
    inp.BorderSizePixel = 0
    inp.Parent = f
    Instance.new("UICorner", inp).CornerRadius = UDim.new(0, 4)
    Instance.new("UIStroke", inp).Color = Color3.fromRGB(42, 42, 48)

    inp.FocusLost:Connect(function()
        local n = tonumber(inp.Text)
        if n and n >= min and n <= max then
            cb(n)
            lbl.Text = name .. ": " .. tostring(n)
        else
            inp.Text = tostring(def)
        end
    end)
    updateScroll()
end

makeSectionLabel("COMBAT")
makeToggle("Aimbot", false, function(s)
    getgenv().AimbotEnabled = s
    if not s then getgenv().AimbotTarget = nil end
end)
makeSlider("Smoothness", 0.3, 0.05, 1.0, function(v) getgenv().AimbotSmoothness = v end)
makeSlider("FOV", 500, 100, 2000, function(v) getgenv().AimbotFOV = v end)

makeSectionLabel("VISUALS")
makeToggle("Player ESP", false, function(s) getgenv().ESPEnabled = s end)
makeToggle("Chams (Green)", true, function(s) getgenv().ChamsEnabled = s end)
makeToggle("Box ESP", true, function(s) getgenv().ShowBox = s end)
makeToggle("Show Name", true, function(s) getgenv().ShowName = s end)
makeToggle("Show Distance", true, function(s) getgenv().ShowDistance = s end)
makeToggle("Show Health", true, function(s) getgenv().ShowHealth = s end)
makeToggle("Tracers", true, function(s) getgenv().ShowTracers = s end)
makeSlider("ESP Distance", 5000, 500, 20000, function(v) getgenv().ESPDistance = v end)

makeSectionLabel("SETTINGS")
makeToggle("Team Check", true, function(s) getgenv().TeamCheck = s end)
makeToggle("Visible Check", false, function(s) getgenv().VisibleCheck = s end)

updateScroll()

local menuOpen = false
menuBtn.MouseButton1Click:Connect(function()
    menuOpen = not menuOpen
    if menuOpen then
        contentPanel.Visible = true
        TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0, 230, 0, 270)}):Play()
        menuBtn.Text = "−"
        menuBtn.BackgroundColor3 = AccentColor
        menuBtn.TextColor3 = Color3.fromRGB(10, 10, 12)
    else
        TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Size = UDim2.new(0, 230, 0, 44)}):Play()
        task.wait(0.2)
        contentPanel.Visible = false
        menuBtn.Text = "☰"
        menuBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
        menuBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
    end
end)

gui.Destroying:Connect(function()
    ReleaseAllDrawings(ActiveESPDrawings)
    for _, hl in pairs(ActiveHighlights) do hl:Destroy() end
    table.clear(ActiveHighlights)
    pcall(function() HighlightFolder:Destroy() end)
    RunService:UnbindFromRenderStep("AndepzaiAimbot")
    RunService:UnbindFromRenderStep("AndepzaiESP")
end)

task.spawn(function()
    while task.wait(60) do
        collectgarbage("collect")
        for classType, pool in pairs(DrawingPool) do
            if #pool > 100 then
                for i = #pool, 101, -1 do
                    pool[i]:Remove()
                    pool[i] = nil
                end
            end
        end
    end
end)