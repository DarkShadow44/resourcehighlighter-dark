data:extend {
    {
        type = "custom-input",
        name = "resourcehighlighter-toggle",
        key_sequence = "SHIFT + H",
        consuming = "none"
    },
    {
        type = "custom-input",
        name = "resourcehighlighter-focus-search",
        key_sequence = "",
        linked_game_control = "focus-search",
    },
}

data:extend {
    {
        type = "shortcut",
        name = "resourcehighlighter-toggle",
        action = "lua",
        icon = {
            filename = "__resourcehighlighter-dark__/graphics/icons/shortcut.png",
            width = 64,
            height = 64,
            scale = 1
        }
    }
}

for k, v in pairs(data.raw.resource) do
	data:extend {
		{
			type = "item",
			name = "resourcehighlighter-treasure-"..v.name,
			icons = {
				{
					icon = "__resourcehighlighter-dark__/graphics/icons/glow.png",
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
