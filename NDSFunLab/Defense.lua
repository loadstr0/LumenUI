local Defense = {}

local function humanoid(ctx)
    local character = ctx.player.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function root(ctx)
    local character = ctx.player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

function Defense.clearConnections(ctx)
    for _, connection in ipairs(ctx.state.defenseConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(ctx.state.defenseConnections)
end

function Defense.clearCollisionGuards(ctx)
    for _, constraint in ipairs(ctx.state.collisionGuards or {}) do
        pcall(function() constraint:Destroy() end)
    end
    table.clear(ctx.state.collisionGuards)
end

function Defense.refreshCollisionGuards(ctx)
    Defense.clearCollisionGuards(ctx)
    if not ctx.state.selfNoCollide then return end
    local character = ctx.player.Character
    if not character then return end

    local characterParts = {}
    for _, object in ipairs(character:GetDescendants()) do
        if object:IsA("BasePart") then table.insert(characterParts, object) end
    end

    local debrisParts, seen = {}, {}
    for _, assemblyRoot in ipairs(ctx.state.controlled) do
        if assemblyRoot and assemblyRoot.Parent then
            local connected = assemblyRoot:GetConnectedParts(true)
            table.insert(connected, assemblyRoot)
            for _, object in ipairs(connected) do
                if object:IsA("BasePart") and not seen[object] then
                    seen[object] = true
                    table.insert(debrisParts, object)
                    if #debrisParts >= 180 then break end
                end
            end
        end
        if #debrisParts >= 180 then break end
    end

    for _, debris in ipairs(debrisParts) do
        for _, bodyPart in ipairs(characterParts) do
            local constraint = Instance.new("NoCollisionConstraint")
            constraint.Name = "NDSFunLab_NoSelfCollision"
            constraint.Part0 = debris
            constraint.Part1 = bodyPart
            constraint.Parent = character
            table.insert(ctx.state.collisionGuards, constraint)
        end
    end
end

function Defense.install(ctx, character)
    Defense.clearConnections(ctx)
    Defense.clearCollisionGuards(ctx)
    if ctx.state.forceField then
        pcall(function() ctx.state.forceField:Destroy() end)
        ctx.state.forceField = nil
    end

    local hum = character:WaitForChild("Humanoid", 8)
    local hrp = character:WaitForChild("HumanoidRootPart", 8)
    if not hum or not hrp then return end

    ctx.state.safeCFrame = hrp.CFrame
    local shield = Instance.new("ForceField")
    shield.Name = "NDSFunLabShield"
    shield.Visible = false
    shield.Parent = character
    ctx.state.forceField = shield

    pcall(function() hum.BreakJointsOnDeath = false end)
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end)
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false) end)
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false) end)

    local repairing = false
    table.insert(ctx.state.defenseConnections, hum.HealthChanged:Connect(function(health)
        if ctx.state.invulnerable and health > 0 and health < hum.MaxHealth and not repairing then
            repairing = true
            hum.Health = hum.MaxHealth
            repairing = false
        end
    end))
end

function Defense.heal(ctx)
    local hum = humanoid(ctx)
    if hum then
        hum.Health = hum.MaxHealth
        hum.PlatformStand = false
        hum.Sit = false
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end

function Defense.savePosition(ctx)
    local hrp = root(ctx)
    if hrp then ctx.state.safeCFrame = hrp.CFrame end
end

function Defense.returnToSafety(ctx)
    local hrp = root(ctx)
    if hrp and ctx.state.safeCFrame then
        hrp.CFrame = ctx.state.safeCFrame + Vector3.new(0, 4, 0)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
end

function Defense.tick(ctx, now)
    local hrp = root(ctx)
    local hum = humanoid(ctx)
    if not hrp or not hum then return end

    if ctx.state.invulnerable and hum.Health > 0 and hum.Health < hum.MaxHealth then
        hum.Health = hum.MaxHealth
    end
    hum.PlatformStand = false
    if hum.Sit and ctx.state.flight then hum.Sit = false end

    if hum.FloorMaterial ~= Enum.Material.Air
        and hrp.AssemblyLinearVelocity.Magnitude < 90
        and hrp.Position.Y > workspace.FallenPartsDestroyHeight + 35
    then
        ctx.state.safeCFrame = hrp.CFrame
    end

    if ctx.state.autoRecover
        and ctx.state.safeCFrame
        and hrp.Position.Y < workspace.FallenPartsDestroyHeight + 25
    then
        Defense.returnToSafety(ctx)
    end

    if ctx.state.flight or now <= ctx.state.selfPhysicsGrace then return end

    local velocity = hrp.AssemblyLinearVelocity
    if ctx.state.antiFall and velocity.Y < -72 then
        velocity = Vector3.new(velocity.X, -42, velocity.Z)
    end
    if ctx.state.antiFling then
        local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
        if horizontal.Magnitude > 115 then
            horizontal = horizontal.Unit * 115
            velocity = Vector3.new(horizontal.X, math.clamp(velocity.Y, -58, 110), horizontal.Z)
        end
        if hrp.AssemblyAngularVelocity.Magnitude > 38 and not ctx.state.avatarCyclone then
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
    hrp.AssemblyLinearVelocity = velocity
end

function Defense.cleanup(ctx)
    Defense.clearConnections(ctx)
    Defense.clearCollisionGuards(ctx)
    if ctx.state.forceField then
        pcall(function() ctx.state.forceField:Destroy() end)
        ctx.state.forceField = nil
    end
end

return Defense
