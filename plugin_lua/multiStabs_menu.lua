-- multiStabs_menu
-- Entry point for the Multi Stabs plugin.
-- Runs all pre-flight validation ONCE here (rather than duplicated in every
-- variant's _init), then sets shared.shuffleMode, shared.buttonMode,
-- shared.offTime, and shared.seqIndex before dispatching.
--
-- Pre-flight validation, in order (all before the function picker dialog, so
-- nothing is wasted picking a function if the console isn't in a runnable
-- state):
--   1. Sequence selected? (hard stop if not, modal + Printf)
--   2. Fixtures selected? (hard stop if not, modal + Printf. SelectionCount()
--      confirmed via MA Lighting docs to return 0 when nothing is selected)
--   3. Is the sequence's executor on the CURRENT page? (warning, Continue/
--      Abort. multiStabs_finish only configures buttons on the current page,
--      so running elsewhere silently skips that step)
--   4. Does the sequence contain more cues than an empty one would? (warning,
--      Continue/Abort. Running this plugin stores into the sequence, which
--      will overwrite existing sequence data)
--
-- buttonMode values:
--   "go"   executor Key = "Go+" (advances to next cue on press)
--   "temp" executor Key = "Temp" (momentary/bump-style playback)
--
-- offTime: OffCue fade time in seconds, user-entered here instead of the old
-- hardcoded 0.5. whiteFilter restricts input to digits and a single decimal
-- point, and tonumber() on the result does the rest of the validation for
-- free: it rejects anything malformed (multiple decimal points, a bare ".",
-- an empty string) by returning nil, which is treated the same as any other
-- hard-stop validation failure. No unit suffix or special-case time format
-- is needed, the console always assumes seconds outside special cases this
-- plugin doesn't touch.
--
-- Selector display note: MA3 selectors display in ALPHABETICAL order by key
-- name, not insertion order. The Function selector keeps a bare
-- leading digit (no underscore) to hold the 1-9 grouping in order, single
-- digits sort correctly both alphabetically and numerically. Button Function
-- has no prefix: "Go+"/"Temp" already sort alphabetically as desired.
--
-- Help screen: MessageBox() has no confirmed live-update mechanism, so
-- "Help" opens multiStabs_help, a read-only reference screen with a "Back"
-- button that returns here.
--
-- Function list:
--   1  Straight Stabs           XGroup, no shuffle
--   2  Straight Shuffle Stabs   XGroup, shuffle before
--   3  Block Stabs              XBlock + XGroup, no shuffle
--   4  Block Shuffle Stabs      XBlock + XGroup, shuffle after
--   5  Shuffle Block Stabs      XBlock + XGroup, shuffle before
--   6  Wing Stabs               XWings + XGroup, no shuffle
--   7  Wing Shuffle Stabs       XWings + XGroup, shuffle before
--   8  Wing Block Stabs         XWings + XBlock + XGroup, no shuffle
--   9  Wing Shuffle Block Stabs XWings + XBlock + XGroup, shuffle before

local shared = select(3, ...)

