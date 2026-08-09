--[[
	Notify.lua

	Toast notifications. Visual structure (pill-shaped card, white gradient-stroke glow, bottom
	timeline bar that drains over the notification's duration) matches the real values extracted
	from the source project's notification instance: BackgroundColor3 RGB(79,79,79) at ~0.05
	transparency, a white UIStroke with a UIGradient (transparency 0.69-0.87, 80deg rotation), and
	a 100px pill CornerRadius. See HANDOFF.md/Theme.lua for the extraction detail.
]]

return function(ctx)
	local TweenService = game:GetService("TweenService")

	local Theme = ctx:Require("Theme")
	local Helpers = ctx:Require("Helpers")
	local new, corner = Helpers.new, Helpers.corner

	local Notify = {}

	function Notify.Show(window, title, content, icon, duration)
		duration = duration or 5

		local titleLabel = new("TextLabel", {
			Name = "title",
			BackgroundTransparency = 1,
			Text = title or "",
			FontFace = Theme.CustomFontMedium,
			TextSize = 14,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 16),
		})

		local contentLabel = new("TextLabel", {
			Name = "content",
			BackgroundTransparency = 1,
			Text = content or "",
			FontFace = Theme.CustomFont,
			TextSize = 13,
			TextColor3 = Theme.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.fromOffset(0, 18),
		})

		-- Real values: both the track and the fill are the same sliced pill image
		-- (rbxassetid://16294678871, also the slider handle image) rather than flat Color3 pills -
		-- track at 0.8 transparency, fill at 0.2.
		local timelineBar = new("ImageLabel", {
			Name = "bar",
			BackgroundTransparency = 1,
			Image = "rbxassetid://16294678871",
			ImageTransparency = 0.2,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(206, 206, 206, 206),
			Size = UDim2.fromScale(0, 1),
		})

		local timeline = new("ImageLabel", {
			Name = "timeline",
			BackgroundTransparency = 1,
			Image = "rbxassetid://16294678871",
			ImageTransparency = 0.8,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(206, 206, 206, 206),
			Size = UDim2.new(1, -24, 0, 3),
			Position = UDim2.new(0, 12, 1, -8),
		}, { timelineBar })

		-- Real extracted values: white stroke, gradient transparency 0.69->0.87, 80deg rotation -
		-- a subtle, mostly-transparent glow rather than a hard visible ring.
		local strokeGradient = new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.69375),
				NumberSequenceKeypoint.new(1, 0.86875),
			}),
			Rotation = 80,
		})

		local toast = new("Frame", {
			Name = "toast",
			BackgroundColor3 = Theme.SurfaceRaised,
			BackgroundTransparency = 0.05,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.new(0.5, 0, 0, -80),
			AnchorPoint = Vector2.new(0.5, 0),
			ClipsDescendants = true,
		}, {
			corner(Theme.CornerRadiusPill),
			Helpers.stroke(Theme.Glow, 1),
			strokeGradient,
			new("UIPadding", {
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 16),
				PaddingLeft = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 16),
			}),
			titleLabel,
			contentLabel,
			timeline,
		})

		if not window.NotifyContainer then
			window.NotifyContainer = new("Frame", {
				Name = "notifications",
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 320, 1, 0),
				Position = UDim2.new(1, -336, 0, 16),
			}, {
				new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
			})
			window.NotifyContainer.Parent = window.ScreenGui
		end
		toast.Parent = window.NotifyContainer

		TweenService:Create(toast, Theme.Tweens.Window, { Position = UDim2.new(0.5, 0, 0, 0) }):Play()
		TweenService:Create(timelineBar, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }):Play()

		local dismissed = false
		local function dismiss()
			if dismissed then
				return
			end
			dismissed = true
			TweenService:Create(toast, Theme.Tweens.Window, { Position = UDim2.new(0.5, 0, 0, -80) }):Play()
			task.wait(0.4)
			toast:Destroy()
		end

		toast.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dismiss()
			end
		end)

		task.delay(duration, dismiss)
	end

	return Notify
end
