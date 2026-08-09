--[[
	Lucide.lua

	Icon-name resolver, adapted from lucide-roblox's lib/init.luau
	(https://github.com/latte-soft/lucide-roblox, MIT License, Copyright (c) 2023 Latte
	Softworks <https://latte.to>) against LumenUI's ctx:Require convention instead of a Roblox
	require(script.Icons) reference. Icons.lua (the vendored sprite-sheet index) is the other
	half of this port.

	Trimmed from the original: no IconNames list/GetAllAssets/ImageLabel builder (LumenUI has
	its own Instance-construction helpers - see Helpers.icon/withIcon, the actual integration
	point used by Window.lua/Elements.lua), and GetAsset returns nil instead of erroring on an
	unknown name, since callers here treat an icon argument as optional/best-effort rather than
	a hard requirement.
]]

return function(ctx)
	local Icons = ctx:Require("Icons")

	local Lucide = {}

	local function trim(name)
		return string.match(string.lower(name), "^%s*(.*)%s*$")
	end

	-- Example: Lucide.GetAsset("settings", 48) -> { Id, Url = "rbxassetid://...",
	-- ImageRectSize = Vector2.new(48, 48), ImageRectOffset = Vector2.new(x, y) }, or nil if
	-- iconName isn't a real Lucide icon name.
	function Lucide.GetAsset(iconName, iconSize)
		if type(iconName) ~= "string" or iconName == "" then
			return nil
		end
		local size = iconSize or 256
		if size < 0 then
			size = -size
		end

		local sizeIndex = (size <= 48) and "48px" or "256px"
		local rawAsset = Icons[sizeIndex][trim(iconName)]
		if not rawAsset then
			return nil
		end

		local id, rectSize, rectOffset = rawAsset[1], rawAsset[2], rawAsset[3]
		return {
			Id = id,
			Url = "rbxassetid://" .. id,
			ImageRectSize = Vector2.new(rectSize[1], rectSize[2]),
			ImageRectOffset = Vector2.new(rectOffset[1], rectOffset[2]),
		}
	end

	return Lucide
end
