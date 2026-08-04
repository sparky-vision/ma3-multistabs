-- multiStabs_finish
-- Universal finalisation component for all stabs variants.
-- Called by any variant's _run component when the iteration loop is complete.
-- Reads seqIndex from the shared state table (Lua-scoped, no UserVars needed).
--
-- Responsibilities:
--   1. ClearAll + Blind Off
--   2. Set sequence properties
--   3. ClearAll (final)
--   4. Delete stash objects
--   5. Set executor button properties (Key=Go+, KeyUnpress=Off)
--   6. Clean up UserVars (stepCounter only)
--   7. Print completion message

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
    Cmd('Set Sequence ' .. seqIndex .. ' Cue "OffCue" "CueFade" "0.5"')
    Cmd('Set Sequence ' .. seqIndex .. ' Property "Tracking" "0"')

    -- Final programmer clear
    Cmd("ClearAll")

    -- Delete both stash objects now that the loop is complete
    Cmd("Delete Sequence 9990")
    Cmd("Delete Group 9990")

    -- Set executor button properties on all executors this sequence is assigned to.
    -- Key        = "Go+" : pressing the button triggers Go+
    -- KeyUnpress = "Off" : releasing the button triggers Off
    -- ToAddr() returns "Page X.NNN" which is used directly in the Cmd call.
    -- If the sequence is not assigned to any executor, this block is skipped silently.
    local seqHandle = DataPool().Sequences[seqIndex]
    if seqHandle then
        for _, ref in ipairs(seqHandle:GetReferences()) do
            if ref:GetClass() == 'Exec' then
                local addr = ref:ToAddr()
                local pageNum, execNum = addr:match("Page (%d+)%.(%d+)")
                if pageNum and execNum then
                    Cmd('Set ' .. addr .. ' Property "Key" "Go+"')
                    Cmd('Set ' .. addr .. ' Property "KeyUnpress" "Off"')
                    Printf("Multi Stabs: set Key=Go+, KeyUnpress=Off on " .. addr)
                else
                    Printf("Multi Stabs: could not parse executor address: " .. tostring(addr))
                end
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