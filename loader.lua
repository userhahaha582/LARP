--[[
    LARP | Script Hub Loader
    Select a script from the list, then press LOAD.
    Repository: https://github.com/userhahaha582/LARP
]]

local BASE_URL = "https://raw.githubusercontent.com/userhahaha582/LARP/main/"

-- Add more scripts here. Each file must exist in the repository root.
local SCRIPT_LIST = {
    { Name = "LARP", File = "LARP.lua", Description = "Main LARP client" },
    { Name = "Special Script", File = "Special.lua", Description = "Your selected special script" },
}

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

local function notify(message)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "LARP",
            Text = tostring(message),
            Duration = 4
        })
    end)
end

-- Remove previous UI instance.
local coreGui = game:GetService("CoreGui")
local old = coreGui:FindFirstChild("LARP_ScriptHub")
if old then old:Destroy() end
if player and player:FindFirstChild("PlayerGui") then
    local oldPlayerGui = player.PlayerGui:FindFirstChild("LARP_ScriptHub")
    if oldPlayerGui then oldPlayerGui:Destroy() end
end

local gui = Instance.new("ScreenGui")
gui.Name = "LARP_ScriptHub"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local parented = pcall(function() gui.Parent = coreGui end)
if not parented then gui.Parent = player:WaitForChild("PlayerGui") end

local function make(className, props, parent)
    local obj = Instance.new(className)
    for key, value in pairs(props) do
        obj[key] = value
    end
    obj.Parent = parent
    return obj
end

local function corner(parent, radius)
    make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function outline(parent, color, thickness, transparency)
    make("UIStroke", {
        Color = color,
        Thickness = thickness or 1,
        Transparency = transparency or 0
    }, parent)
end

local C = {
    Background = Color3.fromRGB(12, 15, 23),
    Panel = Color3.fromRGB(18, 23, 35),
    Panel2 = Color3.fromRGB(24, 31, 47),
    Accent = Color3.fromRGB(83, 128, 255),
    AccentDark = Color3.fromRGB(48, 83, 181),
    Text = Color3.fromRGB(239, 243, 255),
    Muted = Color3.fromRGB(139, 151, 178),
    Border = Color3.fromRGB(43, 55, 79),
    Green = Color3.fromRGB(105, 220, 165),
}

local main = make("Frame", {
    Name = "Window",
    Size = UDim2.fromOffset(390, 300),
    Position = UDim2.new(0.5, -195, 0.5, -150),
    BackgroundColor3 = C.Background,
    BorderSizePixel = 0,
}, gui)
corner(main, 12)
outline(main, C.Border, 1)

local top = make("Frame", {
    Size = UDim2.new(1, 0, 0, 62),
    BackgroundColor3 = C.Panel,
    BorderSizePixel = 0,
}, main)
corner(top, 12)

make("Frame", {
    Position = UDim2.new(0, 0, 1, -12),
    Size = UDim2.new(1, 0, 0, 12),
    BackgroundColor3 = C.Panel,
    BorderSizePixel = 0,
}, top)

local logo = make("Frame", {
    Position = UDim2.fromOffset(17, 15),
    Size = UDim2.fromOffset(32, 32),
    BackgroundColor3 = C.AccentDark,
    BorderSizePixel = 0,
}, top)
corner(logo, 9)
make("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    Font = Enum.Font.GothamBlack,
    Text = "L",
    TextColor3 = C.Text,
    TextSize = 20,
}, logo)

make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(59, 12),
    Size = UDim2.fromOffset(220, 22),
    Font = Enum.Font.GothamBold,
    Text = "LARP",
    TextColor3 = C.Text,
    TextSize = 17,
    TextXAlignment = Enum.TextXAlignment.Left,
}, top)

make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(60, 34),
    Size = UDim2.fromOffset(230, 16),
    Font = Enum.Font.Gotham,
    Text = "SCRIPT HUB  /  LOADER",
    TextColor3 = C.Muted,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
}, top)

local close = make("TextButton", {
    Position = UDim2.new(1, -43, 0, 15),
    Size = UDim2.fromOffset(28, 28),
    BackgroundColor3 = C.Panel2,
    BorderSizePixel = 0,
    Text = "×",
    TextColor3 = C.Muted,
    TextSize = 20,
    Font = Enum.Font.Gotham,
    AutoButtonColor = true,
}, top)
corner(close, 7)
close.MouseButton1Click:Connect(function() gui:Destroy() end)

make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(20, 78),
    Size = UDim2.new(1, -40, 0, 22),
    Font = Enum.Font.GothamBold,
    Text = "SELECT YOUR SCRIPT",
    TextColor3 = C.Text,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
}, main)

make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(20, 101),
    Size = UDim2.new(1, -40, 0, 18),
    Font = Enum.Font.Gotham,
    Text = "Choose a script below. LOAD will launch your selection.",
    TextColor3 = C.Muted,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
}, main)

local selectedIndex = 1
local dropdownOpen = false

