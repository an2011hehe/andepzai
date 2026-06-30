getgenv().AimbotEnabled = false
getgenv().ESPEnabled = false
getgenv().AimbotSmoothness = 0.5
getgenv().AimbotTarget = nil
getgenv().AimbotFOV = 500
getgenv().ESPDistance = 5000
getgenv().TeamCheckEnabled = true
getgenv().VisibleCheckEnabled = false

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Teams = game:GetService("Teams")

repeat
    task.wait()
until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

local HighlightFolder = Instance.new("Folder")
HighlightFolder.Name = "Andepzai_Highlights"
HighlightFolder.Parent = Workspace

local ActiveHighlights = {}
local TeamIdentifierCache = {}
local ESPDrawings = {}
local AimbotConnection = nil
local ESPConnection = nil

local function ClearAllHighlights()
    for plr, hl in pairs(ActiveHighlights) do
        pcall(function() hl:Destroy() end)
    end
    table.clear(ActiveHighlights)
end

local function CreateHighlightForPlayer(plr)
    if ActiveHighlights[plr] then
        return
    end
    
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

local function ExtractTeamFromPlayer(plr)
    if TeamIdentifierCache[plr] ~= nil then
        return TeamIdentifierCache[plr]
    end

    local teamData = nil

    pcall(function()
        if plr.Team ~= nil then
            teamData = plr.Team
        end
    end)

    if teamData == nil then
        pcall(function()
            if plr.TeamColor ~= nil then
                teamData = plr.TeamColor
            end
        end)
    end

    if teamData == nil then
        pcall(function()
            local attributeValue = plr:GetAttribute("Team")
            if attributeValue ~= nil then
                teamData = attributeValue
            end
        end)
    end

    if teamData == nil and plr.Character ~= nil then
        local character = plr.Character

        pcall(function()
            local teamFolder = character:FindFirstChild("Team")
            if teamFolder ~= nil then
                if teamFolder:IsA("StringValue") then
                    teamData = teamFolder.Value
                elseif teamFolder:IsA("Folder") then
                    teamData = teamFolder.Name
                elseif teamFolder:IsA("ObjectValue") and teamFolder.Value ~= nil then
                    teamData = tostring(teamFolder.Value)
                end
            end
        end)

        if teamData == nil then
            pcall(function()
                local bodyColors = character:FindFirstChild("BodyColors")
                if bodyColors ~= nil and bodyColors.TorsoColor3 ~= nil then
                    teamData = bodyColors.TorsoColor3
                end
            end)
        end

        if teamData == nil then
            pcall(function()
                local head = character:FindFirstChild("Head")
                if head ~= nil then
                    for _, child in ipairs(head:GetChildren()) do
                        if child:IsA("Decal") and child.Color3 ~= nil then
                            teamData = child.Color3
                            break
                        end
                    end
                end
            end)
        end

        if teamData == nil then
            pcall(function()
                for _, child in ipairs(character:GetChildren()) do
                    if child:IsA("BillboardGui") then
                        for _, element in ipairs(child:GetChildren()) do
                            if element:IsA("TextLabel") and element.Text ~= "" then
                                teamData = element.Text:lower()
                                break
                            end
                        end
                    end
                    if teamData ~= nil then break end
                end
            end)
        end

        if teamData == nil then
            pcall(function()
                local shirt = character:FindFirstChild("Shirt")
                if shirt ~= nil and shirt.ShirtTemplate ~= nil then
                    local template = shirt.ShirtTemplate:lower()
                    if template:find("red") then
                        teamData = "red"
                    elseif template:find("blue") then
                        teamData = "blue"
                    elseif template:find("green") then
                        teamData = "green"
                    elseif template:find("yellow") then
                        teamData = "yellow"
                    end
                end
            end)
        end
    end

    TeamIdentifierCache[plr] = teamData
    return teamData
end

