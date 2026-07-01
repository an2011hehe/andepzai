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

if not LocalPlayer.Character then LocalPlayer.CharacterAdded:Wait() end
if not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then LocalPlayer.Character:WaitForChild("HumanoidRootPart") end

local HighlightFolder = Instance.new("Folder")
HighlightFolder.Name = "Andepzai_Highlights"
HighlightFolder.Parent = Workspace

local ActiveHighlights = {}
local ESPDrawings = {}
local TeamCache = {}

local function ClearAllHighlights()
    for plr, hl in pairs(ActiveHighlights) do
        pcall(function() hl:Destroy() end)
    end
    table.clear(ActiveHighlights)
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

local function ScanPlayerTeam(plr)
    if TeamCache[plr] ~= nil then return TeamCache[plr] end

    local teamIdentifier = nil
    local teamObject = nil

    pcall(function()
        teamObject = plr.Team
        if teamObject then
            if typeof(teamObject) == "Instance" and teamObject:IsA("Team") then
                teamIdentifier = teamObject.Name
                local teams = game:GetService("Teams"):GetChildren()
                local realTeams = {}
                for _, t in ipairs(teams) do
                    if t:IsA("Team") then table.insert(realTeams, t) end
                end
                if #realTeams <= 1 then
                    teamIdentifier = nil
                end
            end
        end
    end)
    if teamIdentifier then TeamCache[plr] = teamIdentifier return teamIdentifier end

    pcall(function()
        if plr:FindFirstChild("TeamColor") then
            local tc = plr.TeamColor
            if typeof(tc) == "Color3" or typeof(tc) == "BrickColor" then
                if typeof(tc) == "BrickColor" then tc = tc.Color end
                teamIdentifier = tc
            end
        end
    end)
    if teamIdentifier then TeamCache[plr] = teamIdentifier return teamIdentifier end

    pcall(function()
        local attr = plr:GetAttribute("Team")
        if attr then teamIdentifier = tostring(attr) end
    end)
    if teamIdentifier then TeamCache[plr] = teamIdentifier return teamIdentifier end

    pcall(function()
        local attr = plr:GetAttribute("TeamColor")
        if attr then teamIdentifier = attr end
    end)
    if teamIdentifier then TeamCache[plr] = teamIdentifier return teamIdentifier end

    pcall(function()
        for _, child in ipairs(plr:GetChildren()) do
            if child:IsA("ObjectValue") and child.Name:lower():find("team") then
                if child.Value and child.Value:IsA("Team") then
                    teamIdentifier = child.Value.Name
                    break
                elseif child.Value then
                    teamIdentifier = tostring(child.Value)
                    break
                end
            elseif child:IsA("StringValue") and child.Name:lower():find("team") then
                teamIdentifier = child.Value
                break
            elseif child:IsA("IntValue") and child.Name:lower():find("team") then
                teamIdentifier = child.Value
                break
            end
        end
    end)
    if teamIdentifier then TeamCache[plr] = teamIdentifier return teamIdentifier end

    if plr.Character then
        local char = plr.Character

        pcall(function()
            local teamFolder = char:FindFirstChild("Team")
            if teamFolder then
                if teamFolder:IsA("StringValue") then teamIdentifier = teamFolder.Value
                elseif teamFolder:IsA("Folder") or teamFolder:IsA("Model") then teamIdentifier = teamFolder.Name
                elseif teamFolder:IsA("ObjectValue") and teamFolder.Value then teamIdentifier = tostring(teamFolder.Value) end
            end
        end)
        if teamIdentifier then TeamCache[plr] = teamIdentifier return teamIdentifier end

        pcall(function()
            local bodyColors = char:FindFirstChild("BodyColors")
            if bodyColors then
                if bodyColors:IsA("BodyColors") then
                    local headColor = bodyColors.HeadColor3
                    local torsoColor = bodyColors.TorsoColor3
                    if torsoColor then
                        teamIdentifier = torsoColor
                    end
                elseif bodyColors:IsA("StringValue") then
                    teamIdentifier = bodyColors.Value
                end
            end
        end)
        if teamIdentifier then TeamCache[plr] = teamIdentifier return teamIdentifier end

        pcall(function()
            local shirt = char:FindFirstChild("Shirt")
            if shirt and shirt:IsA("Shirt") then
                local template = shirt.ShirtTemplate
                if template and template ~= "" then
                    teamIdentifier = template
                end
            end
            if not teamIdentifier then
                local pants = char:FindFirstChild("Pants")
                if pants and pants:IsA("Pants") then
                    local template = pants.PantsTemplate
                    if template and template ~= "" then
                        teamIdentifier = template
                    end
                end
            end
        end)
        if teamIdentifier then TeamCache[plr] = teamIdentifier return teamIdentifier end

        pcall(function()
            local head = char:FindFirstChild("Head")
            if head then
                for _, child in ipairs(head:GetChildren()) do
                    if child:IsA("BillboardGui") then
                        for _, element in ipairs(child:GetChildren()) do
                            if element:IsA("TextLabel") and element.Text ~= "" then
                                local text = element.Text:lower()
                                if text:find("red") or text:find("blue") or text:find("green") or text:find("yellow") then
                                    teamIdentifier = text
                                    break
                                end
                            end
                            if element:IsA("Frame") and element.BackgroundColor3 then
                                teamIdentifier = element.BackgroundColor3
                                break
                            end
                        end
                    end
                    if teamIdentifier then break end
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
                if child:IsA("Folder") and child.Name:lower():find("team") then
                    teamIdentifier = child.Name
                    break
                end
                if child:IsA("Model") and child.Name:lower():find("team") then
                    teamIdentifier = child.Name
                    break
                end
                if child:IsA("Highlight") then
                    teamIdentifier = child.FillColor
                    break
                end
            end
        end)
        if teamIdentifier then TeamCache[plr] = teamIdentifier return teamIdentifier end
    end

    pcall(function()
        local teamsService = game:GetService("Teams")
        local teams = teamsService:GetChildren()
        local validTeams = 0
        for _, t in ipairs(teams) do
            if t:IsA("Team") then validTeams = validTeams + 1 end
        end
        if validTeams <= 1 then
            teamIdentifier = nil
        end
    end)

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
        task.wait(0.5)
        TeamCache[plr] = ScanPlayerTeam(plr)
    end)
