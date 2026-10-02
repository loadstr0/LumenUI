local Patterns = {}

local function clampVelocity(value, maximum)
    return value.Magnitude > maximum and value.Unit * maximum or value
end

local function horizontalFrame(root)
    local look = root.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
    return CFrame.lookAt(root.Position, root.Position + flat.Unit)
end

function Patterns.construct(kind, index, count, now, anchorRoot, targetRoot, state)
    local t = (index - 1) / math.max(1, count - 1)
    local base = state.constructFrame or horizontalFrame(anchorRoot) * CFrame.new(0, 0, -45)
    local point

    if kind == "Sky Serpent" then
        point = Vector3.new(
            math.sin(t * math.pi * 7 + now * 1.8) * 12,
            18 + math.sin(t * math.pi * 5 + now * 2.2) * 9,
            (t - 0.35) * 95
        )
    elseif kind == "Orbital Gate" then
        local angle = t * math.pi * 2 + now * state.speed
        local center = base:PointToWorldSpace(Vector3.new(0, 16, 0))
        return center + base.RightVector * (math.cos(angle) * state.radius) + Vector3.yAxis * (math.sin(angle) * state.radius), base.LookVector * (25 + index % 3 * 8)
    elseif kind == "World Tree" then
        if t < 0.45 then
            local k = t / 0.45
            local angle = index * 2.399
            point = Vector3.new(math.cos(angle) * (1.5 + k * 3), k * 34, math.sin(angle) * (1.5 + k * 3))
        else
            local k = (t - 0.45) / 0.55
            local angle = k * math.pi * 10 + now * 0.35
            local spread = 7 + k * 18
            point = Vector3.new(math.cos(angle) * spread, 25 + math.sin(k * math.pi * 4) * 8, math.sin(angle) * spread)
        end
    else -- UFO
        local angle = t * math.pi * 10 + now * state.speed
        local ring = index % 3
        local radius = 6 + ring * 7
        local center = base:PointToWorldSpace(Vector3.new(0, 22 + math.sin(now * 1.5) * 3, 0))
        return center + Vector3.new(math.cos(angle) * radius, (ring - 1) * 2.5, math.sin(angle) * radius), Vector3.new(0, math.sin(now * 5 + index) * 8, 0)
    end

    return base:PointToWorldSpace(point), Vector3.zero
end

