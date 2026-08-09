--[[
	Theme.lua

	Visual palette extracted directly from the source project's exe.model.json properties (see
	HANDOFF.md), not invented. Key real values found:
	- Main window background: RGB(15,15,15) at 0.1 transparency (near-opaque near-black)
	- Notification/card background: RGB(79,79,79)
	- Menu backdrop element: RGB(62,62,62)
	- Text: pure white throughout
	- "Glow" accent is a white UIGradient stroke at high transparency (0.69-0.87), not a flat
	  colored accent - there is no distinct hue in the source palette, it is monochrome
	- Corner radii: main window/panels use 20px (the value the window's own fullscreen-restore
	  code treats as "normal"); notifications use a 100px pill/capsule shape
	- Icons.EnterFullscreen/ExitFullscreen/Resize are the window_controls.controls.restore/resize
	  icons; Icons.Glow is the soft halo image (controls.restore.selection) that fades in behind
	  a control icon on hover; Icons.Close is navigation_buttons.close's icon, reused here since
	  the source panel has no dedicated title-bar close button of its own to pull from
	- The rotating-shimmer hover gradient (Tweens.GradientLoop + a Transparency 0->0.33125
	  sequence) is ported from hover_navi() in dashboard/credits/menu/main_frame handlers: an
	  always-white UIGradient, disabled by default, continuously rotated 0->360 in the background,
	  and simply toggled Enabled on MouseEnter/InputEnded

	Uses the same return-function(ctx)-returning-module factory convention as Uma Racing Smart
	Hub's own Loader.lua, so this whole library can be loaded/tested through the same kind of
	small custom bootstrap rather than requiring a real Rojo-synced Instance hierarchy.
]]

return function(ctx)
	return {
		Background = Color3.fromRGB(15, 15, 15),
		Surface = Color3.fromRGB(62, 62, 62),
		SurfaceRaised = Color3.fromRGB(79, 79, 79),
		Text = Color3.fromRGB(255, 255, 255),
		TextMuted = Color3.fromRGB(190, 190, 190),
		Glow = Color3.fromRGB(255, 255, 255),

		CornerRadius = UDim.new(0, 20),
		CornerRadiusPill = UDim.new(0, 100),

		Font = Enum.Font.GothamMedium,
		FontBold = Enum.Font.GothamBold,

		Icons = {
			EnterFullscreen = "rbxassetid://11295287158",
			ExitFullscreen = "rbxassetid://11422140434",
			Resize = "rbxassetid://11295287825",
			Glow = "rbxassetid://18412474498",
			Close = "rbxassetid://11293981586",
			Check = "rbxassetid://10709790644",
			Search = "rbxassetid://11293977875",
			Menu = "rbxassetid://11295285432",
			Handle = "rbxassetid://12974354535",
		},

		-- Real 9-slice panel textures (every floating panel/card in the source uses one of
		-- these instead of a flat Color3 + UICorner - see Helpers.panel).
		Panel = {
			Image = "rbxassetid://16286719854",
			Color = Color3.fromRGB(70, 70, 70),
			SliceCenter = Rect.new(512, 512, 512, 512),
			SliceScale = 0.1,
		},
		WindowBackgroundImage = "rbxassetid://16255699706",

		-- Real custom font asset used throughout the source (FontFace family, not a stock
		-- Enum.Font) - applied to Section/Card since those values were directly confirmed;
		-- Font/FontBold above stay as the Gotham fallback used by the rest of the library.
		CustomFont = Font.new("rbxassetid://12187365364", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		CustomFontMedium = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
		CustomFontSemiBold = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),

		-- Real dashboard card-grid values: a labeled section (title+description on the left)
		-- with a horizontal row of icon cards on the right - see Elements:Section/:Card.
		Card = {
			Background = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.7,
			CornerRadius = UDim.new(0, 10),
			IconTransparency = 0.2,
			LabelTransparency = 0.2,
		},
		SectionTitleTransparency = 0.2,
		SectionDescTransparency = 0.8,

		-- Real slider values (the visual instance from tools_panels' custom-command rows, not
		-- Krypt's DevForum drag-math module itself - that's third-party code we don't have the
		-- source of, so the drag logic in Elements:Slider is our own, just wearing the real look).
		Slider = {
			DepthImage = "rbxassetid://16264857615",
			DepthSliceCenter = Rect.new(206, 206, 206, 206),
			HandleImage = "rbxassetid://16294678871",
			TrackHeight = 40,
			HandleSize = 26,
		},

		ShimmerTransparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 0.33125),
		}),

		Tweens = {
			-- Sine InOut instead of the other tweens' Exponential - Exponential's easing is so
			-- front-loaded that a transparency fade using it reads as an instant pop rather than a
			-- gradual fade (almost the whole change happens in the tween's first ~15%). Used for
			-- the splash intro's text fade in/out, where that gradualness is the whole point.
			Fade = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			-- Back Out gives the knob a small overshoot-then-settle, the tactile "snap" an iOS
			-- switch has that a plain ease-out doesn't - used only by the Toggle switch.
			Toggle = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			Fast = TweenInfo.new(0.15, Enum.EasingStyle.Exponential),
			Normal = TweenInfo.new(0.3, Enum.EasingStyle.Exponential),
			Window = TweenInfo.new(0.4, Enum.EasingStyle.Exponential),
			Smooth = TweenInfo.new(0.7, Enum.EasingStyle.Exponential),
			GradientLoop = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false),
			GradientPingPong = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			PanelOpen = TweenInfo.new(0.5, Enum.EasingStyle.Exponential),
			PanelClose = TweenInfo.new(0.3, Enum.EasingStyle.Exponential),
			-- Real "slow" tween from exe_main_module:Go_To - the CanvasGroup page-switch tween.
			PageSwitch = TweenInfo.new(0.8, Enum.EasingStyle.Exponential),
			-- Real window open/close tween from exe_main_module:exe_admin_panel.
			WindowToggle = TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
		},
	}
end