end)

Players.PlayerRemoving:Connect(function(plr)
    TeamCache[plr] = nil
    RemoveHighlightForPlayer(plr)
end)

task.spawn(function()
    while task.wait(2) do
        RefreshAllTeams()
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
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
    
    if type(myTeam) == "number" and type(theirTeam) == "number" then
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

RunService:BindToRenderStep("AndepzaiAimbot", 200, function()
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
    local newDirection = (currentDirection + (targetDirection - currentDirection) * smoothness).Unit
    Camera.CFrame = CFrame.new(cameraPosition, cameraPosition + newDirection)
end)

Mouse.Button2Down:Connect(function()
    if getgenv().AimbotEnabled then
        getgenv().AimbotTarget = GetClosestEnemyPlayer()
    end
end)

local function ClearAllESPDrawings()
    for _, drawing in ipairs(ESPDrawings) do
        pcall(function() drawing:Remove() end)
    end
    table.clear(ESPDrawings)
end

RunService:BindToRenderStep("AndepzaiESP", 201, function()
    ClearAllESPDrawings()

    if not getgenv().ESPEnabled then return end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if not IsPlayerEnemy(plr) then continue end

        local char = plr.Character
        if not char then continue end

        local head = char:FindFirstChild("Head")
        local humanoid = char:FindFirstChild("Humanoid")

        if not head or not humanoid then continue end
        if humanoid.Health <= 0 then continue end

        local headScreen, headOnScreen = Camera:WorldToScreenPoint(head.Position)

        if not headOnScreen or headScreen.Z <= 0 then continue end

        if myRoot then
            local myScreenPos, myOnScreen = Camera:WorldToScreenPoint(myRoot.Position)
            if myOnScreen and myScreenPos.Z > 0 then
                local tracer = Drawing.new("Line")
                tracer.From = Vector2.new(myScreenPos.X, myScreenPos.Y)
                tracer.To = Vector2.new(headScreen.X, headScreen.Y)
                tracer.Color = Color3.fromRGB(0, 255, 0)
                tracer.Thickness = 1
                tracer.Visible = true
                table.insert(ESPDrawings, tracer)
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
        RunService:UnbindFromRenderStep("AndepzaiAimbot")
        RunService:UnbindFromRenderStep("AndepzaiESP")
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
end)

task.spawn(function()
    while task.wait(30) do
        collectgarbage("collect")
    end
end)