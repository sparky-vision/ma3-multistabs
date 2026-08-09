-- multiStabs_help
-- Read-only reference screen listing every Multi Stabs function. Dispatched
-- from multiStabs_menu when the user presses "Help" instead of "Run". The
-- only action is "Back", which returns to multiStabs_menu. This screen does
-- not launch anything itself.

local shared = select(3, ...)

local function main()
    MessageBox({
        title = "Multi Stabs: Function Reference",
        message =
            "This plugin is based on an MA2 macro created by EarlyBird Visual. It simplifies and speeds up the creation of several different lighting stabs, and sets the function of the buttons for the executors. The plugin expects the following workflow: the user selects lights, adjusts some attributes (dimmer, color, for instance) and then enters the configuration options for the executor. Each cue that is created will have a 0-second fadetime, followed by a user-inputtable offtime. The plugin expects the user to have created an empty executor and to have selected it. Once called, you can choose from a variety of stab styles, which are listed below. This plugin does NOT linearize fixtures before creating the stabs, and so it will respect your selection order, including oddities introduced by the Selection Grid.\n\n" ..
            "That Selection Grid quirk is rather important: Rubber-band (marquee) selecting a group of fixtures derives their Selection Grid position from their spatial placement in the Layout View. This plugin is intended for use on fixtures selected in a genuinely linear fashion, like a line of fixtures on a truss. If you rubber-band select a cluster of fixtures out of a two-dimensional layout which might introduce Y or Z positions in the grid, the resulting groupings, blocks, or wing pairings may not follow the order you'd expect.\n\n" ..
            "1  Straight Stabs\n" ..
            "Stabs in order of selection, in however many steps specified.\n\n" ..
            "2  Straight Shuffle Stabs\n" ..
            "Stabs in however many steps specified, but shuffled first.\n\n" ..
            "3  Block Stabs\n" ..
            "Fixtures are chunked into contiguous blocks of the chosen size, in selection order, then distributed across the chosen number of steps.\n\n" ..
            "4  Block Shuffle Stabs\n" ..
            "Stabs with blocks of contiguous n fixtures, but the blocks themselves are shuffled.\n\n" ..
            "5  Shuffle Block Stabs\n" ..
            "Stabs with blocks of non-contiguous n fixtures. Differs from straight shuffle stabs in that you can select your block size. Ordinarily, there's not much of a reason to choose this one over Straight Shuffle Stabs, unless you have a small selection, a large block size, or lots of steps.\n\n" ..
            "6  Wing Stabs\n" ..
            "Stabs in order of selection, in however many steps, with n wings.\n\n" ..
            "7  Wing Shuffle Stabs\n" ..
            "Stabs in order of selection, in however many steps, with wings applied, then shuffled.\n\n" ..
            "8  Wing Block Stabs\n" ..
            "Stabs in order of selection, in however many steps of block n fixtures, with wings applied.\n\n" ..
            "9  Wing Shuffle Block Stabs\n" ..
            "Stabs in order of selection of block n fixtures and n wings, then (contiguous) blocks are shuffled. Blocks fire randomly across n wings.",
        icon = "tools",
        commands = {
            { value = 1, name = "Back" }
        },
    })

    -- Regardless of how the dialog closed, return to the main menu.
    CmdIndirect("Plugin 'Multi Stabs'.multiStabs_menu")
end

return main