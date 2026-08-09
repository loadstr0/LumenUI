--[[
	Window.lua

	Window creation and chrome, rebuilt to match the source project's real navigation model
	instead of inventing a Rayfield-style sidebar. The source has no persistent sidebar at all:
	- window_handler.luau: a small drag "handle" button (real icon rbxassetid://12974354535) that
	  both drags the window and toggles a "controls" cluster (resize + fullscreen/restore icons,
	  the halo-hover pattern already in Helpers.wireIconHover).
	- exe_main_module.luau (:Go_To): pages are CanvasGroups switched by tweening Position
	  ((.5,0,1,0) visible / (.5,0,1.2,0) off-screen below) and GroupTransparency together, on the
	  real "slow" (.8s Exponential) tween - not UIPageLayout.
	- menu_handler.luau / navigation_buttons: a small circular nav button (real icon
	  rbxassetid://11295285432) opens a floating popup menu (menu_frame) listing the available
	  pages; picking one calls Go_To and closes the popup. This popup - not a sidebar - is how
	  navigation actually works in the source.
	- exe_main_module:exe_admin_panel: opening/closing the whole window tweens BackgroundTransparency
	  and a UIScale from 1.2->1, on the real "info" (.8s Exponential Out) tween - not an instant
	  Enabled flip. (The real source also drives a Lighting BlurEffect here; left out of LumenUI
	  by request.)
]]

return function(ctx)
	local TweenService = game:GetService("TweenService")
	local UserInputService = game:GetService("UserInputService")

	local Theme = ctx:Require("Theme")
	local Helpers = ctx:Require("Helpers")
	local BulkFade = ctx:Require("BulkFade")
	local new, corner, stroke, panel, setOwnCorner, safeUiParent =
		Helpers.new, Helpers.corner, Helpers.stroke, Helpers.panel, Helpers.setOwnCorner, Helpers.safeUiParent

	local Window = {}
	Window.__index = Window

	local MIN_SIZE = Vector2.new(550, 350)

	-- Flattens a list of root instances into itself + every descendant, so a BulkFade group
	-- covers a whole chrome cluster (icons, gradients, nested frames) from just its top-level
	-- parts. `opaque` roots are included themselves but not walked into - see pagesContainer's
	-- use of this, which owns its own fade (a CanvasGroup) precisely so its contents are never
	-- captured here.
	local function withDescendants(roots, opaque)
		opaque = opaque or {}
		local result = {}
		for _, root in ipairs(roots) do
			table.insert(result, root)
			if not opaque[root] then
				for _, descendant in ipairs(root:GetDescendants()) do
					table.insert(result, descendant)
				end
			end
		end
		return result
	end

	-- BulkFade.CreateGroup snapshots each element's transparency at call time and treats that as
	-- the "appear" target forever after - so if it's rebuilt AFTER a fade-out (elements already
	-- sitting at 1), the new snapshot just captures 1 and FadeIn becomes a no-op (1 -> 1). The fix
	-- is to snapshot the real authored values exactly once, the first time a panel's shown, and
	-- keep reusing that same pair of groups (a same-snapshot 0-time "snap" group for the instant
	-- reset, and a real-tween "fade" group for the animated move) for every later toggle.
	local function buildFadePair(elements, tween)
		return BulkFade.CreateGroup(elements, tween), BulkFade.CreateGroup(elements, TweenInfo.new(0))
	end

	-- Real window_controls.controls.restore/resize structure: icon + halo "selection" image,
	-- each with its own UIScale, driven by Helpers.wireIconHover.
	local function controlButton(props)
		local iconScale = new("UIScale", { Scale = 1 })
		local icon = new("ImageLabel", {
			Name = "icon",
			BackgroundTransparency = 1,
			Image = props.Icon,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(20, 20),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = 2,
		}, { iconScale })

		local selectionScale = new("UIScale", { Scale = 0.5 })
		local selection = new("ImageLabel", {
			Name = "selection",
			BackgroundTransparency = 1,
			Image = Theme.Icons.Glow,
			ImageTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(40, 40),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = 1,
		}, { selectionScale })

		local button = new("ImageButton", {
			Name = props.Name,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(50, 50),
			LayoutOrder = props.LayoutOrder,
		}, { selection, icon })

		Helpers.wireIconHover(button, iconScale, selection, selectionScale)

		return button, icon
	end

	-- Real navigation_buttons pattern: a pill-shaped, near-transparent white button with a
	-- centered icon, using the rotating-shimmer hover (Helpers.wireShimmerHover) instead of the
	-- halo pattern - this is the source's OTHER hover style, used for nav/action icon buttons.
	local function navButton(props)
		local iconScale = new("UIScale", { Scale = 1 })
		-- Falls back to the hamburger glyph both when no icon was requested (props.Icon is nil)
		-- and when one was requested but the name isn't a real Lucide icon - Helpers.icon can't
		-- tell those two apart on its own, so the fallback has to be supplied here.
		local icon = new("ImageLabel", Helpers.withIcon({
			Name = "icon",
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.45, 0.45),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		}, props.Icon, 48, Theme.Icons.Menu), { iconScale })

		local shimmer = new("UIGradient", {
			Enabled = false,
			Transparency = Theme.ShimmerTransparency,
		})

		local button = new("ImageButton", {
			Name = props.Name or "nav",
			BackgroundColor3 = Theme.SurfaceRaised,
			BackgroundTransparency = 0.3,
			Size = props.Size or UDim2.fromOffset(40, 40),
			Position = props.Position,
			AnchorPoint = props.AnchorPoint,
			LayoutOrder = props.LayoutOrder,
		}, { corner(Theme.CornerRadiusPill), shimmer, icon })

		Helpers.wireShimmerHover(button, shimmer)

		button.MouseEnter:Connect(function()
			TweenService:Create(iconScale, Theme.Tweens.Fast, { Scale = 1.2 }):Play()
		end)
		button.MouseButton1Down:Connect(function()
			TweenService:Create(iconScale, Theme.Tweens.Fast, { Scale = 0.8 }):Play()
		end)
		button.InputEnded:Connect(function()
			TweenService:Create(iconScale, Theme.Tweens.Fast, { Scale = 1 }):Play()
		end)

		return button
	end

	function Window.new(options)
		options = options or {}

		local screenGui = new("ScreenGui", {
			Name = options.Name or "LumenUI",
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 100,
			Parent = safeUiParent(),
		})

		local viewport = workspace.CurrentCamera.ViewportSize
		local maxSize = Vector2.new(viewport.X - 50, viewport.Y - 50)
		local initialSize = options.Size or UDim2.fromOffset(620, 470)

		local titleLabel = new("TextLabel", {
			Name = "title",
			Visible = false,
			BackgroundTransparency = 1,
			Text = options.Title or "LumenUI",
			FontFace = Theme.CustomFontMedium,
			TextSize = 18,
			TextColor3 = Theme.Text,
			TextTransparency = 0.2,
			Size = UDim2.new(1, -32, 0, 24),
			Position = UDim2.fromOffset(16, 44),
		})

		-- Small muted breadcrumb under the window title showing which tab is active - kept in
		-- sync by GoTo(), the only place a tab ever becomes active.
		local tabLabel = new("TextLabel", {
			Name = "tab_label",
			Visible = false,
			BackgroundTransparency = 1,
			Text = "",
			FontFace = Theme.CustomFont,
			TextSize = 13,
			TextColor3 = Theme.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -32, 0, 16),
			Position = UDim2.fromOffset(16, 70),
		})

		-- Rayfield-style intro: a small "Welcome back" card shown instead of popping the full
		-- window straight in - see Window:_playIntro, called at the bottom of Window.new.
		local splashWelcome = new("TextLabel", {
			Name = "welcome",
			BackgroundTransparency = 1,
			Text = "Welcome back!",
			FontFace = Theme.CustomFontSemiBold,
			TextSize = 20,
			TextColor3 = Theme.Text,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, -16),
			Size = UDim2.new(1, -32, 0, 26),
		})

		local splashHubName = new("TextLabel", {
			Name = "hub_name",
			BackgroundTransparency = 1,
			Text = options.Title or "LumenUI",
			FontFace = Theme.CustomFont,
			TextSize = 14,
			TextColor3 = Theme.TextMuted,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 14),
			Size = UDim2.new(1, -32, 0, 18),
		})

		local splashLayer = new("Frame", {
			Name = "splash",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 30,
		}, { splashWelcome, splashHubName })

		local handleIcon = new("ImageLabel", {
			Name = "icon",
			BackgroundTransparency = 1,
			Image = Theme.Icons.Handle,
			ImageTransparency = 0.5,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(1, 0.75),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
		})

		local handle = new("ImageButton", {
			Name = "handle",
			Visible = false,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			ZIndex = 10,
			Size = UDim2.fromOffset(60, 40),
			Position = UDim2.new(0.5, 0, 0, 0),
			AnchorPoint = Vector2.new(0.5, 0),
		}, { handleIcon })

		local fullscreenButton, fullscreenIcon = controlButton({
			Name = "restore",
			Icon = Theme.Icons.EnterFullscreen,
			LayoutOrder = 1,
		})

		local resizeButton = controlButton({
			Name = "resize",
			Icon = Theme.Icons.Resize,
			LayoutOrder = 3,
		})

		-- Real fullscreen behaviour: only resize gets disabled (you can't resize a fullscreen
		-- window) - restore stays live the whole time, just swapping its own icon. A faded,
		-- non-interactive ghost takes resize's exact slot in the list while it's hidden.
		local resizeDisabled = new("ImageLabel", {
			Name = "resize_disabled",
			BackgroundTransparency = 1,
			Visible = false,
			Size = UDim2.fromOffset(50, 50),
			LayoutOrder = 3,
		}, {
			new("ImageLabel", {
				Name = "icon",
				BackgroundTransparency = 1,
				Image = Theme.Icons.Resize,
				ImageTransparency = 0.8,
				Rotation = 90,
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromOffset(20, 20),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
			}),
		})

		local controls = new("Frame", {
			Name = "controls",
			BackgroundTransparency = 1,
			Visible = false,
			Size = UDim2.new(0, 100, 0, 50),
			Position = UDim2.new(1, 0, 1, 0),
			AnchorPoint = Vector2.new(1, 1),
		}, {
			new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
			}),
			fullscreenButton,
			resizeButton,
			resizeDisabled,
		})

		local resizeHandle = new("TextButton", {
			Name = "resizeHandle",
			Visible = false,
			Text = "",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(18, 18),
			Position = UDim2.new(1, -18, 1, -18),
		})

		-- CanvasGroup, not a Frame: its own GroupTransparency is what SetVisible/_playIntro fade
		-- in/out for the whole tab-content area, kept completely separate from the per-tab
		-- CanvasGroups GoTo() manages inside it (see _ensureContentFade/withDescendants's `opaque`
		-- exclusion of this container) - those two fades were fighting each other before: closing
		-- and reopening the window while on a non-Home tab would snap the ACTIVE tab back to
		-- whatever GroupTransparency/Visible BulkFade had snapshotted for it the first time the
		-- window ever opened (Home, at 0; every other tab, at 1, since they hadn't been visited
		-- yet), showing a stale sliver of Home's content instead of the tab actually open.
		local pagesContainer = new("CanvasGroup", {
			Name = "pages",
			Visible = false,
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			ClipsDescendants = true,
			Size = UDim2.new(1, -32, 1, -108),
			Position = UDim2.fromOffset(16, 88),
		})

		local menuList = new("Frame", {
			Name = "list",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 40),
		}, {
			new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})

		local menuScale = new("UIScale", { Scale = 0.5 })
		local menuPopup = panel("ImageLabel", {
			Name = "popup",
			ImageTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 64),
			Position = UDim2.new(0.5, 0, 1, -70),
			AnchorPoint = Vector2.new(0.5, 1),
		}, {
			menuScale,
			new("UIPadding", {
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			menuList,
		})

		local menuBackdrop = new("TextButton", {
			Name = "menu_backdrop",
			Text = "",
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 5,
			Size = UDim2.fromScale(1, 1),
		}, { menuPopup })

		local menuButton = navButton({
			Name = "menu_trigger",
			Icon = Theme.Icons.Menu,
			Size = UDim2.fromOffset(36, 36),
			Position = UDim2.new(0, 16, 1, -16),
			AnchorPoint = Vector2.new(0, 1),
		})
		menuButton.Visible = false

		-- Real "frame" is an ImageButton, not a plain Frame: BackgroundColor3 (15,15,15) at 0.1
		-- transparency WITH the grain image baked onto the same instance (ImageTransparency 0.8,
		-- ScaleType Crop - stretched to fill as one large image, not tiled as a small repeating
		-- pattern) rather than a separate flat Frame + child ImageLabel. Modal=true blocks input
		-- to whatever's behind the window.
		-- Real value: an invisible full-cover ImageButton, shown only while dragging/resizing so
		-- the cursor doesn't hover/click whatever's underneath mid-drag. It's not a visual dimming
		-- effect - the source only ever toggles its Visible, never its transparency.
		local layer = new("ImageButton", {
			Name = "layer",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Visible = false,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 20,
		})

		local splashSize = UDim2.fromOffset(320, 130)

		local windowScale = new("UIScale", { Scale = 1 })
		local mainFrame = new("ImageButton", {
			Name = "main",
			AutoButtonColor = false,
			Modal = true,
			BackgroundColor3 = Theme.Background,
			BackgroundTransparency = 0.1,
			Image = Theme.WindowBackgroundImage,
			ImageTransparency = 0.8,
			ScaleType = Enum.ScaleType.Crop,
			Size = splashSize,
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ClipsDescendants = true,
		}, {
			windowScale,
			corner(),
			stroke(Theme.Glow, 1),
			titleLabel,
			tabLabel,
			handle,
			controls,
			pagesContainer,
			menuButton,
			menuBackdrop,
			resizeHandle,
			layer,
			splashLayer,
		})

		mainFrame.Parent = screenGui

		-- Not nested under mainFrame (which ClipsDescendants), so Destroy() below must clean it
		-- up explicitly instead of it going away with the rest of the tree.
		-- Real value: a drop-shadow image sized mainFrame.Size + (110,110), rbxassetid://
		-- 16286730454, ImageTransparency 0.5, SliceCenter (512,512,512,512), SliceScale 0.19,
		-- ZIndex -10 (confirmed against every "shadow" instance in the exported reference - all
		-- share this exact recipe). It's a sibling of mainFrame (mainFrame.ClipsDescendants=true
		-- would clip it if nested), so it's kept in sync via PropertyChangedSignal rather than
		-- threaded through every place mainFrame moves/resizes. Starts fully faded (1) so the
		-- intro/SetVisible open tweens can fade it in to its real 0.5 alongside mainFrame's own
		-- BackgroundTransparency, instead of it just sitting there fully opaque the whole time.
		local shadow = new("ImageLabel", {
			Name = "shadow",
			BackgroundTransparency = 1,
			Image = "rbxassetid://16286730454",
			ImageTransparency = 1,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(512, 512, 512, 512),
			SliceScale = 0.19,
			ZIndex = -10,
		})
		shadow.Parent = screenGui

		local function syncShadow()
			shadow.AnchorPoint = mainFrame.AnchorPoint
			shadow.Position = mainFrame.Position
			shadow.Size = UDim2.new(
				mainFrame.Size.X.Scale, mainFrame.Size.X.Offset + 110,
				mainFrame.Size.Y.Scale, mainFrame.Size.Y.Offset + 110
			)
		end
		syncShadow()
		mainFrame:GetPropertyChangedSignal("Position"):Connect(syncShadow)
		mainFrame:GetPropertyChangedSignal("Size"):Connect(syncShadow)

		local self = setmetatable({
			ScreenGui = screenGui,
			MainFrame = mainFrame,
			Shadow = shadow,
			TabLabel = tabLabel,
			SplashLayer = splashLayer,
			WindowScale = windowScale,
			PagesContainer = pagesContainer,
			MenuList = menuList,
			MenuPopup = menuPopup,
			MenuScale = menuScale,
			MenuBackdrop = menuBackdrop,
			Tabs = {},
			TabOrder = 0,
			ActiveTab = nil,
			Destroyed = false,
			Fullscreen = false,
			MenuOpen = false,
			Visible = true,
			LastPosition = mainFrame.Position,
			LastSize = mainFrame.Size,
		}, Window)

		self:_wireChrome(handle, controls, resizeButton, resizeDisabled, fullscreenButton, fullscreenIcon, resizeHandle, menuButton, menuBackdrop, layer, maxSize)

		if options.ToggleKeybind then
			self.ToggleConnection = UserInputService.InputBegan:Connect(function(input, processed)
				if processed then
					return
				end
				if input.KeyCode == options.ToggleKeybind then
					self:SetVisible(not self.Visible)
				end
			end)
		end

		-- Real exe_admin_panel behaviour: the window always opens with the pop-in animation -
		-- here fronted by a small "Welcome back" splash that grows into it (see _playIntro).
		self:_playIntro({ titleLabel, tabLabel, handle, pagesContainer, menuButton, resizeHandle }, initialSize)

		return self
	end

	function Window:_wireChrome(handle, controls, resizeButton, resizeDisabled, fullscreenButton, fullscreenIcon, resizeHandle, menuButton, menuBackdrop, layer, maxSize)
		local tweens = Theme.Tweens
		local mainFrame = self.MainFrame

		local dragging = false
		local dragStartInput, dragStartPos

		handle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStartInput = input.Position
				dragStartPos = mainFrame.Position
				layer.Visible = true
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - dragStartInput
				mainFrame.Position = UDim2.new(
					dragStartPos.X.Scale, dragStartPos.X.Offset + delta.X,
					dragStartPos.Y.Scale, dragStartPos.Y.Offset + delta.Y
				)
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				if dragging then
					dragging = false
					self.LastPosition = mainFrame.Position
					layer.Visible = false
				end
			end
		end)

		local resizing = false
		local resizeStartInput, resizeStartSize

		resizeHandle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				resizing = true
				resizeStartInput = input.Position
				resizeStartSize = mainFrame.Size
				layer.Visible = true
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - resizeStartInput
				local newX = math.clamp(resizeStartSize.X.Offset + delta.X, MIN_SIZE.X, maxSize.X)
				local newY = math.clamp(resizeStartSize.Y.Offset + delta.Y, MIN_SIZE.Y, maxSize.Y)
				mainFrame.Size = UDim2.fromOffset(newX, newY)
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				if resizing then
					resizing = false
					self.LastSize = mainFrame.Size
					layer.Visible = false
				end
			end
		end)

		handle.MouseButton1Click:Connect(function()
			controls.Visible = not controls.Visible
		end)

		fullscreenButton.MouseButton1Click:Connect(function()
			self.Fullscreen = not self.Fullscreen
			if self.Fullscreen then
				self.LastPosition = mainFrame.Position
				self.LastSize = mainFrame.Size
				setOwnCorner(mainFrame, UDim.new(0, 0))
				TweenService:Create(mainFrame, tweens.Smooth, {
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1, 1),
				}):Play()
				fullscreenIcon.Image = Theme.Icons.ExitFullscreen
				resizeButton.Visible = false
				resizeDisabled.Visible = true
			else
				setOwnCorner(mainFrame, Theme.CornerRadius)
				TweenService:Create(mainFrame, tweens.Window, {
					Position = self.LastPosition,
					Size = self.LastSize,
				}):Play()
				fullscreenIcon.Image = Theme.Icons.EnterFullscreen
				resizeButton.Visible = true
				resizeDisabled.Visible = false
			end
		end)

		menuButton.MouseButton1Click:Connect(function()
			self:ToggleMenu()
		end)

		menuBackdrop.MouseButton1Click:Connect(function()
			self:ToggleMenu(false)
		end)
	end

	-- Real menu_frame open/close: slides/scales in from the trigger, backdrop fades in behind
	-- it, all on the real "info" (.5s Exponential) tween.
	function Window:ToggleMenu(forceState)
		local open = forceState
		if open == nil then
			open = not self.MenuOpen
		end
		self.MenuOpen = open

		if open then
			self.MenuBackdrop.Visible = true
			TweenService:Create(self.MenuBackdrop, Theme.Tweens.PanelOpen, { BackgroundTransparency = 0.5 }):Play()
			TweenService:Create(self.MenuPopup, Theme.Tweens.PanelOpen, { ImageTransparency = 0.1 }):Play()
			TweenService:Create(self.MenuScale, Theme.Tweens.PanelOpen, { Scale = 1 }):Play()
		else
			TweenService:Create(self.MenuBackdrop, Theme.Tweens.PanelClose, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(self.MenuPopup, Theme.Tweens.PanelClose, { ImageTransparency = 1 }):Play()
			TweenService:Create(self.MenuScale, Theme.Tweens.PanelClose, { Scale = 0.5 }):Play()
			task.delay(Theme.Tweens.PanelClose.Time, function()
				if not self.MenuOpen then
					self.MenuBackdrop.Visible = false
				end
			end)
		end
	end

	-- Real exe_main_module:Go_To - pages are tweened by Position + GroupTransparency together,
	-- not swapped via UIPageLayout: the outgoing page slides down and fades out while the
	-- incoming page starts below and slides up while fading in.
	function Window:GoTo(id)
		local tab = self.Tabs[id]
		if not tab or tab == self.ActiveTab then
			self:ToggleMenu(false)
			return
		end

		local previous = self.ActiveTab
		self.ActiveTab = tab
		self.TabLabel.Text = tab.Title or ""

		if previous then
			TweenService:Create(previous.CanvasGroup, Theme.Tweens.PageSwitch, {
				Position = UDim2.new(0.5, 0, 1.2, 0),
				GroupTransparency = 1,
			}):Play()
		end

		tab.CanvasGroup.Position = UDim2.new(0.5, 0, 1.2, 0)
		tab.CanvasGroup.GroupTransparency = 1
		tab.CanvasGroup.Visible = true
		TweenService:Create(tab.CanvasGroup, Theme.Tweens.PageSwitch, {
			Position = UDim2.new(0.5, 0, 0.5, 0),
			GroupTransparency = 0,
		}):Play()

		for _, existing in pairs(self.Tabs) do
			TweenService:Create(existing.NavButton, Theme.Tweens.Fast, {
				BackgroundTransparency = existing == tab and 0.7 or 0.9,
			}):Play()
		end

		self:ToggleMenu(false)
	end

	function Window:Tab(id, title, icon)
		if self.Tabs[id] then
			return self.Tabs[id]
		end
		self.TabOrder += 1

		local page = new("ScrollingFrame", {
			Name = "page_" .. id,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 4,
		}, {
			new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
			new("UIPadding", {
				PaddingTop = UDim.new(0, 4),
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			}),
		})

		local canvasGroup = new("CanvasGroup", {
			Name = "canvas_" .. id,
			BackgroundTransparency = 1,
			Visible = false,
			Size = UDim2.fromScale(1, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 1.2, 0),
			GroupTransparency = 1,
		}, { page })
		canvasGroup.Parent = self.PagesContainer

		local navButtonInstance = navButton({
			Name = "nav_" .. id,
			Icon = icon,
			LayoutOrder = self.TabOrder,
		})
		navButtonInstance.Parent = self.MenuList

		local TabElements = ctx:Require("Elements")
		local tab = setmetatable({
			Id = id,
			Title = title,
			Page = page,
			CanvasGroup = canvasGroup,
			NavButton = navButtonInstance,
			Window = self,
			ElementOrder = 0,
		}, { __index = TabElements })

		navButtonInstance.MouseButton1Click:Connect(function()
			self:GoTo(id)
		end)

		self.Tabs[id] = tab

		if self.TabOrder == 1 then
			self:GoTo(id)
		end

		return tab
	end

	-- Rayfield-style intro: opens as a small "Welcome back" card (already popped in by the time
	-- this is called), holds briefly, then grows into the real window size while the card fades
	-- out and the real chrome (title, drag handle, pages, menu button) fades in over it.
	-- Built the first time a panel actually needs to fade (either this intro's grow phase or the
	-- first SetVisible call, whichever runs first) and reused for every toggle after - see
	-- buildFadePair for why this can't just be rebuilt fresh on every call.
	function Window:_ensureContentFade()
		if not self.ContentFade then
			local descendants = {}
			for _, descendant in ipairs(self.MainFrame:GetDescendants()) do
				if not descendant:IsDescendantOf(self.PagesContainer) then
					table.insert(descendants, descendant)
				end
			end
			self.ContentFade, self.ContentSnap = buildFadePair(descendants, Theme.Tweens.WindowToggle)
		end
		return self.ContentFade, self.ContentSnap
	end

	function Window:_playIntro(chrome, initialSize)
		local holdTime = 1.1
		local blendTween = Theme.Tweens.Fade
		local growTween = Theme.Tweens.Window

		local splashFade, splashSnap = buildFadePair(withDescendants({ self.SplashLayer }), blendTween)

		-- Soft materialize: just a plain fade (frame + splash text together), no scale-pop -
		-- the pop is reserved for SetVisible's later open/close toggles, not this first intro.
		splashSnap:FadeOut()
		self.MainFrame.BackgroundTransparency = 1
		TweenService:Create(self.MainFrame, blendTween, { BackgroundTransparency = 0.1 }):Play()
		TweenService:Create(self.Shadow, blendTween, { ImageTransparency = 0.5 }):Play()
		splashFade:FadeIn()

		task.delay(holdTime, function()
			if self.Destroyed then
				return
			end

			-- Let the splash text fully tween out on its own first - starting the resize and the
			-- chrome fade-in at the same moment as the fade-out buried it under two other moving
			-- animations and made it read as an abrupt cut rather than a fade.
			splashFade:FadeOut()

			task.delay(blendTween.Time, function()
				if self.Destroyed then
					return
				end

				self.SplashLayer.Visible = false

				for _, element in ipairs(chrome) do
					element.Visible = true
				end
				local contentFade, contentSnap = self:_ensureContentFade()
				contentSnap:FadeOut()
				contentFade:FadeIn()
				TweenService:Create(self.PagesContainer, growTween, { GroupTransparency = 0 }):Play()

				TweenService:Create(self.MainFrame, growTween, { Size = initialSize }):Play()
			end)
		end)
	end

	-- Real exe_main_module:exe_admin_panel - window scale 1.2->1 and BackgroundTransparency
	-- 1->0.1 tween together on open; reversed on close. Also fades every descendant's own
	-- transparency together via BulkFade, so content doesn't just pop in/out already-opaque
	-- while only the frame itself visibly fades.
	function Window:SetVisible(visible)
		self.Visible = visible
		local tween = Theme.Tweens.WindowToggle
		local contentFade, contentSnap = self:_ensureContentFade()

		if visible then
			self.ScreenGui.Enabled = true
			self.MainFrame.BackgroundTransparency = 1
			self.Shadow.ImageTransparency = 1
			self.PagesContainer.GroupTransparency = 1
			self.WindowScale.Scale = 1.2
			contentSnap:FadeOut()
			contentFade:FadeIn()
			TweenService:Create(self.MainFrame, tween, { BackgroundTransparency = 0.1 }):Play()
			TweenService:Create(self.Shadow, tween, { ImageTransparency = 0.5 }):Play()
			TweenService:Create(self.PagesContainer, tween, { GroupTransparency = 0 }):Play()
			TweenService:Create(self.WindowScale, tween, { Scale = 1 }):Play()
		else
			contentFade:FadeOut()
			TweenService:Create(self.MainFrame, tween, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(self.Shadow, tween, { ImageTransparency = 1 }):Play()
			TweenService:Create(self.PagesContainer, tween, { GroupTransparency = 1 }):Play()
			TweenService:Create(self.WindowScale, tween, { Scale = 1.2 }):Play()
			task.delay(tween.Time, function()
				if not self.Visible then
					self.ScreenGui.Enabled = false
				end
			end)
		end
	end

	function Window:Notify(...)
		return ctx:Require("Notify").Show(self, ...)
	end

	function Window:Confirm(...)
		return ctx:Require("Confirm").Show(self, ...)
	end

	function Window:Destroy()
		if self.Destroyed then
			return
		end
		self.Destroyed = true
		if self.ToggleConnection then
			self.ToggleConnection:Disconnect()
		end
		self.Shadow:Destroy()
		self.ScreenGui:Destroy()
	end

	return Window
end
