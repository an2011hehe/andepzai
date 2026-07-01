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

if not LocalPlayer.Character then
    LocalPlayer.CharacterAdded:Wait()
end
if not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
    LocalPlayer.Character:WaitForChild("HumanoidRootPart")
end

local HighlightFolder = Instance.new("Folder")
HighlightFolder.Name = "Andepzai_Chams"
HighlightFolder.Parent = Workspace

local ActiveChams = {}
local TracerLines = {}
local EnemyList = {}
local TeamSnapshot = {}

local function DestroyAllChams()
    for player, chamObject in pairs(ActiveChams) do
        pcall(function()
            chamObject:Destroy()
        end)
    end
    table.clear(ActiveChams)
end

local function ApplyChamToPlayer(player)
    if ActiveChams[player] then
        return
    end
    local character = player.Character
    if not character then
        return
    end
    local headPart = character:FindFirstChild("Head")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not headPart or not rootPart or not humanoid then
        return
    end
    if humanoid.Health <= 0 then
        return
    end
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.fromRGB(0, 255, 0)
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.fromRGB(0, 255, 0)
    highlight.OutlineTransparency = 0.2
    highlight.Adornee = character
    highlight.Parent = HighlightFolder
    ActiveChams[player] = highlight
end

local function RemoveChamFromPlayer(player)
    local cham = ActiveChams[player]
    if cham then
        cham:Destroy()
        ActiveChams[player] = nil
    end
end

local function DestroyAllTracers()
    for _, drawingObject in ipairs(TracerLines) do
        pcall(function()
            drawingObject:Remove()
        end)
    end
    table.clear(TracerLines)
end

local function GetPlayerTeamIdentifier(player)
    local teamIdentifier = nil
    pcall(function()
        teamIdentifier = player.Team
    end)
    if teamIdentifier then
        return teamIdentifier
    end
    pcall(function()
        teamIdentifier = player.TeamColor
    end)
    if teamIdentifier then
        return teamIdentifier
    end
    pcall(function()
        teamIdentifier = player:GetAttribute("Team")
    end)
    if teamIdentifier then
        return teamIdentifier
    end
    if player.Character then
        pcall(function()
            local teamFolder = player.Character:FindFirstChild("Team")
            if teamFolder and teamFolder:IsA("StringValue") then
                teamIdentifier = teamFolder.Value
            elseif teamFolder and teamFolder:IsA("Folder") then
                teamIdentifier = teamFolder.Name
            end
        end)
    end
    return teamIdentifier
end

local function RebuildTeamSnapshot()
    local myTeamID = GetPlayerTeamIdentifier(LocalPlayer)
    local freshSnapshot = {}
    local freshEnemyList = {}
    local allPlayers = Players:GetPlayers()
    for _, player in ipairs(allPlayers) do
        freshSnapshot[player] = GetPlayerTeamIdentifier(player)
    end
    for _, player in ipairs(allPlayers) do
        if player == LocalPlayer then
            freshEnemyList[player] = false
        else
            local theirTeamID = freshSnapshot[player]
            if myTeamID == nil or theirTeamID == nil then
                freshEnemyList[player] = true
            elseif myTeamID == theirTeamID then
                freshEnemyList[player] = false
            elseif type(myTeamID) == "string" and type(theirTeamID) == "string" then
                freshEnemyList[player] = (myTeamID:lower() ~= theirTeamID:lower())
            else
                freshEnemyList[player] = true
            end
        end
    end
    TeamSnapshot = freshSnapshot
    EnemyList = freshEnemyList
end

RebuildTeamSnapshot()

Players.PlayerAdded:Connect(function(addedPlayer)
    addedPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        RebuildTeamSnapshot()
    end)
end)

Players.PlayerRemoving:Connect(function(removedPlayer)
    EnemyList[removedPlayer] = nil
    TeamSnapshot[removedPlayer] = nil
    RemoveChamFromPlayer(removedPlayer)
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    RebuildTeamSnapshot()
end)

