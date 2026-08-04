-- straightStabs_init
-- Entry point for Straight Stabs and Straight Shuffle Stabs.
-- Dispatched from multiStabs_menu for selections 1 and 2.
-- Reads shared.shuffleMode to determine whether to apply Shuffle before XGroup.
--
-- Straight Stabs only ever shuffles before XGroup (to randomise fixture-to-group
-- assignment), so only the "before" case is needed here. "after" is not applicable
-- to a single-Matricks variant and will never be set by the menu for this component.
--
-- Order of operations:
--   1. Validate selected sequence
--   2. Present dialog
--   3. Shuffle (if shuffleMode == "before")
--   4. Apply XGroup [steps]
--   5. Grid UseMatricksPositions
--   6. Stash programmer to Sequence 9990
--   7. Stash selection + Matricks to Group 9990
--   8. ClearAll
--   9. Recall Group 9990
--  10. Blind On
--  11. CmdIndirect to straightStabs_run

local shared = select(3, ...)

local function main()
    -- Check for a selected sequence BEFORE presenting the dialog.
    local seqInfo = SelectedSequence()
    if not seqInfo or not seqInfo.INDEX then
        Printf("Straight Stabs: no sequence selected. Please select a sequence and try again.")
        return
    end
    local seqIndex = seqInfo.INDEX

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

    -- Bail out if the user cancelled.
    if not resultTable.success or resultTable.result == 0 then
        Printf("Straight Stabs: cancelled.")
        return
    end

    -- Validate step count input.
    local steps = tonumber(resultTable.inputs["Steps"])
    if not steps or steps < 1 then
        Printf("Straight Stabs: invalid step count.")
        return
    end

    -- Store seqIndex and steps to the shared state table (Lua-scoped).
    shared.seqIndex = seqIndex
    shared.steps    = steps

    -- stepCounter goes to UserVars because it must survive repeated CmdIndirect
    -- hops back into straightStabs_run.
    SetVar(UserVars(), "MS_stepCounter", 1)

    Printf("Straight Stabs: shuffleMode=" .. tostring(shared.shuffleMode) .. ", Steps=" .. steps .. ", Sequence=" .. seqIndex)

    -- Apply Shuffle before XGroup if requested.
    -- This randomises which fixtures fall into each group.
    if shared.shuffleMode == "before" then
        Cmd("Shuffle")
    end

    -- Divide the selection into N interleaved groups.
    Cmd("Set Selection MAtricks XGroup " .. steps)

    -- Neutralise any Selection Grid influence on selection order.
    -- Must happen after XGroup is applied and before the stash is stored.
    Cmd("Grid UseMatricksPositions")

    -- Stash the current programmer levels to a temp sequence.
    -- Recalled on each iteration to force MA3 to see a programmer change.
    Cmd("Store Sequence 9990 /Overwrite")

    -- Stash the current selection order AND Matricks to a temp group.
    -- Groups preserve both; sequences do not.
    Cmd("Store Group 9990 /Overwrite")

    -- Clear extraneous programmer data before the loop begins.
    Cmd("ClearAll")

    -- Restore the selection order AND Matricks from the stashed group.
    Cmd("Group 9990")

    -- Enter blind mode so the store loop doesn't cause flashes on stage.
    Cmd("Blind On")

    -- Hand off to the run component to begin the iteration loop.
    CmdIndirect("Plugin 'Multi Stabs'.straightStabs_run")
end

return main