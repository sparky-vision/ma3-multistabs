-- multiStabs_finish
-- Universal finalisation component for all stabs variants.
-- Called by any variant's _run component when the iteration loop is complete.
-- Reads seqIndex and buttonMode from the shared state table (Lua-scoped, no
-- UserVars needed).
--
-- Responsibilities:
--   1. ClearAll + Blind Off
--   2. Set sequence properties
--   3. ClearAll (final)
--   4. Delete stash objects
--   5. Set executor button properties (Key=<buttonMode>, KeyUnpress=Off)
--   6. Clean up UserVars (stepCounter only)
--   7. Print completion message
--
-- Note on executor button configuration:
-- A sequence can be assigned across an entire physical fader stack at once (a
-- vertical rubber-band drag spanning e.g. 401/301/201/101), and each of those
-- executor numbers is a fully independent Exec object with its own single
-- Key/KeyUnpress pair — an executor's knob, fader, and button are all just
-- properties of that ONE exec, not separate objects. Confirmed via console
-- property dump: there is no second "bottom button" property on any single
-- executor. "The bottom button" means the lowest-numbered executor in a
-- physical stack, which GetReferences() already returns as a distinct
-- reference when the whole stack is assigned together.
--
-- "Column" = physical fader stack position, derived from the last two digits
-- of the executor number (101/201/301/401 all share column 1). Scope is
-- restricted to the CURRENT page only, so a sequence reused elsewhere on a
-- different page is left untouched there. Within the current page, the
-- bottom-most (lowest-numbered) executor in EVERY column the sequence occupies
-- gets Key/KeyUnpress set — this always happens regardless of how many columns
-- are found. If more than one column is found, a modal alert is raised UNLESS
-- the columns are sequential (e.g. columns 1 and 2 — a deliberately widened
-- sequence). Non-sequential columns most likely indicate an unintended/reused
-- assignment, which is treated as an error condition worth surfacing
-- immediately rather than a silent log line.
--
-- Button function: shared.buttonMode (set in multiStabs_menu) selects between
-- "Go+" (advances to next cue on press) and "Temp" (momentary/bump-style
-- playback). Both confirmed via console property read-back as directly
-- settable literal strings for the Key property. KeyUnpress is always "Off"
-- regardless of buttonMode; confirmed via console read-back that
-- KeyUnpressCommand is empty/null under both configurations, so no explicit
-- clearing of that property is required.

local shared = select(3, ...)

local function main()
    local seqIndex = shared.seqIndex

    if not seqIndex then
        Printf("Multi Stabs: missing shared.seqIndex in finish, aborting.")
        return
    end

    -- Clear the programmer
    Cmd("ClearAll")

    -- Exit blind mode
    Cmd("Blind Off")

    -- Set sequence properties.
    -- Property names sourced from original MA3 macro.
    Cmd('Set Sequence ' .. seqIndex .. ' Property "Wraparound" "1"')
    Cmd('Set Sequence ' .. seqIndex .. ' Property "Restartmode" "Next Cue"')
    Cmd('Set Sequence ' .. seqIndex .. ' Cue "OffCue" "CueFade" "' .. tostring(shared.offTime or 0.5) .. '"')
    Cmd('Set Sequence ' .. seqIndex .. ' Property "Tracking" "0"')

    -- Final programmer clear
    Cmd("ClearAll")

    -- Delete both stash objects now that the loop is complete
    Cmd("Delete Sequence 9990")
    Cmd("Delete Group 9990")

    -- Determine the Key value to apply from shared.buttonMode, set in
    -- multiStabs_menu. Confirmed via console read-back: Key stores "Go+" and
    -- "Temp" as their literal, directly-settable string values.
    local keyValue = (shared.buttonMode == "temp") and "Temp" or "Go+"

    -- Set executor button properties, scoped to the bottom-most executor of
    -- each physical fader-stack column the sequence occupies on the CURRENT
    -- page only. See header note above for the full reasoning.
    local currentPageIndex = CurrentExecPage().index

    local seqHandle = DataPool().Sequences[seqIndex]
    if seqHandle then
        -- Group current-page Exec references by column (last two digits of
        -- the executor number).
        local columns = {}

        for _, ref in ipairs(seqHandle:GetReferences()) do
            if ref:GetClass() == 'Exec' then
                local addr = ref:ToAddr()
                local pageNum, execNum = addr:match("Page (%d+)%.(%d+)")
                if pageNum and execNum then
                    pageNum = tonumber(pageNum)
                    execNum = tonumber(execNum)
                    if pageNum == currentPageIndex then
                        local column = execNum % 100
                        columns[column] = columns[column] or {}
                        table.insert(columns[column], { execNum = execNum, addr = addr })
                    end
                else
                    Printf("Multi Stabs: could not parse executor address: " .. tostring(addr))
                end
            end
        end

        -- Within each column, find the bottom-most (lowest execNum) executor.
        -- Also collect the sorted column numbers to check for sequentiality.
        local columnNumbers = {}
        local bottomAddrs = {}
        for column, execs in pairs(columns) do
            table.insert(columnNumbers, column)
            table.sort(execs, function(a, b) return a.execNum < b.execNum end)
            table.insert(bottomAddrs, execs[1].addr)
        end
        table.sort(columnNumbers)

        if #bottomAddrs == 0 then
            Printf("Multi Stabs: sequence " .. seqIndex .. " has no executor references on the current page (" .. tostring(currentPageIndex) .. ").")
        end

        -- Apply Key=<keyValue>, KeyUnpress=Off to the bottom-most executor of
        -- EVERY column found — this happens regardless of how many columns
        -- there are. KeyUnpressCommand is confirmed empty/null under both
        -- button modes, so it is left untouched.
        for _, addr in ipairs(bottomAddrs) do
            Cmd('Set ' .. addr .. ' Property "Key" "' .. keyValue .. '"')
            Cmd('Set ' .. addr .. ' Property "KeyUnpress" ""')
            Printf("Multi Stabs: set Key=" .. keyValue .. ", cleared KeyUnpress on " .. addr)
        end

        -- If more than one column was found, only alert if they are NOT
        -- sequential. Sequential columns (e.g. 1 and 2) indicate a deliberately
        -- widened sequence — expected, if rare. A gap (e.g. columns 1 and 5)
        -- most likely means an unintended/reused assignment, which is an error
        -- condition for this plugin's use case and gets a modal, not just a
        -- Printf, since it needs the user's attention.
        if #columnNumbers > 1 then
            local sequential = true
            for i = 2, #columnNumbers do
                if columnNumbers[i] ~= columnNumbers[i - 1] + 1 then
                    sequential = false
                    break
                end
            end

            if not sequential then
                MessageBox({
                    title = "Multi Stabs: Executor Warning",
                    message = "Sequence " .. seqIndex .. " is assigned across non-sequential executor columns ("
                        .. table.concat(columnNumbers, ", ") .. ") on page " .. tostring(currentPageIndex) .. ".\n"
                        .. "Button settings were applied to each column's bottom-most executor, but this pattern "
                        .. "is unexpected for this plugin — please verify the assignment.",
                    icon = "tools",
                    commands = { { value = 1, name = "OK" } }
                })
            end
        end
    else
        Printf("Multi Stabs: could not get sequence handle for executor button config.")
    end

    -- Clean up UserVars. Only stepCounter lives in UserVars — everything else
    -- was Lua-scoped via the shared state table and needs no cleanup.
    SetVar(UserVars(), "MS_stepCounter", nil)

    Printf("Multi Stabs: complete.")
end

return main