local function ArePlayersOnSameTeam(playerA, playerB)
    if playerA == playerB then
        return true
    end

    local teamA = ExtractTeamFromPlayer(playerA)
    local teamB = ExtractTeamFromPlayer(playerB)

    if teamA == nil and teamB == nil then
        return false
    end

    if teamA == nil or teamB == nil then
        return false
    end

    if teamA == teamB then
        return true
    end

    if type(teamA) == "string" and type(teamB) == "string" then
        return teamA:lower() == teamB:lower()
    end

    if typeof(teamA) == "Color3" and typeof(teamB) == "Color3" then
        return teamA == teamB
    end

    if typeof(teamA) == "Instance" and typeof(teamB) == "Instance" then
        return teamA == teamB
    end

    if typeof(teamA) == "Instance" and type(teamB) == "string" then
        return tostring(teamA):lower() == teamB:lower()
    end

    if type(teamA) == "string" and typeof(teamB) == "Instance" then
        return teamA:lower() == tostring(teamB):lower()
    end

    return false
end

local function IsPlayerOnLocalTeam(plr)
    if plr == LocalPlayer then
        return true
    end
    return ArePlayersOnSameTeam(LocalPlayer, plr)
end

local function IsPlayerEnemy(plr)
    if plr == LocalPlayer then
        return false
    end
    
    if not getgenv().TeamCheckEnabled then
        return true
    end
    
    if IsPlayerOnLocalTeam(plr) then
        return false
    end
    
    return true
end

local function IsTargetVisible(targetPart)
    if not getgenv().VisibleCheckEnabled then
        return true
    end
    
    local cameraPos = Camera.CFrame.Position
    local direction = (targetPart.Position - cameraPos).Unit * 5000
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    
    local raycastResult = Workspace:Raycast(cameraPos, direction, raycastParams)
    
    if raycastResult == nil then
        return true
    end
    
    return raycastResult.Instance:IsDescendantOf(targetPart.Parent)
end

local function RefreshAllTeamData()
    local freshCache = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        freshCache[plr] = ExtractTeamFromPlayer(plr)
    end
    TeamIdentifierCache = freshCache
end

RefreshAllTeamData()

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        task.wait(1)
        TeamIdentifierCache[plr] = ExtractTeamFromPlayer(plr)
        RefreshAllTeamData()
    end)
end)

Players.PlayerRemoving:Connect(function(plr)
    TeamIdentifierCache[plr] = nil
    RemoveHighlightForPlayer(plr)
end)

task.spawn(function()
    while task.wait(2) do
        RefreshAllTeamData()
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    RefreshAllTeamData()
end)

local function ScanForClosestEnemy()
    local myCharacter = LocalPlayer.Character
    if not myCharacter then
        return nil
    end

    local myRoot = myCharacter:FindFirstChild("HumanoidRootPart")
    if not myRoot then
        return nil
    end

    local myPosition = myRoot.Position
    local closestEnemy = nil
    local closestDistance = getgenv().AimbotFOV

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then
            continue
        end

        if not IsPlayerEnemy(plr) then
            continue
        end

        local character = plr.Character
        if not character then
            continue
        end

        local head = character:FindFirstChild("Head")
        if not head then
            continue
        end

        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid or humanoid.Health <= 0 then
            continue
        end

        if getgenv().VisibleCheckEnabled and not IsTargetVisible(head) then
            continue
        end

        local distance = (head.Position - myPosition).Magnitude
        if distance < closestDistance then
            closestDistance = distance
            closestEnemy = plr
        end
    end

    return closestEnemy
end

local function ValidateTarget(plr)
    if not plr then
        return false
    end

    if plr == LocalPlayer then
        return false
    end

    if not IsPlayerEnemy(plr) then
        return false
    end

    local character = plr.Character
    if not character then
        return false
    end

    local head = character:FindFirstChild("Head")
    if not head then
        return false
    end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return false
    end

    if getgenv().VisibleCheckEnabled and not IsTargetVisible(head) then
        return false
    end

    return true
end

local function PredictTargetPosition(target)
    local head = target.Character.Head
    local root = target.Character:FindFirstChild("HumanoidRootPart")
    
    if not root then
        return head.Position
    end
    
    local velocity = root.AssemblyLinearVelocity
    
    if velocity.Magnitude < 2 then
        return head.Position
    end
    
    local distance = (Camera.CFrame.Position - head.Position).Magnitude
    local timeToTarget = distance / 3000
    
    return head.Position + (velocity * timeToTarget)
end

