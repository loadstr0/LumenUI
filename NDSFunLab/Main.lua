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
        construct = "Orbital Gate",
        radius = 16,
        speed = 2.5,
        strength = 9,
        maxParts = deps.Config.DefaultMaxParts,
        massCap = deps.Config.DefaultMassCap,
        targetName = "Self",
        aimMode = "Mouse World",
        aimDistance = 180,
        aimPoint = nil,
        constructFrame = nil,
        destructionRadius = 42,
        destructionForce = 285,
        smartTargeting = true,
        aimBeacon = false,
        beaconCount = 4,
        comboName = "Cataclysm Protocol",
        comboQueue = {},
        comboGapUntil = nil,
        safetyCorridor = true,
        safetyRadius = 12,
        nextDisaster = "Earthquake",
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
        collisionGuards = {},
        selfNoCollide = true,
        lastCollisionRefresh = 0,
        avatarCyclone = false,
        avatarTrack = nil,
    }
    local ctx = {player = player, state = state}
    local effectToggle, constructToggle, beaconToggle
    local mouse = player:GetMouse()
    local camera = workspace.CurrentCamera

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

    local function flatFrame(root)
        local look = root.CFrame.LookVector
        local flat = Vector3.new(look.X, 0, look.Z)
        if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
        return CFrame.lookAt(root.Position, root.Position + flat.Unit)
    end

    local function rawAimPoint()
        local localRoot = characterRoot(player)
        if not localRoot then return Vector3.zero end
        if state.aimMode == "Selected Player" then
            local targetRoot = characterRoot(selectedTarget())
            return targetRoot and targetRoot.Position + Vector3.new(0, 3, 0) or localRoot.Position
        end
        if state.aimMode == "Forward" then
            return localRoot.Position + localRoot.CFrame.LookVector * state.aimDistance + Vector3.new(0, 3, 0)
        end
        camera = workspace.CurrentCamera or camera
        local ray = mouse.UnitRay
        local parameters = RaycastParams.new()
        parameters.FilterType = Enum.RaycastFilterType.Exclude
        parameters.FilterDescendantsInstances = player.Character and {player.Character} or {}
        local result = workspace:Raycast(ray.Origin, ray.Direction * state.aimDistance, parameters)
        return result and result.Position or ray.Origin + ray.Direction * state.aimDistance
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
            return deps.Targeting.priority(a, origin, state.oneShot, state.smartTargeting)
                < deps.Targeting.priority(b, origin, state.oneShot, state.smartTargeting)
        end)
        table.clear(state.controlled)
        for index = 1, math.min(state.maxParts, #roots) do state.controlled[index] = roots[index] end
        state.peak = math.max(state.peak, #state.controlled)
    end

    local function stopParts()
        state.effectEnabled = false
        state.constructEnabled = false
        state.oneShot = nil
        state.comboGapUntil = nil
        table.clear(state.comboQueue)
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
        if beaconToggle then beaconToggle:Set(false) end
        stopParts()
    end

    local function beginShot(kind, duration, fromCombo)
        if effectToggle then effectToggle:Set(false) end
        if constructToggle then constructToggle:Set(false) end
        if not fromCombo then
            state.comboGapUntil = nil
            table.clear(state.comboQueue)
        end
        state.effectEnabled = false
        state.constructEnabled = false
        local root = characterRoot(player)
        state.oneShot = {
            kind = kind,
            started = os.clock(),
            duration = duration,
            aimPoint = state.aimPoint or rawAimPoint(),
            originPoint = root and root.Position or Vector3.zero,
            destructionRadius = state.destructionRadius,
            destructionForce = state.destructionForce,
        }
        refreshOwned()
        deps.Defense.refreshCollisionGuards(ctx)
    end

    local function beginCombo()
        if effectToggle then effectToggle:Set(false) end
        if constructToggle then constructToggle:Set(false) end
        state.effectEnabled = false
        state.constructEnabled = false
        state.oneShot = nil
        state.comboQueue = deps.Sequences.combo(state.comboName)
        state.comboGapUntil = os.clock()
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
    constructs:Paragraph({Title = "Replicated debris forms", Desc = "Only shapes that stay readable with irregular map assemblies are included. They build about 45 studs ahead of you and are visible to the server."})
    constructs:Dropdown({Title = "Construction", Icon = "hammer", Options = {"Orbital Gate", "UFO", "Sky Serpent", "World Tree"}, Value = "Orbital Gate", Callback = function(value) state.construct = value end})
    constructToggle = constructs:Toggle({
        Title = "Build and animate",
        Icon = "sparkles",
        Value = false,
        Callback = function(value)
            state.constructEnabled = value
            if value then
                local root = characterRoot(player)
                state.constructFrame = root and flatFrame(root) * CFrame.new(0, 0, -45) or nil
                state.effectEnabled = false
                effectToggle:Set(false)
            elseif not state.oneShot then
                for _, root in ipairs(state.controlled) do if root.Parent then root.AssemblyLinearVelocity = Vector3.zero end end
            end
        end,
    })
    constructs:Button({Title = "Rebuild ahead of me", Desc = "Captures a new safe construction point 45 studs forward.", Icon = "move-up-right", Callback = function()
        local root = characterRoot(player)
        if not root then return end
        state.constructFrame = flatFrame(root) * CFrame.new(0, 0, -45)
        state.constructEnabled = true
        state.effectEnabled = false
        constructToggle:Set(true)
        effectToggle:Set(false)
    end})
    constructs:Button({Title = "Collapse construction", Icon = "bomb", Callback = stopAll})

    local powers = window:Tab("powers", "Powers", "zap")
    powers:Paragraph({Title = "Replicated cinematic attacks", Desc = "The moving map assemblies are the visual effect, so observers receive the same physics. Mouse World continuously follows your pointer during aimed attacks."})
    powers:Dropdown({Title = "Aim mode", Icon = "crosshair", Options = {"Mouse World", "Selected Player", "Forward"}, Value = "Mouse World", Callback = function(value) state.aimMode = value end})
    powers:Slider({Title = "Aim range", Min = 60, Max = 300, Increment = 10, Value = 180, Callback = function(value) state.aimDistance = value end})
    beaconToggle = powers:Toggle({Title = "Replicated aim beacon", Desc = "Reserves four network-owned assemblies to mark the live impact point for every observer.", Icon = "locate-fixed", Value = false, Callback = function(value) state.aimBeacon = value end})
    powers:Toggle({Title = "Smart structural targeting", Desc = "Destruction powers prioritize nearby broad wall, roof, and heavy loose assemblies.", Icon = "scan-search", Value = true, Callback = function(value) state.smartTargeting = value; refreshOwned() end})
    powers:Slider({Title = "Destruction radius", Min = 12, Max = 80, Increment = 2, Value = 42, Callback = function(value) state.destructionRadius = value end})
    powers:Slider({Title = "Blast force", Min = 100, Max = 420, Increment = 10, Value = 285, Callback = function(value) state.destructionForce = value end})
    powers:Button({Title = "Seismic Line", Desc = "A chained row of replicated debris eruptions travels from you to the aim point.", Icon = "activity", Callback = function() beginShot("Seismic Line", deps.Sequences.duration("Seismic Line")) end})
    powers:Button({Title = "Railgun", Desc = "Compresses debris into a rotating core, then fires the whole formation down the aim line.", Icon = "crosshair", Callback = function() beginShot("Railgun", deps.Sequences.duration("Railgun")) end})
    powers:Button({Title = "Gravity Wave", Desc = "Expanding physical rings sweep loose structures away from the impact center.", Icon = "radio", Callback = function() beginShot("Gravity Wave", deps.Sequences.duration("Gravity Wave")) end})
    powers:Button({Title = "Meteor Forge", Desc = "Builds a rotating debris meteor overhead and slams it into the selected point.", Icon = "orbit", Callback = function() beginShot("Meteor Forge", deps.Sequences.duration("Meteor Forge")) end})
    powers:Button({Title = "Atomic Breath", Desc = "Charge formation followed by a long aimed debris beam.", Icon = "flame", Callback = function() beginShot("Atomic Breath", deps.Sequences.duration("Atomic Breath")) end})
    powers:Button({Title = "Meteor Rain", Desc = "A collidable meteor grid falls onto the target.", Icon = "cloud-lightning", Callback = function() beginShot("Meteor Rain", deps.Sequences.duration("Meteor Rain")) end})
    powers:Button({Title = "Singularity Collapse", Desc = "Crushes debris inward, then detonates it.", Icon = "circle-dot", Callback = function() beginShot("Singularity", deps.Sequences.duration("Singularity")) end})
    powers:Button({Title = "Kaiju Stomp", Desc = "Low radial blast for players and structures.", Icon = "footprints", Callback = function() beginShot("Kaiju Stomp", deps.Sequences.duration("Kaiju Stomp")) end})
    powers:Button({Title = "Expanding Shockwave", Icon = "radio-tower", Callback = function() beginShot("Shockwave", deps.Sequences.duration("Shockwave")) end})
    powers:Button({Title = "Comet Volley", Icon = "rocket", Callback = function() beginShot("Comet", deps.Sequences.duration("Comet")) end})
    powers:Button({Title = "Demolition Pulse", Desc = "Blasts nearby loose, network-owned assemblies away from the aim point. Anchored map geometry cannot be deleted client-side.", Icon = "bomb", Callback = function() beginShot("Demolition Pulse", deps.Sequences.duration("Demolition Pulse")) end})
    powers:Dropdown({Title = "Combo", Icon = "list-ordered", Options = deps.Sequences.comboNames(), Value = "Cataclysm Protocol", Callback = function(value) state.comboName = value end})
    powers:Button({Title = "Execute combo", Desc = "Chains the selected sequence with a short reset between powers.", Icon = "sparkles", Callback = beginCombo})
    powers:Button({Title = "Emergency stop", Icon = "octagon-x", Callback = stopAll})

    local defense = window:Tab("defense", "Defense", "shield")
    defense:Paragraph({Title = "Layered survival", Desc = "Health repair, ForceField, state protection, impact clamping, and last-grounded-position rescue."})
    defense:Toggle({Title = "Damage shield", Icon = "heart-pulse", Value = true, Callback = function(value) state.invulnerable = value; if value then deps.Defense.heal(ctx) end end})
    defense:Toggle({Title = "Anti-fling", Icon = "anchor", Value = true, Callback = function(value) state.antiFling = value end})
    defense:Toggle({Title = "No collision with controlled debris", Desc = "Creates local physics constraints between your avatar and every controlled assembly, while keeping debris collidable for everyone else.", Icon = "shield", Value = true, Callback = function(value)
        state.selfNoCollide = value
        deps.Defense.refreshCollisionGuards(ctx)
    end})
    defense:Toggle({Title = "Predictive safety corridor", Desc = "Ejects debris predicted to enter the protected capsule around your avatar.", Icon = "shield-check", Value = true, Callback = function(value) state.safetyCorridor = value end})
    defense:Slider({Title = "Safety radius", Min = 8, Max = 24, Increment = 1, Value = 12, Callback = function(value) state.safetyRadius = value end})
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
    server:Paragraph({Title = "Authorized disaster control", Desc = "Uses the private server's enabled Gameplay Control setting. The chosen disaster is applied by the server for the next round."})
    server:Dropdown({Title = "Next disaster", Options = {"Avalanche", "Volcanic Eruption", "Deadly Virus", "Tsunami", "Tornado", "Thunder Storm", "Sandstorm", "Meteor Shower", "Flash Flood", "Fire", "Earthquake", "Blizzard", "Acid Rain"}, Value = "Earthquake", Callback = function(value) state.nextDisaster = value end})
    server:Button({Title = "Set next disaster", Callback = function() remotes.Round:FireServer("Set Disaster", state.nextDisaster) end})
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

        if localRoot then
            local nextAim = rawAimPoint()
            state.aimPoint = state.aimPoint and state.aimPoint:Lerp(nextAim, math.clamp(dt * 12, 0, 1)) or nextAim
            if state.oneShot and (state.oneShot.kind == "Atomic Breath" or state.oneShot.kind == "Comet" or state.oneShot.kind == "Railgun") then
                state.oneShot.aimPoint = state.aimPoint
            end
        end

        if not state.oneShot and state.comboGapUntil and now >= state.comboGapUntil then
            local nextKind = table.remove(state.comboQueue, 1)
            state.comboGapUntil = nil
            if nextKind then beginShot(nextKind, deps.Sequences.duration(nextKind), true) end
        end

        if now - state.lastSimBoost >= 0.5 then
            state.lastSimBoost = now
            pcall(sethiddenproperty, player, "MaximumSimulationRadius", deps.Config.SimulationRadius)
            pcall(sethiddenproperty, player, "SimulationRadius", deps.Config.SimulationRadius)
        end
        if not state.oneShot and now - state.lastScan >= deps.Config.ScanInterval then state.lastScan = now; refreshOwned() end
        if now - state.lastCollisionRefresh >= 2 then
            state.lastCollisionRefresh = now
            deps.Defense.refreshCollisionGuards(ctx)
        end
        if now - lastPlayerRefresh >= 3 then lastPlayerRefresh = now; targetDropdown:SetOptions(playerOptions()) end

        deps.Avatar.tick(ctx, now)
        deps.Defense.tick(ctx, now)

        if now - state.lastStatus >= 0.25 then
            state.lastStatus = now
            local active = state.oneShot and state.oneShot.kind or (state.comboGapUntil and "Combo charging") or (state.constructEnabled and state.construct) or (state.effectEnabled and state.mode) or (state.aimBeacon and "Aim Beacon") or "Idle"
            status:SetDesc(string.format("Owned: %d | Peak: %d | Active: %s | Target: %s | Beacon: %s | Shield: %s", #state.controlled, state.peak, active, state.targetName, state.aimBeacon and "ON" or "OFF", state.invulnerable and "ON" or "OFF"))
        end

        state.accumulator += dt
        if state.accumulator < 1 / deps.Config.PhysicsRate then return end
        state.accumulator = 0
        if not localRoot or #state.controlled == 0 then return end
        if not state.effectEnabled and not state.constructEnabled and not state.oneShot and not state.aimBeacon then return end

        local targetRoot = characterRoot(selectedTarget()) or localRoot
        local viewers = audienceRoots()
        local count = #state.controlled
        local beaconCount = state.aimBeacon and math.min(state.beaconCount, count) or 0
        local effectCount = math.max(0, count - beaconCount)
        for index, root in ipairs(state.controlled) do
            if root and root.Parent then
                local velocity
                local isBeacon = beaconCount > 0 and index > effectCount
                if isBeacon then
                    velocity = deps.Targeting.beacon(root, index - effectCount, beaconCount, now, state.aimPoint or targetRoot.Position)
                elseif state.oneShot then
                    velocity = deps.Patterns.attack(root, index, math.max(effectCount, 1), now, localRoot, targetRoot, state.oneShot)
                elseif state.constructEnabled then
                    local goal, tangent = deps.Patterns.construct(state.construct, index, math.max(effectCount, 1), now, localRoot, targetRoot, state)
                    local raw = (goal - root.Position) * (state.strength + 3) - root.AssemblyLinearVelocity * 0.75 + tangent
                    velocity = raw.Magnitude > 300 and raw.Unit * 300 or raw
                elseif state.effectEnabled then
                    local goal, tangent = deps.Patterns.continuous(state.mode, index, math.max(effectCount, 1), now, localRoot, targetRoot, viewers, state)
                    local raw = (goal - root.Position) * state.strength + tangent
                    velocity = raw.Magnitude > 285 and raw.Unit * 285 or raw
                end
                if state.safetyCorridor then
                    velocity = deps.Targeting.safetyVelocity(root, localRoot, state.safetyRadius) or velocity
                end
                if velocity then root.AssemblyLinearVelocity = velocity end
                if isBeacon then
                    root.AssemblyAngularVelocity = Vector3.new(0, 8, 0)
                elseif state.constructEnabled and not state.oneShot then
                    root.AssemblyAngularVelocity = Vector3.zero
                elseif velocity then
                    root.AssemblyAngularVelocity = Vector3.new(10 + index % 5 * 3, 17, 8 + index % 7)
                end
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
            if #state.comboQueue > 0 then state.comboGapUntil = now + 0.28 end
        end
    end)

    window:Notify("NDS Fun Lab // Overdrive", "Modular runtime loaded. Defenses armed and replicated powers ready.", "sparkles", 7)
    print("[NDS Fun Lab] modular Overdrive v" .. deps.Config.Version .. " loaded")
    return window
end

return Main
