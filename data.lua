data:extend{
    {
        type = "custom-input",
        name = "resourcehighlighter-toggle",
        key_sequence = "SHIFT + H",
        consuming = "none"
    },
    {
        type = "item",
        name = "resourcehighlighter-treasure",
        icons = {
            {
                icon = "__resourcehighlighter__/graphics/icons/glow.png",
                icon_size = 64,
                scale = 2,
            },
            {
                icon = "__resourcehighlighter__/graphics/icons/treasure.png",
                icon_size = 64,
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