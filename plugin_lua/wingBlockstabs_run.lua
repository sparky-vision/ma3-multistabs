-- wingBlockStabs_run
-- Iteration component for Wing Block Stabs and Wing Shuffle Block Stabs.
-- The Matricks setup and any shuffle was handled entirely in wingBlockStabs_init
-- and is baked into the stashed group — the run loop is identical for all variants.
--
-- Called repeatedly via CmdIndirect until stepCounter exceeds steps,
-- at which point it hands off to multiStabs_finish.

local shared = select(3, ...)

local function main()
    local stepCounter = GetVar(UserVars(), "MS_stepCounter")
    local steps       = shared.steps
    local seqIndex    = shared.seqIndex

    if not stepCounter or not steps or not seqIndex then
        Printf("Wing Block Stabs: missing state, aborting. stepCounter=" .. tostring(stepCounter) .. " steps=" .. tostring(steps) .. " seqIndex=" .. tostring(seqIndex))
        return
    end

    if stepCounter > steps then
        CmdIndirect("Plugin 'Multi Stabs'.multiStabs_finish")
        return
    end

    Printf("Wing Block Stabs: storing cue " .. stepCounter .. " of " .. steps)

    -- Activate the next Matricks group in the programmer.
    Cmd("Next")

    -- Recall stash onto current group. Forces MA3 to see a programmer change
    -- so it doesn't skip the Store on unchanged data.
    Cmd("At Sequence 9990 Cue 1")

    -- Store and label the current cue.
    Cmd("Store Sequence " .. seqIndex .. " Cue " .. stepCounter .. " /Merge")
    Cmd('Label Sequence ' .. seqIndex .. ' Cue ' .. stepCounter .. ' "---"')

    SetVar(UserVars(), "MS_stepCounter", stepCounter + 1)

    CmdIndirect("Plugin 'Multi Stabs'.wingBlockStabs_run")
end

return main