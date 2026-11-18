--[[
    LARP - Combined
    Version: 0.3.0 (Nebula UI + Aimbot/ESP + Anti Aim API + Server-authorized Desync ESP)

    Anti Aim и Desync ESP работают только через RemoteEvent, который должен
    быть создан и проверен на сервере вашей игры.
]]

local LARP = {
    Name = "LARP",
    Version = "0.3.0",
    Unloaded = false,
    Connections = {},
    DesyncMarkers = {},
    MenuOpen = false,
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

local function log(message)
    print(("[LARP] %s"):format(tostring(message)))
end

local function trackConnection(connection)
    table.insert(LARP.Connections, connection)
    return connection
end

function LARP:Notify(message, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = self.Name,
            Text = tostring(message),
            Duration = duration or 3,
        })
    end)
end

-- ======================== CONFIG ========================
LARP.Config = {
    MenuKey = Enum.KeyCode.RightShift,

    -- Visuals
    PlayerESP = false,
    PlayerTracers = false,
    ESP_MaxDistance = math.huge,
    NPCESP = false,
    NPCTracers = false,
    NPC_ESP_MaxDistance = 1500,
    Fullbright = false,
    TargetMarker = false,

    -- Aimbot
    Aimbot = {
        Enabled = false,
        WallCheck = true,
        TargetNPCs = false,
        Prediction = false,
        ShowFOV = false,
        FOV = 150,
        Smoothing = 0.25,
        BulletSpeed = 1500,
    },

    -- Anti Aim (server-authorized)
    AntiAim = {
        Enabled = false,
        Pitch = "Off",          -- Off, Up, Down, Random, Custom
        Yaw = "Off",            -- Off, Backward, Spin, Static, Random, Custom
        YawOffset = 0,
        SpinSpeed = 180,
        Jitter = false,
        JitterAmount = 30,
        BodyYaw = false,
        BodyYawAmount = 0,
        Inverter = false,
        Conditions = {
            Standing = true,
            Moving = true,
            InAir = true,
        },
    },

    -- Desync ESP (server-authorized)
    DesyncESP = {
        Enabled = false,
        ShowReal = true,
        ShowFake = true,
        ShowLine = true,
        ShowNames = true,
        MaxDistance = 1000,
        RealColor = Color3.fromRGB(70, 170, 255),
        FakeColor = Color3.fromRGB(255, 90, 120),
    },
}

-- ======================== TARGET MARKER (Nebula) ========================
local MARKER_IMAGE = "rbxassetid://114677874909839"
local MARKER_SCALE = 2.6
local MAX_DISTANCE = 60

local targetesp = {
    Enabled = false,
    Color = Color3.fromRGB(255, 255, 255),
}

local Animation = {}
Animation.__index = Animation
function Animation.new(duration)
    return setmetatable({duration = duration, progress = 0, value = 0}, Animation)
end
function Animation:update(dt, forward)
    local step = dt / self.duration
    self.progress = math.clamp(self.progress + (forward and step or -step), 0, 1)
    self.value = 1 - (1 - self.progress) ^ 3
end

local anchor = Instance.new("Part")
anchor.Name = "NebulaTargetESPAnchor"
anchor.Anchored = true
anchor.CanCollide = false
anchor.CanQuery = false
anchor.CanTouch = false
anchor.Transparency = 1
anchor.Size = Vector3.new(0.1, 0.1, 0.1)
anchor.Parent = workspace.CurrentCamera

local Pool = {}
Pool.__index = Pool
function Pool.new(adornee)
    return setmetatable({adornee = adornee, items = {}, used = 0}, Pool)
end
function Pool:_make()
    local gui = Instance.new("BillboardGui")
    gui.Name = "NebulaTargetMarker"
    gui.Adornee = self.adornee
    gui.AlwaysOnTop = true
    gui.LightInfluence = 0
    gui.Size = UDim2.fromScale(1, 1)
    gui.Enabled = false

    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.AnchorPoint = Vector2.new(0.5, 0.5)
    img.Position = UDim2.fromScale(0.5, 0.5)
    img.Size = UDim2.fromScale(1, 1)
    img.Image = MARKER_IMAGE
    img.Parent = gui
    gui.Parent = self.adornee

    local item = {gui = gui, img = img}
    table.insert(self.items, item)
    return item
end
function Pool:Begin() self.used = 0 end
function Pool:Add(offset, size, alpha, rotation)
    self.used += 1
    local item = self.items[self.used] or self:_make()
    item.gui.Enabled = true
    item.gui.StudsOffsetWorldSpace = offset
    item.gui.Size = UDim2.fromScale(size, size)
    item.img.ImageTransparency = 1 - math.clamp(alpha, 0, 1)
    item.img.ImageColor3 = targetesp.Color
    item.img.Rotation = rotation or 0
end
function Pool:End()
    for i = self.used + 1, #self.items do
        if self.items[i].gui.Enabled then
            self.items[i].gui.Enabled = false
        end
    end
end

local pool = Pool.new(anchor)
local anim = Animation.new(0.4)
local target = nil
local lastTarget = nil
local rotAngle = 0
local rotSpeed = 0
local reversing = false

local function setTarget(model)
    target = model
end

