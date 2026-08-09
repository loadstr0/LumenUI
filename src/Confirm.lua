--[[
	Confirm.lua

	Confirm/cancel modal. Interaction pattern (confirm/cancel buttons, background-click-to-cancel,
	hover/press color feedback) adapted from the source project's prompt_handler.luau, which was
	already fully generic. Dialog uses the real 9-slice panel texture (Helpers.panel) with the
	real pop-in animation (ImageTransparency 1->0.1, UIScale 1.2->1) the source uses for every
	panel open.

	Layout is a UIListLayout (title/content/buttons stacked, dialog AutomaticSize=Y) rather than
	fixed offsets - the original had a hardcoded 128px dialog height with the button row pinned
	at a fixed y=70, which worked for short test strings but overlapped/clipped for anything
	longer once content actually wrapped to 3+ lines. Buttons also now get the same rotating-
	shimmer hover (Helpers.wireShimmerHover) and Theme.Surface/SurfaceRaised coloring as every
	other interactive element in the library, instead of the old hardcoded RGB(85,89,91)/
	RGB(100,105,107) one-off colors with no shimmer at all.
]]

return function(ctx)
	local TweenService = game:GetService("TweenService")

	local Theme = ctx:Require("Theme")
	local Helpers = ctx:Require("Helpers")
	local BulkFade = ctx:Require("BulkFade")
	local new, panel, corner = Helpers.new, Helpers.panel, Helpers.corner

	local Confirm = {}

	function Confirm.Show(window, title, content, callback)
		local titleLabel = new("TextLabel", {
			Name = "title",
			BackgroundTransparency = 1,
			Text = title or "",
			FontFace = Theme.CustomFontMedium,
			TextSize = 18,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 1,
		})

		local contentLabel = new("TextLabel", {
			Name = "content",
			BackgroundTransparency = 1,
			Text = content or "",
			FontFace = Theme.CustomFont,
			TextSize = 14,
			TextColor3 = Theme.Text,
			TextTransparency = 0.2,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 2,
		})

		local cancelShimmer = new("UIGradient", { Enabled = false, Transparency = Theme.ShimmerTransparency })
		local cancelButton = new("TextButton", {
			Name = "cancel",
			Text = "Cancel",
			FontFace = Theme.CustomFontMedium,
			TextSize = 17,
			TextColor3 = Theme.Text,
			TextTransparency = 0.2,
			BackgroundColor3 = Theme.Surface,
			BackgroundTransparency = 0.4,
			Size = UDim2.new(0.4, -5, 0, 45),
		}, { corner(Theme.CornerRadiusPill), cancelShimmer })

		local confirmShimmer = new("UIGradient", { Enabled = false, Transparency = Theme.ShimmerTransparency })
		local confirmButton = new("TextButton", {
			Name = "confirm",
			Text = "Continue",
			FontFace = Theme.CustomFontSemiBold,
			TextSize = 17,
			TextColor3 = Theme.Text,
			BackgroundColor3 = Theme.SurfaceRaised,
			BackgroundTransparency = 0.05,
			Size = UDim2.new(0.6, -5, 0, 45),
		}, { corner(Theme.CornerRadiusPill), confirmShimmer })

		local buttonRow = new("Frame", {
			Name = "buttons",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 45),
			LayoutOrder = 3,
		}, {
			new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			cancelButton,
			confirmButton,
		})

		local dialogScale = new("UIScale", { Scale = 1.2 })
		local dialog = panel("ImageLabel", {
			Name = "dialog",
			ImageTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(0, 380, 0, 0),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
		}, {
			dialogScale,
			new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }),
			new("UIPadding", {
				PaddingTop = UDim.new(0, 18),
				PaddingBottom = UDim.new(0, 18),
				PaddingLeft = UDim.new(0, 18),
				PaddingRight = UDim.new(0, 18),
			}),
			titleLabel,
			contentLabel,
			buttonRow,
		})

		local overlay = new("TextButton", {
			Name = "confirm_overlay",
			Text = "",
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, { dialog })
		overlay.Parent = window.ScreenGui

		-- Fades title/content/buttons together with the panel itself, instead of just the panel's
		-- own ImageTransparency tweening while everything on top of it pops in/out already-opaque.
		-- Built fresh every Show() call (each dialog is a one-shot instance, never reused), so
		-- there's no risk of BulkFade's "captures values once, forever" snapshot going stale the
		-- way it could for the main Window's long-lived, repeatedly-toggled content.
		local descendants = dialog:GetDescendants()
		local openFade = BulkFade.CreateGroup(descendants, Theme.Tweens.PanelOpen)
		local openSnap = BulkFade.CreateGroup(descendants, TweenInfo.new(0))
		local closeFade = BulkFade.CreateGroup(descendants, Theme.Tweens.PanelClose)

		openSnap:FadeOut()
		TweenService:Create(overlay, Theme.Tweens.PanelOpen, { BackgroundTransparency = 0.5 }):Play()
		TweenService:Create(dialog, Theme.Tweens.PanelOpen, { ImageTransparency = 0.1 }):Play()
		TweenService:Create(dialogScale, Theme.Tweens.PanelOpen, { Scale = 1 }):Play()
		openFade:FadeIn()

		local function close()
			TweenService:Create(overlay, Theme.Tweens.PanelClose, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(dialog, Theme.Tweens.PanelClose, { ImageTransparency = 1 }):Play()
			TweenService:Create(dialogScale, Theme.Tweens.PanelClose, { Scale = 1.2 }):Play()
			closeFade:FadeOut()
			task.delay(Theme.Tweens.PanelClose.Time, function()
				overlay:Destroy()
			end)
		end

		local function hoverColor(button, transparency, hoverTransparency)
			button.MouseEnter:Connect(function()
				TweenService:Create(button, Theme.Tweens.Fast, { BackgroundTransparency = hoverTransparency }):Play()
			end)
			button.MouseLeave:Connect(function()
				TweenService:Create(button, Theme.Tweens.Fast, { BackgroundTransparency = transparency }):Play()
			end)
		end

		hoverColor(cancelButton, 0.4, 0.2)
		hoverColor(confirmButton, 0.05, 0)
		Helpers.wireShimmerHover(cancelButton, cancelShimmer)
		Helpers.wireShimmerHover(confirmButton, confirmShimmer)

		cancelButton.MouseButton1Click:Connect(close)
		overlay.MouseButton1Click:Connect(close)
		confirmButton.MouseButton1Click:Connect(function()
			close()
			if type(callback) == "function" then
				callback()
			end
		end)
	end

	return Confirm
end
