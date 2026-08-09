-- blockStabs_init
-- Entry point for Block Stabs, Block Shuffle Stabs, and Shuffle Block Stabs.
-- Dispatched from multiStabs_menu for selections 3, 4, and 5.
-- Reads shared.shuffleMode to determine when (if at all) to apply Shuffle.
-- Reads shared.seqIndex, already validated in multiStabs_menu before dispatch
-- (sequence selected, fixtures selected, executor page, cue count) — no need
-- to re-check any of that here.
--
-- shuffleMode behaviour for block variants:
--   "none"   — XBlock then XGroup, no shuffle.
--   "before" — Shuffle + Grid UseMatricksPositions to commit shuffled order,
--              THEN XBlock + XGroup. The UseMatricksPositions call is required
--              here because XBlock would otherwise anchor to the prior selection
--              order, ignoring the shuffle.
--   "after"  — XBlock then XGroup, then Shuffle to randomise group firing order.
--
-- blockSize is local to _init only — once baked into the stashed group it is not needed.

local shared = select(3, ...)

local function main()
    local seqIndex = shared.seqIndex

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

    if not resultTable.success or resultTable.result == 0 then
        Printf("Block Stabs: cancelled.")
        return
    end

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

    -- seqIndex is already set by multiStabs_menu — only steps needs storing.
    shared.steps = steps

    SetVar(UserVars(), "MS_stepCounter", 1)

    Printf("Block Stabs: shuffleMode=" .. tostring(shared.shuffleMode) .. ", BlockSize=" .. blockSize .. ", Steps=" .. steps .. ", Sequence=" .. seqIndex)

    Cmd("Store Sequence 9990 /Overwrite")

    if shared.shuffleMode == "before" then
        Cmd("Shuffle")
        Cmd("Grid UseMatricksPositions")
    end

    Cmd("Set Selection MAtricks XBlock " .. blockSize)
    Cmd("Set Selection MAtricks XGroup " .. steps)

    if shared.shuffleMode == "after" then
        Cmd("Shuffle")
    end

    Cmd("Grid UseMatricksPositions")
    Cmd("Store Group 9990 /Overwrite")
    Cmd("ClearAll")
    Cmd("Group 9990")
    Cmd("Blind On")

    CmdIndirect("Plugin 'Multi Stabs'.blockStabs_run")
end

return main