trackConnection(RunService.RenderStepped:Connect(function(dt)
    local hasTarget = targetesp.Enabled and target ~= nil and target.Parent ~= nil
    if hasTarget then lastTarget = target end
    anim:update(dt, hasTarget)
    if not hasTarget and anim.value <= 0 then lastTarget = nil end

    pool:Begin()
    if lastTarget and lastTarget.Parent and anim.value > 0.01 then
        local boundingCFrame = lastTarget:GetBoundingBox()
        anchor.Position = boundingCFrame.Position

        local k = dt * 60
        if not reversing then
            rotSpeed = math.min(rotSpeed + 0.01 * k, 2.3)
            if rotSpeed >= 2.3 then reversing = true end
        else
            rotSpeed = math.max(rotSpeed - 0.01 * k, -2.3)
            if rotSpeed <= -2.3 then reversing = false end
        end
        rotAngle = (rotAngle + rotSpeed * k) % 360
        pool:Add(Vector3.zero, 1.8 * anim.value * MARKER_SCALE, anim.value, rotAngle)
    end
    pool:End()
end))

-- Nearest player target for marker
task.spawn(function()
    while not LARP.Unloaded do
        task.wait(0.2)
        local bestCharacter = nil
        local bestDistance = MAX_DISTANCE

        if targetesp.Enabled then
            local myCharacter = LocalPlayer.Character
            local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")
            if myRoot then
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        local character = player.Character
                        local root = character and character:FindFirstChild("HumanoidRootPart")
                        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                        if root and humanoid and humanoid.Health > 0 then
                            local distance = (root.Position - myRoot.Position).Magnitude
                            if distance < bestDistance then
                                bestCharacter = character
                                bestDistance = distance
                            end
                        end
                    end
                end
            end
        end
        setTarget(bestCharacter)
    end
end)

-- ======================== ESP / AIMBOT ========================
local OriginalAmbient = Lighting.Ambient
local OriginalBrightness = Lighting.Brightness

local ESP_CONFIG = {
    TOP_OFFSET = Vector3.new(0, 3, 0),
    BOTTOM_OFFSET = Vector3.new(0, 3.5, 0),
    DISTANCE_DIVISOR = 3.5,
    MIN_HEIGHT = 6,
    MIN_WIDTH = 4,
}
local MIN_BULLET_SPEED = 1

local ESP_Cache = {}
local Visibility_Cache = {}
local Tracked_NPCs = {}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function refreshRayFilter()
    local filter = {}
    if LocalPlayer.Character then table.insert(filter, LocalPlayer.Character) end
    if workspace.CurrentCamera then table.insert(filter, workspace.CurrentCamera) end
    rayParams.FilterDescendantsInstances = filter
end

local DrawingAPI = Drawing
local drawingAvailable = DrawingAPI ~= nil
local FOVCircle
if drawingAvailable then
    local ok, circle = pcall(function()
        local obj = DrawingAPI.new("Circle")
        obj.Thickness = 1
        obj.Color = Color3.fromRGB(255, 255, 255)
        obj.Transparency = 1
        obj.Filled = false
        obj.Visible = false
        return obj
    end)
    if ok then FOVCircle = circle else drawingAvailable = false end
end

local function removeDrawing(obj)
    if obj then pcall(function() obj:Remove() end) end
end

local function ClearEntityESP(id)
    local cached = ESP_Cache[id]
    if cached then
        removeDrawing(cached.Box)
        removeDrawing(cached.Text)
        removeDrawing(cached.Tracer)
        ESP_Cache[id] = nil
    end
    Visibility_Cache[id] = nil
end

local function HideESP(id)
    local cached = ESP_Cache[id]
    if not cached then return end
    cached.Box.Visible = false
    cached.Text.Visible = false
    cached.Tracer.Visible = false
end

trackConnection(Players.PlayerRemoving:Connect(function(player)
    ClearEntityESP(tostring(player.UserId))
end))

local function IsNPC(model)
    if not model or not model:IsA("Model") then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    return hum ~= nil
        and hum.Health > 0
        and model:FindFirstChild("HumanoidRootPart") ~= nil
        and Players:GetPlayerFromCharacter(model) == nil
end

local function CheckAndAddNPC(obj)
    if IsNPC(obj) then Tracked_NPCs[obj] = true end
end

local function RemoveNPC(obj)
    if Tracked_NPCs[obj] then
        Tracked_NPCs[obj] = nil
        ClearEntityESP(obj)
    end
end

task.spawn(function()
    local count = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") then CheckAndAddNPC(obj) end
        count += 1
        if count % 500 == 0 then task.wait() end
    end
end)

trackConnection(workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("Model") then
        task.delay(0.5, function()
            if obj.Parent then CheckAndAddNPC(obj) end
        end)
    end
end))
trackConnection(workspace.DescendantRemoving:Connect(RemoveNPC))

local function GetVisibility(targetId, character)
    local now = tick()
    local cached = Visibility_Cache[targetId]
    if cached and (now - cached.lastUpdate) < 0.1 then
        return cached.isVisible
    end

    local cam = workspace.CurrentCamera
    if not cam then return false end

    local partsToCheck = {
        character:FindFirstChild("Head"),
        character:FindFirstChild("HumanoidRootPart"),
        character:FindFirstChild("Right Arm") or character:FindFirstChild("RightUpperArm"),
        character:FindFirstChild("Left Arm") or character:FindFirstChild("LeftUpperArm"),
        character:FindFirstChild("Right Leg") or character:FindFirstChild("RightUpperLeg"),
        character:FindFirstChild("Left Leg") or character:FindFirstChild("LeftUpperLeg"),
    }

    local origin = cam.CFrame.Position
    local visible = false
    for _, part in ipairs(partsToCheck) do
        if part and part:IsA("BasePart") then
            local result = workspace:Raycast(origin, part.Position - origin, rayParams)
            if result and result.Instance:IsDescendantOf(character) then
                visible = true
                break
            end
        end
    end

    Visibility_Cache[targetId] = {isVisible = visible, lastUpdate = now}
    return visible
