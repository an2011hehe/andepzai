getgenv().AimbotEnabled = false
getgenv().ESPEnabled = false
getgenv().AimbotSmoothness = 0.18
getgenv().AimbotTarget = nil
getgenv().AimbotFOV = 500
getgenv().ESPDistance = 5000
getgenv().TeamCheck = true
getgenv().VisibleCheck = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
    LocalPlayer.CharacterAdded:Wait()
end

do
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    local oldIndex = mt.__index
    setreadonly(mt, false)

    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if method == "Kick" or method == "kick" or method == "Ban" then
            return nil
        end
        if method == "FireServer" and self and self.Name then
            local nameLower = self.Name:lower()
            if nameLower:find("ban") or nameLower:find("kick") or nameLower:find("report") then
                return nil
            end
        end
        if method == "Destroy" and self == LocalPlayer.Character then
            return nil
        end
        return oldNamecall(self, unpack(args))
    end)

    mt.__index = newcclosure(function(self, idx)
        if idx == "WalkSpeed" or idx == "JumpPower" or idx == "HipHeight" then
            if self:IsA("Humanoid") then
                return idx == "WalkSpeed" and 16 or idx == "JumpPower" and 50 or 2
            end
        end
        if idx == "Health" and self:IsA("Humanoid") then
            local originalHealth = oldIndex(self, "Health")
            if originalHealth <= 0 then
                return 100
            end
        end
        return oldIndex(self, idx)
    end)

    setreadonly(mt, true)
local TeamCache = {}
local function GetTeam(player)
    if TeamCache[player] then return TeamCache[player] end
    local teamData = nil

    pcall(function()
        if player:FindFirstChild("Team") then
            teamData = player.Team
        end
    end)
    if teamData then TeamCache[player] = teamData return teamData end

    pcall(function()
        if player:FindFirstChild("TeamColor") then
            teamData = player.TeamColor
        end
    end)
    if teamData then TeamCache[player] = teamData return teamData end

    pcall(function()
        teamData = player:GetAttribute("Team")
    end)
    if teamData then TeamCache[player] = teamData return teamData end

    if player.Character then
        pcall(function()
            local folder = player.Character:FindFirstChild("Team")
            if folder then
                if folder:IsA("StringValue") then
                    teamData = folder.Value
                elseif folder:IsA("Folder") then
                    teamData = folder.Name
                end
            end
        end)
    end
    if teamData then TeamCache[player] = teamData return teamData end

    if player.Character then
        pcall(function()
            local bc = player.Character:FindFirstChild("BodyColors")
            if bc and bc.TorsoColor3 then
                teamData = bc.TorsoColor3
            end
        end)
    end
    if teamData then TeamCache[player] = teamData return teamData end

    if player.Character then
        pcall(function()
            for _, child in ipairs(player.Character:GetChildren()) do
                if child:IsA("BillboardGui") then
                    for _, element in ipairs(child:GetChildren()) do
                        if element:IsA("TextLabel") and element.Text ~= "" then
                            teamData = element.Text:lower()
                            break
                        end
                    end
                end
                if teamData then break end
            end
        end)
    end
    TeamCache[player] = teamData
    return teamData
end

local function RefreshTeams()
    for _, player in ipairs(Players:GetPlayers()) do
        TeamCache[player] = GetTeam(player)
    end
end
RefreshTeams()

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        TeamCache[player] = GetTeam(player)
    end)
end)
Players.PlayerRemoving:Connect(function(player)
    TeamCache[player] = nil
end)
task.spawn(function()
    while task.wait(5) do
        RefreshTeams()
    end
end)

local function IsEnemy(player)
    if player == LocalPlayer then return false end
    if not getgenv().TeamCheck then return true end
    local myTeam = TeamCache[LocalPlayer]
    local theirTeam = TeamCache[player]
    if not myTeam or not theirTeam then return true end
    if myTeam == theirTeam then return false end
    if type(myTeam) == "string" and type(theirTeam) == "string" then
        return myTeam:lower() ~= theirTeam:lower()
    end
    if typeof(myTeam) == "Color3" and typeof(theirTeam) == "Color3" then
        return myTeam ~= theirTeam
    end
    return true
end

local function IsVisible(targetPart)
    if not getgenv().VisibleCheck then return true end
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin).Unit * 5000
    local ray = Ray.new(origin, direction)
    local hit = Workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character}, false, true)
    return hit == nil or hit:IsDescendantOf(targetPart.Parent)