local selector = make("TextButton", {
    Position = UDim2.fromOffset(20, 132),
    Size = UDim2.new(1, -40, 0, 48),
    BackgroundColor3 = C.Panel2,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
}, main)
corner(selector, 8)
outline(selector, C.Border, 1)

local selectedName = make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(14, 5),
    Size = UDim2.new(1, -48, 0, 20),
    Font = Enum.Font.GothamBold,
    TextColor3 = C.Text,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = SCRIPT_LIST[1].Name,
}, selector)

local selectedDescription = make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(14, 25),
    Size = UDim2.new(1, -48, 0, 15),
    Font = Enum.Font.Gotham,
    TextColor3 = C.Muted,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = SCRIPT_LIST[1].Description,
}, selector)

local arrow = make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -34, 0, 0),
    Size = UDim2.fromOffset(22, 48),
    Font = Enum.Font.GothamBold,
    Text = "⌄",
    TextColor3 = C.Muted,
    TextSize = 17,
}, selector)

local options = make("Frame", {
    Position = UDim2.fromOffset(20, 184),
    Size = UDim2.new(1, -40, 0, 0),
    BackgroundColor3 = C.Panel,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Visible = false,
    ZIndex = 10,
}, main)
corner(options, 8)
outline(options, C.Border, 1)

local function refreshSelected()
    local item = SCRIPT_LIST[selectedIndex]
    selectedName.Text = item.Name
    selectedDescription.Text = item.Description
end

local function closeDropdown()
    dropdownOpen = false
    options.Visible = false
    options.Size = UDim2.new(1, -40, 0, 0)
    arrow.Text = "⌄"
end

local function openDropdown()
    dropdownOpen = true
    options.Visible = true
    options.Size = UDim2.new(1, -40, 0, math.min(#SCRIPT_LIST * 39, 156))
    arrow.Text = "⌃"
end

for i, item in ipairs(SCRIPT_LIST) do
    local option = make("TextButton", {
        Position = UDim2.fromOffset(5, (i - 1) * 39 + 4),
        Size = UDim2.new(1, -10, 0, 35),
        BackgroundColor3 = C.Panel2,
        BorderSizePixel = 0,
        Text = item.Name,
        TextColor3 = C.Text,
        TextSize = 11,
        Font = Enum.Font.GothamSemibold,
        AutoButtonColor = true,
        ZIndex = 11,
    }, options)
    corner(option, 6)
    option.MouseButton1Click:Connect(function()
        selectedIndex = i
        refreshSelected()
        closeDropdown()
    end)
end

selector.MouseButton1Click:Connect(function()
    if dropdownOpen then closeDropdown() else openDropdown() end
end)

local loadButton = make("TextButton", {
    Position = UDim2.fromOffset(20, 196),
    Size = UDim2.new(1, -40, 0, 43),
    BackgroundColor3 = C.AccentDark,
    BorderSizePixel = 0,
    Text = "LOAD  →",
    TextColor3 = C.Text,
    TextSize = 12,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = true,
}, main)
corner(loadButton, 8)

local status = make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(20, 247),
    Size = UDim2.new(1, -40, 0, 18),
    Font = Enum.Font.Gotham,
    Text = "●  READY",
    TextColor3 = C.Green,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
}, main)

local loading = false
loadButton.MouseButton1Click:Connect(function()
    if loading then return end
    closeDropdown()

    local item = SCRIPT_LIST[selectedIndex]
    loading = true
    loadButton.Text = "LOADING..."
    loadButton.AutoButtonColor = false
    status.TextColor3 = C.Muted
    status.Text = "●  DOWNLOADING " .. string.upper(item.Name)

    local url = BASE_URL .. item.File
    local ok, source = pcall(function()
        return game:HttpGet(url)
    end)

    if not ok or type(source) ~= "string" or #source == 0 then
        status.TextColor3 = Color3.fromRGB(255, 125, 125)
        status.Text = "●  DOWNLOAD FAILED - CHECK FILE: " .. item.File
        warn("[LARP] Download failed:", source)
    else
        local compileOk, chunkOrError = pcall(loadstring, source)
        if not compileOk or type(chunkOrError) ~= "function" then
            status.TextColor3 = Color3.fromRGB(255, 125, 125)
            status.Text = "●  COMPILE ERROR"
            warn("[LARP] Compile error:", chunkOrError)
        else
            status.TextColor3 = C.Green
            status.Text = "●  STARTING " .. string.upper(item.Name)
            local runOk, runError = pcall(chunkOrError)
            if not runOk then
                status.TextColor3 = Color3.fromRGB(255, 125, 125)
                status.Text = "●  SCRIPT ERROR"
                warn("[LARP] Runtime error:", runError)
            else
                status.TextColor3 = C.Green
                status.Text = "●  " .. string.upper(item.Name) .. " LOADED"
            end
        end
    end

    loading = false
    loadButton.Text = "LOAD  →"
    loadButton.AutoButtonColor = true
end)

-- Drag window from header.
local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
top.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

top.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging and (input == dragInput or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

notify("Select a script, then press LOAD.")
