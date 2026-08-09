--[[
	Elements.lua

	Tab-scoped element constructors: Paragraph, Button, Toggle. Mixed into each Tab object
	returned by Window:Tab (see Window.lua) via __index, so callers write tab:Button{...} etc.

	Paragraph/Button/Toggle/Slider use Helpers.surface - a flat Theme.SurfaceRaised @ 0.3
	transparency background, the same treatment as Window.lua's nav buttons, so tab content reads
	as one family instead of mixing in the separate 9-slice Panel texture (Helpers.panel, still
	used by Window.lua's menu popup and Confirm.lua's dialog, both real extracted values). Toggle
	is a checkmark row (label + a check icon that shows/hides), not an iOS-style knob/track switch
	- the source has no knob/track switch anywhere; every boolean and single-choice setting uses
	this checkmark pattern instead, so this matches the actual source UI rather than inventing one
	that isn't there.
]]

return function(ctx)
	local TweenService = game:GetService("TweenService")
	local UserInputService = game:GetService("UserInputService")

	local Theme = ctx:Require("Theme")
	local Helpers = ctx:Require("Helpers")
	local new, surface, corner = Helpers.new, Helpers.surface, Helpers.corner

	local Elements = {}

	function Elements:_nextOrder()
		self.ElementOrder += 1
		return self.ElementOrder
	end

	function Elements:Paragraph(options)
		options = options or {}

		local titleLabel = new("TextLabel", {
			Name = "title",
			BackgroundTransparency = 1,
			Text = options.Title or "",
			FontFace = Theme.CustomFontMedium,
			TextSize = 14,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 18),
		})

		local descLabel = new("TextLabel", {
			Name = "desc",
			BackgroundTransparency = 1,
			Text = options.Desc or "",
			FontFace = Theme.CustomFont,
			TextSize = 13,
			TextColor3 = Theme.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.fromOffset(0, 20),
		})

		local container = surface("Frame", {
			Name = "paragraph",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = self:_nextOrder(),
		}, {
			new("UIPadding", {
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			titleLabel,
			descLabel,
		})
		container.Parent = self.Page

		local paragraph = {}
		function paragraph:SetTitle(text)
			titleLabel.Text = text
		end
		function paragraph:SetDesc(text)
			descLabel.Text = text
		end
		function paragraph:Destroy()
			container:Destroy()
		end
		return paragraph
	end

	function Elements:Button(options)
		options = options or {}
		local hasIcon = options.Icon ~= nil and options.Icon ~= ""
		local textOffset = hasIcon and 32 or 0

		local icon = new("ImageLabel", Helpers.withIcon({
			Name = "icon",
			BackgroundTransparency = 1,
			Visible = hasIcon,
			ImageColor3 = Theme.Text,
			ImageTransparency = 0.2,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(20, 20),
			Position = UDim2.fromOffset(0, 0),
		}, options.Icon, 48))

		local titleLabel = new("TextLabel", {
			Name = "title",
			BackgroundTransparency = 1,
			Text = options.Title or "",
			FontFace = Theme.CustomFontMedium,
			TextSize = 14,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(textOffset, 0),
			Size = UDim2.new(1, -textOffset, 0, 18),
		})

		local descLabel = new("TextLabel", {
			Name = "desc",
			BackgroundTransparency = 1,
			Text = options.Desc or "",
			Visible = options.Desc ~= nil and options.Desc ~= "",
			FontFace = Theme.CustomFont,
			TextSize = 13,
			TextColor3 = Theme.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Position = UDim2.fromOffset(textOffset, 20),
			Size = UDim2.new(1, -textOffset, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		})

		local shimmer = new("UIGradient", {
			Enabled = false,
			Transparency = Theme.ShimmerTransparency,
		})

		local button = surface("ImageButton", {
			Name = "button",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = self:_nextOrder(),
		}, {
			shimmer,
			new("UIPadding", {
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			icon,
			titleLabel,
			descLabel,
		})
		button.Parent = self.Page

		button.MouseEnter:Connect(function()
			TweenService:Create(button, Theme.Tweens.Fast, { BackgroundTransparency = 0.5 }):Play()
		end)
		button.MouseLeave:Connect(function()
			TweenService:Create(button, Theme.Tweens.Fast, { BackgroundTransparency = 0.7 }):Play()
		end)
		Helpers.wireShimmerHover(button, shimmer)
		button.MouseButton1Click:Connect(function()
			if type(options.Callback) == "function" then
				options.Callback()
			end
		end)

		return button
	end

	-- iOS-style track+knob switch, not the checkmark row the real source actually uses anywhere
	-- (it has no knob/track switch at all) - a deliberate, explicitly-requested departure from
	-- 1:1 replication for this one element. Track/knob stay in the same monochrome family as the
	-- rest of the theme (Theme.Surface/SurfaceRaised/Text) rather than introducing an accent hue,
	-- and the knob's slide uses Theme.Tweens.Toggle (Back Out) for the tactile little overshoot
	-- an iOS switch has, instead of the plain eases used everywhere else.
	function Elements:Toggle(options)
		options = options or {}
		local value = options.Value == true
		local hasIcon = options.Icon ~= nil and options.Icon ~= ""
		local textOffset = hasIcon and 32 or 0
		local switchWidth = 44

		local icon = new("ImageLabel", Helpers.withIcon({
			Name = "icon",
			BackgroundTransparency = 1,
			Visible = hasIcon,
			ImageColor3 = Theme.Text,
			ImageTransparency = 0.2,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(20, 20),
			Position = UDim2.fromOffset(0, 0),
		}, options.Icon, 48))

		local titleLabel = new("TextLabel", {
			Name = "title",
			BackgroundTransparency = 1,
			Text = options.Title or "",
			FontFace = Theme.CustomFontMedium,
			TextSize = 14,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(textOffset, 0),
			Size = UDim2.new(1, -textOffset - switchWidth - 12, 0, 18),
		})

		local descLabel = new("TextLabel", {
			Name = "desc",
			BackgroundTransparency = 1,
			Text = options.Desc or "",
			Visible = options.Desc ~= nil and options.Desc ~= "",
			FontFace = Theme.CustomFont,
			TextSize = 13,
			TextColor3 = Theme.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Position = UDim2.fromOffset(textOffset, 20),
			Size = UDim2.new(1, -textOffset - switchWidth - 12, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		})

		local knob = new("Frame", {
			Name = "knob",
			BackgroundColor3 = Theme.Text,
			BackgroundTransparency = 0.05,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = value and UDim2.fromOffset(32, 12) or UDim2.fromOffset(12, 12),
			Size = UDim2.fromOffset(18, 18),
		}, { corner(Theme.CornerRadiusPill) })

		local switch = new("Frame", {
			Name = "switch",
			BackgroundColor3 = value and Theme.SurfaceRaised or Theme.Surface,
			BackgroundTransparency = value and 0.05 or 0.35,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(switchWidth, 24),
		}, { corner(Theme.CornerRadiusPill), Helpers.stroke(Theme.Glow, 1), knob })

		local hitbox = surface("ImageButton", {
			Name = "toggle",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = self:_nextOrder(),
		}, {
			new("UIPadding", {
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			icon,
			titleLabel,
			descLabel,
			switch,
		})
		hitbox.Parent = self.Page

		local api = {}

		local function render()
			TweenService:Create(knob, Theme.Tweens.Toggle, {
				Position = value and UDim2.fromOffset(32, 12) or UDim2.fromOffset(12, 12),
			}):Play()
			TweenService:Create(switch, Theme.Tweens.Fast, {
				BackgroundColor3 = value and Theme.SurfaceRaised or Theme.Surface,
				BackgroundTransparency = value and 0.05 or 0.35,
			}):Play()
		end

		-- Deliberately does not invoke options.Callback - this is the programmatic setter (e.g. a
		-- caller resetting a toggle's visual state), not a user click, so it must not re-trigger
		-- whatever the callback does.
		function api:Set(newValue)
			value = newValue == true
			render()
		end

		hitbox.MouseButton1Click:Connect(function()
			value = not value
			render()
			if type(options.Callback) == "function" then
				options.Callback(value)
			end
		end)

		return api
	end

	-- Dashboard-style labeled section: a title+description on the left (real values: 25px
	-- title @ 0.2 transparency, 14px description @ 0.8 transparency, both offset per the
	-- source's own header/description layout) and a horizontal row of icon cards on the
	-- right, added via section:Card{...}. Matches scroll > moderator_tools/server_equipment/
	-- additional_features > features in the source's dashboard_frame.
	function Elements:Section(options)
		options = options or {}

		local descLabel = new("TextLabel", {
			Name = "description",
			BackgroundTransparency = 1,
			Text = options.Desc or "",
			FontFace = Theme.CustomFont,
			TextSize = 14,
			TextColor3 = Theme.Text,
			TextTransparency = Theme.SectionDescTransparency,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Position = UDim2.fromOffset(0, 55),
		})

		local titleLabel = new("TextLabel", {
			Name = "title",
			BackgroundTransparency = 1,
			Text = options.Title or "",
			FontFace = Theme.CustomFontMedium,
			TextSize = 25,
			TextColor3 = Theme.Text,
			TextTransparency = Theme.SectionTitleTransparency,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0, 150, 1, 0),
		}, { descLabel })

		local features = new("Frame", {
			Name = "features",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(1, -180, 1, 0),
		}, {
			new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})

		local container = new("Frame", {
			Name = "section",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 150),
			LayoutOrder = self:_nextOrder(),
		}, {
			new("UIPadding", {
				PaddingTop = UDim.new(0, 20),
				PaddingBottom = UDim.new(0, 20),
				PaddingLeft = UDim.new(0, 20),
			}),
			titleLabel,
			features,
		})
		container.Parent = self.Page

		local section = { Cards = {} }

		local function relayout()
			local count = #section.Cards
			if count == 0 then
				return
			end
			local widthEach = -(10 * (count - 1)) / count
			for _, card in ipairs(section.Cards) do
				card.Size = UDim2.new(1 / count, widthEach, 1, 0)
			end
		end

		function section:Card(cardOptions)
			cardOptions = cardOptions or {}

			local icon = new("ImageLabel", Helpers.withIcon({
				Name = "icon",
				BackgroundTransparency = 1,
				ImageTransparency = Theme.Card.IconTransparency,
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromOffset(30, 30),
			}, cardOptions.Icon, 48))

			local label = new("TextLabel", {
				Name = "label",
				BackgroundTransparency = 1,
				Text = cardOptions.Title or "",
				FontFace = Theme.CustomFontMedium,
				TextSize = 14,
				TextColor3 = Theme.Text,
				TextTransparency = Theme.Card.LabelTransparency,
				TextWrapped = true,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 10),
			})

			local card = new("ImageButton", {
				Name = "card",
				BackgroundColor3 = Theme.Card.Background,
				BackgroundTransparency = Theme.Card.BackgroundTransparency,
				Size = UDim2.new(1, 0, 1, 0),
				LayoutOrder = #section.Cards + 1,
			}, {
				corner(Theme.Card.CornerRadius),
				new("UIListLayout", {
					VerticalAlignment = Enum.VerticalAlignment.Center,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, 12),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				new("UIPadding", {
					PaddingTop = UDim.new(0, 10),
					PaddingBottom = UDim.new(0, 10),
					PaddingLeft = UDim.new(0, 15),
					PaddingRight = UDim.new(0, 15),
				}),
				icon,
				label,
			})
			card.Parent = features

			card.MouseEnter:Connect(function()
				TweenService:Create(card, Theme.Tweens.Fast, { BackgroundTransparency = 0.5 }):Play()
			end)
			card.MouseLeave:Connect(function()
				TweenService:Create(card, Theme.Tweens.Fast, { BackgroundTransparency = Theme.Card.BackgroundTransparency }):Play()
			end)
			card.MouseButton1Click:Connect(function()
				if type(cardOptions.Callback) == "function" then
					cardOptions.Callback()
				end
			end)

			table.insert(section.Cards, card)
			relayout()

			return card
		end

		function section:Destroy()
			container:Destroy()
		end

		return section
	end

	-- Real slider values (tools_panels' custom-command rows): pill black@70% track, an inset
	-- "depth" 9-slice shadow image, min/max labels pinned to the ends, and a circular handle
	-- image. The drag math itself is ours, not Krypt's third-party module - see Theme.Slider.
	function Elements:Slider(options)
		options = options or {}
		local min = options.Min or 0
		local max = options.Max or 100
		local increment = options.Increment or 1
		local value = math.clamp(options.Value or min, min, max)

		-- Chip/badge pattern (real "bulked"/"adornee" tag style: BackgroundColor3=TextColor3 @ 0.8
		-- transparency, pill corner, auto-sized) instead of a bare, unpositioned text label.
		local valueLabel = new("TextLabel", {
			Name = "text",
			BackgroundTransparency = 1,
			Text = tostring(value),
			FontFace = Theme.CustomFontMedium,
			TextSize = 12,
			TextColor3 = Theme.Text,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
		})

		local valueBadge = new("Frame", {
			Name = "value",
			BackgroundColor3 = Theme.Text,
			BackgroundTransparency = 0.8,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
		}, {
			corner(Theme.CornerRadiusPill),
			new("UIPadding", {
				PaddingLeft = UDim.new(0, 9),
				PaddingRight = UDim.new(0, 9),
			}),
			valueLabel,
		})

		local titleLabel = new("TextLabel", {
			Name = "title",
			BackgroundTransparency = 1,
			Text = options.Title or "",
			FontFace = Theme.CustomFontMedium,
			TextSize = 14,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -50, 0, 20),
		}, { valueBadge })

		local descLabel = new("TextLabel", {
			Name = "desc",
			BackgroundTransparency = 1,
			Text = options.Desc or "",
			Visible = options.Desc ~= nil and options.Desc ~= "",
			FontFace = Theme.CustomFont,
			TextSize = 13,
			TextColor3 = Theme.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		})

		local header = new("Frame", {
			Name = "header",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,
		}, {
			new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
			titleLabel,
			descLabel,
		})

		local minLabel = new("TextLabel", {
			Name = "min_value",
			BackgroundTransparency = 1,
			Text = tostring(min),
			FontFace = Theme.CustomFont,
			TextSize = 12,
			TextColor3 = Theme.TextMuted,
			Size = UDim2.fromOffset(30, Theme.Slider.TrackHeight),
			Position = UDim2.fromOffset(12, 0),
		})

		local maxLabel = new("TextLabel", {
			Name = "max_value",
			BackgroundTransparency = 1,
			Text = tostring(max),
			FontFace = Theme.CustomFont,
			TextSize = 12,
			TextColor3 = Theme.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.fromOffset(30, Theme.Slider.TrackHeight),
			Position = UDim2.new(1, -42, 0, 0),
		})

		local depth = new("ImageLabel", {
			Name = "depth",
			BackgroundTransparency = 1,
			Image = Theme.Slider.DepthImage,
			ImageTransparency = 0.5,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Theme.Slider.DepthSliceCenter,
			Size = UDim2.new(1, 0, 1, 0),
		})

		-- Fills the track from the left up to the handle, giving it a sense of progress. Flat
		-- Theme.SurfaceRaised (the same gray used for the nav buttons/panel elements) instead of
		-- the real "focused_bg" blue/purple gradient, which would clash with the rest of the theme.
		local fill = new("Frame", {
			Name = "fill",
			BackgroundColor3 = Theme.SurfaceRaised,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Size = UDim2.fromScale(0, 1),
			ZIndex = 1,
		}, {
			corner(Theme.CornerRadiusPill),
		})

		-- Real halo pattern (Theme.Icons.Glow) reused here as a soft glow sitting behind the
		-- handle, matching the "lifted" feel of the window controls' own hover halo instead of a
		-- flat plain circle.
		local handleGlow = new("ImageLabel", {
			Name = "glow",
			BackgroundTransparency = 1,
			Image = Theme.Icons.Glow,
			ImageTransparency = 0.5,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(Theme.Slider.HandleSize + 22, Theme.Slider.HandleSize + 22),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = 2,
		})

		local handle = new("ImageLabel", {
			Name = "handle",
			BackgroundTransparency = 1,
			Image = Theme.Slider.HandleImage,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(Theme.Slider.HandleSize, Theme.Slider.HandleSize),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			ZIndex = 3,
		}, { handleGlow })

		local track = new("TextButton", {
			Name = "track",
			Text = "",
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.7,
			Size = UDim2.new(1, 0, 0, Theme.Slider.TrackHeight),
			LayoutOrder = 2,
		}, { corner(Theme.CornerRadiusPill), Helpers.stroke(Theme.Glow, 1), depth, fill, minLabel, maxLabel, handle })

		local container = surface("Frame", {
			Name = "slider",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = self:_nextOrder(),
		}, {
			new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
			new("UIPadding", {
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			header,
			track,
		})
		container.Parent = self.Page

		local function render()
			local fraction = (value - min) / (max - min)
			TweenService:Create(handle, Theme.Tweens.Fast, {
				Position = UDim2.new(fraction, 0, 0.5, 0),
			}):Play()
			TweenService:Create(fill, Theme.Tweens.Fast, {
				Size = UDim2.fromScale(fraction, 1),
			}):Play()
			valueLabel.Text = tostring(value)
		end

		local function setFromScreenX(x)
			local fraction = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
			local raw = min + fraction * (max - min)
			value = math.clamp(math.floor(raw / increment + 0.5) * increment, min, max)
			render()
			if type(options.Callback) == "function" then
				options.Callback(value)
			end
		end

		local dragging = false

		track.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				setFromScreenX(input.Position.X)
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				setFromScreenX(input.Position.X)
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)

		render()

		local api = {}

		function api:Set(newValue)
			value = math.clamp(newValue, min, max)
			render()
		end

		function api:Get()
			return value
		end

		return api
	end

	return Elements
end