end

local function DrawESP(id, character, root, displayName, team, isNPC)
    local showBox = isNPC and LARP.Config.NPCESP or (not isNPC and LARP.Config.PlayerESP)
    local showTracer = isNPC and LARP.Config.NPCTracers or (not isNPC and LARP.Config.PlayerTracers)
    local maxDistance = isNPC and LARP.Config.NPC_ESP_MaxDistance or LARP.Config.ESP_MaxDistance
    if not showBox and not showTracer then return end

    local cam = workspace.CurrentCamera
    if not cam or not drawingAvailable then return end

    local distance = (cam.CFrame.Position - root.Position).Magnitude
    if distance > maxDistance or distance == 0 then return end

    local rootScreen, onScreen = cam:WorldToViewportPoint(root.Position)
    if not onScreen then return end

    if not ESP_Cache[id] then
        local ok, cache = pcall(function()
            return {
                Box = DrawingAPI.new("Square"),
                Text = DrawingAPI.new("Text"),
                Tracer = DrawingAPI.new("Line"),
            }
        end)
        if not ok then
            drawingAvailable = false
            return
        end
        ESP_Cache[id] = cache
        cache.Box.Thickness = 1.5
        cache.Box.Filled = false
        cache.Text.Size = 14
        cache.Text.Center = true
        cache.Text.Outline = true
        cache.Tracer.Thickness = 1.5
    end

    local cache = ESP_Cache[id]
    local top = cam:WorldToViewportPoint(root.Position + ESP_CONFIG.TOP_OFFSET)
    local bottom = cam:WorldToViewportPoint(root.Position - ESP_CONFIG.BOTTOM_OFFSET)
    local height = math.abs(bottom.Y - top.Y)
    local width = height / 2
    if height < ESP_CONFIG.MIN_HEIGHT then
        height = ESP_CONFIG.MIN_HEIGHT
        width = ESP_CONFIG.MIN_WIDTH
    end

    local visible = GetVisibility(id, character)
    local color
    if isNPC then
        color = visible and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(200, 0, 255)
    else
        color = Color3.new(1, 0, 0)
        if team == LocalPlayer.Team and team ~= nil then
            color = Color3.new(0, 0.5, 1)
        elseif visible then
            color = Color3.new(0, 1, 0)
        end
    end

    if showBox then
        cache.Box.Size = Vector2.new(width, height)
        cache.Box.Position = Vector2.new(rootScreen.X - width / 2, top.Y)
        cache.Box.Color = color
        cache.Box.Visible = true

        local prefix = isNPC and "[NPC] " or ""
        cache.Text.Text = string.format("%s%s [%dm]", prefix, displayName,
            math.floor(distance / ESP_CONFIG.DISTANCE_DIVISOR))
        cache.Text.Position = Vector2.new(rootScreen.X, top.Y - 18)
        cache.Text.Color = color
        cache.Text.Visible = true
    else
        cache.Box.Visible = false
        cache.Text.Visible = false
    end

    if showTracer then
        cache.Tracer.From = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
        cache.Tracer.To = Vector2.new(rootScreen.X, bottom.Y)
        cache.Tracer.Color = color
        cache.Tracer.Visible = true
    else
        cache.Tracer.Visible = false
    end
end

local function GetClosestTarget()
    if not LARP.Config.Aimbot.Enabled then return nil end
    local cam = workspace.CurrentCamera
    if not cam then return nil end

    local targetPart = nil
    local shortest = LARP.Config.Aimbot.FOV
    local mousePos = UserInputService:GetMouseLocation()

    local function checkTarget(id, character)
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return end
        local part = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
        if not part then return end

        local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
        if not onScreen then return end

        local distanceToMouse = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
        if distanceToMouse >= shortest then return end
        if LARP.Config.Aimbot.WallCheck and not GetVisibility(id, character) then return end

        targetPart = part
        shortest = distanceToMouse
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            if player.Team == nil or player.Team ~= LocalPlayer.Team then
                checkTarget(tostring(player.UserId), player.Character)
            end
        end
    end

    if LARP.Config.Aimbot.TargetNPCs then
        for npc in pairs(Tracked_NPCs) do
            if npc.Parent then checkTarget(npc, npc) end
        end
    end
    return targetPart
end

