-- wingStabs_init
-- Entry point for Wing Stabs and Wing Shuffle Stabs.
-- Dispatched from multiStabs_menu for selections 6 and 7.
-- Reads shared.shuffleMode to determine whether to apply Shuffle.
--
-- shuffleMode behaviour for wing variants:
--   "none"   — XWings then XGroup, no shuffle.
--   "before" — XWings then XGroup, then Shuffle to randomise node order.
--              Y and Z shuffle axes are nulled immediately after Shuffle because
--              Shuffle applies to all axes simultaneously and would otherwise
--              scramble fixtures within each wing node. Grid UseMatricksPositions
--              then commits the corrected state before stashing.
--
-- Note: Store Sequence 9990 is performed immediately — it captures only the
-- target programmer levels and has no dependency on selection order or Matricks.
--
-- Note: XWings and XGroup command order is interchangeable for this variant —
-- final stage output is identical regardless of order.
--
-- wings is local to _init only — once baked into the stashed group it is not needed.
--
-- Order of operations (shuffleMode == "none"):
--   1. Validate selected sequence
--   2. Present dialog (Wings + Steps)
--   3. Store Sequence 9990 (programmer levels stash)
--   4. Apply XWings [wings]
--   5. Apply XGroup [steps]
--   6. Grid UseMatricksPositions
--   7. Store Group 9990 (selection + Matricks stash)
--   8. ClearAll
--   9. Recall Group 9990
--  10. Blind On
--  11. CmdIndirect to wingStabs_run
--
-- Order of operations (shuffleMode == "before"):
--   1. Validate selected sequence
--   2. Present dialog (Wings + Steps)
--   3. Store Sequence 9990 (programmer levels stash)
--   4. Apply XWings [wings]
--   5. Apply XGroup [steps]
--   6. Shuffle
--   7. Null YShuffle + ZShuffle
--   8. Grid UseMatricksPositions
--   9. Store Group 9990 (selection + Matricks stash)
--  10. ClearAll
--  11. Recall Group 9990
--  12. Blind On
--  13. CmdIndirect to wingStabs_run

local shared = select(3, ...)

local function main()
    -- Check for a selected sequence BEFORE presenting the dialog.
    local seqInfo = SelectedSequence()
    if not seqInfo or not seqInfo.INDEX then
        Printf("Wing Stabs: no sequence selected. Please select a sequence and try again.")
        return
    end
    local seqIndex = seqInfo.INDEX

    -- Present the user input dialog.
    -- Two inputs: Wings (N for XWings) and Steps (N for XGroup).
    -- These are independent values — XWings defines the mirrored pairing depth,
    -- XGroup defines how many chase steps the result is divided into.
    local resultTable = MessageBox({
        title = "Wing Stabs",
        message = "Ensure your selection and programmer levels are set before running.\nStoring to Sequence " .. seqIndex .. ".",
        inputs = {
            { name = "Wings", value = "4", whiteFilter = "0123456789", vkPlugin = "NumericInput" },
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
        Printf("Wing Stabs: cancelled.")
        return
    end

    -- Validate both inputs.
    local wings = tonumber(resultTable.inputs["Wings"])
    local steps = tonumber(resultTable.inputs["Steps"])

    if not wings or wings < 1 then
        Printf("Wing Stabs: invalid wing count.")
        return
    end
    if not steps or steps < 1 then
        Printf("Wing Stabs: invalid step count.")
        return
    end

    -- Store seqIndex and steps to the shared state table (Lua-scoped).
    -- wings is NOT stored — it is only needed here in _init.
    shared.seqIndex = seqIndex
    shared.steps    = steps

    -- stepCounter goes to UserVars because it must survive repeated CmdIndirect
    -- hops back into wingStabs_run.
    SetVar(UserVars(), "MS_stepCounter", 1)

    Printf("Wing Stabs: shuffleMode=" .. tostring(shared.shuffleMode) .. ", Wings=" .. wings .. ", Steps=" .. steps .. ", Sequence=" .. seqIndex)

    -- Stash programmer levels immediately. This only captures target dimmer values
    -- and has no dependency on selection order or Matricks state.
    Cmd("Store Sequence 9990 /Overwrite")

    -- Apply XWings to define the mirrored pairing depth,
    -- then XGroup to divide the result into the correct number of chase steps.
    -- Command order is interchangeable — final stage output is identical either way.
    Cmd("Set Selection MAtricks XWings " .. wings)
    Cmd("Set Selection MAtricks XGroup " .. steps)

    if shared.shuffleMode == "before" then
        -- Shuffle randomises all axes simultaneously, including within wing nodes.
        -- XWings collapses fixtures into paired nodes, so without correction Shuffle
        -- would scramble which fixture is on which side of each pair. Nulling YShuffle
        -- and ZShuffle immediately after Shuffle corrects this, leaving only the node
        -- order on the X axis randomised.
        -- Note: these Set Property commands produce an "Illegal Property" error in the
        -- system monitor on some software versions — this is a known console bug and
        -- does not affect the result.
        Cmd("Shuffle")
        Cmd("Set CurrentUserProfile Property \"YShuffle\" \"None\"")
        Cmd("Set CurrentUserProfile Property \"ZShuffle\" \"None\"")
    end

    -- Neutralise any Selection Grid influence on selection order.
    -- Must happen after all Matricks commands (and after Shuffle correction if
    -- applicable) and before the group stash is stored.
    Cmd("Grid UseMatricksPositions")

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
    CmdIndirect("Plugin 'Multi Stabs'.wingStabs_run")
end

return main