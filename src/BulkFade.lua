--[[
	BulkFade.lua

	Third-party community utility, credited to its original authors (kingerman88, xxkeithx),
	ported near-verbatim since it was already fully generic - groups a set of instances and tweens
	their transparency-family properties together, so a panel's whole visual tree can fade in/out
	as one operation instead of hand-tweening every descendant.
]]

return function(ctx)
	local TweenService = game:GetService("TweenService")

	local ImageElements = { ImageButton = true, ImageLabel = true }
	local TextElements = { TextLabel = true, TextButton = true, TextBox = true }
	local ScrollingElements = { ScrollingFrame = true }
	local OtherElements = { CanvasGroup = true }

	local function attributesAtValue(attributes, value)
		local result = {}
		for key in pairs(attributes) do
			result[key] = value
		end
		return result
	end

	local function addElement(self, element, tweenConfig)
		local attributes = {}

		if element:IsA("UIStroke") then
			attributes.Transparency = element.Transparency
			table.insert(self.UiElements, element)
			self.AppearTweens[element] = TweenService:Create(element, tweenConfig, attributes)
			self.DisappearTweens[element] = TweenService:Create(element, tweenConfig, { Transparency = 1 })
			return
		elseif not element:IsA("GuiObject") then
			return
		end

		attributes.BackgroundTransparency = element.BackgroundTransparency
		if ImageElements[element.ClassName] then
			attributes.ImageTransparency = element.ImageTransparency
		end
		if TextElements[element.ClassName] then
			attributes.TextTransparency = element.TextTransparency
			attributes.TextStrokeTransparency = element.TextStrokeTransparency
		end
		if ScrollingElements[element.ClassName] then
			attributes.ScrollBarImageTransparency = element.ScrollBarImageTransparency
		end
		if OtherElements[element.ClassName] then
			attributes.GroupTransparency = element.GroupTransparency
		end

		table.insert(self.UiElements, element)
		self.AppearTweens[element] = TweenService:Create(element, tweenConfig, attributes)
		self.DisappearTweens[element] = TweenService:Create(element, tweenConfig, attributesAtValue(attributes, 1))
	end

	local BulkFade = {}
	BulkFade.__index = BulkFade

	function BulkFade.CreateGroup(elements, tweenConfig)
		local self = setmetatable({
			Faded = false,
			UiElements = {},
			AppearTweens = {},
			DisappearTweens = {},
		}, BulkFade)
		for _, element in ipairs(elements) do
			addElement(self, element, tweenConfig or TweenInfo.new(0.01))
		end
		return self
	end

	function BulkFade:FadeIn()
		self.Faded = true
		for _, tween in pairs(self.AppearTweens) do
			tween:Play()
		end
	end

	function BulkFade:FadeOut()
		self.Faded = false
		for _, tween in pairs(self.DisappearTweens) do
			tween:Play()
		end
	end

	function BulkFade:GetElements()
		return self.UiElements
	end

	return BulkFade
end
