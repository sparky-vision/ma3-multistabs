-- wingBlockStabs_init
-- Entry point for Wing Block Stabs and Wing Shuffle Block Stabs.
-- Dispatched from multiStabs_menu for selections 8 and 9.
-- Reads shared.seqIndex, already validated in multiStabs_menu before dispatch
-- (sequence selected, fixtures selected, executor page, cue count) — no need
-- to re-check any of that here.
--
-- shuffleMode behaviour for this variant (confirmed via console testing):
--   "none"   — XBlock, XWings, XGroup, single Grid UseMatricksPositions commit.
--              No intermediate commit needed between XBlock and XWings without
--              shuffle involved.
--   "before" — XBlock, XWings, THEN a commit BEFORE Shuffle (confirmed required
--              specifically for this combined variant). After Shuffle, YShuffle/
--              ZShuffle are nulled, a second commit follows, and only then is
--              XGroup applied. XGroup does NOT need its own trailing commit
--              before the Group stash — the second commit carries through.
--   There is no "after" mode for this variant — mirrors plain Wing Stabs.
--
-- Note on why this uses the Group 9990 stash/recall and NOT SelFix from a stored
-- Sequence: confirmed that `SelFix Sequence [n]` brings fixtures into the
-- Programmer in patch order, not their original selection order. Patch order IS
-- a real, confirmed phenomenon — it's specifically a SelFix-into-Programmer
-- behaviour, unrelated to how the Selection Grid handles fixture order (the
-- Selection Grid and every Matricks command operate on selection order only).
-- Group 9990 remains the only confirmed way to preserve original fixture
-- selection order (and Matricks state) through a ClearAll.
--
-- wings and blockSize are local to _init only — once baked into the stashed
-- group they are not needed again.

local shared = select(3, ...)

local function main()
    local seqIndex = shared.seqIndex

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

    if not resultTable.success or resultTable.result == 0 then
        Printf("Wing Block Stabs: cancelled.")
        return
    end

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

    -- seqIndex is already set by multiStabs_menu — only steps needs storing.
    shared.steps = steps

    SetVar(UserVars(), "MS_stepCounter", 1)

    Printf("Wing Block Stabs: shuffleMode=" .. tostring(shared.shuffleMode) .. ", Wings=" .. wings .. ", BlockSize=" .. blockSize .. ", Steps=" .. steps .. ", Sequence=" .. seqIndex)

    Cmd("Store Sequence 9990 /Overwrite")

    Cmd("Set Selection MAtricks XBlock " .. blockSize)
    Cmd("Set Selection MAtricks XWings " .. wings)

    if shared.shuffleMode == "before" then
        Cmd("Grid UseMatricksPositions")
        Cmd("Shuffle")
        Cmd("Set CurrentUserProfile Property \"YShuffle\" \"None\"")
        Cmd("Set CurrentUserProfile Property \"ZShuffle\" \"None\"")
        Cmd("Grid UseMatricksPositions")
        Cmd("Set Selection MAtricks XGroup " .. steps)
    else
        Cmd("Set Selection MAtricks XGroup " .. steps)
        Cmd("Grid UseMatricksPositions")
    end

    Cmd("Store Group 9990 /Overwrite")
    Cmd("ClearAll")
    Cmd("Group 9990")
    Cmd("Blind On")

    CmdIndirect("Plugin 'Multi Stabs'.wingBlockStabs_run")
end

return main