local function AimbotStep()
    if not getgenv().AimbotEnabled then
        getgenv().AimbotTarget = nil
        return
    end

    if getgenv().AimbotTarget ~= nil then
        if not ValidateTarget(getgenv().AimbotTarget) then
            getgenv().AimbotTarget = nil
        end
    end

    if getgenv().AimbotTarget == nil then
        getgenv().AimbotTarget = ScanForClosestEnemy()
    end

    local target = getgenv().AimbotTarget
    if target == nil then
        return
    end

    if not ValidateTarget(target) then
        getgenv().AimbotTarget = nil
        return
    end

    local targetPosition = PredictTargetPosition(target)
    local cameraPosition = Camera.CFrame.Position
    local desiredDirection = (targetPosition - cameraPosition).Unit
    local currentDirection = Camera.CFrame.LookVector
    local smoothnessFactor = math.clamp(getgenv().AimbotSmoothness, 0.1, 1.0)
    local interpolationAlpha = math.min(smoothnessFactor, 1)
    local blendedDirection = (currentDirection + (desiredDirection - currentDirection) * interpolationAlpha).Unit

    Camera.CFrame = CFrame.new(cameraPosition, cameraPosition + blendedDirection)
end

AimbotConnection = RunService.RenderStepped:Connect(AimbotStep)

Mouse.Button2Down:Connect(function()
    if getgenv().AimbotEnabled then
        getgenv().AimbotTarget = ScanForClosestEnemy()
    end
end)

local function ClearESPDrawings()
    for _, drawing in ipairs(ESPDrawings) do
        pcall(function() drawing:Remove() end)
    end
    table.clear(ESPDrawings)
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

local function DrawFilledBox(x1, y1, x2, y2, color, transparency)
    local box = Drawing.new("Square")
    box.Position = Vector2.new(x1, y1)
    box.Size = Vector2.new(x2 - x1, y2 - y1)
    box.Color = color
    box.Filled = true
    box.Transparency = transparency
    box.Visible = true
    table.insert(ESPDrawings, box)
end

local function ESPStep()
    ClearESPDrawings()

    if not getgenv().ESPEnabled then
        return
    end

    local myCharacter = LocalPlayer.Character
    local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then
            continue
        end

        if not IsPlayerEnemy(plr) then
            continue
        end

        local character = plr.Character
        if not character then
            continue
        end

        local head = character:FindFirstChild("Head")
        local root = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChild("Humanoid")

        if not head or not root or not humanoid then
            continue
        end

        if humanoid.Health <= 0 then
            continue
        end

        local distance = 0
        if myRoot then
            distance = (myRoot.Position - root.Position).Magnitude
        end

        if distance > getgenv().ESPDistance then
            continue
        end

        local topPosition = head.Position + Vector3.new(0, 0.7, 0)
        local bottomPosition = root.Position - Vector3.new(0, 3.0, 0)

        local topScreen, topOnScreen = Camera:WorldToScreenPoint(topPosition)
        local bottomScreen, bottomOnScreen = Camera:WorldToScreenPoint(bottomPosition)
        local headScreen, headOnScreen = Camera:WorldToScreenPoint(head.Position)

        if not topOnScreen or not bottomOnScreen then
            continue
        end

        if topScreen.Z <= 0 or bottomScreen.Z <= 0 then
            continue
        end

        local boxHeight = math.abs(bottomScreen.Y - topScreen.Y)
        local boxWidth = boxHeight * 0.65
        local centerX = (topScreen.X + bottomScreen.X) / 2
        local left = centerX - boxWidth / 2
        local right = centerX + boxWidth / 2
        local top = topScreen.Y
        local bottom = bottomScreen.Y

        DrawCornerBox(left, top, right, bottom, Color3.fromRGB(0, 255, 0), 1.8)

        local distanceText = math.floor(distance)
        DrawESPText(plr.DisplayName .. " [" .. distanceText .. "m]", centerX, top - 14, 13, Color3.new(1, 1, 1))

        local healthPercent = humanoid.Health / humanoid.MaxHealth
        local barY = bottom + 3
        local barHeight = 4

        DrawFilledBox(left, barY, right, barY + barHeight, Color3.fromRGB(20, 20, 20), 0)

        local healthColor
        if healthPercent > 0.6 then
            healthColor = Color3.fromRGB(0, 255, 0)
        elseif healthPercent > 0.3 then
            healthColor = Color3.fromRGB(255, 255, 0)
        else
            healthColor = Color3.fromRGB(255, 0, 0)
        end

        local healthWidth = (right - left) * healthPercent
        DrawFilledBox(left, barY, left + healthWidth, barY + barHeight, healthColor, 0)

        if myRoot and headOnScreen and headScreen.Z > 0 then
            local myScreenPos, myOnScreen = Camera:WorldToScreenPoint(myRoot.Position)
            if myOnScreen and myScreenPos.Z > 0 then
                DrawTracerLine(myScreenPos.X, myScreenPos.Y, headScreen.X, headScreen.Y, Color3.fromRGB(0, 255, 0, 0.7), 1)
            end
        end
    end