end

local function GetClosestEnemy()
    local localChar = LocalPlayer.Character
    if not localChar then return nil end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart")
    if not localRoot then return nil end
    local localPos = localRoot.Position
    local closest = nil
    local minDist = getgenv().AimbotFOV

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer or not IsEnemy(player) then continue end
        local char = player.Character
        if not char then continue end
        local head = char:FindFirstChild("Head")
        local humanoid = char:FindFirstChild("Humanoid")
        if not head or not humanoid or humanoid.Health <= 0 then continue end
        if getgenv().VisibleCheck and not IsVisible(head) then continue end

        local distance = (head.Position - localPos).Magnitude
        if distance < minDist then
            minDist = distance
            closest = player
        end
    end
    return closest
end

local function IsValidTarget(player)
    if not player or not IsEnemy(player) then return false end
    local char = player.Character
    if not char then return false end
    local head = char:FindFirstChild("Head")
    local humanoid = char:FindFirstChild("Humanoid")
    return head and humanoid and humanoid.Health > 0
end

local function PredictPosition(head, root)
    if not root then return head.Position end
    local velocity = root.AssemblyLinearVelocity
    if velocity.Magnitude < 2 then return head.Position end
    local distance = (Camera.CFrame.Position - head.Position).Magnitude
    local timeToTarget = distance / 3000
    return head.Position + velocity * timeToTarget
end

local function AimAtPosition(worldPos, smoothness, dt)
    local camPos = Camera.CFrame.Position
    local targetDir = (worldPos - camPos).Unit
    local currentDir = Camera.CFrame.LookVector
    local lerpFactor = math.min(smoothness * dt * 60, 0.95)
    local newDir = (currentDir + (targetDir - currentDir) * lerpFactor).Unit
    Camera.CFrame = CFrame.new(camPos, camPos + newDir)
end

local AimConnection
AimConnection = RunService:BindToRenderStep("AndepzaiAimbot", 200, function(dt)
    if not getgenv().AimbotEnabled then
        getgenv().AimbotTarget = nil
        return
    end

    if not getgenv().AimbotTarget or not IsValidTarget(getgenv().AimbotTarget) then
        getgenv().AimbotTarget = GetClosestEnemy()
    end

    local target = getgenv().AimbotTarget
    if target and IsValidTarget(target) then
        local head = target.Character.Head
        local root = target.Character:FindFirstChild("HumanoidRootPart")
        local aimPos = PredictPosition(head, root)
        AimAtPosition(aimPos, getgenv().AimbotSmoothness, dt)
    else
        getgenv().AimbotTarget = nil
    end
end)

Mouse.Button2Down:Connect(function()
    if getgenv().AimbotEnabled then
        getgenv().AimbotTarget = GetClosestEnemy()
    end
end)
local ESPDrawings = {}

local function ClearESP()
    for _, drawing in ipairs(ESPDrawings) do
        pcall(function() drawing:Remove() end)
    end
    ESPDrawings = {}
end

local function CreateCornerBox(x1, y1, x2, y2, color, thickness)
    local height = math.abs(y2 - y1)
    local cornerLength = math.clamp(height * 0.22, 6, 18)
    local lines = {
        {x1, y1, x1, y1 + cornerLength},
        {x1, y1, x1 + cornerLength, y1},
        {x2, y1, x2, y1 + cornerLength},
        {x2, y1, x2 - cornerLength, y1},
        {x1, y2, x1, y2 - cornerLength},
        {x1, y2, x1 + cornerLength, y2},
        {x2, y2, x2, y2 - cornerLength},
        {x2, y2, x2 - cornerLength, y2},
    }
    for _, line in ipairs(lines) do
        local d = Drawing.new("Line")
        d.From = Vector2.new(line[1], line[2])
        d.To = Vector2.new(line[3], line[4])
        d.Color = color
        d.Thickness = thickness
        d.Visible = true
        table.insert(ESPDrawings, d)
    end
end

local function CreateText(text, x, y, size, color, outline)
    local d = Drawing.new("Text")
    d.Text = text
    d.Position = Vector2.new(x, y)
    d.Size = size
    d.Color = color
    d.Center = true
    d.Outline = outline
    d.OutlineColor = Color3.new(0,0,0)
    d.Visible = true
    table.insert(ESPDrawings, d)
