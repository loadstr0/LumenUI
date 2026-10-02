local UserInputService = game:GetService("UserInputService")

local Avatar = {}

local function humanoid(ctx)
    local character = ctx.player.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function root(ctx)
    local character = ctx.player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

function Avatar.stopCyclone(ctx)
    ctx.state.avatarCyclone = false
    if ctx.state.avatarTrack then
        pcall(function() ctx.state.avatarTrack:Stop(0.15) end)
        pcall(function() ctx.state.avatarTrack:Destroy() end)
        ctx.state.avatarTrack = nil
    end
    local hum, hrp = humanoid(ctx), root(ctx)
    if hum then hum.AutoRotate = not ctx.state.flight end
    if hrp and not ctx.state.flight then hrp.AssemblyAngularVelocity = Vector3.zero end
end

function Avatar.startCyclone(ctx)
    Avatar.stopCyclone(ctx)
    local hum, hrp = humanoid(ctx), root(ctx)
    if not hum or not hrp then return end
    local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
    local animation = Instance.new("Animation")
    animation.AnimationId = "rbxassetid://507776043"
    local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
    animation:Destroy()
    if ok and track then
        ctx.state.avatarTrack = track
        track.Priority = Enum.AnimationPriority.Action4
        track.Looped = true
        track:Play(0.15, 1, 2.5)
    end
    hum.AutoRotate = false
    ctx.state.avatarCyclone = true
end

function Avatar.setFlight(ctx, enabled)
    ctx.state.flight = enabled
    ctx.state.selfPhysicsGrace = enabled and math.huge or os.clock() + 0.5
    local hum = humanoid(ctx)
    if hum then hum.AutoRotate = not enabled and not ctx.state.avatarCyclone end
end

function Avatar.launch(ctx)
    local hrp = root(ctx)
    if hrp then
        ctx.state.selfPhysicsGrace = os.clock() + 2.5
        hrp.AssemblyLinearVelocity = Vector3.new(0, 210, 0)
    end
end

function Avatar.tick(ctx, now)
    local hrp = root(ctx)
    if not hrp then return end

    if ctx.state.flight then
        local camera = workspace.CurrentCamera
        local direction = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction += camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction -= camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction -= camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction += camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then direction -= Vector3.yAxis end
        hrp.AssemblyLinearVelocity = direction.Magnitude > 0 and direction.Unit * ctx.state.flightSpeed or Vector3.zero
        local flatLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
        if flatLook.Magnitude > 0.01 then hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flatLook.Unit) end
    end

    if ctx.state.avatarCyclone then
        hrp.AssemblyAngularVelocity = Vector3.new(2, 18, 2)
        if ctx.state.avatarTrack then
            ctx.state.avatarTrack:AdjustSpeed(2.5 + math.sin(now * 4) * 1.2)
        end
    end
end

function Avatar.cleanup(ctx)
    ctx.state.flight = false
    Avatar.stopCyclone(ctx)
end

return Avatar
