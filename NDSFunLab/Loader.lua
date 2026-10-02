local BASE = "https://raw.githubusercontent.com/loadstr0/LumenUI/main/"

local function fetch(path)
    local source = game:HttpGet(BASE .. path)
    local chunk, compileError = loadstring(source, "=LumenUI/" .. path)
    if not chunk then error("[NDS Fun Lab] " .. path .. " compile failed: " .. tostring(compileError), 0) end
    local ok, result = pcall(chunk)
    if not ok then error("[NDS Fun Lab] " .. path .. " load failed: " .. tostring(result), 0) end
    return result
end

local liveState = getfenv(0).STATE
if not liveState then
    local environment = getgenv()
    if environment.NDSFunLabCleanup then pcall(environment.NDSFunLabCleanup) end
    local alive, connections, cleanups = true, {}, {}
    liveState = {
        alive = function() return alive end,
        connect = function(signal, callback)
            local connection = signal:Connect(callback)
            table.insert(connections, connection)
            return connection
        end,
        onCleanup = function(callback) table.insert(cleanups, callback) end,
    }
    environment.NDSFunLabCleanup = function()
        if not alive then return end
        alive = false
        for _, connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
        for index = #cleanups, 1, -1 do pcall(cleanups[index]) end
    end
end

local dependencies = {
    LumenUI = fetch("Loader.lua"),
    Config = fetch("NDSFunLab/Config.lua"),
    Patterns = fetch("NDSFunLab/PhysicsPatterns.lua"),
    Defense = fetch("NDSFunLab/Defense.lua"),
    Avatar = fetch("NDSFunLab/Avatar.lua"),
}

return fetch("NDSFunLab/Main.lua").start(dependencies, liveState)
