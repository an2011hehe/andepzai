getgenv().AimbotEnabled = false
getgenv().ESPEnabled = false
getgenv().AimbotSmoothness = 0.5
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

local function ClearAllHighlights()
    for plr, hl in pairs(ActiveHighlights) do
        pcall(function() hl:Destroy() end)
    end
    ActiveHighlights = {}
end

local function CreateHighlightForPlayer(plr)
    if ActiveHighlights[plr] then return end
    local char = plr.Character
    if not char then return end
    if not char:FindFirstChild("Head") then return end
    if not char:FindFirstChild("HumanoidRootPart") then return end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_" .. plr.Name
    highlight.FillColor = Color3.fromRGB(0, 255, 0)
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.fromRGB(0, 255, 0)
    highlight.OutlineTransparency = 0.2
    highlight.Adornee = char
    highlight.Parent = HighlightFolder
    ActiveHighlights[plr] = highlight
end

local function RemoveHighlightForPlayer(plr)
    if ActiveHighlights[plr] then
        pcall(function() ActiveHighlights[plr]:Destroy() end)
        ActiveHighlights[plr] = nil
    end
end

local TeamCache = {}

local function ScanPlayerTeam(plr)
    if TeamCache[plr] ~= nil then return TeamCache[plr] end

    local teamIdentifier = nil

    pcall(function()
        if plr:FindFirstChild("Team") then
            local teamObj = plr.Team
            if type(teamObj) == "string" then teamIdentifier = teamObj
            elseif typeof(teamObj) == "Instance" then teamIdentifier = teamObj.Name or tostring(teamObj) end
        end
    end)
    if teamIdentifier then TeamCache[plr] = teamIdentifier return teamIdentifier end

    pcall(function()
        if plr:FindFirstChild("TeamColor") then
            teamIdentifier = plr.TeamColor
        end
    end)
    if teamIdentifier then TeamCache[plr] = teamIdentifier return teamIdentifier end

    pcall(function()
        local attr = plr:GetAttribute("Team")
        if attr then teamIdentifier = attr end
    end)
    if teamIdentifier then TeamCache[plr] = teamIdentifier return teamIdentifier end

    if plr.Character then
        local char = plr.Character
        pcall(function()
            local teamFolder = char:FindFirstChild("Team")
            if teamFolder then
                if teamFolder:IsA("StringValue") then teamIdentifier = teamFolder.Value
                elseif teamFolder:IsA("Folder") then teamIdentifier = teamFolder.Name end
            end
        end)
        if teamIdentifier then TeamCache[plr] = teamIdentifier return teamIdentifier end

        pcall(function()
            local bodyColors = char:FindFirstChild("BodyColors")
            if bodyColors and bodyColors.TorsoColor3 then
                teamIdentifier = bodyColors.TorsoColor3
            end
        end)
        if teamIdentifier then TeamCache[plr] = teamIdentifier return teamIdentifier end

        pcall(function()
            local head = char:FindFirstChild("Head")
            if head then
                for _, child in ipairs(head:GetChildren()) do
                    if child:IsA("Decal") and child.Color3 then
                        teamIdentifier = child.Color3
                        break
                    end
                end
            end
        end)
        if teamIdentifier then TeamCache[plr] = teamIdentifier return teamIdentifier end

        pcall(function()
            for _, child in ipairs(char:GetChildren()) do
                if child:IsA("BillboardGui") then
                    for _, element in ipairs(child:GetChildren()) do
                        if element:IsA("TextLabel") and element.Text ~= "" then
                            teamIdentifier = element.Text:lower()
                            break
                        end
                    end
                end
                if teamIdentifier then break end
            end
        end)
        if teamIdentifier then TeamCache[plr] = teamIdentifier return teamIdentifier end
    end

    TeamCache[plr] = nil
    return nil
end

local function RefreshAllTeams()
    local newCache = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        newCache[plr] = ScanPlayerTeam(plr)
    end
    TeamCache = newCache
