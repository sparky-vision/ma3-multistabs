-- wingBlockStabs_init
-- Entry point for Wing Block Stabs and Wing Shuffle Block Stabs.
-- Dispatched from multiStabs_menu for selections 8 and 9.
-- Combines XWings, XBlock, and XGroup — mirrored fixture pairing, subdivided
-- into contiguous blocks, subdivided again into N chase steps.
--
-- Note on why this uses the Group 9990 stash/recall and NOT SelFix from a stored
-- Sequence: confirmed that `SelFix Sequence [n]` brings fixtures into the
-- Programmer in patch order, not their original selection order.
--
-- wings and blockSize are local to _init only — once baked into the stashed group
-- they are not needed again.
--
-- Order of operations (shuffleMode == "none"):
--   1. Validate selected sequence
--   2. Present dialog (Wings + Block Size + Steps)
--   3. Store Sequence 9990 (programmer levels stash — no Matricks dependency, done first)
--   4. Apply XBlock [blockSize]
--   5. Apply XWings [wings]
--   6. Apply XGroup [steps]
--   7. Grid UseMatricksPositions
--   8. Store Group 9990 (selection + Matricks stash)
--   9. ClearAll
--  10. Recall Group 9990
--  11. Blind On
--  12. CmdIndirect to wingBlockStabs_run
--
-- Order of operations (shuffleMode == "before"):
--   1. Validate selected sequence
--   2. Present dialog (Wings + Block Size + Steps)
--   3. Store Sequence 9990 (programmer levels stash)
--   4. Apply XBlock [blockSize]
--   5. Apply XWings [wings]
--   6. Grid UseMatricksPositions (commit — required before Shuffle for this combo)
--   7. Shuffle
--   8. Null YShuffle + ZShuffle
--   9. Grid UseMatricksPositions (second commit)
--  10. Apply XGroup [steps]
--  11. Store Group 9990 (no additional commit needed — confirmed)
--  12. ClearAll
--  13. Recall Group 9990
--  14. Blind On
--  15. CmdIndirect to wingBlockStabs_run

local shared = select(3, ...)

local function main()
    -- Check for a selected sequence BEFORE presenting the dialog.
    local seqInfo = SelectedSequence()
    if not seqInfo or not seqInfo.INDEX then
        Printf("Wing Block Stabs: no sequence selected. Please select a sequence and try again.")
        return
    end
    local seqIndex = seqInfo.INDEX

    -- Present the user input dialog.
    -- Three inputs: Wings (N for XWings), Block Size (fixtures per block), and
    -- Steps (N for XGroup). All three are independent values.
    local resultTable = MessageBox({
        title = "Wing Block Stabs",
        message = "Ensure your selection and programmer levels are set before running.\nStoring to Sequence " .. seqIndex .. ".",
        inputs = {
            { name = "Wings",      value = "4", whiteFilter = "0123456789", vkPlugin = "NumericInput" },
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
        Printf("Wing Block Stabs: cancelled.")
        return
    end

    -- Validate all three inputs.
    local wings     = tonumber(resultTable.inputs["Wings"])
    local blockSize = tonumber(resultTable.inputs["Block Size"])
    local steps     = tonumber(resultTable.inputs["Steps"])

    if not wings or wings < 1 then
        Printf("Wing Block Stabs: invalid wing count.")
        return
    end
    if not blockSize or blockSize < 1 then
        Printf("Wing Block Stabs: invalid block size.")
        return
    end
    if not steps or steps < 1 then
        Printf("Wing Block Stabs: invalid step count.")
        return
    end

    -- Store seqIndex and steps to the shared state table (Lua-scoped).
    -- wings and blockSize are NOT stored — they are only needed here in _init.
    shared.seqIndex = seqIndex
    shared.steps    = steps

    -- stepCounter goes to UserVars because it must survive repeated CmdIndirect
    -- hops back into wingBlockStabs_run.
    SetVar(UserVars(), "MS_stepCounter", 1)

    Printf("Wing Block Stabs: shuffleMode=" .. tostring(shared.shuffleMode) .. ", Wings=" .. wings .. ", BlockSize=" .. blockSize .. ", Steps=" .. steps .. ", Sequence=" .. seqIndex)

    -- Stash programmer levels immediately. This only captures target dimmer values
    -- and has no dependency on selection order or Matricks state.
    Cmd("Store Sequence 9990 /Overwrite")

    -- Apply XBlock then XWings. Confirmed via testing that, without shuffle in the
    -- picture, XBlock does not disturb the wing pairing — no intermediate commit
    -- is required here for the "none" case.
    Cmd("Set Selection MAtricks XBlock " .. blockSize)
    Cmd("Set Selection MAtricks XWings " .. wings)

    if shared.shuffleMode == "before" then
        -- Confirmed via testing: this combined variant needs a commit HERE, before
        -- Shuffle runs, to produce correct, symmetric results. This is required
        -- specifically for wings+blocks together — plain Wing Stabs' shuffle-before
        -- flow does not commit until after Shuffle, and that ordering does not work
        -- for this variant.
        Cmd("Grid UseMatricksPositions")

        -- Shuffle randomises all axes simultaneously. Y and Z shuffle axes are
        -- nulled immediately after to confine the randomisation to fixture/block
        -- firing order along the X axis, preserving symmetry across wing pairs.
        -- Note: these Set Property commands may produce an "Illegal Property" error
        -- in the system monitor on some software versions — known console bug,
        -- does not affect the result.
        Cmd("Shuffle")
        Cmd("Set CurrentUserProfile Property \"YShuffle\" \"None\"")
        Cmd("Set CurrentUserProfile Property \"ZShuffle\" \"None\"")

        -- Second commit, after the shuffle correction, before XGroup is applied.
        Cmd("Grid UseMatricksPositions")

        -- Apply XGroup last. Confirmed via testing that XGroup does NOT need its
        -- own trailing commit before the Group stash — this second commit carries
        -- through cleanly.
        Cmd("Set Selection MAtricks XGroup " .. steps)
    else
        -- shuffleMode == "none": apply XGroup directly, then a single commit,
        -- matching the standard pattern used by every other "none" variant.
        Cmd("Set Selection MAtricks XGroup " .. steps)
        Cmd("Grid UseMatricksPositions")
    end

    -- Stash the current selection order AND Matricks to a temp group.
    -- Groups preserve both; sequences do not (see note above on why SelFix from a
    -- stored Sequence is not used here).
    Cmd("Store Group 9990 /Overwrite")

    -- Clear extraneous programmer data before the loop begins.
    Cmd("ClearAll")

    -- Restore the selection order AND Matricks from the stashed group.
    Cmd("Group 9990")

    -- Enter blind mode so the store loop doesn't cause flashes on stage.
    Cmd("Blind On")

    -- Hand off to the run component to begin the iteration loop.
    CmdIndirect("Plugin 'Multi Stabs'.wingBlockStabs_run")
end

return main