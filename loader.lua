--[[
    LARP Loader
    Repository: https://github.com/userhahaha582/LARP
    Put this file in your executor as the entry point.
]]

local RAW_URL = "https://raw.githubusercontent.com/userhahaha582/LARP/main/LARP.lua"

local function report(message)
    warn("[LARP Loader] " .. tostring(message))
end

if type(loadstring) ~= "function" then
    report("This environment does not support loadstring.")
    return
end

if not game or type(game.HttpGet) ~= "function" then
    report("HTTP requests are not available in this environment.")
    return
end

local ok, source = pcall(function()
    return game:HttpGet(RAW_URL)
end)

if not ok then
    report("Could not download LARP: " .. tostring(source))
    return
end

if type(source) ~= "string" or #source == 0 then
    report("The downloaded LARP file is empty.")
    return
end

local compileOk, chunk, compileError = pcall(loadstring, source)
if not compileOk then
    report("Compiler failed: " .. tostring(chunk))
    return
end

if type(chunk) ~= "function" then
    report("LARP could not be compiled: " .. tostring(compileError))
    return
end

local runOk, runError = pcall(chunk)
if not runOk then
    report("LARP runtime error: " .. tostring(runError))
end
