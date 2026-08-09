-- straightStabs_init
-- Entry point for Straight Stabs and Straight Shuffle Stabs.
-- Dispatched from multiStabs_menu for selections 1 and 2.
-- Reads shared.shuffleMode to determine whether to apply Shuffle before XGroup.
-- Reads shared.seqIndex, already validated in multiStabs_menu before dispatch
-- (sequence selected, fixtures selected, executor page, cue count) — no need
-- to re-check any of that here.
--
-- Straight Stabs only ever shuffles before XGroup (to randomise fixture-to-group
-- assignment), so only the "before" case is needed here. "after" is not applicable
-- to a single-Matricks variant and will never be set by the menu for this component.
--
-- Note: unlike block variants, Shuffle before a single XGroup command works correctly
-- without an intermediate Grid UseMatricksPositions call. XGroup operates on whatever
-- selection order is currently active, which is the shuffled order.

local shared = select(3, ...)

local function main()
    local seqIndex = shared.seqIndex

    -- Present the user input dialog.
    local resultTable = MessageBox({
        title = "Straight Stabs",
        message = "Ensure your selection and programmer levels are set before running.\nStoring to Sequence " .. seqIndex .. ".",
        inputs = {
            { name = "Steps", value = "8", whiteFilter = "0123456789", vkPlugin = "NumericInput" }
        },
        commands = {
            { value = 1, name = "Run" },
            { value = 0, name = "Cancel" }
        },
        icon = "tools",
        backColor = "Global.Default",
        titleTextColor = "Global.Text",
        messageTextColor = "Global.Text"
    })

    if not resultTable.success or resultTable.result == 0 then
        Printf("Straight Stabs: cancelled.")
        return
    end

    local steps = tonumber(resultTable.inputs["Steps"])
    if not steps or steps < 1 then
        Printf("Straight Stabs: invalid step count.")
        return
    end

    -- seqIndex is already set by multiStabs_menu — only steps needs storing.
    shared.steps = steps

    SetVar(UserVars(), "MS_stepCounter", 1)

    Printf("Straight Stabs: shuffleMode=" .. tostring(shared.shuffleMode) .. ", Steps=" .. steps .. ", Sequence=" .. seqIndex)

    Cmd("Store Sequence 9990 /Overwrite")

    if shared.shuffleMode == "before" then
        Cmd("Shuffle")
    end

    Cmd("Set Selection MAtricks XGroup " .. steps)
    Cmd("Grid UseMatricksPositions")
    Cmd("Store Group 9990 /Overwrite")
    Cmd("ClearAll")
    Cmd("Group 9990")
    Cmd("Blind On")

    CmdIndirect("Plugin 'Multi Stabs'.straightStabs_run")
end

return main