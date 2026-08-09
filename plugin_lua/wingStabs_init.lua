-- wingStabs_init
-- Entry point for Wing Stabs and Wing Shuffle Stabs.
-- Dispatched from multiStabs_menu for selections 6 and 7.
-- Reads shared.shuffleMode to determine whether to apply Shuffle.
-- Reads shared.seqIndex, already validated in multiStabs_menu before dispatch
-- (sequence selected, fixtures selected, executor page, cue count) — no need
-- to re-check any of that here.
--
-- shuffleMode behaviour for wing variants:
--   "none"   — XWings then XGroup, no shuffle.
--   "before" — XWings then XGroup, then Shuffle to randomise fixture order.
--              Y and Z shuffle axes are nulled immediately after Shuffle because
--              Shuffle applies to all axes simultaneously and would otherwise
--              scramble fixtures within each wing pair. Grid UseMatricksPositions
--              then commits the corrected state before stashing.
--
-- Note: Store Sequence 9990 is performed immediately — it captures only the
-- target programmer levels and has no dependency on selection order or Matricks.
--
-- Note: XWings and XGroup command order is interchangeable for this variant —
-- final stage output is identical regardless of order.
--
-- wings is local to _init only — once baked into the stashed group it is not needed.

local shared = select(3, ...)

local function main()
    local seqIndex = shared.seqIndex

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

    if not resultTable.success or resultTable.result == 0 then
        Printf("Wing Stabs: cancelled.")
        return
    end

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

    -- seqIndex is already set by multiStabs_menu — only steps needs storing.
    shared.steps = steps

    SetVar(UserVars(), "MS_stepCounter", 1)

    Printf("Wing Stabs: shuffleMode=" .. tostring(shared.shuffleMode) .. ", Wings=" .. wings .. ", Steps=" .. steps .. ", Sequence=" .. seqIndex)

    Cmd("Store Sequence 9990 /Overwrite")

    Cmd("Set Selection MAtricks XWings " .. wings)
    Cmd("Set Selection MAtricks XGroup " .. steps)

    if shared.shuffleMode == "before" then
        Cmd("Shuffle")
        Cmd("Set CurrentUserProfile Property \"YShuffle\" \"None\"")
        Cmd("Set CurrentUserProfile Property \"ZShuffle\" \"None\"")
    end

    Cmd("Grid UseMatricksPositions")
    Cmd("Store Group 9990 /Overwrite")
    Cmd("ClearAll")
    Cmd("Group 9990")
    Cmd("Blind On")

    CmdIndirect("Plugin 'Multi Stabs'.wingStabs_run")
end

return main