local function main()
    -- 1. Hard stop: no sequence selected.
    local seqInfo = SelectedSequence()
    if not seqInfo or not seqInfo.INDEX then
        MessageBox({
            title = "Multi Stabs: Error",
            message = "No sequence is selected.\nPlease select a sequence and try again.",
            icon = "tools",
            commands = { { value = 1, name = "OK" } }
        })
        Printf("Multi Stabs: no sequence selected. Please select a sequence and try again.")
        return
    end
    local seqIndex = seqInfo.INDEX

    -- 2. Hard stop: no fixtures selected.
    if SelectionCount() == 0 then
        MessageBox({
            title = "Multi Stabs: Error",
            message = "No fixtures are selected.\nPlease select fixtures and try again.",
            icon = "tools",
            commands = { { value = 1, name = "OK" } }
        })
        Printf("Multi Stabs: no fixtures selected. Please select fixtures and try again.")
        return
    end

    local seqHandle = DataPool().Sequences[seqIndex]

    if seqHandle then
        -- 3. Warning: executor not on the current page.
        local currentPageIndex = CurrentExecPage().index
        local onCurrentPage = false
        for _, ref in ipairs(seqHandle:GetReferences()) do
            if ref:GetClass() == 'Exec' then
                local pageNum = ref:ToAddr():match("Page (%d+)%.")
                if pageNum and tonumber(pageNum) == currentPageIndex then
                    onCurrentPage = true
                    break
                end
            end
        end

        if not onCurrentPage then
            local warnResult = MessageBox({
                title = "Multi Stabs: Warning",
                message = "Sequence " .. seqIndex .. "'s executor is not on the current page ("
                    .. tostring(currentPageIndex) .. ").\nExecutor button settings will be skipped "
                    .. "at the end of this run.\n\nContinue anyway?",
                icon = "tools",
                commands = {
                    { value = 1, name = "Continue" },
                    { value = 0, name = "Abort" }
                }
            })
            if not warnResult.success or warnResult.result == 0 then
                Printf("Multi Stabs: aborted (executor not on current page).")
                return
            end
        end

        -- 4. Warning: sequence contains more cues than an "empty" sequence
        -- would have. MA3 sequences always include a CueZero and an OffCue,
        -- and Storing to an executor that's never been used adds one more
        -- empty cue on top of those, so a genuinely empty sequence typically
        -- shows 2 or 3 cues, not 0. Only counts above that baseline indicate
        -- real, pre-existing show data that this plugin would merge into.
        local cueCount = #seqHandle:Children()
        if cueCount > 3 then
            local warnResult = MessageBox({
                title = "Multi Stabs: Warning",
                message = "Sequence " .. seqIndex .. " already contains " .. cueCount
                    .. " cues (more than the 2-3 expected for an empty sequence).\n"
                    .. "Running this plugin will store into this existing sequence, "
                    .. "which may overwrite data.\n\nContinue anyway?",
                icon = "tools",
                commands = {
                    { value = 1, name = "Continue" },
                    { value = 0, name = "Abort" }
                }
            })
            if not warnResult.success or warnResult.result == 0 then
                Printf("Multi Stabs: aborted (sequence already contains cues).")
                return
            end
        end
    end

    -- All pre-flight checks passed (or were explicitly overridden). Stash
    -- seqIndex now so every _init component can read it directly.
    shared.seqIndex = seqIndex

    local selectorButtons = {
        {
            name = "Function",
            selectedValue = shared.lastFunctionChoice or 1,
            type = 0,
            values = {
                ["1 Straight Stabs"]             = 1,
                ["2 Straight Shuffle Stabs"]      = 2,
                ["3 Block Stabs"]                 = 3,
                ["4 Block Shuffle Stabs"]         = 4,
                ["5 Shuffle Block Stabs"]         = 5,
                ["6 Wing Stabs"]                  = 6,
                ["7 Wing Shuffle Stabs"]          = 7,
                ["8 Wing Block Stabs"]            = 8,
                ["9 Wing Shuffle Block Stabs"]    = 9,
            }
        },
        {
            name = "Button Function",
            selectedValue = shared.lastButtonChoice or 1,
            type = 0,
            values = {
                ["Go+"]  = 1,
                ["Temp"] = 2,
            }
        }
    }

    local returnTable = MessageBox({
        title = "Multi Stabs",
        message = "Select a function to run.",
        inputs = {
            { name = "Off Time", value = shared.lastOffTime or "0.5", whiteFilter = "0123456789.", vkPlugin = "NumericInput" }
        },
        commands = {
            { value = 1, name = "Run" },
            { value = 2, name = "Help" },
            { value = 0, name = "Cancel" }
        },
        selectors = selectorButtons,
    })

    if returnTable.success then
        shared.lastFunctionChoice = returnTable.selectors["Function"]
        shared.lastButtonChoice   = returnTable.selectors["Button Function"]
    end

    if not returnTable.success or returnTable.result == 0 then
        Printf("Multi Stabs: cancelled.")
        return
    end

    if returnTable.result == 2 then
        CmdIndirect("Plugin 'Multi Stabs'.multiStabs_help")
        return
    end

    -- Validate the off time input. whiteFilter already restricts entry to
    -- digits and a decimal point, but tonumber() is what actually confirms
    -- the result is a clean, single number (rejects "1.2.3", ".", "", etc.).
    local offTimeStr = returnTable.inputs["Off Time"]
    local offTime = tonumber(offTimeStr)
    if not offTime or offTime < 0 then
        MessageBox({
            title = "Multi Stabs: Error",
            message = "Off Time must be a number (seconds), with at most one decimal point.\nPlease correct it and try again.",
            icon = "tools",
            commands = { { value = 1, name = "OK" } }
        })
        Printf("Multi Stabs: invalid Off Time entered: " .. tostring(offTimeStr))
        return
    end
    shared.offTime = offTime
    shared.lastOffTime = offTimeStr

    local selection = returnTable.selectors["Function"]
    local buttonChoice = returnTable.selectors["Button Function"]
    shared.buttonMode = (buttonChoice == 2) and "temp" or "go"

    Printf("Multi Stabs: launching function " .. tostring(selection) .. ", buttonMode=" .. shared.buttonMode .. ", offTime=" .. offTime)

    if selection == 1 then
        shared.shuffleMode = "none"
        CmdIndirect("Plugin 'Multi Stabs'.straightStabs_init")
    elseif selection == 2 then
        shared.shuffleMode = "before"
        CmdIndirect("Plugin 'Multi Stabs'.straightStabs_init")
    elseif selection == 3 then
        shared.shuffleMode = "none"
        CmdIndirect("Plugin 'Multi Stabs'.blockStabs_init")
    elseif selection == 4 then
        shared.shuffleMode = "after"
        CmdIndirect("Plugin 'Multi Stabs'.blockStabs_init")
    elseif selection == 5 then
        shared.shuffleMode = "before"
        CmdIndirect("Plugin 'Multi Stabs'.blockStabs_init")
    elseif selection == 6 then
        shared.shuffleMode = "none"
        CmdIndirect("Plugin 'Multi Stabs'.wingStabs_init")
    elseif selection == 7 then
        shared.shuffleMode = "before"
        CmdIndirect("Plugin 'Multi Stabs'.wingStabs_init")
    elseif selection == 8 then
        shared.shuffleMode = "none"
        CmdIndirect("Plugin 'Multi Stabs'.wingBlockStabs_init")
    elseif selection == 9 then
        shared.shuffleMode = "before"
        CmdIndirect("Plugin 'Multi Stabs'.wingBlockStabs_init")
    else
        Printf("Multi Stabs: unknown selection " .. tostring(selection) .. ", aborting.")
    end

end

return main