trackConnection(RunService.RenderStepped:Connect(function()
    local camera = workspace.CurrentCamera
    refreshRayFilter()

    local mousePos = UserInputService:GetMouseLocation()
    if FOVCircle then
        FOVCircle.Visible = LARP.Config.Aimbot.ShowFOV
        if LARP.Config.Aimbot.ShowFOV then
            FOVCircle.Position = mousePos
            FOVCircle.Radius = LARP.Config.Aimbot.FOV
        end
    end

    if LARP.Config.Fullbright then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
    else
        Lighting.Ambient = OriginalAmbient
        Lighting.Brightness = OriginalBrightness
    end

    for id in pairs(ESP_Cache) do HideESP(id) end

    if camera then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    DrawESP(tostring(player.UserId), player.Character, root,
                        player.Name, player.Team, false)
                end
            end
        end

        for npc in pairs(Tracked_NPCs) do
            if npc.Parent then
                local humanoid = npc:FindFirstChildOfClass("Humanoid")
                local root = npc:FindFirstChild("HumanoidRootPart")
                if humanoid and humanoid.Health > 0 and root then
                    DrawESP(npc, npc, root, npc.Name, nil, true)
                else
                    HideESP(npc)
                end
            end
        end
    end

    if LARP.Config.Aimbot.Enabled
        and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        and type(mousemoverel) == "function"
        and camera then

        local aimTarget = GetClosestTarget()
        if aimTarget then
            local aimPosition = aimTarget.Position
            if LARP.Config.Aimbot.Prediction then
                local distance = (aimPosition - camera.CFrame.Position).Magnitude
                local speed = math.max(LARP.Config.Aimbot.BulletSpeed, MIN_BULLET_SPEED)
                aimPosition += aimTarget.AssemblyLinearVelocity * (distance / speed)
            end

            local screenPos, onScreen = camera:WorldToViewportPoint(aimPosition)
            if onScreen then
                local moveX = (screenPos.X - mousePos.X) * LARP.Config.Aimbot.Smoothing
                local moveY = (screenPos.Y - mousePos.Y) * LARP.Config.Aimbot.Smoothing
                mousemoverel(moveX, moveY)
            end
        end
    end
end))

-- ======================== ANTI AIM + DESYNC (from v0.2) ========================
function LARP:BindAntiAimRemote(remote)
    assert(typeof(remote) == "Instance" and remote:IsA("RemoteEvent"),
        "BindAntiAimRemote expects a RemoteEvent")
    self.AntiAimRemote = remote
    self:PushAntiAimConfig()
end

function LARP:PushAntiAimConfig()
    if not self.AntiAimRemote then
        log("Anti Aim config changed locally; no server RemoteEvent is bound.")
        return false
    end

    local config = self.Config.AntiAim
    local payload = {
        Enabled = config.Enabled == true,
        Pitch = config.Pitch,
        Yaw = config.Yaw,
        YawOffset = math.clamp(tonumber(config.YawOffset) or 0, -180, 180),
        SpinSpeed = math.clamp(tonumber(config.SpinSpeed) or 180, 0, 720),
        Jitter = config.Jitter == true,
        JitterAmount = math.clamp(tonumber(config.JitterAmount) or 30, 0, 180),
        BodyYaw = config.BodyYaw == true,
        BodyYawAmount = math.clamp(tonumber(config.BodyYawAmount) or 0, -180, 180),
        Inverter = config.Inverter == true,
        Conditions = {
            Standing = config.Conditions.Standing == true,
            Moving = config.Conditions.Moving == true,
            InAir = config.Conditions.InAir == true,
        },
    }
    self.AntiAimRemote:FireServer(payload)
    return true
end

function LARP:SetAntiAimEnabled(enabled)
    self.Config.AntiAim.Enabled = enabled == true
    return self:PushAntiAimConfig()
end

function LARP:SetAntiAimOption(option, value)
    local config = self.Config.AntiAim
    if config[option] == nil then
        warn("[LARP] Unknown Anti Aim option: " .. tostring(option))
        return false
    end
    config[option] = value
    return self:PushAntiAimConfig()
end

local function destroyMarkerSet(player)
    local markerSet = LARP.DesyncMarkers[player]
    if not markerSet then return end
    for _, object in pairs(markerSet) do
        if typeof(object) == "Instance" then
            pcall(function() object:Destroy() end)
        end
    end
    LARP.DesyncMarkers[player] = nil
end

local function makeMarker(name, color, size)
    local part = Instance.new("Part")
    part.Name = name
    part.Shape = Enum.PartType.Ball
    part.Size = Vector3.new(size, size, size)
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Material = Enum.Material.Neon
    part.Color = color
    part.Transparency = 0.15
    part.Parent = workspace
    return part
end

local function makeLine(name, color)
    local holder = Instance.new("Part")
    holder.Name = name
    holder.Anchored = true
    holder.CanCollide = false
    holder.CanTouch = false
    holder.CanQuery = false
    holder.Transparency = 1
    holder.Size = Vector3.new(0.05, 0.05, 0.05)
    holder.Parent = workspace

    local a0 = Instance.new("Attachment")
    a0.Parent = holder
    local a1 = Instance.new("Attachment")
    a1.Parent = holder

    local beam = Instance.new("Beam")
    beam.Name = "DesyncBeam"
    beam.Attachment0 = a0
    beam.Attachment1 = a1
    beam.Color = ColorSequence.new(color)
    beam.Width0 = 0.045
    beam.Width1 = 0.045
    beam.FaceCamera = true
    beam.Parent = holder

    return holder, a0, a1
end

