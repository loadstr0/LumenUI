--[[
	Helpers.lua

	Small Instance-construction utilities shared across Window.lua/Elements.lua/Notify.lua/
	Confirm.lua.
]]

return function(ctx)
	local Players = game:GetService("Players")
	local TweenService = game:GetService("TweenService")
	local Theme = ctx:Require("Theme")

	local Helpers = {}

	function Helpers.new(className, properties, children)
		local instance = Instance.new(className)
		for key, value in pairs(properties or {}) do
			instance[key] = value
		end
		for _, child in ipairs(children or {}) do
			child.Parent = instance
		end
		return instance
	end

	function Helpers.corner(radius)
		return Helpers.new("UICorner", { CornerRadius = radius or Theme.CornerRadius })
	end

	-- Real panel surface: every floating card/panel in the source project is a 9-slice image
	-- (Theme.Panel), not a flat Color3 + UICorner - the rounding and shading come from the
	-- image itself. className is "ImageLabel" for static surfaces or "ImageButton" for
	-- clickable ones; pass ImageColor3 in properties to tint darker/lighter than the default.
	function Helpers.panel(className, properties, children)
		local props = {}
		for key, value in pairs(properties or {}) do
			props[key] = value
		end
		props.BackgroundTransparency = 1
		props.Image = props.Image or Theme.Panel.Image
		props.ImageColor3 = props.ImageColor3 or Theme.Panel.Color
		props.ScaleType = Enum.ScaleType.Slice
		props.SliceCenter = Theme.Panel.SliceCenter
		props.SliceScale = Theme.Panel.SliceScale
		return Helpers.new(className, props, children)
	end

	-- Flat surface instead of the 9-slice Panel texture, used for card/panel-style containers
	-- (Paragraph/Button/Toggle/Slider) - the real black @ 0.7 transparency value (same as
	-- Theme.Card, the dashboard row/card background) rather than a lighter flat grey.
	function Helpers.surface(className, properties, children)
		local props = {}
		for key, value in pairs(properties or {}) do
			props[key] = value
		end
		props.BackgroundColor3 = props.BackgroundColor3 or Color3.new(0, 0, 0)
		props.BackgroundTransparency = props.BackgroundTransparency or 0.7

		local kids = { Helpers.corner(Theme.CornerRadius) }
		for _, child in ipairs(children or {}) do
			table.insert(kids, child)
		end

		return Helpers.new(className, props, kids)
	end

	-- Resolves an icon argument that may be nil, an already-real Roblox asset reference
	-- ("rbxassetid://...", "rbxasset://...", a URL), or a Lucide icon name ("settings",
	-- "shield-alert", ...) - see Lucide.lua, vendored from
	-- https://github.com/latte-soft/lucide-roblox (MIT). Returns a props table to merge onto
	-- an ImageLabel/ImageButton (Image, plus ImageRectOffset/ImageRectSize for a Lucide sprite);
	-- empty if nothing could be resolved, so an unknown name just falls back to no icon rather
	-- than erroring the whole element.
	function Helpers.icon(value, size)
		if type(value) ~= "string" or value == "" then
			return {}
		end
		if value:match("^rbx") or value:match("^https?://") then
			return { Image = value, ImageRectOffset = Vector2.new(0, 0), ImageRectSize = Vector2.new(0, 0) }
		end

		local Lucide = ctx:Require("Lucide")
		local asset = Lucide.GetAsset(value, size or 48)
		if not asset then
			return {}
		end
		return {
			Image = asset.Url,
			ImageRectOffset = asset.ImageRectOffset,
			ImageRectSize = asset.ImageRectSize,
		}
	end

	-- Helpers.icon, merged directly onto a properties table - the usual call shape at every
	-- icon-consuming call site (Window.lua's nav/tab buttons, Elements.lua's Button/Card/Toggle).
	-- `fallback`, if given, is a real asset id applied when `value` didn't resolve to anything -
	-- covers both "no icon requested" (value is nil) AND "an icon was requested but the name
	-- isn't a real Lucide icon" (Helpers.icon can't tell those apart, but an unresolvable name
	-- landing on the same fallback as no name at all is what makes it a *fallback* rather than
	-- silently rendering a blank icon).
	function Helpers.withIcon(props, value, size, fallback)
		local resolved = Helpers.icon(value, size)
		if next(resolved) == nil and fallback then
			resolved = { Image = fallback }
		end
		for key, resolvedValue in pairs(resolved) do
			props[key] = resolvedValue
		end
		return props
	end

	function Helpers.stroke(color, thickness)
		return Helpers.new("UIStroke", {
			Color = color or Theme.Glow,
			Thickness = thickness or 1,
		})
	end

	-- Sets the CornerRadius of root's own direct UICorner child, if any. Deliberately not
	-- recursive - a recursive version would also flatten every nested button/toggle/pill corner,
	-- not just the window's own outer shape (see Window.lua's fullscreen toggle, the only caller).
	function Helpers.setOwnCorner(root, radius)
		local existing = root:FindFirstChildOfClass("UICorner")
		if existing then
			existing.CornerRadius = radius
		end
	end

	function Helpers.safeUiParent()
		local player = Players.LocalPlayer
		local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
		if playerGui then
			return playerGui
		end
		return game:GetService("CoreGui")
	end

	-- Ported from window_handler.luau's controls.restore/resize hover wiring: grow the icon and
	-- fade in a halo image behind it on hover, shrink further on press, and reset on InputEnded -
	-- deliberately InputEnded rather than MouseLeave, matching the source (it fires on release
	-- and on the mouse leaving a hovered button alike, so one handler covers both).
	function Helpers.wireIconHover(button, iconScale, selection, selectionScale)
		local tween = Theme.Tweens.Window

		button.MouseEnter:Connect(function()
			TweenService:Create(iconScale, tween, { Scale = 1.2 }):Play()
			TweenService:Create(selection, tween, { ImageTransparency = 0.8 }):Play()
			TweenService:Create(selectionScale, tween, { Scale = 1 }):Play()
		end)

		button.MouseButton1Down:Connect(function()
			TweenService:Create(iconScale, tween, { Scale = 0.5 }):Play()
			TweenService:Create(selection, tween, { ImageTransparency = 0.9 }):Play()
			TweenService:Create(selectionScale, tween, { Scale = 0.8 }):Play()
		end)

		button.InputEnded:Connect(function()
			TweenService:Create(iconScale, tween, { Scale = 1 }):Play()
			TweenService:Create(selection, tween, { ImageTransparency = 1 }):Play()
			TweenService:Create(selectionScale, tween, { Scale = 0.5 }):Play()
		end)
	end

	-- Ported from hover_navi() (dashboard/credits/menu/main_frame handlers): the gradient rotates
	-- continuously in the background from the moment the button exists, but is invisible until
	-- Enabled is toggled on - so hovering just reveals a shimmer already mid-sweep rather than
	-- starting a fresh animation each time.
	function Helpers.wireShimmerHover(button, gradient)
		gradient.Rotation = 0
		TweenService:Create(gradient, Theme.Tweens.GradientLoop, { Rotation = 360 }):Play()

		button.MouseEnter:Connect(function()
			gradient.Enabled = true
		end)

		button.InputEnded:Connect(function()
			gradient.Enabled = false
		end)
	end

	return Helpers
end
