local Main = {}

function Main.start(deps, liveState)
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local player = Players.LocalPlayer
    local structure = workspace:WaitForChild("Structure")
    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    local Window = deps.LumenUI:Require("Window")

    local state = {
        effectEnabled = false,
        constructEnabled = false,
        mode = "Halo",
        construct = "Godzilla",
        radius = 16,
        speed = 2.5,
        strength = 9,
        maxParts = deps.Config.DefaultMaxParts,
        massCap = deps.Config.DefaultMassCap,
        targetName = "Self",
        controlled = {},
        peak = 0,
        lastScan = 0,
        lastSimBoost = 0,
        lastStatus = 0,
        accumulator = 0,
        oneShot = nil,
        invulnerable = true,
        antiFling = true,
        antiFall = true,
        autoRecover = true,
        flight = false,
        flightSpeed = 90,
        selfPhysicsGrace = 0,
        safeCFrame = nil,
        forceField = nil,
        defenseConnections = {},
        avatarCyclone = false,
        avatarTrack = nil,
    }
    local ctx = {player = player, state = state}
    local effectToggle, constructToggle

    local okSim, originalSimulationRadius = pcall(gethiddenproperty, player, "SimulationRadius")
    local okMax, originalMaximumRadius = pcall(gethiddenproperty, player, "MaximumSimulationRadius")
    originalSimulationRadius = okSim and originalSimulationRadius or 1
    originalMaximumRadius = okMax and originalMaximumRadius or 1000

    local function characterRoot(target)
        local character = target and target.Character
        return character and character:FindFirstChild("HumanoidRootPart")
    end

    local function selectedTarget()
        return state.targetName == "Self" and player or Players:FindFirstChild(state.targetName) or player
    end

    local function playerOptions()
        local options = {"Self"}
        for _, target in ipairs(Players:GetPlayers()) do
            if target ~= player then table.insert(options, target.Name) end
        end
        table.sort(options, function(a, b)
            if a == "Self" then return true end
            if b == "Self" then return false end
            return a:lower() < b:lower()
        end)
        return options
    end

    local function audienceRoots()
        local roots = {}
        for _, target in ipairs(Players:GetPlayers()) do
            local root = characterRoot(target)
            local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
            if root and humanoid and humanoid.Health > 0 then table.insert(roots, root) end
        end
        if #roots == 0 then
            local root = characterRoot(player)
            if root then table.insert(roots, root) end
        end
        return roots
    end

    local function eligibleRoot(part)
        if not part:IsA("BasePart") or part.Anchored or not part.CanCollide then return nil end
        local model = part:FindFirstAncestorOfClass("Model")
        if model and model:FindFirstChildOfClass("Humanoid") then return nil end
        if part:FindFirstAncestorOfClass("Tool") or part:FindFirstAncestorOfClass("Accessory") then return nil end
        local root = part.AssemblyRootPart or part
        if root.Anchored or not root.CanCollide then return nil end
        if root.AssemblyMass > state.massCap or root.Size.Magnitude > 100 then return nil end
        return root
    end

    local function refreshOwned()
        local localRoot = characterRoot(player)
        local origin = localRoot and localRoot.Position or Vector3.zero
        local roots, seen = {}, {}
        for _, instance in ipairs(structure:GetDescendants()) do
            local root = eligibleRoot(instance)
            if root and not seen[root] then
                seen[root] = true
                local ok, owned = pcall(isnetworkowner, root)
                if ok and owned then table.insert(roots, root) end
            end
        end
        table.sort(roots, function(a, b)
            return (a.Position - origin).Magnitude + a.AssemblyMass * 0.08 < (b.Position - origin).Magnitude + b.AssemblyMass * 0.08
        end)
        table.clear(state.controlled)
        for index = 1, math.min(state.maxParts, #roots) do state.controlled[index] = roots[index] end
        state.peak = math.max(state.peak, #state.controlled)
    end

    local function stopParts()
        state.effectEnabled = false
        state.constructEnabled = false
        state.oneShot = nil
        for _, root in ipairs(state.controlled) do
            if root and root.Parent then
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end

    local function stopAll()
        if effectToggle then effectToggle:Set(false) end
        if constructToggle then constructToggle:Set(false) end
        stopParts()
    end

    local function beginShot(kind, duration)
        if effectToggle then effectToggle:Set(false) end
        if constructToggle then constructToggle:Set(false) end
        state.effectEnabled = false
        state.constructEnabled = false
        state.oneShot = {kind = kind, started = os.clock(), duration = duration}
    end

    local window = Window.new({
        Name = "NDSFunLab",
        Title = "NDS Fun Lab // Overdrive v" .. deps.Config.Version,
        Size = UDim2.fromOffset(700, 560),
        ToggleKeybind = Enum.KeyCode.RightControl,
    })

    local physicsTab = window:Tab("physics", "Physics", "orbit")
    local status = physicsTab:Paragraph({Title = "Replication core", Desc = "Scanning network-owned assemblies..."})
    physicsTab:Paragraph({Title = "How it replicates", Desc = "Only collidable assemblies owned by this client are controlled, so their real physics replicate to every observer."})
    local targetDropdown = physicsTab:Dropdown({Title = "Target", Icon = "crosshair", Options = playerOptions(), Value = "Self", Callback = function(value) state.targetName = value end})
    physicsTab:Dropdown({Title = "Continuous mode", Icon = "orbit", Options = {"Halo", "Tornado", "Target Orbit", "Black Hole", "Planetary Rings", "Audience Vortex"}, Value = "Halo", Callback = function(value) state.mode = value end})
    effectToggle = physicsTab:Toggle({
        Title = "Run continuous effect",
        Desc = "Audience Vortex puts a collidable debris tornado around every player.",
        Icon = "power",
        Value = false,
        Callback = function(value)
            state.effectEnabled = value
            if value then
                state.constructEnabled = false
                if constructToggle then constructToggle:Set(false) end
            elseif not state.oneShot then
                for _, root in ipairs(state.controlled) do if root.Parent then root.AssemblyLinearVelocity = Vector3.zero end end
            end
        end,
    })
    physicsTab:Slider({Title = "Radius", Min = 5, Max = 55, Increment = 1, Value = 16, Callback = function(value) state.radius = value end})
    physicsTab:Slider({Title = "Rotation speed", Min = 0.5, Max = 10, Increment = 0.25, Value = 2.5, Callback = function(value) state.speed = value end})
    physicsTab:Slider({Title = "Maximum assemblies", Min = 8, Max = deps.Config.MaximumParts, Increment = 1, Value = state.maxParts, Callback = function(value) state.maxParts = value end})
    physicsTab:Button({Title = "Stop every part effect", Icon = "square", Callback = stopAll})

    local constructs = window:Tab("constructs", "Constructs", "blocks")
    constructs:Paragraph({Title = "Replicated debris sculptures", Desc = "Build moving creatures and monuments from real map assemblies. They remain collidable and visible to everyone."})
    constructs:Dropdown({Title = "Construction", Icon = "hammer", Options = {"Godzilla", "Sky Serpent", "Titan Mech", "Orbital Gate", "World Tree", "UFO"}, Value = "Godzilla", Callback = function(value) state.construct = value end})
    constructToggle = constructs:Toggle({
        Title = "Build and animate",
        Icon = "sparkles",
        Value = false,
        Callback = function(value)
            state.constructEnabled = value
            if value then
                state.effectEnabled = false
                effectToggle:Set(false)
            elseif not state.oneShot then
                for _, root in ipairs(state.controlled) do if root.Parent then root.AssemblyLinearVelocity = Vector3.zero end end
            end
        end,
    })
    constructs:Button({Title = "Awaken Godzilla", Desc = "Builds the kaiju; combine it with Atomic Breath on the Powers tab.", Icon = "flame", Callback = function() state.construct = "Godzilla"; state.constructEnabled = true; state.effectEnabled = false; constructToggle:Set(true); effectToggle:Set(false) end})
    constructs:Button({Title = "Collapse construction", Icon = "bomb", Callback = stopAll})

    local powers = window:Tab("powers", "Powers", "zap")
    powers:Paragraph({Title = "Cinematic attacks", Desc = "Each attack takes temporary control of every available assembly, then releases it automatically."})
    powers:Button({Title = "Atomic Breath", Desc = "Charge orb + 100-stud physical debris beam.", Icon = "flame", Callback = function() beginShot("Atomic Breath", 2.6) end})
    powers:Button({Title = "Meteor Rain", Desc = "A collidable meteor grid falls onto the target.", Icon = "cloud-lightning", Callback = function() beginShot("Meteor Rain", 3.0) end})
    powers:Button({Title = "Singularity Collapse", Desc = "Crushes debris inward, then detonates it.", Icon = "circle-dot", Callback = function() beginShot("Singularity", 2.4) end})
    powers:Button({Title = "Kaiju Stomp", Desc = "Low radial blast for players and structures.", Icon = "footprints", Callback = function() beginShot("Kaiju Stomp", 1.5) end})
    powers:Button({Title = "Expanding Shockwave", Icon = "radio-tower", Callback = function() beginShot("Shockwave", 1.35) end})
    powers:Button({Title = "Comet Volley", Icon = "rocket", Callback = function() beginShot("Comet", 1.8) end})
    powers:Button({Title = "Emergency stop", Icon = "octagon-x", Callback = stopAll})

    local defense = window:Tab("defense", "Defense", "shield")
    defense:Paragraph({Title = "Layered survival", Desc = "Health repair, ForceField, state protection, impact clamping, and last-grounded-position rescue."})
    defense:Toggle({Title = "Damage shield", Icon = "heart-pulse", Value = true, Callback = function(value) state.invulnerable = value; if value then deps.Defense.heal(ctx) end end})
    defense:Toggle({Title = "Anti-fling", Icon = "anchor", Value = true, Callback = function(value) state.antiFling = value end})
    defense:Toggle({Title = "Anti-fall impact", Icon = "umbrella", Value = true, Callback = function(value) state.antiFall = value end})
    defense:Toggle({Title = "Void recovery", Icon = "rotate-ccw", Value = true, Callback = function(value) state.autoRecover = value end})
    defense:Button({Title = "Save current position", Icon = "map-pin", Callback = function() deps.Defense.savePosition(ctx) end})
    defense:Button({Title = "Return to safe position", Icon = "undo-2", Callback = function() deps.Defense.returnToSafety(ctx) end})
    defense:Button({Title = "Emergency heal + stand", Icon = "heart", Callback = function() deps.Defense.heal(ctx) end})

    local avatar = window:Tab("avatar", "Avatar", "person-standing")
    avatar:Toggle({Title = "Avatar cyclone", Desc = "Now isolated to this toggle only.", Icon = "tornado", Value = false, Callback = function(value) if value then deps.Avatar.startCyclone(ctx) else deps.Avatar.stopCyclone(ctx) end end})
    avatar:Slider({Title = "Flight speed", Min = 25, Max = 220, Increment = 5, Value = 90, Callback = function(value) state.flightSpeed = value end})
    avatar:Toggle({Title = "Replicated flight", Desc = "WASD, Space up, LeftControl down.", Icon = "plane", Value = false, Callback = function(value) deps.Avatar.setFlight(ctx, value) end})
    avatar:Button({Title = "Protected launch", Desc = "Anti-fall catches the landing.", Icon = "arrow-up", Callback = function() deps.Avatar.launch(ctx) end})

    local server = window:Tab("server", "Server", "server-cog")
    server:Button({Title = "Pause round", Callback = function() remotes.Round:FireServer("Pause") end})
    server:Button({Title = "Resume round", Callback = function() remotes.Round:FireServer("Resume") end})

    -- Compatibility for a cached pre-fix LumenUI bundle.
    local originalGoTo = window.GoTo
    function window:GoTo(id)
        for _, tab in pairs(self.Tabs) do tab.CanvasGroup.Interactable = false end
        originalGoTo(self, id)
        if self.ActiveTab then self.ActiveTab.CanvasGroup.Interactable = true end
    end
    for _, tab in pairs(window.Tabs) do tab.CanvasGroup.Interactable = tab == window.ActiveTab end

    liveState.onCleanup(function()
        stopParts()
        deps.Avatar.cleanup(ctx)
        deps.Defense.cleanup(ctx)
        pcall(sethiddenproperty, player, "SimulationRadius", originalSimulationRadius)
        pcall(sethiddenproperty, player, "MaximumSimulationRadius", originalMaximumRadius)
        pcall(function() window:Destroy() end)
    end)
    liveState.connect(Players.PlayerAdded, function() targetDropdown:SetOptions(playerOptions()) end)
    liveState.connect(Players.PlayerRemoving, function(target)
        if state.targetName == target.Name then state.targetName = "Self" end
        targetDropdown:SetOptions(playerOptions())
    end)
    liveState.connect(player.CharacterAdded, function(character) task.defer(deps.Defense.install, ctx, character) end)
    if player.Character then task.defer(deps.Defense.install, ctx, player.Character) end

    local lastPlayerRefresh = 0
    liveState.connect(RunService.Heartbeat, function(dt)
        if not liveState.alive() then return end
        local now = os.clock()
        local localRoot = characterRoot(player)

        if now - state.lastSimBoost >= 0.5 then
            state.lastSimBoost = now
            pcall(sethiddenproperty, player, "MaximumSimulationRadius", deps.Config.SimulationRadius)
            pcall(sethiddenproperty, player, "SimulationRadius", deps.Config.SimulationRadius)
        end
        if now - state.lastScan >= deps.Config.ScanInterval then state.lastScan = now; refreshOwned() end
        if now - lastPlayerRefresh >= 3 then lastPlayerRefresh = now; targetDropdown:SetOptions(playerOptions()) end

        deps.Avatar.tick(ctx, now)
        deps.Defense.tick(ctx, now)

        if now - state.lastStatus >= 0.25 then
            state.lastStatus = now
            local active = state.oneShot and state.oneShot.kind or (state.constructEnabled and state.construct) or (state.effectEnabled and state.mode) or "Idle"
            status:SetDesc(string.format("Owned: %d | Peak: %d | Active: %s | Target: %s | Shield: %s", #state.controlled, state.peak, active, state.targetName, state.invulnerable and "ON" or "OFF"))
        end

        state.accumulator += dt
        if state.accumulator < 1 / deps.Config.PhysicsRate then return end
        state.accumulator = 0
        if not localRoot or #state.controlled == 0 then return end
        if not state.effectEnabled and not state.constructEnabled and not state.oneShot then return end

        local targetRoot = characterRoot(selectedTarget()) or localRoot
        local viewers = audienceRoots()
        local count = #state.controlled
        for index, root in ipairs(state.controlled) do
            if root and root.Parent then
                local velocity
                if state.oneShot then
                    velocity = deps.Patterns.attack(root, index, count, now, localRoot, targetRoot, state.oneShot)
                elseif state.constructEnabled then
                    local goal, tangent = deps.Patterns.construct(state.construct, index, count, now, localRoot, targetRoot, state)
                    local raw = (goal - root.Position) * (state.strength + 3) + tangent
                    velocity = raw.Magnitude > 300 and raw.Unit * 300 or raw
                else
                    local goal, tangent = deps.Patterns.continuous(state.mode, index, count, now, localRoot, targetRoot, viewers, state)
                    local raw = (goal - root.Position) * state.strength + tangent
                    velocity = raw.Magnitude > 285 and raw.Unit * 285 or raw
                end
                root.AssemblyLinearVelocity = velocity
                root.AssemblyAngularVelocity = Vector3.new(10 + index % 5 * 3, 17, 8 + index % 7)
            end
        end

        if state.oneShot and now - state.oneShot.started >= state.oneShot.duration then
            state.oneShot = nil
            for _, root in ipairs(state.controlled) do
                if root and root.Parent then
                    root.AssemblyLinearVelocity *= 0.25
                    root.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end
    end)

    window:Notify("NDS Fun Lab // Overdrive", "Modular runtime loaded. Defenses armed and replicated powers ready.", "sparkles", 7)
    print("[NDS Fun Lab] modular Overdrive v" .. deps.Config.Version .. " loaded")
    return window
end

return Main