local function ensureMarkerSet(player)
    local set = LARP.DesyncMarkers[player]
    if set then return set end

    local cfg = LARP.Config.DesyncESP
    local realMarker = makeMarker("LARP_RealPosition", cfg.RealColor, 0.65)
    local fakeMarker = makeMarker("LARP_FakePosition", cfg.FakeColor, 0.65)

    local nameGui = Instance.new("BillboardGui")
    nameGui.Name = "LARP_DesyncName"
    nameGui.Size = UDim2.fromOffset(150, 28)
    nameGui.StudsOffset = Vector3.new(0, 1.1, 0)
    nameGui.AlwaysOnTop = true
    nameGui.Adornee = fakeMarker
    nameGui.Parent = fakeMarker

    local nameLabel = Instance.new("TextLabel")
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.fromScale(1, 1)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 13
    nameLabel.TextColor3 = cfg.FakeColor
    nameLabel.TextStrokeTransparency = 0.25
    nameLabel.Parent = nameGui

    set = {
        Real = realMarker,
        Fake = fakeMarker,
        NameGui = nameGui,
        NameLabel = nameLabel,
        LineHolder = nil,
        LineA0 = nil,
        LineA1 = nil,
    }
    set.LineHolder, set.LineA0, set.LineA1 = makeLine("LARP_DesyncLine", cfg.FakeColor)
    LARP.DesyncMarkers[player] = set
    return set
end

local function hideMarkerSet(set)
    if not set then return end
    set.Real.Transparency = 1
    set.Fake.Transparency = 1
    set.LineHolder.Transparency = 1
    local beam = set.LineHolder:FindFirstChild("DesyncBeam")
    if beam then beam.Enabled = false end
end

function LARP:BindDesyncRemote(remote)
    assert(typeof(remote) == "Instance" and remote:IsA("RemoteEvent"),
        "BindDesyncRemote expects a RemoteEvent")

    self.DesyncRemote = remote
    trackConnection(remote.OnClientEvent:Connect(function(targetPlayer, realPosition, fakePosition)
        if self.Unloaded or not self.Config.DesyncESP.Enabled then return end
        if typeof(targetPlayer) ~= "Instance" or not targetPlayer:IsA("Player") then return end
        if targetPlayer == LocalPlayer then return end
        if typeof(realPosition) ~= "Vector3" or typeof(fakePosition) ~= "Vector3" then return end

        local camera = workspace.CurrentCamera
        local maxDistance = self.Config.DesyncESP.MaxDistance
        if camera and (camera.CFrame.Position - realPosition).Magnitude > maxDistance then
            destroyMarkerSet(targetPlayer)
            return
        end

        local cfg = self.Config.DesyncESP
        local set = ensureMarkerSet(targetPlayer)
        set.Real.Position = realPosition
        set.Fake.Position = fakePosition
        set.Real.Color = cfg.RealColor
        set.Fake.Color = cfg.FakeColor
        set.Real.Transparency = cfg.ShowReal and 0.15 or 1
        set.Fake.Transparency = cfg.ShowFake and 0.15 or 1
        set.NameGui.Enabled = cfg.ShowNames and cfg.ShowFake
        set.NameLabel.Text = targetPlayer.DisplayName
        set.NameLabel.TextColor3 = cfg.FakeColor

        set.LineA0.WorldPosition = realPosition
        set.LineA1.WorldPosition = fakePosition
        local beam = set.LineHolder:FindFirstChild("DesyncBeam")
        if beam then
            beam.Enabled = cfg.ShowLine
            beam.Color = ColorSequence.new(cfg.FakeColor)
        end
        set.LineHolder.Transparency = 1
    end))
end

function LARP:SetDesyncESPEnabled(enabled)
    self.Config.DesyncESP.Enabled = enabled == true
    if not enabled then
        for _, set in pairs(self.DesyncMarkers) do
            hideMarkerSet(set)
        end
    end
end

trackConnection(Players.PlayerRemoving:Connect(function(player)
    destroyMarkerSet(player)
end))

-- ======================== UI (Neverlose style) ========================
local ParentContainer
pcall(function()
    if gethui then
        ParentContainer = gethui()
    else
        ParentContainer = game:GetService("CoreGui")
    end
end)
if not ParentContainer then
    ParentContainer = LocalPlayer:WaitForChild("PlayerGui")
end

local oldGui = ParentContainer:FindFirstChild("LARPUI")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LARPUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 100
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = ParentContainer

local C = {
    main = Color3.fromRGB(8, 14, 23),
    side = Color3.fromRGB(15, 25, 38),
    content = Color3.fromRGB(5, 9, 15),
    panel = Color3.fromRGB(13, 22, 34),
    row = Color3.fromRGB(18, 31, 46),
    accent = Color3.fromRGB(0, 170, 255),
    white = Color3.fromRGB(240, 245, 250),
    muted = Color3.fromRGB(120, 140, 160),
}

local function corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = obj
end

local function makeLabel(parent, text, size, pos, color, font, textSize)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = size
    label.Position = pos
    label.Text = text
    label.TextColor3 = color or C.white
    label.Font = font or Enum.Font.Gotham
    label.TextSize = textSize or 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
    return label
end

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.fromOffset(850, 700)
MainFrame.Position = UDim2.new(0.5, -425, 0.5, -350)
MainFrame.BackgroundColor3 = C.main
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Active = true
MainFrame.Visible = false
MainFrame.Parent = ScreenGui
corner(MainFrame, 7)

local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 200, 1, 0)
Sidebar.BackgroundColor3 = C.side
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

makeLabel(Sidebar, "LARP", UDim2.new(1, -20, 0, 60), UDim2.fromOffset(16, 0),
    C.white, Enum.Font.GothamBold, 26)

