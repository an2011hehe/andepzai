getgenv().AimbotEnabled = false
getgenv().ESPEnabled = false
getgenv().AimbotSmoothness = 0.3
getgenv().AimbotFOV = 500
getgenv().ESPDistance = 5000
getgenv().AimbotTarget = nil

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

repeat task.wait() until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

local HighlightFolder = Instance.new("Folder")
HighlightFolder.Name = "Andepzai_Highlights"
HighlightFolder.Parent = Workspace

local ActiveHighlights = {}
local ESPDrawings = {}

local function ClearHighlights()
    for _, hl in pairs(ActiveHighlights) do
        pcall(function() hl:Destroy() end)
    end
    table.clear(ActiveHighlights)
end

local function AddHighlight(plr)
    if ActiveHighlights[plr] then return end
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
    if ActiveHighlights[plr] then
        pcall(function() ActiveHighlights[plr]:Destroy() end)
        ActiveHighlights[plr] = nil
    end
end

local function IsEnemy(plr)
    if plr == LocalPlayer then return false end
    local myTeam, theirTeam = nil, nil
    pcall(function() myTeam = LocalPlayer.Team end)
    pcall(function() theirTeam = plr.Team end)
    if myTeam and theirTeam then return myTeam ~= theirTeam end
    pcall(function() myTeam = LocalPlayer.TeamColor end)
    pcall(function() theirTeam = plr.TeamColor end)
    if myTeam and theirTeam then return myTeam ~= theirTeam end
    return true
end

local function GetClosestEnemy()
    local char = LocalPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local pos = root.Position
    local best, bestDist = nil, getgenv().AimbotFOV
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if not IsEnemy(plr) then continue end
        local c = plr.Character
        if not c then continue end
        local h = c:FindFirstChild("Head")
        local hum = c:FindFirstChild("Humanoid")
        if not h or not hum or hum.Health <= 0 then continue end
        local d = (h.Position - pos).Magnitude
        if d < bestDist then bestDist = d best = plr end
    end
    return best
end

local function IsValid(plr)
    if not plr then return false end
    if not IsEnemy(plr) then return false end
    local c = plr.Character
    if not c then return false end
    local hum = c:FindFirstChild("Humanoid")
    return c:FindFirstChild("Head") and hum and hum.Health > 0
end

local function ClearESPDrawings()
    for _, d in ipairs(ESPDrawings) do
        pcall(function() d:Remove() end)
    end
    table.clear(ESPDrawings)
end

RunService.RenderStepped:Connect(function(dt)
    if getgenv().AimbotEnabled then
        if not getgenv().AimbotTarget or not IsValid(getgenv().AimbotTarget) then
            getgenv().AimbotTarget = GetClosestEnemy()
        end
        local t = getgenv().AimbotTarget
        if t and IsValid(t) then
            local hp = t.Character.Head.Position
            local cp = Camera.CFrame.Position
            local dir = (hp - cp).Unit
            local cur = Camera.CFrame.LookVector
            local s = math.clamp(getgenv().AimbotSmoothness * dt * 60, 0.08, 1)
            local nd = (cur + (dir - cur) * s).Unit
            Camera.CFrame = CFrame.new(cp, cp + nd)
        else
            getgenv().AimbotTarget = nil
        end
    else
        getgenv().AimbotTarget = nil
    end

    ClearESPDrawings()
    if not getgenv().ESPEnabled then ClearHighlights() return end
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if not IsEnemy(plr) then RemoveHighlight(plr) continue end
        local c = plr.Character
        if not c then RemoveHighlight(plr) continue end
        local h = c:FindFirstChild("Head")
        local r = c:FindFirstChild("HumanoidRootPart")
        local hum = c:FindFirstChild("Humanoid")
        if not h or not r or not hum or hum.Health <= 0 then RemoveHighlight(plr) continue end
        local dist = myRoot and (myRoot.Position - r.Position).Magnitude or 0
        if dist > getgenv().ESPDistance then RemoveHighlight(plr) continue end
        AddHighlight(plr)
        local ts, tv = Camera:WorldToScreenPoint(h.Position + Vector3.new(0, 0.6, 0))
        local bs, bv = Camera:WorldToScreenPoint(r.Position - Vector3.new(0, 2.8, 0))
        if not tv or not bv or ts.Z <= 0 or bs.Z <= 0 then continue end
        local bh = math.abs(bs.Y - ts.Y)
        local bw = bh * 0.6
        local cx = (ts.X + bs.X) / 2
        local l, ri, t, b = cx - bw/2, cx + bw/2, ts.Y, bs.Y
        local cl = math.clamp(bh * 0.22, 6, 18)
        local corners = {
            {l, t, l, t+cl}, {l, t, l+cl, t}, {ri, t, ri, t+cl}, {ri, t, ri-cl, t},
            {l, b, l, b-cl}, {l, b, l+cl, b}, {ri, b, ri, b-cl}, {ri, b, ri-cl, b}
        }
        for _, v in ipairs(corners) do
            local ln = Drawing.new("Line")
            ln.From, ln.To, ln.Color, ln.Thickness, ln.Visible = Vector2.new(v[1], v[2]), Vector2.new(v[3], v[4]), Color3.fromRGB(0,255,0), 2, true
            table.insert(ESPDrawings, ln)
        end
        local nt = Drawing.new("Text")
        nt.Text, nt.Position, nt.Size, nt.Color, nt.Center, nt.Outline, nt.OutlineColor, nt.Visible = plr.Name.." ["..math.floor(dist).."m]", Vector2.new(cx, t-10), 13, Color3.new(1,1,1), true, true, Color3.new(0,0,0), true
        table.insert(ESPDrawings, nt)
    end
end)