task.spawn(function()
    while task.wait(1) do
        RebuildTeamSnapshot()
    end
end)

local function IsPlayerEnemy(player)
    if player == LocalPlayer then
        return false
    end
    if EnemyList[player] == nil then
        return true
    end
    return EnemyList[player] == true
end

local function ScanForClosestEnemy()
    local myCharacter = LocalPlayer.Character
    if not myCharacter then
        return nil
    end
    local myRootPart = myCharacter:FindFirstChild("HumanoidRootPart")
    if not myRootPart then
        return nil
    end
    local myPosition = myRootPart.Position
    local closestEnemyPlayer = nil
    local closestDistance = math.huge
    local allPlayers = Players:GetPlayers()
    for _, player in ipairs(allPlayers) do
        if player == LocalPlayer then
            continue
        end
        if not IsPlayerEnemy(player) then
            continue
        end
        local character = player.Character
        if not character then
            continue
        end
        local headPart = character:FindFirstChild("Head")
        local humanoid = character:FindFirstChild("Humanoid")
        if not headPart or not humanoid then
            continue
        end
        if humanoid.Health <= 0 then
            continue
        end
        local distance = (headPart.Position - myPosition).Magnitude
        if distance < closestDistance then
            closestDistance = distance
            closestEnemyPlayer = player
        end
    end
    return closestEnemyPlayer
end

local function IsTargetStillValid(player)
    if not player then
        return false
    end
    if not IsPlayerEnemy(player) then
        return false
    end
    local character = player.Character
    if not character then
        return false
    end
    local headPart = character:FindFirstChild("Head")
    local humanoid = character:FindFirstChild("Humanoid")
    if not headPart or not humanoid then
        return false
    end
    if humanoid.Health <= 0 then
        return false
    end
    return true
end

local AimbotRenderConnection = RunService.RenderStepped:Connect(function(deltaTime)
    if not getgenv().AimbotEnabled then
        getgenv().AimbotTarget = nil
        return
    end

    local currentTarget = getgenv().AimbotTarget
    if not currentTarget or not IsTargetStillValid(currentTarget) then
        getgenv().AimbotTarget = ScanForClosestEnemy()
    end

    local targetToAim = getgenv().AimbotTarget
    if not targetToAim or not IsTargetStillValid(targetToAim) then
        getgenv().AimbotTarget = nil
        return
    end

    local targetHeadPosition = targetToAim.Character.Head.Position
    local cameraPosition = Camera.CFrame.Position
    local desiredLookVector = (targetHeadPosition - cameraPosition).Unit
    local currentLookVector = Camera.CFrame.LookVector
    local smoothFactor = math.clamp(getgenv().AimbotSmoothness, 0.1, 1.0)
    local blendedVector = (currentLookVector + (desiredLookVector - currentLookVector) * smoothFactor).Unit
    Camera.CFrame = CFrame.new(cameraPosition, cameraPosition + blendedVector)
end)

Mouse.Button2Down:Connect(function()
    if getgenv().AimbotEnabled then
        getgenv().AimbotTarget = ScanForClosestEnemy()
    end
end)