end

ESPConnection = RunService.RenderStepped:Connect(ESPStep)

local function HighlightUpdateLoop()
    while task.wait(0.2) do
        if not getgenv().ESPEnabled then
            ClearAllHighlights()
            continue
        end

        local playersToRemove = {}
        for plr, highlight in pairs(ActiveHighlights) do
            local character = plr.Character
            if not character or character ~= highlight.Adornee then
                pcall(function() highlight:Destroy() end)
                table.insert(playersToRemove, plr)
                continue
            end
            local humanoid = character:FindFirstChild("Humanoid")
            if not humanoid or humanoid.Health <= 0 then
                pcall(function() highlight:Destroy() end)
                table.insert(playersToRemove, plr)
            end
        end

        for _, plr in ipairs(playersToRemove) do
            ActiveHighlights[plr] = nil
        end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer then
                continue
            end

            if not IsPlayerEnemy(plr) then
                RemoveHighlightForPlayer(plr)
                continue
            end

            local distance = 0
            local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local plrRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            
            if myRoot and plrRoot then
                distance = (myRoot.Position - plrRoot.Position).Magnitude
            end

            if distance > getgenv().ESPDistance then
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

task.spawn(HighlightUpdateLoop)

local function BuildUserInterface()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AndepzaiHub"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = LocalPlayer.PlayerGui

    local mainContainer = Instance.new("Frame")
    mainContainer.Size = UDim2.new(0, 240, 0, 46)
    mainContainer.Position = UDim2.new(0, 15, 0, 200)
    mainContainer.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    mainContainer.BorderSizePixel = 0
    mainContainer.ClipsDescendants = true
    mainContainer.Active = true
    mainContainer.Draggable = true
    mainContainer.Parent = screenGui

    Instance.new("UICorner", mainContainer).CornerRadius = UDim.new(0, 10)
    Instance.new("UIStroke", mainContainer).Color = Color3.fromRGB(50, 50, 58)
    Instance.new("UIStroke", mainContainer).Thickness = 1.2

    local headerBar = Instance.new("Frame")
    headerBar.Size = UDim2.new(1, 0, 0, 46)
    headerBar.BackgroundColor3 = Color3.fromRGB(16, 16, 19)
    headerBar.BorderSizePixel = 0
    headerBar.Parent = mainContainer
    Instance.new("UICorner", headerBar).CornerRadius = UDim.new(0, 10)

    local accentLine = Instance.new("Frame")
    accentLine.Size = UDim2.new(1, 0, 0, 2)
    accentLine.Position = UDim2.new(0, 0, 1, -2)
    accentLine.BackgroundColor3 = Color3.fromRGB(0, 255, 140)
    accentLine.BorderSizePixel = 0
    accentLine.Parent = headerBar

    local glowEffect = Instance.new("ImageLabel")
    glowEffect.Size = UDim2.new(1, 0, 0, 1)
    glowEffect.Position = UDim2.new(0, 0, 1, -3)
    glowEffect.BackgroundTransparency = 1
    glowEffect.Image = "rbxassetid://6014261993"
    glowEffect.ImageColor3 = Color3.fromRGB(0, 255, 140)
    glowEffect.ImageTransparency = 0.8
    glowEffect.ScaleType = Enum.ScaleType.Slice
    glowEffect.SliceCenter = Rect.new(8, 8, 8, 8)
    glowEffect.Parent = headerBar

    local menuButton = Instance.new("TextButton")
    menuButton.Size = UDim2.new(0, 32, 0, 28)
    menuButton.Position = UDim2.new(0, 8, 0.5, -14)
    menuButton.BackgroundColor3 = Color3.fromRGB(28, 28, 33)
    menuButton.Text = "☰"
    menuButton.TextColor3 = Color3.fromRGB(240, 240, 245)
    menuButton.Font = Enum.Font.GothamBold
    menuButton.TextSize = 15
    menuButton.BorderSizePixel = 0
    menuButton.AutoButtonColor = false
    menuButton.Parent = headerBar
    Instance.new("UICorner", menuButton).CornerRadius = UDim.new(0, 7)
    Instance.new("UIStroke", menuButton).Color = Color3.fromRGB(55, 55, 63)
    Instance.new("UIStroke", menuButton).Thickness = 1

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0, 150, 1, 0)
    titleLabel.Position = UDim2.new(0, 48, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "ANDEPZAI HUB"
    titleLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
    titleLabel.Font = Enum.Font.GothamBlack
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = headerBar

    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 32, 0, 28)
    closeButton.Position = UDim2.new(1, -40, 0.5, -14)
    closeButton.BackgroundColor3 = Color3.fromRGB(235, 55, 65)
    closeButton.Text = "✕"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 13
    closeButton.BorderSizePixel = 0
    closeButton.AutoButtonColor = false
    closeButton.Parent = headerBar
    Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 7)

    closeButton.MouseButton1Click:Connect(function()
        ClearAllHighlights()
        ClearESPDrawings()
        pcall(function() HighlightFolder:Destroy() end)
        if AimbotConnection then AimbotConnection:Disconnect() end
        if ESPConnection then ESPConnection:Disconnect() end
        screenGui:Destroy()
    end)

    local contentPanel = Instance.new("Frame")
    contentPanel.Size = UDim2.new(0, 240, 0, 200)
    contentPanel.Position = UDim2.new(0, 0, 0, 50)
    contentPanel.BackgroundColor3 = Color3.fromRGB(16, 16, 19)
    contentPanel.BorderSizePixel = 0
    contentPanel.ClipsDescendants = true
    contentPanel.Visible = false
    contentPanel.Parent = mainContainer
    Instance.new("UICorner", contentPanel).CornerRadius = UDim.new(0, 10)

    local contentScroll = Instance.new("ScrollingFrame")
    contentScroll.Size = UDim2.new(1, -16, 1, -12)
    contentScroll.Position = UDim2.new(0, 8, 0, 6)
    contentScroll.BackgroundColor3 = Color3.fromRGB(16, 16, 19)
    contentScroll.BorderSizePixel = 0
    contentScroll.ScrollBarThickness = 3
    contentScroll.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 140)
    contentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    contentScroll.ScrollingDirection = Enum.ScrollingDirection.Y
    contentScroll.Parent = contentPanel

    local contentList = Instance.new("UIListLayout")
    contentList.Padding = UDim.new(0, 7)
    contentList.SortOrder = Enum.SortOrder.LayoutOrder
    contentList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    contentList.Parent = contentScroll

    local function UpdateScrollCanvas()
        contentScroll.CanvasSize = UDim2.new(0, 0, 0, contentList.AbsoluteContentSize.Y + 12)
    end

    local function CreateSectionLabel(text)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -8, 0, 20)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(0, 255, 140)
        label.Font = Enum.Font.GothamBlack
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = contentScroll
        UpdateScrollCanvas()
        return label
    end

    local function CreateToggleComponent(name, defaultState, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -8, 0, 38)
        container.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
        container.BorderSizePixel = 0
        container.Parent = contentScroll
        Instance.new("UICorner", container).CornerRadius = UDim.new(0, 9)
        Instance.new("UIStroke", container).Color = Color3.fromRGB(40, 40, 46)
        Instance.new("UIStroke", container).Thickness = 1

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, 120, 1, 0)
        label.Position = UDim2.new(0, 14, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.fromRGB(240, 240, 245)
        label.Font = Enum.Font.GothamSemibold
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = container

        local switchFrame = Instance.new("TextButton")
        switchFrame.Size = UDim2.new(0, 46, 0, 24)
        switchFrame.Position = UDim2.new(1, -60, 0.5, -12)
        switchFrame.BackgroundColor3 = defaultState and Color3.fromRGB(0, 230, 120) or Color3.fromRGB(30, 30, 36)
        switchFrame.Text = ""
        switchFrame.BorderSizePixel = 0
        switchFrame.AutoButtonColor = false
        switchFrame.Parent = container
        Instance.new("UICorner", switchFrame).CornerRadius = UDim.new(0, 12)

        local switchKnob = Instance.new("Frame")
        switchKnob.Size = UDim2.new(0, 20, 0, 20)
        switchKnob.Position = UDim2.new(defaultState and 1 or 0, defaultState and -23 or 3, 0.5, -10)
        switchKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        switchKnob.BorderSizePixel = 0
        switchKnob.Parent = switchFrame
        Instance.new("UICorner", switchKnob).CornerRadius = UDim.new(0, 10)

        local isOn = defaultState

        local function AnimateSwitch(state)
            isOn = state
            local targetColor = state and Color3.fromRGB(0, 230, 120) or Color3.fromRGB(30, 30, 36)
            local targetPos = state and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)

            local colorTween = TweenService:Create(switchFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundColor3 = targetColor})
            colorTween:Play()

            local posTween = TweenService:Create(switchKnob, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = targetPos})
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
        container.Size = UDim2.new(1, -8, 0, 56)
        container.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
        container.BorderSizePixel = 0
        container.Parent = contentScroll
        Instance.new("UICorner", container).CornerRadius = UDim.new(0, 9)
        Instance.new("UIStroke", container).Color = Color3.fromRGB(40, 40, 46)
        Instance.new("UIStroke", container).Thickness = 1

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
        inputBox.Size = UDim2.new(1, -20, 0, 28)
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
        Instance.new("UIStroke", inputBox).Thickness = 1

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

    CreateSectionLabel("COMBAT")
    CreateToggleComponent("Aimbot", false, function(state)
        getgenv().AimbotEnabled = state
        if not state then getgenv().AimbotTarget = nil end
    end)
    CreateSliderComponent("Smoothness", 0.5, 0.1, 1.0, function(value)
        getgenv().AimbotSmoothness = value
    end)
    CreateSliderComponent("FOV", 500, 100, 2000, function(value)
        getgenv().AimbotFOV = value
    end)

    CreateSectionLabel("VISUALS")
    CreateToggleComponent("Player ESP", false, function(state)
        getgenv().ESPEnabled = state
    end)
    CreateSliderComponent("ESP Distance", 5000, 500, 20000, function(value)
        getgenv().ESPDistance = value
    end)

    CreateSectionLabel("SETTINGS")
    CreateToggleComponent("Team Check", true, function(state)
        getgenv().TeamCheckEnabled = state
    end)
    CreateToggleComponent("Visible Check", false, function(state)
        getgenv().VisibleCheckEnabled = state
    end)

    UpdateScrollCanvas()

    local menuOpen = false
    local function ToggleMenu()
        menuOpen = not menuOpen
        if menuOpen then
            contentPanel.Visible = true
            local expandTween = TweenService:Create(mainContainer, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 240, 0, 260)
            })
            expandTween:Play()
            menuButton.Text = "−"
            menuButton.BackgroundColor3 = Color3.fromRGB(0, 230, 120)
            menuButton.TextColor3 = Color3.fromRGB(10, 10, 12)
            UpdateScrollCanvas()
        else
            local collapseTween = TweenService:Create(mainContainer, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 240, 0, 46)
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

    return screenGui
end

local GUI = BuildUserInterface()

GUI.Destroying:Connect(function()
    ClearAllHighlights()
    ClearESPDrawings()
    pcall(function() HighlightFolder:Destroy() end)
    if AimbotConnection then AimbotConnection:Disconnect() end
    if ESPConnection then ESPConnection:Disconnect() end
end)

task.spawn(function()
    while task.wait(30) do
        collectgarbage("collect")
    end
end)

print("Andepzai Hub loaded successfully.")
print("Features: Aimbot, ESP, Team Check, Visible Check")
print("Press ☰ to open menu, Right Click to lock target")