Mouse.Button2Down:Connect(function()
    if getgenv().AimbotEnabled then getgenv().AimbotTarget = GetClosestEnemy() end
end)

local function BuildUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "AndepzaiHub"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = LocalPlayer.PlayerGui

    local NexLib = {}
    NexLib.accent = Color3.fromRGB(0, 230, 120)
    NexLib.dropdownFrames = {}
    NexLib.colorpickerFrames = {}

    local function makeDrag(dragFrame, targetFrame)
        local isDragging = false
        local dragStart = nil
        local frameStart = nil
        dragFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                isDragging = true
                dragStart = input.Position
                frameStart = targetFrame.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then isDragging = false end
                end)
            end
        end)
        dragFrame.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                UserInputService.InputChanged:Connect(function(uiInput)
                    if uiInput == input and isDragging then
                        local delta = uiInput.Position - dragStart
                        targetFrame.Position = UDim2.new(frameStart.X.Scale, frameStart.X.Offset + delta.X, frameStart.Y.Scale, frameStart.Y.Offset + delta.Y)
                    end
                end)
            end
        end)
    end

    function NexLib:Notification(title, message, duration)
        local notif = Instance.new("Frame")
        notif.Name = "Notification"
        notif.Size = UDim2.new(0, 300, 0, 45)
        notif.Position = UDim2.new(1.5, 0, 0.5, 0)
        notif.AnchorPoint = Vector2.new(0.5, 0.5)
        notif.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        notif.BorderSizePixel = 0
        notif.Parent = gui

        Instance.new("UICorner", notif).CornerRadius = UDim.new(0, 6)
        Instance.new("UIStroke", notif).Color = Color3.fromRGB(50, 50, 58)

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Position = UDim2.new(0, 40, 0, 6)
        titleLabel.Size = UDim2.new(1, -50, 0, 18)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = title
        titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextSize = 14
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Parent = notif

        local descLabel = Instance.new("TextLabel")
        descLabel.Position = UDim2.new(0, 40, 0, 24)
        descLabel.Size = UDim2.new(1, -50, 0, 18)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = message
        descLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextSize = 12
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.Parent = notif

        local ico = Instance.new("Frame")
        ico.Size = UDim2.new(0, 24, 0, 24)
        ico.Position = UDim2.new(0, 8, 0.5, -12)
        ico.BackgroundColor3 = NexLib.accent
        ico.BorderSizePixel = 0
        ico.Parent = notif
        Instance.new("UICorner", ico).CornerRadius = UDim.new(0, 6)

        local icoText = Instance.new("TextLabel")
        icoText.Size = UDim2.new(1, 0, 1, 0)
        icoText.BackgroundTransparency = 1
        icoText.Text = "i"
        icoText.TextColor3 = Color3.fromRGB(10, 10, 12)
        icoText.Font = Enum.Font.GothamBlack
        icoText.TextSize = 16
        icoText.Parent = ico

        TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
        delay(duration or 3, function()
            TweenService:Create(notif, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {Position = UDim2.new(1.5, 0, 0.5, 0)}):Play()
            task.wait(0.2)
            notif:Destroy()
        end)
    end

    function NexLib:Window(title)
        local mainFrame = Instance.new("Frame")
        mainFrame.Size = UDim2.new(0, 240, 0, 46)
        mainFrame.Position = UDim2.new(0, 15, 0, 200)
        mainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
        mainFrame.BorderSizePixel = 0
        mainFrame.ClipsDescendants = true
        mainFrame.Parent = gui
        Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)
        Instance.new("UIStroke", mainFrame).Color = Color3.fromRGB(45, 45, 52)

        local headerBar = Instance.new("Frame")
        headerBar.Size = UDim2.new(1, 0, 0, 46)
        headerBar.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
        headerBar.BorderSizePixel = 0
        headerBar.Parent = mainFrame
        Instance.new("UICorner", headerBar).CornerRadius = UDim.new(0, 10)

        local accentLine = Instance.new("Frame")
        accentLine.Size = UDim2.new(1, 0, 0, 2)
        accentLine.Position = UDim2.new(0, 0, 1, -2)
        accentLine.BorderSizePixel = 0
        accentLine.Parent = headerBar

        task.spawn(function()
            while task.wait() do
                accentLine.BackgroundColor3 = NexLib.accent
            end
        end)

        makeDrag(headerBar, mainFrame)

        local menuBtn = Instance.new("TextButton")
        menuBtn.Size = UDim2.new(0, 30, 0, 26)
        menuBtn.Position = UDim2.new(0, 8, 0.5, -13)
        menuBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
        menuBtn.Text = "☰"
        menuBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
        menuBtn.Font = Enum.Font.GothamBold
        menuBtn.TextSize = 15
        menuBtn.BorderSizePixel = 0
        menuBtn.AutoButtonColor = false
        menuBtn.Parent = headerBar
        Instance.new("UICorner", menuBtn).CornerRadius = UDim.new(0, 7)
        Instance.new("UIStroke", menuBtn).Color = Color3.fromRGB(55, 55, 63)

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(0, 150, 1, 0)
        titleLabel.Position = UDim2.new(0, 46, 0, 0)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = title
        titleLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
        titleLabel.Font = Enum.Font.GothamBlack
        titleLabel.TextSize = 13
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Parent = headerBar

        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 30, 0, 26)
        closeBtn.Position = UDim2.new(1, -38, 0.5, -13)
        closeBtn.BackgroundColor3 = Color3.fromRGB(235, 55, 65)
        closeBtn.Text = "✕"
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 13
        closeBtn.BorderSizePixel = 0
        closeBtn.AutoButtonColor = false
        closeBtn.Parent = headerBar
        Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 7)
        closeBtn.MouseButton1Click:Connect(function()
            ClearHighlights()
            ClearESPDrawings()
            pcall(function() HighlightFolder:Destroy() end)
            gui:Destroy()
        end)

        local contentPanel = Instance.new("Frame")
        contentPanel.Size = UDim2.new(0, 240, 0, 200)
        contentPanel.Position = UDim2.new(0, 0, 0, 50)
        contentPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
        contentPanel.BorderSizePixel = 0
        contentPanel.ClipsDescendants = true
        contentPanel.Visible = false
        contentPanel.Parent = mainFrame
        Instance.new("UICorner", contentPanel).CornerRadius = UDim.new(0, 10)

        local tabHolder = Instance.new("Frame")
        tabHolder.Size = UDim2.new(1, 0, 0, 32)
        tabHolder.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
        tabHolder.BorderSizePixel = 0
        tabHolder.Parent = contentPanel

        local tabList = Instance.new("UIListLayout")
        tabList.FillDirection = Enum.FillDirection.Horizontal
        tabList.SortOrder = Enum.SortOrder.LayoutOrder
        tabList.Padding = UDim.new(0, 4)
        tabList.Parent = tabHolder

        local tabPadding = Instance.new("UIPadding")
        tabPadding.PaddingLeft = UDim.new(0, 8)
        tabPadding.Parent = tabHolder

        local sectionScroll = Instance.new("ScrollingFrame")
        sectionScroll.Size = UDim2.new(1, -14, 1, -38)
        sectionScroll.Position = UDim2.new(0, 7, 0, 36)
        sectionScroll.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
        sectionScroll.BorderSizePixel = 0
        sectionScroll.ScrollBarThickness = 3
        sectionScroll.ScrollBarImageColor3 = NexLib.accent
        sectionScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        sectionScroll.Parent = contentPanel

        local sectionList = Instance.new("UIListLayout")
        sectionList.Padding = UDim.new(0, 8)
        sectionList.SortOrder = Enum.SortOrder.LayoutOrder
        sectionList.HorizontalAlignment = Enum.HorizontalAlignment.Center
        sectionList.Parent = sectionScroll

        local function updateScroll()
            sectionScroll.CanvasSize = UDim2.new(0, 0, 0, sectionList.AbsoluteContentSize.Y + 10)
        end

        local currentTab = nil
        local tabContents = {}

        local menuOpen = false
        menuBtn.MouseButton1Click:Connect(function()
            menuOpen = not menuOpen
            if menuOpen then
                contentPanel.Visible = true
                TweenService:Create(mainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0, 240, 0, 260)}):Play()
                menuBtn.Text = "−"
                menuBtn.BackgroundColor3 = NexLib.accent
                menuBtn.TextColor3 = Color3.fromRGB(10, 10, 12)
            else
                TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Size = UDim2.new(0, 240, 0, 46)}):Play()
                task.wait(0.25)
                contentPanel.Visible = false
                menuBtn.Text = "☰"
                menuBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
                menuBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
            end
        end)

        local function switchTab(tabBtn, contentFrame)
            for _, tab in ipairs(tabContents) do
                if tab.content == contentFrame then
                    tab.content.Visible = true
                    tab.btn.TextTransparency = 0
                else
                    tab.content.Visible = false
                    tab.btn.TextTransparency = 0.5
                end
            end
            updateScroll()
        end

        local function createTab(name)
            local tabBtn = Instance.new("TextButton")
            tabBtn.Size = UDim2.new(0, tabBtn.TextBounds.X + 20, 1, 0)
            tabBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
            tabBtn.BackgroundTransparency = 1
            tabBtn.Text = name
            tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            tabBtn.Font = Enum.Font.GothamBold
            tabBtn.TextSize = 13
            tabBtn.TextTransparency = 0.5
            tabBtn.BorderSizePixel = 0
            tabBtn.AutoButtonColor = false
            tabBtn.Parent = tabHolder

            local tabContent = Instance.new("Frame")
            tabContent.Size = UDim2.new(1, 0, 1, 0)
            tabContent.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
            tabContent.BorderSizePixel = 0
            tabContent.Visible = false
            tabContent.Parent = sectionScroll

            local contentLayout = Instance.new("UIListLayout")
            contentLayout.Padding = UDim.new(0, 6)
            contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
            contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            contentLayout.Parent = tabContent

            table.insert(tabContents, {btn = tabBtn, content = tabContent})
            if #tabContents == 1 then switchTab(tabBtn, tabContent) end

            tabBtn.MouseButton1Click:Connect(function()
                switchTab(tabBtn, tabContent)
            end)

            local function createSection(title)
                local sectionFrame = Instance.new("Frame")
                sectionFrame.Size = UDim2.new(1, -8, 0, 30)
                sectionFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 29)
                sectionFrame.BorderSizePixel = 0
                sectionFrame.Parent = tabContent
                Instance.new("UICorner", sectionFrame).CornerRadius = UDim.new(0, 8)
                Instance.new("UIStroke", sectionFrame).Color = Color3.fromRGB(40, 40, 46)

                local titleFrame = Instance.new("Frame")
                titleFrame.Size = UDim2.new(0, 80, 0, 8)
                titleFrame.Position = UDim2.new(0, 12, 0, 0)
                titleFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 29)
                titleFrame.BorderSizePixel = 0
                titleFrame.Parent = sectionFrame

                local titleLabel = Instance.new("TextLabel")
                titleLabel.Position = UDim2.new(0, 0, 0, -3)
                titleLabel.Size = UDim2.new(1, 0, 0, 8)
                titleLabel.BackgroundTransparency = 1
                titleLabel.Text = title
                titleLabel.TextColor3 = NexLib.accent
                titleLabel.Font = Enum.Font.GothamBold
                titleLabel.TextSize = 12
                titleLabel.TextXAlignment = Enum.TextXAlignment.Left
                titleLabel.Parent = titleFrame

                local itemHolder = Instance.new("Frame")
                itemHolder.Size = UDim2.new(1, -16, 0, 0)
                itemHolder.Position = UDim2.new(0, 8, 0, 16)
                itemHolder.BackgroundTransparency = 1
                itemHolder.Parent = sectionFrame

                local itemList = Instance.new("UIListLayout")
                itemList.Padding = UDim.new(0, 4)
                itemList.SortOrder = Enum.SortOrder.LayoutOrder
                itemList.Parent = itemHolder

                local function updateSection()
                    sectionFrame.Size = UDim2.new(1, -8, 0, itemList.AbsoluteContentSize.Y + 22)
                    updateScroll()
                end

                local sectionAPI = {}

                function sectionAPI:Toggle(name, default, callback)
                    local toggleFrame = Instance.new("TextButton")
                    toggleFrame.Size = UDim2.new(1, 0, 0, 24)
                    toggleFrame.BackgroundTransparency = 1
                    toggleFrame.Text = ""
                    toggleFrame.BorderSizePixel = 0
                    toggleFrame.AutoButtonColor = false
                    toggleFrame.Parent = itemHolder

                    local toggleLabel = Instance.new("TextLabel")
                    toggleLabel.Size = UDim2.new(0, 120, 1, 0)
                    toggleLabel.Position = UDim2.new(0, 0, 0, 0)
                    toggleLabel.BackgroundTransparency = 1
                    toggleLabel.Text = name
                    toggleLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
                    toggleLabel.Font = Enum.Font.GothamSemibold
                    toggleLabel.TextSize = 12
                    toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
                    toggleLabel.Parent = toggleFrame

                    local switchFrame = Instance.new("Frame")
                    switchFrame.Size = UDim2.new(0, 38, 0, 20)
                    switchFrame.Position = UDim2.new(1, -38, 0.5, -10)
                    switchFrame.BackgroundColor3 = default and NexLib.accent or Color3.fromRGB(35, 35, 40)
                    switchFrame.BorderSizePixel = 0
                    switchFrame.Parent = toggleFrame
                    Instance.new("UICorner", switchFrame).CornerRadius = UDim.new(0, 10)

                    local switchKnob = Instance.new("Frame")
                    switchKnob.Size = UDim2.new(0, 16, 0, 16)
                    switchKnob.Position = UDim2.new(default and 1 or 0, default and -19 or 3, 0.5, -8)
                    switchKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    switchKnob.BorderSizePixel = 0
                    switchKnob.Parent = switchFrame
                    Instance.new("UICorner", switchKnob).CornerRadius = UDim.new(0, 8)

                    local isOn = default

                    toggleFrame.MouseButton1Click:Connect(function()
                        isOn = not isOn
                        local tc = isOn and NexLib.accent or Color3.fromRGB(35, 35, 40)
                        local tp = isOn and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
                        TweenService:Create(switchFrame, TweenInfo.new(0.2), {BackgroundColor3 = tc}):Play()
                        TweenService:Create(switchKnob, TweenInfo.new(0.2), {Position = tp}):Play()
                        callback(isOn)
                    end)

                    updateSection()
                    return toggleFrame
                end

                function sectionAPI:Slider(name, defaultVal, minVal, maxVal, callback)
                    local sliderFrame = Instance.new("Frame")
                    sliderFrame.Size = UDim2.new(1, 0, 0, 40)
                    sliderFrame.BackgroundTransparency = 1
                    sliderFrame.Parent = itemHolder

                    local sliderLabel = Instance.new("TextLabel")
                    sliderLabel.Size = UDim2.new(1, 0, 0, 14)
                    sliderLabel.BackgroundTransparency = 1
                    sliderLabel.Text = name .. ": " .. tostring(defaultVal)
                    sliderLabel.TextColor3 = Color3.fromRGB(180, 180, 185)
                    sliderLabel.Font = Enum.Font.GothamSemibold
                    sliderLabel.TextSize = 11
                    sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
                    sliderLabel.Parent = sliderFrame

                    local sliderBar = Instance.new("Frame")
                    sliderBar.Size = UDim2.new(1, 0, 0, 20)
                    sliderBar.Position = UDim2.new(0, 0, 0, 18)
                    sliderBar.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
                    sliderBar.BorderSizePixel = 0
                    sliderBar.Parent = sliderFrame
                    Instance.new("UICorner", sliderBar).CornerRadius = UDim.new(0, 4)

                    local sliderFill = Instance.new("Frame")
                    local ratio = (defaultVal - minVal) / (maxVal - minVal)
                    sliderFill.Size = UDim2.new(ratio, 0, 1, 0)
                    sliderFill.BackgroundColor3 = NexLib.accent
                    sliderFill.BorderSizePixel = 0
                    sliderFill.Parent = sliderBar
                    Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(0, 4)

                    local sliderVal = Instance.new("TextLabel")
                    sliderVal.Size = UDim2.new(1, 0, 1, 0)
                    sliderVal.BackgroundTransparency = 1
                    sliderVal.Text = tostring(defaultVal)
                    sliderVal.TextColor3 = Color3.fromRGB(240, 240, 245)
                    sliderVal.Font = Enum.Font.GothamBold
                    sliderVal.TextSize = 11
                    sliderVal.Parent = sliderBar

                    local isSliding = false

                    local function updateSlider(input)
                        local mouseX = UserInputService:GetMouseLocation().X
                        local barStart = sliderBar.AbsolutePosition.X
                        local barWidth = sliderBar.AbsoluteSize.X
                        local ratio = math.clamp((mouseX - barStart) / barWidth, 0, 1)
                        sliderFill.Size = UDim2.new(ratio, 0, 1, 0)
                        local value = math.round((minVal + (maxVal - minVal) * ratio) * 100) / 100
                        sliderVal.Text = tostring(value)
                        sliderLabel.Text = name .. ": " .. tostring(value)
                        callback(value)
                    end

                    sliderBar.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            isSliding = true
                            updateSlider(input)
                        end
                    end)

                    sliderBar.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            isSliding = false
                        end
                    end)

                    UserInputService.InputChanged:Connect(function(input)
                        if isSliding and input.UserInputType == Enum.UserInputType.MouseMovement then
                            updateSlider(input)
                        end
                    end)

                    updateSection()
                end

                function sectionAPI:Label(text)
                    local label = Instance.new("TextLabel")
                    label.Size = UDim2.new(1, 0, 0, 18)
                    label.BackgroundTransparency = 1
                    label.Text = text
                    label.TextColor3 = Color3.fromRGB(160, 160, 170)
                    label.Font = Enum.Font.Gotham
                    label.TextSize = 11
                    label.TextXAlignment = Enum.TextXAlignment.Left
                    label.Parent = itemHolder
                    updateSection()
                end

                function sectionAPI:Button(text, callback)
                    local btn = Instance.new("TextButton")
                    btn.Size = UDim2.new(1, 0, 0, 24)
                    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
                    btn.Text = text
                    btn.TextColor3 = Color3.fromRGB(240, 240, 245)
                    btn.Font = Enum.Font.GothamBold
                    btn.TextSize = 12
                    btn.BorderSizePixel = 0
                    btn.AutoButtonColor = false
                    btn.Parent = itemHolder
                    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
                    Instance.new("UIStroke", btn).Color = Color3.fromRGB(45, 45, 52)

                    btn.MouseButton1Click:Connect(function()
                        callback()
                    end)

                    btn.MouseEnter:Connect(function()
                        btn.BorderSizePixel = 1
                        btn.BorderColor3 = NexLib.accent
                    end)
                    btn.MouseLeave:Connect(function()
                        btn.BorderSizePixel = 0
                    end)

                    updateSection()
                end

                return sectionAPI
            end

            return {
                createSection = createSection
            }
        end

        return {
            createTab = createTab,
            Notification = function(title, msg, dur) NexLib:Notification(title, msg, dur) end
        }
    end

    return NexLib