end

local ESPConnection
ESPConnection = RunService:BindToRenderStep("AndepzaiESP", 201, function()
    ClearESP()
    if not getgenv().ESPEnabled then return end

    local localChar = LocalPlayer.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    local drawnCount = 0
    local maxDrawings = 100

    for _, player in ipairs(Players:GetPlayers()) do
        if drawnCount >= maxDrawings then break end
        if player == LocalPlayer then continue end
        if not IsEnemy(player) then continue end

        local char = player.Character
        if not char then continue end
        local head = char:FindFirstChild("Head")
        local root = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        if not head or not root or not humanoid or humanoid.Health <= 0 then continue end

        local dist = localRoot and (localRoot.Position - root.Position).Magnitude or 9999
        if dist > getgenv().ESPDistance then continue end

        if getgenv().VisibleCheck and not IsVisible(head) then continue end

        local topPos = head.Position + Vector3.new(0, 0.7, 0)
        local botPos = root.Position - Vector3.new(0, 2.9, 0)
        local topScreen, topOnScreen = Camera:WorldToScreenPoint(topPos)
        local botScreen, botOnScreen = Camera:WorldToScreenPoint(botPos)

        if not topOnScreen or not botOnScreen or topScreen.Z <= 0 or botScreen.Z <= 0 then continue end

        local boxHeight = math.abs(botScreen.Y - topScreen.Y)
        local boxWidth = boxHeight * 0.6
        local centerX = (topScreen.X + botScreen.X) / 2
        local left = centerX - boxWidth / 2
        local right = centerX + boxWidth / 2
        local top = topScreen.Y
        local bottom = botScreen.Y

        CreateCornerBox(left, top, right, bottom, Color3.fromRGB(0, 255, 0), 1.5)

        local displayText = player.DisplayName .. " [" .. math.floor(dist) .. "m]"
        CreateText(displayText, centerX, top - 12, 13, Color3.new(1,1,1), true)

        drawnCount = drawnCount + 1
    end
end)
local function CreateGUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "AndepzaiHub"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = LocalPlayer.PlayerGui

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "Main"
    mainFrame.Size = UDim2.new(0, 200, 0, 30)
    mainFrame.Position = UDim2.new(0, 20, 0, 150)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15,15,15)
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = gui

    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 6)

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1,0,0,30)
    titleBar.BackgroundColor3 = Color3.fromRGB(255,85,0)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0,6)

    local menuBtn = Instance.new("TextButton")
    menuBtn.Size = UDim2.new(0,24,0,20)
    menuBtn.Position = UDim2.new(0,6,0.5,-10)
    menuBtn.BackgroundColor3 = Color3.fromRGB(255,150,0)
    menuBtn.Text = "☰"
    menuBtn.TextColor3 = Color3.new(1,1,1)
    menuBtn.Font = Enum.Font.GothamBold
    menuBtn.TextSize = 14
    menuBtn.BorderSizePixel = 0
    menuBtn.Parent = titleBar
    Instance.new("UICorner", menuBtn).CornerRadius = UDim.new(0,3)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1,-90,1,0)
    titleLabel.Position = UDim2.new(0,36,0,0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "ANDEPZAI HUB"
    titleLabel.TextColor3 = Color3.new(1,1,1)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 11
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0,24,0,20)
    closeBtn.Position = UDim2.new(1,-28,0.5,-10)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200,0,0)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1,1,1)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 11
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = titleBar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,3)
    closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

    local contentFrame = Instance.new("ScrollingFrame")
    contentFrame.Size = UDim2.new(1,-8,0,130)
    contentFrame.Position = UDim2.new(0,4,0,34)
    contentFrame.BackgroundColor3 = Color3.fromRGB(18,18,18)
    contentFrame.BorderSizePixel = 0
    contentFrame.ScrollBarThickness = 2
    contentFrame.ScrollBarImageColor3 = Color3.fromRGB(255,85,0)
    contentFrame.CanvasSize = UDim2.new(0,0,0,0)
    contentFrame.Visible = false
    contentFrame.Parent = mainFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0,3)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = contentFrame

    local function UpdateCanvas()
        contentFrame.CanvasSize = UDim2.new(0,0,0, listLayout.AbsoluteContentSize.Y + 6)
    end

    local function MakeToggle(name, default, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1,-2,0,30)
        frame.BackgroundColor3 = Color3.fromRGB(26,26,26)
        frame.BorderSizePixel = 0
        frame.Parent = contentFrame
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0,5)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0,90,1,0)
        label.Position = UDim2.new(0,8,0,0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.new(1,1,1)
        label.Font = Enum.Font.GothamSemibold
        label.TextSize = 11
        label.Parent = frame

        local switch = Instance.new("TextButton")
        switch.Size = UDim2.new(0,38,0,20)
        switch.Position = UDim2.new(1,-46,0.5,-10)
        switch.BackgroundColor3 = default and Color3.fromRGB(0,150,0) or Color3.fromRGB(60,60,60)
        switch.Text = default and "ON" or "OFF"
        switch.TextColor3 = Color3.new(1,1,1)
        switch.Font = Enum.Font.GothamBold
        switch.TextSize = 10
        switch.BorderSizePixel = 0
        switch.Parent = frame
        Instance.new("UICorner", switch).CornerRadius = UDim.new(0,3)

        local state = default
        switch.MouseButton1Click:Connect(function()
            state = not state
            switch.Text = state and "ON" or "OFF"
            switch.BackgroundColor3 = state and Color3.fromRGB(0,150,0) or Color3.fromRGB(60,60,60)
            callback(state)
        end)
        UpdateCanvas()
    end

    local function MakeSlider(name, defaultVal, min, max, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1,-2,0,50)
        frame.BackgroundColor3 = Color3.fromRGB(26,26,26)
        frame.BorderSizePixel = 0
        frame.Parent = contentFrame
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0,5)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1,-16,0,18)
        label.Position = UDim2.new(0,8,0,3)
        label.BackgroundTransparency = 1
        label.Text = name .. ": " .. defaultVal
        label.TextColor3 = Color3.fromRGB(180,180,180)
        label.Font = Enum.Font.Gotham
        label.TextSize = 10
        label.Parent = frame

        local input = Instance.new("TextBox")
        input.Size = UDim2.new(1,-16,0,22)
        input.Position = UDim2.new(0,8,0,22)
        input.BackgroundColor3 = Color3.fromRGB(38,38,38)
        input.Text = tostring(defaultVal)
        input.TextColor3 = Color3.new(1,1,1)
        input.Font = Enum.Font.Gotham
        input.TextSize = 10
        input.BorderSizePixel = 0
        input.Parent = frame
        Instance.new("UICorner", input).CornerRadius = UDim.new(0,3)

        input.FocusLost:Connect(function()
            local num = tonumber(input.Text)
            if num and num >= min and num <= max then
                callback(num)
                label.Text = name .. ": " .. num
            else
                input.Text = tostring(defaultVal)
            end
        end)
        UpdateCanvas()
    end

    MakeToggle("Aimbot", false, function(val) getgenv().AimbotEnabled = val if not val then getgenv().AimbotTarget = nil end end)
    MakeToggle("ESP", false, function(val) getgenv().ESPEnabled = val end)
    MakeSlider("Smoothness", 0.18, 0.01, 0.5, function(val) getgenv().AimbotSmoothness = val end)
    MakeToggle("Team Check", true, function(val) getgenv().TeamCheck = val end)
    MakeToggle("Visible Check", true, function(val) getgenv().VisibleCheck = val end)

    local open = false
    menuBtn.MouseButton1Click:Connect(function()
        open = not open
        if open then
            mainFrame.Size = UDim2.new(0,200,0,195)
            contentFrame.Visible = true
            menuBtn.Text = "X"
            menuBtn.BackgroundColor3 = Color3.fromRGB(200,0,0)
        else
            mainFrame.Size = UDim2.new(0,200,0,30)
            contentFrame.Visible = false
            menuBtn.Text = "☰"
            menuBtn.BackgroundColor3 = Color3.fromRGB(255,150,0)
        end
    end)

    return gui
end

local GUI = CreateGUI()

GUI.Destroying:Connect(function()
    RunService:UnbindFromRenderStep("AndepzaiAimbot")
    RunService:UnbindFromRenderStep("AndepzaiESP")
    ClearESP()
end)

local GarbageCollectionInterval = 60
task.spawn(function()
    while task.wait(GarbageCollectionInterval) do
        collectgarbage("collect")
    end
end)