local ESPRenderConnection = RunService.RenderStepped:Connect(function()
    DestroyAllTracers()

    if not getgenv().ESPEnabled then
        DestroyAllChams()
        return
    end

    local myCharacter = LocalPlayer.Character
    local myRootPart = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")
    local allPlayers = Players:GetPlayers()

    for _, player in ipairs(allPlayers) do
        if player == LocalPlayer then
            continue
        end

        if not IsPlayerEnemy(player) then
            RemoveChamFromPlayer(player)
            continue
        end

        local character = player.Character
        if not character then
            RemoveChamFromPlayer(player)
            continue
        end

        local headPart = character:FindFirstChild("Head")
        local humanoid = character:FindFirstChild("Humanoid")
        if not headPart or not humanoid then
            RemoveChamFromPlayer(player)
            continue
        end
        if humanoid.Health <= 0 then
            RemoveChamFromPlayer(player)
            continue
        end

        ApplyChamToPlayer(player)

        if not myRootPart then
            continue
        end

        local headScreenPosition, headIsOnScreen = Camera:WorldToScreenPoint(headPart.Position)
        if not headIsOnScreen or headScreenPosition.Z <= 0 then
            continue
        end

        local myScreenPosition, myIsOnScreen = Camera:WorldToScreenPoint(myRootPart.Position)
        if not myIsOnScreen or myScreenPosition.Z <= 0 then
            continue
        end

        local tracerLine = Drawing.new("Line")
        tracerLine.From = Vector2.new(myScreenPosition.X, myScreenPosition.Y)
        tracerLine.To = Vector2.new(headScreenPosition.X, headScreenPosition.Y)
        tracerLine.Color = Color3.fromRGB(0, 255, 0)
        tracerLine.Thickness = 1
        tracerLine.Visible = true
        table.insert(TracerLines, tracerLine)
    end
end)

