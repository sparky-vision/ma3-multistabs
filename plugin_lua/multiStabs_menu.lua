-- multiStabs_menu
-- Entry point for the Multi Stabs plugin.
-- Sets shared.shuffleMode before dispatching so variant _init components
-- can conditionally apply Shuffle without needing separate components per variant.
--
-- shuffleMode values:
--   "none"   — no shuffle
--   "before" — Shuffle BEFORE Matricks is applied (randomises fixture-to-group assignment)
--   "after"  — Shuffle AFTER Matricks is applied (randomises group firing order)
--
-- Function list:
--   1  Straight Stabs           — XGroup, no shuffle
--   2  Straight Shuffle Stabs   — XGroup, shuffle before
--   3  Block Stabs              — XBlock + XGroup, no shuffle
--   4  Block Shuffle Stabs      — XBlock + XGroup, shuffle after
--   5  Shuffle Block Stabs      — XBlock + XGroup, shuffle before
--   6  Wing Stabs               — XWings + XGroup, no shuffle
--   7  Wing Shuffle Stabs       — XWings + XGroup, shuffle before
--   8  Wing Block Stabs         — XWings + XBlock + XGroup, no shuffle
--   9  Wing Shuffle Block Stabs — XWings + XBlock + XGroup, shuffle before

local shared = select(3, ...)

local function main()

    local selectorButtons = {
        {
            name = "Function",
            selectedValue = 1,
            type = 0,
            values = {
                ["1_Straight Stabs"]             = 1,
                ["2_Straight Shuffle Stabs"]      = 2,
                ["3_Block Stabs"]                 = 3,
                ["4_Block Shuffle Stabs"]         = 4,
                ["5_Shuffle Block Stabs"]         = 5,
                ["6_Wing Stabs"]                  = 6,
                ["7_Wing Shuffle Stabs"]          = 7,
                ["8_Wing Block Stabs"]            = 8,
                ["9_Wing Shuffle Block Stabs"]    = 9,
            }
        }
    }

    local returnTable = MessageBox({
        title = "Multi Stabs",
        message = "Select a function to run.",
        commands = {
            { value = 1, name = "Run" },
            { value = 0, name = "Cancel" }
        },
        selectors = selectorButtons,
    })

    if not returnTable.success or returnTable.result == 0 then
        Printf("Multi Stabs: cancelled.")
        return
    end

    local selection = returnTable.selectors["Function"]
    Printf("Multi Stabs: launching function " .. tostring(selection))

    if selection == 1 then
        shared.shuffleMode = "none"
        CmdIndirect("Plugin 'Multi Stabs'.straightStabs_init")
    elseif selection == 2 then
        shared.shuffleMode = "before"
        CmdIndirect("Plugin 'Multi Stabs'.straightStabs_init")
    elseif selection == 3 then
        shared.shuffleMode = "none"
        CmdIndirect("Plugin 'Multi Stabs'.blockStabs_init")
    elseif selection == 4 then
        shared.shuffleMode = "after"
        CmdIndirect("Plugin 'Multi Stabs'.blockStabs_init")
    elseif selection == 5 then
        shared.shuffleMode = "before"
        CmdIndirect("Plugin 'Multi Stabs'.blockStabs_init")
    elseif selection == 6 then
        shared.shuffleMode = "none"
        CmdIndirect("Plugin 'Multi Stabs'.wingStabs_init")
    elseif selection == 7 then
        shared.shuffleMode = "before"
        CmdIndirect("Plugin 'Multi Stabs'.wingStabs_init")
    elseif selection == 8 then
        shared.shuffleMode = "none"
        CmdIndirect("Plugin 'Multi Stabs'.wingBlockStabs_init")
    elseif selection == 9 then
        shared.shuffleMode = "before"
        CmdIndirect("Plugin 'Multi Stabs'.wingBlockStabs_init")
    else
        Printf("Multi Stabs: unknown selection " .. tostring(selection) .. ", aborting.")
    end

end

return main