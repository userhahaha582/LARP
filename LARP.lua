--[[
    LARP - Base
    Version: 0.1.0
    Repository: https://github.com/userhahaha582/LARP

    This is a clean starter foundation. Add your own Roblox experience
    features in the sections marked below. Test in a private place first.
]]

local LARP = {
    Name = "LARP",
    Version = "0.1.0",
    Unloaded = false,
    Connections = {},
}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local function log(message)
    print(("[LARP] %s"):format(tostring(message)))
end

local function trackConnection(connection)
    table.insert(LARP.Connections, connection)
    return connection
end

function LARP:Notify(message, duration)
    -- Simple built-in notification; replace with your custom UI later.
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = self.Name,
            Text = tostring(message),
            Duration = duration or 3,
        })
    end)
end

function LARP:Unload()
    if self.Unloaded then
        return
    end
    self.Unloaded = true

    for _, connection in ipairs(self.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(self.Connections)

    log("Unloaded.")
end

-- Right Shift demo toggle. Replace this with the full LARP menu.
LARP.MenuOpen = false
trackConnection(UserInputService.InputBegan:Connect(function(input, processed)
    if processed or LARP.Unloaded then
        return
    end

    if input.KeyCode == Enum.KeyCode.RightShift then
        LARP.MenuOpen = not LARP.MenuOpen
        log("Menu state: " .. (LARP.MenuOpen and "OPEN" or "CLOSED"))
    end
end))

-- ============================================================
-- FEATURE PLACEHOLDERS
-- Add legitimate, experience-authorized features below.
-- Keep each feature isolated and clean up its connections on unload.
-- ============================================================

LARP.Config = {
    MenuKey = Enum.KeyCode.RightShift,
    PlayerESP = false,
    NPCESP = false,
    Fullbright = false,
}

function LARP:SetFeatureEnabled(featureName, enabled)
    if self.Config[featureName] == nil then
        warn("[LARP] Unknown feature: " .. tostring(featureName))
        return
    end

    self.Config[featureName] = enabled == true
    log(("%s: %s"):format(featureName, self.Config[featureName] and "ON" or "OFF"))
end

log(("Loaded %s v%s for %s"):format(LARP.Name, LARP.Version, LocalPlayer and LocalPlayer.Name or "player"))
LARP:Notify("LARP base loaded. Right Shift toggles the demo menu state.", 4)

return LARP