end
RefreshAllTeams()

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        task.wait(1)
        TeamCache[plr] = ScanPlayerTeam(plr)
    end)
end)

Players.PlayerRemoving:Connect(function(plr)
    TeamCache[plr] = nil
    RemoveHighlightForPlayer(plr)
end)

task.spawn(function()
    while task.wait(3) do
        RefreshAllTeams()
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    RefreshAllTeams()
end)

local function IsPlayerEnemy(plr)
    if plr == LocalPlayer then return false end
    local myTeam = TeamCache[LocalPlayer]
    local theirTeam = TeamCache[plr]
    if myTeam == nil or theirTeam == nil then return true end
    if myTeam == theirTeam then return false end
    if type(myTeam) == "string" and type(theirTeam) == "string" then
        return myTeam:lower() ~= theirTeam:lower()
    end
    if typeof(myTeam) == "Color3" and typeof(theirTeam) == "Color3" then
        return myTeam ~= theirTeam
    end
    return true
end

local function GetClosestEnemyPlayer()
    local myChar = LocalPlayer.Character
    if not myChar then return nil end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    local myPos = myRoot.Position
    local closestPlayer = nil
    local closestDist = math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if not IsPlayerEnemy(plr) then continue end
        local char = plr.Character
        if not char then continue end
        local head = char:FindFirstChild("Head")
        if not head then continue end
        local humanoid = char:FindFirstChild("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end

        local dist = (head.Position - myPos).Magnitude
        if dist < closestDist then
            closestDist = dist
            closestPlayer = plr
        end
    end

    return closestPlayer
end

local function IsTargetValid(plr)
    if not plr then return false end
    if not IsPlayerEnemy(plr) then return false end
    local char = plr.Character
    if not char then return false end
    if not char:FindFirstChild("Head") then return false end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    return true
end

local AimbotConnection
AimbotConnection = RunService.RenderStepped:Connect(function(deltaTime)
    if not getgenv().AimbotEnabled then
        getgenv().AimbotTarget = nil
        return
    end

    if not getgenv().AimbotTarget or not IsTargetValid(getgenv().AimbotTarget) then
        getgenv().AimbotTarget = GetClosestEnemyPlayer()
    end

    local target = getgenv().AimbotTarget
    if not target or not IsTargetValid(target) then
        getgenv().AimbotTarget = nil
        return
    end

    local headPosition = target.Character.Head.Position
    local cameraPosition = Camera.CFrame.Position
    local targetDirection = (headPosition - cameraPosition).Unit
    local currentDirection = Camera.CFrame.LookVector
    local smoothness = math.clamp(getgenv().AimbotSmoothness, 0.1, 1.0)
    local interpolationFactor = math.min(smoothness * deltaTime * 60, 1)
    local newDirection = (currentDirection + (targetDirection - currentDirection) * interpolationFactor).Unit
    Camera.CFrame = CFrame.new(cameraPosition, cameraPosition + newDirection)
end)

Mouse.Button2Down:Connect(function()
    if getgenv().AimbotEnabled then
        getgenv().AimbotTarget = GetClosestEnemyPlayer()
    end
end)

local ESPDrawings = {}

local function ClearAllESPDrawings()
    for _, drawing in ipairs(ESPDrawings) do
        pcall(function() drawing:Remove() end)
    end
    ESPDrawings = {}
end

local function DrawCornerBox(x1, y1, x2, y2, color, thickness)
    local boxHeight = math.abs(y2 - y1)
    local cornerLength = math.clamp(boxHeight * 0.22, 6, 18)

    local corners = {
        {x1, y1, x1, y1 + cornerLength},
        {x1, y1, x1 + cornerLength, y1},
        {x2, y1, x2, y1 + cornerLength},
        {x2, y1, x2 - cornerLength, y1},
        {x1, y2, x1, y2 - cornerLength},
        {x1, y2, x1 + cornerLength, y2},
        {x2, y2, x2, y2 - cornerLength},
        {x2, y2, x2 - cornerLength, y2},
    }

    for _, corner in ipairs(corners) do
        local line = Drawing.new("Line")
        line.From = Vector2.new(corner[1], corner[2])
        line.To = Vector2.new(corner[3], corner[4])
        line.Color = color
        line.Thickness = thickness
        line.Visible = true
        table.insert(ESPDrawings, line)
    end
end

local function DrawESPText(text, x, y, size, color)
    local textDrawing = Drawing.new("Text")
    textDrawing.Text = text
    textDrawing.Position = Vector2.new(x, y)
    textDrawing.Size = size
    textDrawing.Color = color
    textDrawing.Center = true
    textDrawing.Outline = true
    textDrawing.OutlineColor = Color3.new(0, 0, 0)
    textDrawing.Visible = true
    table.insert(ESPDrawings, textDrawing)
end

local function DrawTracerLine(fromX, fromY, toX, toY, color, thickness)
    local line = Drawing.new("Line")
    line.From = Vector2.new(fromX, fromY)
    line.To = Vector2.new(toX, toY)
    line.Color = color
    line.Thickness = thickness
    line.Visible = true
    table.insert(ESPDrawings, line)
end

local ESPConnection
ESPConnection = RunService.RenderStepped:Connect(function()
    ClearAllESPDrawings()

    if not getgenv().ESPEnabled then return end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local screenCenterX = Camera.ViewportSize.X / 2
    local screenCenterY = Camera.ViewportSize.Y / 2

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if not IsPlayerEnemy(plr) then continue end

        local char = plr.Character
        if not char then continue end

        local head = char:FindFirstChild("Head")
        local root = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")

        if not head or not root or not humanoid then continue end
        if humanoid.Health <= 0 then continue end

        local topPos = head.Position + Vector3.new(0, 0.7, 0)
        local bottomPos = root.Position - Vector3.new(0, 3.0, 0)

        local topScreen, topOnScreen = Camera:WorldToScreenPoint(topPos)
        local bottomScreen, bottomOnScreen = Camera:WorldToScreenPoint(bottomPos)
        local headScreen, headOnScreen = Camera:WorldToScreenPoint(head.Position)

        if not topOnScreen or not bottomOnScreen or topScreen.Z <= 0 or bottomScreen.Z <= 0 then continue end

        local boxHeight = math.abs(bottomScreen.Y - topScreen.Y)
        local boxWidth = boxHeight * 0.65
        local centerX = (topScreen.X + bottomScreen.X) / 2
        local left = centerX - boxWidth / 2
        local right = centerX + boxWidth / 2
        local top = topScreen.Y
        local bottom = bottomScreen.Y

        DrawCornerBox(left, top, right, bottom, Color3.fromRGB(0, 255, 0), 1.8)

        local distance = myRoot and math.floor((myRoot.Position - root.Position).Magnitude) or 0
        DrawESPText(plr.DisplayName .. " [" .. distance .. "m]", centerX, top - 14, 13, Color3.new(1, 1, 1))

        if myRoot and headOnScreen and headScreen.Z > 0 then
            local myScreenPos, myOnScreen = Camera:WorldToScreenPoint(myRoot.Position)
            if myOnScreen and myScreenPos.Z > 0 then
                DrawTracerLine(myScreenPos.X, myScreenPos.Y, headScreen.X, headScreen.Y, Color3.fromRGB(0, 255, 0), 1)
            end
        end
    end
end)

local function UpdateHighlightsLoop()
    while task.wait(0.2) do
        if not getgenv().ESPEnabled then
            ClearAllHighlights()
            continue
        end

        local playersToRemove = {}
        for plr, hl in pairs(ActiveHighlights) do
            local char = plr.Character
            if not char or char ~= hl.Adornee then
                pcall(function() hl:Destroy() end)
                table.insert(playersToRemove, plr)
                continue
            end
            local humanoid = char:FindFirstChild("Humanoid")
            if not humanoid or humanoid.Health <= 0 then
                pcall(function() hl:Destroy() end)
                table.insert(playersToRemove, plr)
            end
        end

        for _, plr in ipairs(playersToRemove) do
            ActiveHighlights[plr] = nil
        end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer then continue end
            if not IsPlayerEnemy(plr) then
                RemoveHighlightForPlayer(plr)
                continue
            end
            if plr.Character then
                local humanoid = plr.Character:FindFirstChild("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    CreateHighlightForPlayer(plr)
                else
                    RemoveHighlightForPlayer(plr)
                end
            else
                RemoveHighlightForPlayer(plr)
            end
        end
    end
end

task.spawn(UpdateHighlightsLoop)

local function BuildUserInterface()
    local gui = Instance.new("ScreenGui")
    gui.Name = "AndepzaiHub"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = LocalPlayer.PlayerGui

    local mainContainer = Instance.new("Frame")
    mainContainer.Size = UDim2.new(0, 230, 0, 44)
    mainContainer.Position = UDim2.new(0, 15, 0, 200)
    mainContainer.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    mainContainer.BorderSizePixel = 0
    mainContainer.ClipsDescendants = true
    mainContainer.Active = true
    mainContainer.Draggable = true
    mainContainer.Parent = gui

    Instance.new("UICorner", mainContainer).CornerRadius = UDim.new(0, 9)
    Instance.new("UIStroke", mainContainer).Color = Color3.fromRGB(50, 50, 58)

    local headerBar = Instance.new("Frame")
    headerBar.Size = UDim2.new(1, 0, 0, 44)
    headerBar.BackgroundColor3 = Color3.fromRGB(16, 16, 19)
    headerBar.BorderSizePixel = 0
    headerBar.Parent = mainContainer
    Instance.new("UICorner", headerBar).CornerRadius = UDim.new(0, 9)

    local accentLine = Instance.new("Frame")
    accentLine.Size = UDim2.new(1, 0, 0, 2)
    accentLine.Position = UDim2.new(0, 0, 1, -2)
    accentLine.BackgroundColor3 = Color3.fromRGB(0, 255, 140)
    accentLine.BorderSizePixel = 0
    accentLine.Parent = headerBar

    local menuButton = Instance.new("TextButton")
    menuButton.Size = UDim2.new(0, 30, 0, 26)
    menuButton.Position = UDim2.new(0, 8, 0.5, -13)
    menuButton.BackgroundColor3 = Color3.fromRGB(28, 28, 33)
    menuButton.Text = "☰"
    menuButton.TextColor3 = Color3.fromRGB(240, 240, 245)
    menuButton.Font = Enum.Font.GothamBold
    menuButton.TextSize = 14
    menuButton.BorderSizePixel = 0
    menuButton.AutoButtonColor = false
    menuButton.Parent = headerBar
    Instance.new("UICorner", menuButton).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", menuButton).Color = Color3.fromRGB(55, 55, 63)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0, 140, 1, 0)
    titleLabel.Position = UDim2.new(0, 46, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "ANDEPZAI HUB"
    titleLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
    titleLabel.Font = Enum.Font.GothamBlack
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = headerBar

    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 30, 0, 26)
    closeButton.Position = UDim2.new(1, -38, 0.5, -13)
    closeButton.BackgroundColor3 = Color3.fromRGB(235, 55, 65)
    closeButton.Text = "✕"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 12
    closeButton.BorderSizePixel = 0
    closeButton.AutoButtonColor = false
    closeButton.Parent = headerBar
    Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 6)

    closeButton.MouseButton1Click:Connect(function()
        ClearAllHighlights()
        ClearAllESPDrawings()
        pcall(function() HighlightFolder:Destroy() end)
        if AimbotConnection then AimbotConnection:Disconnect() end
        if ESPConnection then ESPConnection:Disconnect() end
        gui:Destroy()
    end)

    local contentPanel = Instance.new("Frame")
    contentPanel.Size = UDim2.new(0, 230, 0, 170)
    contentPanel.Position = UDim2.new(0, 0, 0, 48)
    contentPanel.BackgroundColor3 = Color3.fromRGB(16, 16, 19)
    contentPanel.BorderSizePixel = 0
    contentPanel.ClipsDescendants = true
    contentPanel.Visible = false
    contentPanel.Parent = mainContainer
    Instance.new("UICorner", contentPanel).CornerRadius = UDim.new(0, 9)

    local contentScroll = Instance.new("ScrollingFrame")
    contentScroll.Size = UDim2.new(1, -14, 1, -10)
    contentScroll.Position = UDim2.new(0, 7, 0, 5)
    contentScroll.BackgroundColor3 = Color3.fromRGB(16, 16, 19)
    contentScroll.BorderSizePixel = 0
    contentScroll.ScrollBarThickness = 3
    contentScroll.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 140)
    contentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    contentScroll.ScrollingDirection = Enum.ScrollingDirection.Y
    contentScroll.Parent = contentPanel

    local contentList = Instance.new("UIListLayout")
    contentList.Padding = UDim.new(0, 6)
    contentList.SortOrder = Enum.SortOrder.LayoutOrder
    contentList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    contentList.Parent = contentScroll

    local function UpdateScrollCanvas()
        contentScroll.CanvasSize = UDim2.new(0, 0, 0, contentList.AbsoluteContentSize.Y + 10)
    end

    local function CreateToggleComponent(name, defaultState, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -8, 0, 36)
        container.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
        container.BorderSizePixel = 0
        container.Parent = contentScroll
        Instance.new("UICorner", container).CornerRadius = UDim.new(0, 8)
        Instance.new("UIStroke", container).Color = Color3.fromRGB(40, 40, 46)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, 110, 1, 0)
        label.Position = UDim2.new(0, 14, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.fromRGB(240, 240, 245)
        label.Font = Enum.Font.GothamSemibold
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = container

        local switchFrame = Instance.new("TextButton")
        switchFrame.Size = UDim2.new(0, 44, 0, 22)
        switchFrame.Position = UDim2.new(1, -58, 0.5, -11)
        switchFrame.BackgroundColor3 = defaultState and Color3.fromRGB(0, 230, 120) or Color3.fromRGB(30, 30, 36)
        switchFrame.Text = ""
        switchFrame.BorderSizePixel = 0
        switchFrame.AutoButtonColor = false
        switchFrame.Parent = container
        Instance.new("UICorner", switchFrame).CornerRadius = UDim.new(0, 11)

        local switchKnob = Instance.new("Frame")
        switchKnob.Size = UDim2.new(0, 18, 0, 18)
        switchKnob.Position = UDim2.new(defaultState and 1 or 0, defaultState and -21 or 3, 0.5, -9)
        switchKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        switchKnob.BorderSizePixel = 0
        switchKnob.Parent = switchFrame
        Instance.new("UICorner", switchKnob).CornerRadius = UDim.new(0, 9)

        local isOn = defaultState

        local function AnimateSwitch(state)
            isOn = state
            local targetColor = state and Color3.fromRGB(0, 230, 120) or Color3.fromRGB(30, 30, 36)
            local targetPos = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)

            local colorTween = TweenService:Create(switchFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {BackgroundColor3 = targetColor})
            colorTween:Play()

            local posTween = TweenService:Create(switchKnob, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {Position = targetPos})
            posTween:Play()
        end

        switchFrame.MouseButton1Click:Connect(function()
            isOn = not isOn
            AnimateSwitch(isOn)
            callback(isOn)
        end)

        UpdateScrollCanvas()
        return container
    end

    local function CreateSliderComponent(name, defaultVal, minVal, maxVal, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -8, 0, 54)
        container.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
        container.BorderSizePixel = 0
        container.Parent = contentScroll
        Instance.new("UICorner", container).CornerRadius = UDim.new(0, 8)
        Instance.new("UIStroke", container).Color = Color3.fromRGB(40, 40, 46)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -20, 0, 20)
        label.Position = UDim2.new(0, 10, 0, 5)
        label.BackgroundTransparency = 1
        label.Text = name .. ": " .. tostring(defaultVal)
        label.TextColor3 = Color3.fromRGB(170, 170, 180)
        label.Font = Enum.Font.GothamSemibold
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = container

        local inputBox = Instance.new("TextBox")
        inputBox.Size = UDim2.new(1, -20, 0, 26)
        inputBox.Position = UDim2.new(0, 10, 0, 26)
        inputBox.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
        inputBox.Text = tostring(defaultVal)
        inputBox.PlaceholderText = tostring(minVal) .. " - " .. tostring(maxVal)
        inputBox.TextColor3 = Color3.fromRGB(240, 240, 245)
        inputBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
        inputBox.Font = Enum.Font.Gotham
        inputBox.TextSize = 11
        inputBox.BorderSizePixel = 0
        inputBox.Parent = container
        Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0, 5)
        Instance.new("UIStroke", inputBox).Color = Color3.fromRGB(45, 45, 52)

        inputBox.FocusLost:Connect(function()
            local num = tonumber(inputBox.Text)
            if num and num >= minVal and num <= maxVal then
                callback(num)
                label.Text = name .. ": " .. tostring(num)
            else
                inputBox.Text = tostring(defaultVal)
            end
        end)

        UpdateScrollCanvas()
        return container
    end

    CreateToggleComponent("Aimbot", false, function(state)
        getgenv().AimbotEnabled = state
        if not state then getgenv().AimbotTarget = nil end
    end)

    CreateToggleComponent("Player ESP", false, function(state)
        getgenv().ESPEnabled = state
    end)

    CreateSliderComponent("Aim Smoothness", 0.5, 0.1, 1.0, function(value)
        getgenv().AimbotSmoothness = value
    end)

    UpdateScrollCanvas()

    local menuOpen = false
    local function ToggleMenu()
        menuOpen = not menuOpen
        if menuOpen then
            contentPanel.Visible = true
            local expandTween = TweenService:Create(mainContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 230, 0, 230)
            })
            expandTween:Play()
            menuButton.Text = "−"
            menuButton.BackgroundColor3 = Color3.fromRGB(0, 230, 120)
            menuButton.TextColor3 = Color3.fromRGB(10, 10, 12)
            UpdateScrollCanvas()
        else
            local collapseTween = TweenService:Create(mainContainer, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 230, 0, 44)
            })
            collapseTween:Play()
            task.wait(0.25)
            contentPanel.Visible = false
            menuButton.Text = "☰"
            menuButton.BackgroundColor3 = Color3.fromRGB(28, 28, 33)
            menuButton.TextColor3 = Color3.fromRGB(240, 240, 245)
        end
    end

    menuButton.MouseButton1Click:Connect(ToggleMenu)

    return gui
end

local GUI = BuildUserInterface()

GUI.Destroying:Connect(function()
    RunService:UnbindFromRenderStep("AndepzaiAimbot")
    RunService:UnbindFromRenderStep("AndepzaiESP")
    ClearAllHighlights()
    ClearAllESPDrawings()
    pcall(function() HighlightFolder:Destroy() end)
    if AimbotConnection then AimbotConnection:Disconnect() end
    if ESPConnection then ESPConnection:Disconnect() end
end)

task.spawn(function()
    while task.wait(30) do
        collectgarbage("collect")
    end
end)

print("Andepzai Hub vFinal loaded successfully.")