local function BuildGraphicalInterface()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AndepzaiHub"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = LocalPlayer.PlayerGui

    local mainContainer = Instance.new("Frame")
    mainContainer.Size = UDim2.new(0, 230, 0, 44)
    mainContainer.Position = UDim2.new(0, 15, 0, 200)
    mainContainer.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    mainContainer.BorderSizePixel = 0
    mainContainer.ClipsDescendants = true
    mainContainer.Active = true
    mainContainer.Draggable = true
    mainContainer.Parent = screenGui
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

    local toggleMenuButton = Instance.new("TextButton")
    toggleMenuButton.Size = UDim2.new(0, 28, 0, 24)
    toggleMenuButton.Position = UDim2.new(0, 8, 0.5, -12)
    toggleMenuButton.BackgroundColor3 = Color3.fromRGB(28, 28, 33)
    toggleMenuButton.Text = "☰"
    toggleMenuButton.TextColor3 = Color3.fromRGB(240, 240, 245)
    toggleMenuButton.Font = Enum.Font.GothamBold
    toggleMenuButton.TextSize = 14
    toggleMenuButton.BorderSizePixel = 0
    toggleMenuButton.AutoButtonColor = false
    toggleMenuButton.Parent = headerBar
    Instance.new("UICorner", toggleMenuButton).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", toggleMenuButton).Color = Color3.fromRGB(55, 55, 63)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0, 140, 1, 0)
    titleLabel.Position = UDim2.new(0, 44, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "ANDEPZAI HUB"
    titleLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
    titleLabel.Font = Enum.Font.GothamBlack
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = headerBar

    local exitButton = Instance.new("TextButton")
    exitButton.Size = UDim2.new(0, 28, 0, 24)
    exitButton.Position = UDim2.new(1, -36, 0.5, -12)
    exitButton.BackgroundColor3 = Color3.fromRGB(235, 55, 65)
    exitButton.Text = "✕"
    exitButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    exitButton.Font = Enum.Font.GothamBold
    exitButton.TextSize = 12
    exitButton.BorderSizePixel = 0
    exitButton.AutoButtonColor = false
    exitButton.Parent = headerBar
    Instance.new("UICorner", exitButton).CornerRadius = UDim.new(0, 6)

    exitButton.MouseButton1Click:Connect(function()
        AimbotRenderConnection:Disconnect()
        ESPRenderConnection:Disconnect()
        DestroyAllChams()
        DestroyAllTracers()
        pcall(function() HighlightFolder:Destroy() end)
        screenGui:Destroy()
    end)

    local settingsPanel = Instance.new("Frame")
    settingsPanel.Size = UDim2.new(0, 230, 0, 140)
    settingsPanel.Position = UDim2.new(0, 0, 0, 48)
    settingsPanel.BackgroundColor3 = Color3.fromRGB(16, 16, 19)
    settingsPanel.BorderSizePixel = 0
    settingsPanel.ClipsDescendants = true
    settingsPanel.Visible = false
    settingsPanel.Parent = mainContainer
    Instance.new("UICorner", settingsPanel).CornerRadius = UDim.new(0, 9)

    local scrollableContent = Instance.new("ScrollingFrame")
    scrollableContent.Size = UDim2.new(1, -14, 1, -10)
    scrollableContent.Position = UDim2.new(0, 7, 0, 5)
    scrollableContent.BackgroundColor3 = Color3.fromRGB(16, 16, 19)
    scrollableContent.BorderSizePixel = 0
    scrollableContent.ScrollBarThickness = 3
    scrollableContent.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 140)
    scrollableContent.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollableContent.Parent = settingsPanel

    local contentLayout = Instance.new("UIListLayout")
    contentLayout.Padding = UDim.new(0, 6)
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    contentLayout.Parent = scrollableContent

    local function recalculateCanvas()
        scrollableContent.CanvasSize = UDim2.new(0, 0, 0, contentLayout.AbsoluteContentSize.Y + 10)
    end

    local function createToggleComponent(featureName, defaultEnabled, toggleCallback)
        local toggleContainer = Instance.new("Frame")
        toggleContainer.Size = UDim2.new(1, -8, 0, 34)
        toggleContainer.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
        toggleContainer.BorderSizePixel = 0
        toggleContainer.Parent = scrollableContent
        Instance.new("UICorner", toggleContainer).CornerRadius = UDim.new(0, 8)
        Instance.new("UIStroke", toggleContainer).Color = Color3.fromRGB(40, 40, 46)

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0, 110, 1, 0)
        nameLabel.Position = UDim2.new(0, 14, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = featureName
        nameLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
        nameLabel.Font = Enum.Font.GothamSemibold
        nameLabel.TextSize = 12
        nameLabel.Parent = toggleContainer

        local switchFrame = Instance.new("TextButton")
        switchFrame.Size = UDim2.new(0, 42, 0, 22)
        switchFrame.Position = UDim2.new(1, -56, 0.5, -11)
        switchFrame.BackgroundColor3 = defaultEnabled and Color3.fromRGB(0, 230, 120) or Color3.fromRGB(30, 30, 36)
        switchFrame.Text = ""
        switchFrame.BorderSizePixel = 0
        switchFrame.AutoButtonColor = false
        switchFrame.Parent = toggleContainer
        Instance.new("UICorner", switchFrame).CornerRadius = UDim.new(0, 11)

        local switchKnob = Instance.new("Frame")
        switchKnob.Size = UDim2.new(0, 18, 0, 18)
        switchKnob.Position = UDim2.new(defaultEnabled and 1 or 0, defaultEnabled and -21 or 3, 0.5, -9)
        switchKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        switchKnob.BorderSizePixel = 0
        switchKnob.Parent = switchFrame
        Instance.new("UICorner", switchKnob).CornerRadius = UDim.new(0, 9)

        local isFeatureOn = defaultEnabled
        switchFrame.MouseButton1Click:Connect(function()
            isFeatureOn = not isFeatureOn
            local knobTargetPosition = isFeatureOn and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
            local frameTargetColor = isFeatureOn and Color3.fromRGB(0, 230, 120) or Color3.fromRGB(30, 30, 36)
            TweenService:Create(switchFrame, TweenInfo.new(0.2), {BackgroundColor3 = frameTargetColor}):Play()
            TweenService:Create(switchKnob, TweenInfo.new(0.2), {Position = knobTargetPosition}):Play()
            toggleCallback(isFeatureOn)
        end)
        recalculateCanvas()
    end

    local function createSliderComponent(sliderName, defaultValue, minValue, maxValue, sliderCallback)
        local sliderContainer = Instance.new("Frame")
        sliderContainer.Size = UDim2.new(1, -8, 0, 50)
        sliderContainer.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
        sliderContainer.BorderSizePixel = 0
        sliderContainer.Parent = scrollableContent
        Instance.new("UICorner", sliderContainer).CornerRadius = UDim.new(0, 8)
        Instance.new("UIStroke", sliderContainer).Color = Color3.fromRGB(40, 40, 46)

        local sliderLabel = Instance.new("TextLabel")
        sliderLabel.Size = UDim2.new(1, -20, 0, 18)
        sliderLabel.Position = UDim2.new(0, 10, 0, 4)
        sliderLabel.BackgroundTransparency = 1
        sliderLabel.Text = sliderName .. ": " .. tostring(defaultValue)
        sliderLabel.TextColor3 = Color3.fromRGB(170, 170, 180)
        sliderLabel.Font = Enum.Font.GothamSemibold
        sliderLabel.TextSize = 11
        sliderLabel.Parent = sliderContainer

        local inputField = Instance.new("TextBox")
        inputField.Size = UDim2.new(1, -20, 0, 26)
        inputField.Position = UDim2.new(0, 10, 0, 24)
        inputField.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
        inputField.Text = tostring(defaultValue)
        inputField.TextColor3 = Color3.fromRGB(240, 240, 245)
        inputField.Font = Enum.Font.Gotham
        inputField.TextSize = 11
        inputField.BorderSizePixel = 0
        inputField.Parent = sliderContainer
        Instance.new("UICorner", inputField).CornerRadius = UDim.new(0, 5)
        Instance.new("UIStroke", inputField).Color = Color3.fromRGB(45, 45, 52)

        inputField.FocusLost:Connect(function()
            local numericValue = tonumber(inputField.Text)
            if numericValue and numericValue >= minValue and numericValue <= maxValue then
                sliderCallback(numericValue)
                sliderLabel.Text = sliderName .. ": " .. tostring(numericValue)
            else
                inputField.Text = tostring(defaultValue)
            end
        end)
        recalculateCanvas()
    end

    createToggleComponent("Aimbot", false, function(isEnabled)
        getgenv().AimbotEnabled = isEnabled
        if not isEnabled then
            getgenv().AimbotTarget = nil
        end
    end)
    createToggleComponent("Player ESP", false, function(isEnabled)
        getgenv().ESPEnabled = isEnabled
    end)
    createSliderComponent("Smoothness", 0.5, 0.1, 1.0, function(newValue)
        getgenv().AimbotSmoothness = newValue
    end)
    recalculateCanvas()

    local isMenuVisible = false
    toggleMenuButton.MouseButton1Click:Connect(function()
        isMenuVisible = not isMenuVisible
        if isMenuVisible then
            settingsPanel.Visible = true
            TweenService:Create(mainContainer, TweenInfo.new(0.25), {Size = UDim2.new(0, 230, 0, 198)}):Play()
            toggleMenuButton.Text = "−"
            toggleMenuButton.BackgroundColor3 = Color3.fromRGB(0, 230, 120)
            toggleMenuButton.TextColor3 = Color3.fromRGB(10, 10, 12)
        else
            TweenService:Create(mainContainer, TweenInfo.new(0.2), {Size = UDim2.new(0, 230, 0, 44)}):Play()
            task.wait(0.2)
            settingsPanel.Visible = false
            toggleMenuButton.Text = "☰"
            toggleMenuButton.BackgroundColor3 = Color3.fromRGB(28, 28, 33)
            toggleMenuButton.TextColor3 = Color3.fromRGB(240, 240, 245)
        end
    end)

    return screenGui
end

local GUI = BuildGraphicalInterface()

GUI.Destroying:Connect(function()
    AimbotRenderConnection:Disconnect()
    ESPRenderConnection:Disconnect()
    DestroyAllChams()
    DestroyAllTracers()
    pcall(function() HighlightFolder:Destroy() end)
end)