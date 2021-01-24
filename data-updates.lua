for k, v in pairs(data.raw.resource) do

	data:extend{
		{
			type = "custom-input",
			name = "resourcehighlighter-toggle",
			key_sequence = "SHIFT + H",
			consuming = "none"
		},
		{
			type = "item",
			name = "resourcehighlighter-treasure-"..v.name,
			icons = {
				{
					icon = "__resourcehighlighter__/graphics/icons/glow.png",
					icon_size = 64,
					scale = 2,
				},
				{
					icon = v.icon or v.icons[1].icon,
					icon_size = v.icon_size or v.icons[1].icon_size,
					scale = 1,
				}
			},
			icon_size = 64,
			subgroup = "raw-resource",
			order = "",
			stack_size = 1,
			flags = {"hidden"}
		},
	}
end
