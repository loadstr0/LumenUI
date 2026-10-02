local Targeting = {}

local DESTRUCTION_POWER = {
    ["Demolition Pulse"] = true,
    ["Seismic Line"] = true,
    ["Gravity Wave"] = true,
    ["Meteor Forge"] = true,
    ["Shockwave"] = true,
}

local function clampVelocity(value, maximum)
    return value.Magnitude > maximum and value.Unit * maximum or value
end

function Targeting.priority(root, fallbackOrigin, shot, smartEnabled)
    local origin = shot and shot.aimPoint or fallbackOrigin
    local distance = (root.Position - origin).Magnitude
    if not smartEnabled or not shot or not DESTRUCTION_POWER[shot.kind] then
        return distance + root.AssemblyMass * 0.08
    end

    local size = root.Size
    local dimensions = {size.X, size.Y, size.Z}
    table.sort(dimensions)
    local thinness = dimensions[3] / math.max(dimensions[1], 0.25)
    local surface = dimensions[2] * dimensions[3]
    local structuralBonus = math.min(surface * 0.14, 38) + math.min(thinness * 2.5, 18)
    local massBonus = math.min(math.sqrt(math.max(root.AssemblyMass, 0)) * 1.4, 24)
    return distance - structuralBonus - massBonus
end

function Targeting.beacon(root, index, count, now, aimPoint)
    local phase = (index - 1) / math.max(1, count) * math.pi * 2 + now * 2.8
    local ring = aimPoint + Vector3.new(math.cos(phase) * 4.5, 2.5 + math.sin(now * 4 + index) * 1.3, math.sin(phase) * 4.5)
    return clampVelocity((ring - root.Position) * 15 - root.AssemblyLinearVelocity * 0.45, 220)
end

function Targeting.safetyVelocity(root, localRoot, radius)
    local predicted = root.Position + root.AssemblyLinearVelocity * 0.28
    local bottom = localRoot.Position - Vector3.new(0, 4, 0)
    local top = localRoot.Position + Vector3.new(0, 9, 0)
    local segment = top - bottom
    local t = math.clamp((predicted - bottom):Dot(segment) / math.max(segment:Dot(segment), 0.01), 0, 1)
    local nearest = bottom + segment * t
    local separation = predicted - nearest
    if separation.Magnitude >= radius then return nil end

    local away = separation.Magnitude > 0.2 and separation.Unit or localRoot.CFrame.LookVector
    local urgency = 1 - math.clamp(separation.Magnitude / math.max(radius, 1), 0, 0.85)
    return away * (180 + urgency * 130) + Vector3.new(0, 45 + urgency * 45, 0)
end

return Targeting