local MenuContainer = Instance.new("ScrollingFrame")
MenuContainer.Name = "MenuContainer"
MenuContainer.Size = UDim2.new(1, 0, 1, -125)
MenuContainer.Position = UDim2.fromOffset(0, 60)
MenuContainer.BackgroundTransparency = 1
MenuContainer.BorderSizePixel = 0
MenuContainer.ScrollBarThickness = 3
MenuContainer.CanvasSize = UDim2.new()
MenuContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
MenuContainer.Parent = Sidebar

local menuLayout = Instance.new("UIListLayout")
menuLayout.SortOrder = Enum.SortOrder.LayoutOrder
menuLayout.Padding = UDim.new(0, 2)
menuLayout.Parent = MenuContainer

local menuPadding = Instance.new("UIPadding")
menuPadding.PaddingLeft = UDim.new(0, 10)
menuPadding.PaddingRight = UDim.new(0, 10)
menuPadding.Parent = MenuContainer

local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -200, 1, 0)
ContentArea.Position = UDim2.fromOffset(200, 0)
ContentArea.BackgroundColor3 = C.content
ContentArea.BorderSizePixel = 0
ContentArea.Parent = MainFrame

local ProfileFrame = Instance.new("Frame")
ProfileFrame.Size = UDim2.new(1, 0, 0, 60)
ProfileFrame.Position = UDim2.new(0, 0, 1, -60)
ProfileFrame.BackgroundTransparency = 1
ProfileFrame.Parent = Sidebar

local AvatarImage = Instance.new("ImageLabel")
AvatarImage.Size = UDim2.fromOffset(38, 38)
AvatarImage.Position = UDim2.fromOffset(14, 11)
AvatarImage.BackgroundColor3 = C.row
AvatarImage.BorderSizePixel = 0
AvatarImage.Parent = ProfileFrame
corner(AvatarImage, 20)

task.spawn(function()
    local ok, image = pcall(function()
        return Players:GetUserThumbnailAsync(
            LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420
        )
    end)
    if ok then AvatarImage.Image = image end
end)

makeLabel(ProfileFrame, LocalPlayer.Name, UDim2.new(1, -65, 0, 18),
    UDim2.fromOffset(60, 11), C.white, Enum.Font.GothamBold, 13)
makeLabel(ProfileFrame, "LARP • READY", UDim2.new(1, -65, 0, 16),
    UDim2.fromOffset(60, 30), C.accent, Enum.Font.Gotham, 11)

local pages = {}
local activeTabButton, activeTabText
local order = 0

local function createCategory(name)
    order += 1
    local label = makeLabel(MenuContainer, name:upper(), UDim2.new(1, 0, 0, 26),
        UDim2.new(), Color3.fromRGB(65, 85, 110), Enum.Font.GothamBold, 11)
    label.LayoutOrder = order
end

local function createPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name .. "Page"
    page.Size = UDim2.new(1, -32, 1, -65)
    page.Position = UDim2.fromOffset(16, 52)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.CanvasSize = UDim2.new()
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = ContentArea
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page
    pages[name] = page
    return page
end

local function selectTab(name, button, textLabel)
    if activeTabButton then
        activeTabButton.BackgroundTransparency = 1
        activeTabText.TextColor3 = C.muted
    end
    for _, page in pairs(pages) do page.Visible = false end
    button.BackgroundTransparency = 0
    button.BackgroundColor3 = Color3.fromRGB(13, 40, 65)
    textLabel.TextColor3 = C.white
    activeTabButton, activeTabText = button, textLabel
    pages[name].Visible = true
end

local function createTab(name, iconId)
    order += 1
    local button = Instance.new("TextButton")
    button.Name = name .. "Tab"
    button.Size = UDim2.new(1, 0, 0, 34)
    button.BackgroundColor3 = Color3.fromRGB(13, 40, 65)
    button.BackgroundTransparency = 1
    button.Text = ""
    button.AutoButtonColor = false
    button.BorderSizePixel = 0
    button.LayoutOrder = order
    button.Parent = MenuContainer
    corner(button, 6)

    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.fromOffset(18, 18)
    icon.Position = UDim2.new(0, 12, 0.5, -9)
    icon.BackgroundTransparency = 1
    icon.Image = iconId or ""
    icon.ImageColor3 = C.accent
    icon.Parent = button

    local textLabel = makeLabel(button, name, UDim2.new(1, -45, 1, 0),
        UDim2.fromOffset(38, 0), C.muted, Enum.Font.GothamMedium, 13)
    button.MouseButton1Click:Connect(function()
        selectTab(name, button, textLabel)
    end)
    local page = createPage(name)
    return page, button, textLabel
end

local function createSection(page, title)
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, 0, 0, 10)
    section.AutomaticSize = Enum.AutomaticSize.Y
    section.BackgroundColor3 = C.panel
    section.BorderSizePixel = 0
    section.Parent = page
    corner(section, 6)

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = section

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 9)
    pad.PaddingBottom = UDim.new(0, 9)
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.Parent = section

    local titleLabel = makeLabel(section, title, UDim2.new(1, 0, 0, 22),
        UDim2.new(), C.accent, Enum.Font.GothamBold, 13)
    titleLabel.LayoutOrder = 0
    return section
end

