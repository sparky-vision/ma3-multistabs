-- blockStabs_init
-- Entry point for Block Stabs, Block Shuffle Stabs, and Shuffle Block Stabs.
-- Dispatched from multiStabs_menu for selections 3, 4, and 5.
-- Reads shared.shuffleMode to determine when (if at all) to apply Shuffle.
--
-- shuffleMode behaviour for block variants:
--   "none"   — XBlock then XGroup, no shuffle.
--   "before" — Shuffle + Grid UseMatricksPositions to commit shuffled order,
--              THEN XBlock + XGroup. The UseMatricksPositions call is required
--              here because XBlock would otherwise anchor to natural patch order,
--              ignoring the shuffle. (Single-Matricks variants like Straight Stabs
--              do not exhibit this behaviour and do not need the extra call.)
--   "after"  — XBlock then XGroup, then Shuffle to randomise group firing order.
--
-- blockSize is local to _init only — once baked into the stashed group it is not needed.
--
-- Order of operations:
--   1. Validate selected sequence
--   2. Present dialog (Block Size + Steps)
--   3. Shuffle + Grid UseMatricksPositions (if shuffleMode == "before")
--   4. Apply XBlock [blockSize]
--   5. Apply XGroup [steps]
--   6. Shuffle (if shuffleMode == "after")
--   7. Grid UseMatricksPositions
--   8. Stash programmer to Sequence 9990
--   9. Stash selection + Matricks to Group 9990
--  10. ClearAll
--  11. Recall Group 9990
--  12. Blind On
--  13. CmdIndirect to blockStabs_run

local shared = select(3, ...)

local function main()
    -- Check for a selected sequence BEFORE presenting the dialog.
    local seqInfo = SelectedSequence()
    if not seqInfo or not seqInfo.INDEX then
        Printf("Block Stabs: no sequence selected. Please select a sequence and try again.")
        return
    end
    local seqIndex = seqInfo.INDEX

    -- Present the user input dialog.
    -- Two inputs: Block Size (fixtures per cue) and Steps (number of cues/groups).
    local resultTable = MessageBox({
        title = "Block Stabs",
        message = "Ensure your selection and programmer levels are set before running.\nStoring to Sequence " .. seqIndex .. ".",
        inputs = {
            { name = "Block Size", value = "2", whiteFilter = "0123456789", vkPlugin = "NumericInput" },
            { name = "Steps",      value = "8", whiteFilter = "0123456789", vkPlugin = "NumericInput" }
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
        Printf("Block Stabs: cancelled.")
        return
    end

    -- Validate both inputs.
    local blockSize = tonumber(resultTable.inputs["Block Size"])
    local steps     = tonumber(resultTable.inputs["Steps"])

    if not blockSize or blockSize < 1 then
        Printf("Block Stabs: invalid block size.")
        return
    end
    if not steps or steps < 1 then
        Printf("Block Stabs: invalid step count.")
        return
    end

    -- Store seqIndex and steps to the shared state table (Lua-scoped).
    -- blockSize is NOT stored — it is only needed here in _init.
    shared.seqIndex = seqIndex
    shared.steps    = steps

    -- stepCounter goes to UserVars because it must survive repeated CmdIndirect
    -- hops back into blockStabs_run.
    SetVar(UserVars(), "MS_stepCounter", 1)

    Printf("Block Stabs: shuffleMode=" .. tostring(shared.shuffleMode) .. ", BlockSize=" .. blockSize .. ", Steps=" .. steps .. ", Sequence=" .. seqIndex)

    -- If shuffleMode is "before", shuffle first then commit the randomised order
    -- into Matricks via Grid UseMatricksPositions. Without this commit step, XBlock
    -- anchors to natural patch order and the shuffle has no effect.
    if shared.shuffleMode == "before" then
        Cmd("Shuffle")
        Cmd("Grid UseMatricksPositions")
    end

    -- Apply XBlock first to define the size of each contiguous block,
    -- then XGroup to divide those blocks into the correct number of chase steps.
    Cmd("Set Selection MAtricks XBlock " .. blockSize)
    Cmd("Set Selection MAtricks XGroup " .. steps)

    -- If shuffleMode is "after", shuffle now to randomise the group firing order.
    if shared.shuffleMode == "after" then
        Cmd("Shuffle")
    end

    -- Neutralise any Selection Grid influence on selection order.
    -- Must happen after all Matricks commands and before the stash is stored.
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
    CmdIndirect("Plugin 'Multi Stabs'.blockStabs_run")
end

return main