function Patterns.continuous(mode, index, count, now, localRoot, targetRoot, viewers, state)
    local lane = (index - 1) % 4
    local phase = ((index - 1) / math.max(1, count)) * math.pi * 2
    local angle = now * state.speed + phase
    local center = targetRoot.Position + Vector3.new(0, 6, 0)

    if mode == "Tornado" then
        local height = ((index - 1) / math.max(1, count - 1)) * 42 - 8
        local radius = 6 + ((index - 1) % 6) * 2.7
        return center + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius), Vector3.new(-math.sin(angle), 0, math.cos(angle)) * 42
    elseif mode == "Black Hole" then
        local radius = 2.5 + ((index - 1) % 5) * 1.8
        return center + Vector3.new(math.cos(angle * 1.9) * radius, math.sin(angle + index) * 5, math.sin(angle * 1.9) * radius), Vector3.new(-math.sin(angle), 0, math.cos(angle)) * 25
    elseif mode == "Target Orbit" then
        local radius = state.radius + lane * 3
        return center + Vector3.new(math.cos(angle) * radius, (lane - 1.5) * 3.5, math.sin(angle) * radius), Vector3.new(-math.sin(angle), 0, math.cos(angle)) * 34
    elseif mode == "Planetary Rings" then
        local tilt = (lane - 1.5) * 0.35
        local radius = state.radius + lane * 5
        local flat = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
        return center + CFrame.Angles(tilt, 0, tilt * 0.55):VectorToWorldSpace(flat), Vector3.new(-math.sin(angle), 0, math.cos(angle)) * 38
    elseif mode == "Audience Vortex" then
        local viewer = viewers[((index - 1) % math.max(1, #viewers)) + 1] or targetRoot
        local radius = 4.5 + lane * 2.1
        local height = ((index - 1) % 9) * 2.6 - 4
        return viewer.Position + Vector3.new(math.cos(angle * 1.6) * radius, 5 + height, math.sin(angle * 1.6) * radius), Vector3.new(-math.sin(angle), 3, math.cos(angle)) * 45
    end

    local radius = state.radius + lane * 3.2
    local centerSelf = localRoot.Position + Vector3.new(0, 7, 0)
    return centerSelf + Vector3.new(math.cos(angle) * radius, (lane - 1.5) * 2.8, math.sin(angle) * radius), Vector3.new(-math.sin(angle), 0, math.cos(angle)) * 30
end

function Patterns.attack(root, index, count, now, localRoot, targetRoot, shot)
    local elapsed = now - shot.started
    local phase = ((index - 1) / math.max(1, count)) * math.pi * 2
    local lane = (index - 1) % 5
    local aimPoint = shot.aimPoint or targetRoot.Position
    local aim = aimPoint - localRoot.Position
    local direction = aim.Magnitude > 2 and aim.Unit or localRoot.CFrame.LookVector

    if shot.kind == "Seismic Line" then
        local origin = shot.originPoint or localRoot.Position
        local path = aimPoint - origin
        local steps = 12
        local step = (index - 1) % steps + 1
        local layer = math.floor((index - 1) / steps)
        local trigger = (step - 1) * 0.11
        local point = origin:Lerp(aimPoint, step / steps) + Vector3.new(0, 1 + layer * 0.7, 0)
        if elapsed < trigger then
            return clampVelocity((point - root.Position) * 16 - root.AssemblyLinearVelocity * 0.35, 260)
        end
        if elapsed < trigger + 0.38 then
            local flat = Vector3.new(path.X, 0, path.Z)
            local forward = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, -1)
            local side = Vector3.new(-forward.Z, 0, forward.X)
            local eruption = side * math.sin(phase) * (65 + layer * 8) + forward * 35
            return eruption + Vector3.new(0, 245 + layer * 18, 0)
        end
        return root.AssemblyLinearVelocity * 0.96
    elseif shot.kind == "Railgun" then
        local muzzle = localRoot.Position + Vector3.new(0, 6, 0) + direction * 8
        local frame = CFrame.lookAt(muzzle, muzzle + direction)
        local coilAngle = phase * 3 + now * 11
        local coilRadius = 2.4 + lane * 0.55
        if elapsed < 0.9 then
            local depth = ((index - 1) / math.max(count, 1) - 0.5) * 12
            local goal = muzzle + direction * depth + frame.RightVector * math.cos(coilAngle) * coilRadius + frame.UpVector * math.sin(coilAngle) * coilRadius
            return clampVelocity((goal - root.Position) * 22 - root.AssemblyLinearVelocity * 0.5, 320)
        end
        local travel = (elapsed - 0.9) * 235 + index / math.max(count, 1) * 38
        local lance = muzzle + direction * travel + frame.RightVector * math.cos(coilAngle) * 0.8 + frame.UpVector * math.sin(coilAngle) * 0.8
        return clampVelocity((lance - root.Position) * 20 + direction * 210, 430)
    elseif shot.kind == "Gravity Wave" then
        local ring = (index - 1) % 4
        local ringPhase = phase + ring * 0.35
        local radius = 5 + elapsed * 68 + ring * 7
        local goal = aimPoint + Vector3.new(math.cos(ringPhase) * radius, 3 + math.sin(now * 5 + index) * 2.5, math.sin(ringPhase) * radius)
        local radial = Vector3.new(math.cos(ringPhase), 0.12, math.sin(ringPhase)).Unit
        return clampVelocity((goal - root.Position) * 13 + radial * (115 + ring * 15), 350)
    elseif shot.kind == "Meteor Forge" then
        local forge = aimPoint + Vector3.new(0, 72, 0)
        if elapsed < 1.45 then
            local orbit = phase + now * (4.5 + lane * 0.2)
            local radius = 7 + lane * 1.5
            local goal = forge + Vector3.new(math.cos(orbit) * radius, math.sin(phase * 2 + now * 3) * 6, math.sin(orbit) * radius)
            return clampVelocity((goal - root.Position) * 18 - root.AssemblyLinearVelocity * 0.4, 320)
        elseif elapsed < 2.55 then
            local impact = aimPoint + Vector3.new(math.cos(phase) * lane * 0.65, 1, math.sin(phase) * lane * 0.65)
            return clampVelocity((impact - root.Position) * 19 + Vector3.new(0, -210, 0), 410)
        end
        local offset = root.Position - aimPoint
        local outward = offset.Magnitude > 0.2 and offset.Unit or Vector3.new(math.cos(phase), 0.4, math.sin(phase)).Unit
        return outward * 330 + Vector3.new(0, 105, 0)
    elseif shot.kind == "Shockwave" then
        local offset = root.Position - aimPoint
        local outward = offset.Magnitude > 0.1 and offset.Unit or Vector3.new(math.cos(phase), 0.2, math.sin(phase)).Unit
        return outward * (180 + lane * 25) + Vector3.new(0, 38, 0)
    elseif shot.kind == "Comet" then
        return clampVelocity((aimPoint - root.Position) * 16, 310)
    elseif shot.kind == "Atomic Breath" then
        local mouth = localRoot.Position + Vector3.new(0, 6, 0) + direction * 7
        if elapsed < 0.75 then
            local charge = mouth + Vector3.new(math.cos(phase) * 5, math.sin(phase * 2) * 3, math.sin(phase) * 5)
            return clampVelocity((charge - root.Position) * 18, 240)
        end
        local beam = mouth + direction * (15 + index / count * 105) + Vector3.new(math.cos(phase) * lane * 0.6, math.sin(phase) * lane * 0.6, 0)
        return clampVelocity((beam - root.Position) * 24 + direction * 170, 360)
    elseif shot.kind == "Meteor Rain" then
        local sky = aimPoint + Vector3.new(((index - 1) % 9 - 4) * 8, 70 + lane * 7, (math.floor((index - 1) / 9) % 7 - 3) * 8)
        if elapsed < 1.15 then return clampVelocity((sky - root.Position) * 14, 280) end
        return Vector3.new(math.sin(index * 9) * 18, -300 - lane * 15, math.cos(index * 7) * 18)
    elseif shot.kind == "Singularity" then
        local center = aimPoint + Vector3.new(0, 5, 0)
        if elapsed < 1.5 then
            local spiral = center + Vector3.new(math.cos(phase + now * 8) * 3, math.sin(phase * 2) * 3, math.sin(phase + now * 8) * 3)
            return clampVelocity((spiral - root.Position) * 22, 330)
        end
        local outward = root.Position - center
        outward = outward.Magnitude > 0.2 and outward.Unit or Vector3.new(math.cos(phase), 0.35, math.sin(phase)).Unit
        return outward * 340 + Vector3.new(0, 70, 0)
    elseif shot.kind == "Demolition Pulse" then
        local offset = root.Position - aimPoint
        if offset.Magnitude > (shot.destructionRadius or 42) then return nil end
        local outward = offset.Magnitude > 0.2 and offset.Unit or Vector3.new(math.cos(phase), 0.25, math.sin(phase)).Unit
        local falloff = 1 - math.clamp(offset.Magnitude / math.max(1, shot.destructionRadius or 42), 0, 0.8)
        return outward * (shot.destructionForce or 285) * falloff + Vector3.new(0, 65 * falloff, 0)
    end

    local offset = Vector3.new(root.Position.X - localRoot.Position.X, 0, root.Position.Z - localRoot.Position.Z)
    local outward = offset.Magnitude > 0.2 and offset.Unit or Vector3.new(math.cos(phase), 0, math.sin(phase))
    return outward * (225 + lane * 18) + Vector3.new(0, 22 + lane * 5, 0)
end

return Patterns