local function createToggle(section, title, getter, setter)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 30)
    row.BackgroundTransparency = 1
    row.Parent = section

    makeLabel(row, title, UDim2.new(1, -75, 1, 0), UDim2.new(),
        C.white, Enum.Font.Gotham, 12)

    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(54, 22)
    button.Position = UDim2.new(1, -54, 0.5, -11)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.TextSize = 10
    button.Parent = row
    corner(button, 5)

    local function refresh()
        local enabled = getter()
        button.Text = enabled and "ON" or "OFF"
        button.BackgroundColor3 = enabled and Color3.fromRGB(20, 105, 75)
            or Color3.fromRGB(65, 45, 55)
        button.TextColor3 = C.white
    end
    button.MouseButton1Click:Connect(function()
        setter(not getter())
        refresh()
    end)
    refresh()
    return refresh
end

local function createSlider(section, title, minValue, maxValue, initial, setter)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 48)
    row.BackgroundTransparency = 1
    row.Parent = section

    local value = initial
    local titleLabel = makeLabel(row, title .. ": " .. tostring(value),
        UDim2.new(1, 0, 0, 18), UDim2.new(), C.white, Enum.Font.Gotham, 12)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 7)
    bar.Position = UDim2.fromOffset(0, 29)
    bar.BackgroundColor3 = Color3.fromRGB(35, 49, 65)
    bar.BorderSizePixel = 0
    bar.Parent = row
    corner(bar, 4)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((value - minValue) / (maxValue - minValue), 0, 1, 0)
    fill.BackgroundColor3 = C.accent
    fill.BorderSizePixel = 0
    fill.Parent = bar
    corner(fill, 4)

    local dragging = false
    local function setFromX(x)
        local alpha = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        value = minValue + (maxValue - minValue) * alpha
        if maxValue - minValue > 10 then value = math.floor(value + 0.5)
        else value = math.floor(value * 100 + 0.5) / 100 end
        fill.Size = UDim2.new((value - minValue) / (maxValue - minValue), 0, 1, 0)
        titleLabel.Text = title .. ": " .. tostring(value)
        setter(value)
    end
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            setFromX(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            setFromX(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end

-- Tabs
createCategory("Aimbot")
local ragePage, rageButton, rageText = createTab("Ragebot", "rbxassetid://11738355467")
createTab("Anti Aim", "rbxassetid://131818722808112")
createTab("Legitbot", "rbxassetid://10088146939")

createCategory("Visuals")
local playersPage = createTab("Players", "rbxassetid://117259180607823")
createTab("Weapon", "rbxassetid://97190175392549")
createTab("Grenades", "rbxassetid://13424571211")
createTab("Bomb", "rbxassetid://103342882158009")
local worldPage = createTab("World", "rbxassetid://4830959433")
createTab("View", "rbxassetid://6266103551")

createCategory("Miscellaneous")
local mainPage = createTab("Main", "rbxassetid://12403104094")
createTab("Inventory", "rbxassetid://13747709452")
createTab("Scripts", "rbxassetid://137649072568517")
local configsPage = createTab("Configs", "rbxassetid://9405931578")

-- Aimbot section
local aimSection = createSection(ragePage, "AIMBOT")
createToggle(aimSection, "Aimbot (Hold Right Click)", function() return LARP.Config.Aimbot.Enabled end,
    function(v) LARP.Config.Aimbot.Enabled = v end)
createToggle(aimSection, "Wall Check", function() return LARP.Config.Aimbot.WallCheck end,
    function(v) LARP.Config.Aimbot.WallCheck = v end)
createToggle(aimSection, "Target NPCs", function() return LARP.Config.Aimbot.TargetNPCs end,
    function(v) LARP.Config.Aimbot.TargetNPCs = v end)
createToggle(aimSection, "Prediction", function() return LARP.Config.Aimbot.Prediction end,
    function(v) LARP.Config.Aimbot.Prediction = v end)
createToggle(aimSection, "Show FOV Circle", function() return LARP.Config.Aimbot.ShowFOV end,
    function(v) LARP.Config.Aimbot.ShowFOV = v end)
createSlider(aimSection, "FOV Radius", 50, 800, LARP.Config.Aimbot.FOV, function(v) LARP.Config.Aimbot.FOV = v end)
createSlider(aimSection, "Smoothing", 0.1, 1, LARP.Config.Aimbot.Smoothing, function(v) LARP.Config.Aimbot.Smoothing = v end)
createSlider(aimSection, "Bullet Speed", 100, 5000, LARP.Config.Aimbot.BulletSpeed,
    function(v) LARP.Config.Aimbot.BulletSpeed = math.max(v, MIN_BULLET_SPEED) end)

-- Player ESP
local playerSection = createSection(playersPage, "PLAYER ESP")
createToggle(playerSection, "Player ESP Boxes + Names", function() return LARP.Config.PlayerESP end,
    function(v) LARP.Config.PlayerESP = v end)
createToggle(playerSection, "Player Tracers", function() return LARP.Config.PlayerTracers end,
    function(v) LARP.Config.PlayerTracers = v end)
createSlider(playerSection, "Player ESP Max Distance", 100, 5000, 5000,
    function(v) LARP.Config.ESP_MaxDistance = v end)

-- NPC ESP + Fullbright + Target Marker
local npcSection = createSection(worldPage, "NPC ESP / WORLD")
createToggle(npcSection, "NPC ESP Boxes + Names", function() return LARP.Config.NPCESP end,
    function(v) LARP.Config.NPCESP = v end)
createToggle(npcSection, "NPC Tracers", function() return LARP.Config.NPCTracers end,
    function(v) LARP.Config.NPCTracers = v end)
createSlider(npcSection, "NPC ESP Max Distance", 50, 5000, LARP.Config.NPC_ESP_MaxDistance,
    function(v) LARP.Config.NPC_ESP_MaxDistance = v end)
createToggle(npcSection, "Fullbright", function() return LARP.Config.Fullbright end,
    function(v) LARP.Config.Fullbright = v end)
createToggle(npcSection, "Target Marker ESP", function() return targetesp.Enabled end,
    function(v)
        targetesp.Enabled = v
        LARP.Config.TargetMarker = v
        if not v then setTarget(nil) end
    end)

-- Anti Aim section
local aaPage = pages["Anti Aim"]
local aaSection = createSection(aaPage, "ANTI AIM (Server)")
createToggle(aaSection, "Anti Aim Enabled", function() return LARP.Config.AntiAim.Enabled end,
    function(v) LARP:SetAntiAimEnabled(v) end)
createToggle(aaSection, "Jitter", function() return LARP.Config.AntiAim.Jitter end,
    function(v) LARP:SetAntiAimOption("Jitter", v) end)
createToggle(aaSection, "Body Yaw", function() return LARP.Config.AntiAim.BodyYaw end,
    function(v) LARP:SetAntiAimOption("BodyYaw", v) end)
createToggle(aaSection, "Inverter", function() return LARP.Config.AntiAim.Inverter end,
    function(v) LARP:SetAntiAimOption("Inverter", v) end)
createSlider(aaSection, "Yaw Offset", -180, 180, LARP.Config.AntiAim.YawOffset,
    function(v) LARP:SetAntiAimOption("YawOffset", v) end)
createSlider(aaSection, "Spin Speed", 0, 720, LARP.Config.AntiAim.SpinSpeed,
    function(v) LARP:SetAntiAimOption("SpinSpeed", v) end)
createSlider(aaSection, "Jitter Amount", 0, 180, LARP.Config.AntiAim.JitterAmount,
    function(v) LARP:SetAntiAimOption("JitterAmount", v) end)

-- Desync ESP
local desyncSection = createSection(aaPage, "DESYNC ESP (Server)")
createToggle(desyncSection, "Desync ESP Enabled", function() return LARP.Config.DesyncESP.Enabled end,
    function(v) LARP:SetDesyncESPEnabled(v) end)
createToggle(desyncSection, "Show Real", function() return LARP.Config.DesyncESP.ShowReal end,
    function(v) LARP.Config.DesyncESP.ShowReal = v end)
createToggle(desyncSection, "Show Fake", function() return LARP.Config.DesyncESP.ShowFake end,
    function(v) LARP.Config.DesyncESP.ShowFake = v end)
createToggle(desyncSection, "Show Line", function() return LARP.Config.DesyncESP.ShowLine end,
    function(v) LARP.Config.DesyncESP.ShowLine = v end)
createToggle(desyncSection, "Show Names", function() return LARP.Config.DesyncESP.ShowNames end,
    function(v) LARP.Config.DesyncESP.ShowNames = v end)

-- Configs help
local configSection = createSection(configsPage, "LARP")
makeLabel(configSection, "Menu toggle: RIGHT SHIFT", UDim2.new(1, 0, 0, 22),
    UDim2.new(), C.white, Enum.Font.Gotham, 12)
makeLabel(configSection, "Anti Aim / Desync требуют RemoteEvent на сервере.",
    UDim2.new(1, 0, 0, 22), UDim2.new(), C.muted, Enum.Font.Gotham, 11)

-- Default tab
ragePage.Visible = true
rageButton.BackgroundTransparency = 0
rageText.TextColor3 = C.white
activeTabButton, activeTabText = rageButton, rageText

-- Drag
local dragBar = Instance.new("Frame")
dragBar.Size = UDim2.new(1, -200, 0, 45)
dragBar.Position = UDim2.fromOffset(200, 0)
dragBar.BackgroundTransparency = 1
dragBar.Active = true
dragBar.Parent = MainFrame
makeLabel(ContentArea, "LARP  /  CONTROL PANEL", UDim2.new(1, -32, 0, 34),
    UDim2.fromOffset(16, 7), C.white, Enum.Font.GothamBold, 17)

do
    local dragging, dragStart, startPos = false, nil, nil
    dragBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end

-- Menu toggle
trackConnection(UserInputService.InputBegan:Connect(function(input, processed)
    if processed or LARP.Unloaded then return end
    if input.KeyCode == LARP.Config.MenuKey then
        MainFrame.Visible = not MainFrame.Visible
        LARP.MenuOpen = MainFrame.Visible
    end
end))

-- Unload
function LARP:Unload()
    if self.Unloaded then return end
    self.Unloaded = true

    for _, connection in ipairs(self.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(self.Connections)

    for player in pairs(self.DesyncMarkers) do
        destroyMarkerSet(player)
    end

    if ScreenGui then ScreenGui:Destroy() end
    log("Unloaded.")
end

log(("Loaded %s v%s for %s"):format(LARP.Name, LARP.Version, LocalPlayer and LocalPlayer.Name or "player"))
LARP:Notify("LARP 0.3.0 loaded (Nebula + Anti Aim + Desync)", 4)

return LARP