end

local NexLib = BuildUI()
local Window = NexLib:Window("ANDEPZAI HUB")

local CombatTab = Window:createTab("Combat")
local VisualsTab = Window:createTab("Visuals")
local SettingsTab = Window:createTab("Settings")

local aimSection = CombatTab:createSection("Aimbot")
aimSection:Toggle("Enable Aimbot", false, function(s)
    getgenv().AimbotEnabled = s
    if not s then getgenv().AimbotTarget = nil end
end)
aimSection:Slider("Smoothness", 0.3, 0.05, 1.0, function(v) getgenv().AimbotSmoothness = v end)
aimSection:Slider("FOV", 500, 100, 2000, function(v) getgenv().AimbotFOV = v end)
aimSection:Label("Right Click to lock target")

local espSection = VisualsTab:createSection("ESP")
espSection:Toggle("Enable ESP", false, function(s) getgenv().ESPEnabled = s end)
espSection:Slider("Max Distance", 5000, 500, 20000, function(v) getgenv().ESPDistance = v end)
espSection:Label("Green highlight + box on enemies")

local settingsSection = SettingsTab:createSection("Info")
settingsSection:Label("Andepzai Hub v2.0")
settingsSection:Label("Game: Rivals")
settingsSection:Label("Made with NexLib")
settingsSection:Button("Unload Script", function()
    ClearHighlights()
    ClearESPDrawings()
    pcall(function() HighlightFolder:Destroy() end)
    gui:Destroy()
end)

task.delay(0.5, function()
    NexLib:Notification("Andepzai Hub", "Loaded successfully!", 3)
end)