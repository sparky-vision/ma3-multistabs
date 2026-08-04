-- straightStabs_run
-- Iteration component for Straight Stabs.
-- Called repeatedly via CmdIndirect until stepCounter exceeds steps,
-- at which point it hands off to multiStabs_finish.
--
-- Reads seqIndex and steps from the shared state table (Lua-scoped).
-- Reads/writes stepCounter via UserVars (must survive CmdIndirect hops).
--
-- Each iteration:
--   1. Next                   -- activates the next XBlock group in the programmer
--   2. At Sequence 9990 Cue 1 -- recalls stashed values onto the current group.
--      This is necessary because MA3 will not store unchanged programmer data.
--   3. Store                  -- stores the current programmer state to the cue
--   4. Label                  -- applies a generic placeholder label
--   5. Increment              -- advances the step counter and loops

local shared = select(3, ...)

local function main()
    -- Read iteration state.
    -- stepCounter comes from UserVars — it must survive CmdIndirect hops.
    -- seqIndex and steps come from the shared table — Lua-scoped, set once in _init.
    local stepCounter = GetVar(UserVars(), "MS_stepCounter")
    local steps       = shared.steps
    local seqIndex    = shared.seqIndex

    -- Validate that all required state is present before proceeding
    if not stepCounter or not steps or not seqIndex then
        Printf("Straight Stabs: missing state, aborting. stepCounter=" .. tostring(stepCounter) .. " steps=" .. tostring(steps) .. " seqIndex=" .. tostring(seqIndex))
        return
    end

    -- If we've exceeded the step count, hand off to the universal finish component
    if stepCounter > steps then
        CmdIndirect("Plugin 'Multi Stabs'.multiStabs_finish")
        return
    end

    Printf("Straight Stabs: storing cue " .. stepCounter .. " of " .. steps)

    -- Advance to the next XBlock group, activating it in the programmer
    Cmd("Next")

    -- Recall stashed programmer values onto the currently active group.
    -- Without this, MA3 sees no programmer change and stores nothing.
    Cmd("At Sequence 9990 Cue 1")

    -- Store current programmer state to the specified cue
    Cmd("Store Sequence " .. seqIndex .. " Cue " .. stepCounter .. " /Merge")

    -- Apply a generic placeholder label to the cue
    Cmd('Label Sequence ' .. seqIndex .. ' Cue ' .. stepCounter .. ' "---"')

    -- Increment the step counter for the next iteration
    SetVar(UserVars(), "MS_stepCounter", stepCounter + 1)

    -- Loop back to this component for the next iteration
    CmdIndirect("Plugin 'Multi Stabs'.straightStabs_run")
end

return main