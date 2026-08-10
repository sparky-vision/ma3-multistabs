# GrandMA3 Multi Stabs Plugin
## Technical Specification & Development Reference
**Version 0.7 | All Nine Functions Complete, Pre-Release Documentation Pass**

---

## 1. Purpose

This document describes the design, architecture, confirmed behaviours, and working code for the GrandMA3 Multi Stabs Plugin, a Lua plugin that automates the creation of sequential dimmer chase cuelists ("stabs") from a user's current fixture selection and configures the executor it's stored to.

The plugin is a re-creation of a GrandMA2 macro workflow originally created by EarlyBird Visual. Because macro conditional logic no longer exists in MA3, all logic is implemented in Lua. Straight Stabs was the first and simplest function, and served as the template for all subsequent variants. As of this version, all nine planned function variants are complete and console-tested.

### 1.1 Changes Since v0.6

This pass folds in everything confirmed or built since the previous version. At a glance:

- Both Wing Block variants (functions 8 and 9) are complete, tested, and documented.
- Terminology cleanup: "node" replaced with "fixture" or "position" throughout (see section 2), and the Selection Grid / patch order relationship is corrected (section 2, section 3.9).
- All pre-flight validation (sequence selected, fixtures selected, executor on current page, existing cue count) is consolidated into `multiStabs_menu` rather than duplicated per variant, and hard-stop errors now show a modal dialog in addition to a `Printf` log line (section 3.18).
- The "empty sequence" cue-count baseline is corrected, and the plugin now reports and compares against a *real* cue count that excludes the always-present CueZero and OffCue special cues (section 3.18).
- Continuing past the existing-cues warning now clears the sequence's numbered cues before storing, so a shorter re-run doesn't leave stale higher-numbered cues behind (section 3.18).
- The `Store` command in every `_run` component's iteration loop now uses `/Overwrite` instead of `/Merge`, matching the plugin's stated behaviour that running it on an existing sequence replaces that sequence's content rather than blending with it.
- The OffCue fade time is now a user-entered value (`shared.offTime`) instead of a fixed 0.5 seconds (section 3.19).
- The executor button function is now user-selectable between "Go+" and "Temp" (section 3.20).
- Executor button configuration is now scoped correctly to physical fader-stack columns on the current page, and a fixed bug where `KeyUnpress` was being assigned the literal value `"Off"` instead of being cleared has been corrected (section 3.15).
- A read-only Help screen (`multiStabs_help`) was added, since `MessageBox()` has no confirmed mechanism for live-updating descriptive text (section 3.21).
- A documented limitation on custom images and icons in `MessageBox()` dialogs, including why animated content isn't possible through any confirmed method (section 3.22).
- A usage note on how fixture selection method (clicking versus rubber-band) affects Selection Grid position, and why this plugin expects linear selections (section 3.23).
- Guidance on exporting the finished plugin to a single XML file for distribution, and a gotcha to check before doing so (section 3.24).

---

## 2. Terminology

| Term | Definition |
|------|------------|
| Plugin | A Lua script in MA3. Composed of one or more Components. Plugin name: `Multi Stabs`. |
| Component | A discrete Lua function within a Plugin. Each returns a single callable function. Only the FIRST Component runs automatically when a Plugin is called. All others must be triggered via CLI. |
| Macro | A separate MA3 object that executes CLI commands. Distinct from Plugins. |
| CLI | Console command line. All console operations are CLI-driven. |
| `Cmd()` | BLOCKING Lua function. Waits for the CLI command to complete before returning. Use for all sequential store/label operations. |
| `CmdIndirect()` | NON-BLOCKING Lua function. Fires a CLI command in the background. Use for jumping to the next Component. |
| `CmdIndirectWait()` | Synchronous variant of `CmdIndirect()`. Waits for command completion, but not for user or hardware input. Not currently used by this plugin, noted for completeness. |
| `Printf()` | Outputs to the system monitor. For debug/status messages. There is no console CLI output from a Lua plugin unless the component explicitly calls `Printf`. |
| Fixture | Any light-emitting stage light with a dimmer attribute. This is the correct term for an individual light in this system. Earlier drafts of this document used "node" in some places to mean an individual fixture; that usage has been corrected throughout. "Position" or "wing pair" is used instead where the original intent was a Selection Grid slot rather than a single light (see the Wing variant notes in section 3.9). |
| Programmer | A temporary memory location where edited values are placed, then stored or released. Every user profile has a programmer, with three levels: Selected fixture, Active programmer values, and Deactivated programmer values. Programmer values usually affect the system's output; the Blind function hides them from output without clearing them. Selected fixtures are affected by encoder input or command line entries, for example `Fixture 1 At Preset 2.1`. |
| Selection Grid | The mechanism behind every Matricks command (XBlock, XGroup, XWings, Shuffle). Always operates on selection order, never patch order. When fixtures are selected by clicking individually, selection order is strict linear click order. When fixtures are selected via rubber-band/marquee, the Selection Grid instead derives position from the fixtures' spatial (X/Y/Z) placement in the Layout View, since a marquee gesture has no click sequence to draw from. See section 3.23 for the resulting usage implication. |
| Patch order | The order fixtures were originally patched into the show. Real and confirmed, but relevant only to `SelFix Sequence [n]`, which brings fixtures from a stored sequence into the Programmer in patch order. Unrelated to the Selection Grid or any Matricks command, none of which consider patch order at all. |
| Matricks | Internal MA3 name for selection grid operations: XBlock, XGroup, XWings, etc. |
| XGroup | CLI keyword. Divides selection into N interleaved groups. Syntax: `Set Selection MAtricks XGroup [N]`. Note: XGroup's group count is independent of any earlier XBlock size, if the number of blocks produced by XBlock exceeds the XGroup step count, multiple whole blocks land in the same step (see section 3.9's Block variant notes and the Function List discussion of function 5). |
| XBlock | CLI keyword. Divides selection into N-fixture contiguous chunks. Syntax: `Set Selection MAtricks XBlock [N]`. |
| XWings | CLI keyword. Divides selection into mirrored pairs from outside in. Syntax: `Set Selection MAtricks XWings [N]`. Confirmed correct keyword, not `XWing`. |
| Next | CLI keyword. Advances to the next Matricks group, activating it in the programmer. |
| `Shuffle` | CLI keyword. Randomises current fixture selection order across ALL axes simultaneously. Confirmed keyword, `ShuffleSelection` does NOT work. |
| `SelFix` | CLI keyword, SELect FIXtures. Syntax: `SelFix Sequence [n] Please`. Brings the fixtures stored in sequence [n] into the Programmer, but in patch order, not their original selection order. This plugin does not use SelFix for stash/recall for this reason, since sequences don't preserve selection order and SelFix's patch-order behaviour isn't a substitute. See the Group 9990 stash pattern in section 3.5 instead. |
| Store | CLI keyword. Stores programmer state to a cue. The temporary stash uses `Store Sequence [n] /Overwrite`. The actual per-step cue store in each `_run` loop uses `Store Sequence [n] Cue [n] /Overwrite` (changed from `/Merge` in this version, see section 3.10). |
| Column | The physical fader-stack position of an executor, shared by every page's copy of that stack (for example, executors 101, 201, 301, and 401 are all "column 1" on their respective pages). Computed as `execNum % 100`. |
| Bottom button | The lowest-numbered executor within a column. Since a sequence assigned across an entire fader stack creates one independent Exec object per page, each with its own Key/KeyUnpress pair, "the bottom button" refers to whichever of those Exec objects has the lowest executor number, not a separate property on a single executor. |
| Real cue count | A sequence's cue count (`#seqHandle:Children()`) minus 2, to exclude the CueZero and OffCue special cues that exist on every MA3 sequence regardless of content. Programmers do not consider CueZero or OffCue part of the "real" cue stack, so this plugin's pre-flight validation reports and compares against the real count, not the raw one. See section 3.18. |
| `SelectedSequence()` | Lua API. Returns info about the currently selected sequence. `.INDEX` is the pool number. |
| `SelectionCount()` | Lua API. Returns the number of currently selected fixtures. Returns 0 when nothing is selected, confirmed via official MA Lighting documentation. |
| `CurrentExecPage().index` | Lua API. Returns the current executor page number. Community-confirmed; used for current-page scoping in section 3.15 and 3.18. |
| `UserVars()` | Lua API. Returns the console-global user variable store. ALWAYS namespace keys, e.g. `MS_stepCounter`. |
| `select(3,...)` | Lua pattern. Returns the shared state table passed to all Components. Must be called at TOP LEVEL of a Component, outside `main()`. Persists across Component calls within the same plugin session. |
| `GetVar()` | Returns TYPED values in MA3. Do NOT wrap in `tonumber()`, it will error if the value is already a number. |
| Please | Physical hardkey on the console, equivalent to [Enter]. NOT a CLI keyword, cannot be used in `Cmd()`. |

---

## 3. MA3 Lua, Confirmed Behaviours

The following behaviours have been confirmed through testing on a live MA3 console. These supersede any assumptions from MA2 documentation.

### 3.1 Plugin Execution Model

- Only the FIRST Component runs automatically when a Plugin is called.
- All subsequent Components must be triggered via CLI, typically via `CmdIndirect` from the previous Component.
- Each Component must return a callable function or MA3 will error: `LUA: no reference to main function found for plugin.`
- `multiStabs_menu` MUST be the first component in the plugin so it runs automatically on plugin call.
- There is no console CLI output from a Lua plugin unless the component explicitly calls `Printf`. Errors such as the one above appear in the System Monitor, not the CLI.

### 3.2 Shared State Table, select(3, ...)

- MA3 passes three arguments to each Component at the TOP LEVEL (outside any function).
- `select(3,...)` returns a table that is the SAME INSTANCE across all Components in the same Plugin session.
- This table persists between separate CLI-triggered Component calls.
- The varargs `(...)` are only valid at the top level. They are NOT available inside the returned `main()` function. Capture as an upvalue at top level.

Confirmed argument values:

| Argument | Value |
|----------|-------|
| `select(1,...)` | `"UserPlugin"`, a string |
| `select(2,...)` | Empty / nil |
| `select(3,...)` | Shared state table (same address across all Components) |

### 3.3 State Storage Strategy

| Mechanism | Use for |
|-----------|---------|
| `select(3,...)` shared table | Plugin-scoped. Preferred for all values that only need to survive within a single plugin session. Used for `seqIndex`, `steps`, `shuffleMode`, `buttonMode`, `offTime`, and the remembered last-choice values. |
| `UserVars()` | Console-global. Use ONLY for iteration state that must survive repeated `CmdIndirect` hops (i.e. `MS_stepCounter`). ALWAYS namespace keys with the `MS_` prefix. |

**Rule:** Default to the shared table. Only use UserVars if the value must be written and read across multiple separate `CmdIndirect`-triggered component invocations.

### 3.4 GetVar Returns Typed Values

`GetVar()` in MA3 returns TYPED values, not strings. Wrapping in `tonumber()` will cause a runtime error if the value is already a number.

Correct pattern:
```lua
local stepCounter = GetVar(UserVars(), "MS_stepCounter")   -- already a number, use directly
```

### 3.5 ClearAll Clears Matricks AND Selection

- `ClearAll` wipes the Matricks assignment AND the fixture selection. Both must be restored afterward.
- In MA3, Matricks IS stored in Groups. Store Group AFTER applying Matricks to capture both selection order and Matricks assignment in the group stash.
- Recalling a group (e.g. `Group 9990`) restores both selection order and Matricks. No need to re-apply `Set Selection MAtricks` afterward.
- Sequences do NOT preserve selection order. Always use a Group for the selection/Matricks stash, never a Sequence and never `SelFix`.

### 3.6 MA3 Will Not Store Unchanged Programmer Data

If the programmer data has not changed since the last Store, MA3 stores nothing. This is why a stash/recall pattern is required in the iteration loop.

Solution: stash programmer levels to Sequence 9990 before the loop. On each iteration, after `Next` activates the new group, recall the stash with `At Sequence 9990 Cue 1`. This forces MA3 to see a programmer change on every iteration.

### 3.7 At Syntax

- Correct syntax: `At Sequence [n] Cue [n]`
- INCORRECT (will not work): `At Cue [n] Sequence [n]`

### 3.8 Sequence 9990 Stash, Programmer Levels Only

`Store Sequence 9990` captures only the target programmer levels (e.g. dimmer values). It does NOT encode selection order or Matricks state. This means it can be stored immediately after validating inputs and before any Matricks commands are applied. The recall in the run loop (`At Sequence 9990 Cue 1`) restores only those levels, Matricks remains live from the Group recall.

### 3.9 Matricks Application Order in _init

The order of operations in `_init` is critical. The correct sequence depends on the variant.

#### Straight variants (XGroup only)

`Shuffle` before a single Matricks command works correctly without an intermediate `Grid UseMatricksPositions` call, XGroup operates on whatever selection order is currently active.

| Step | Command | Reason |
|------|---------|--------|
| 1 | `Store Sequence 9990 /Overwrite` | Stash programmer levels. No dependency on Matricks, can be stored immediately. |
| 2 | `Shuffle` *(shuffleMode == "before" only)* | Randomise selection order before XGroup. |
| 3 | `Set Selection MAtricks XGroup [n]` | Divide selection into N interleaved groups. |
| 4 | `Grid UseMatricksPositions` | Neutralise Selection Grid influence. Must be after XGroup and before group stash. |
| 5 | `Store Group 9990 /Overwrite` | Stash selection order + Matricks. Groups preserve both; sequences do not. |
| 6 | `ClearAll` | Clears programmer, selection, and Matricks. |
| 7 | `Group 9990` | Restores selection order AND Matricks in one command. |
| 8 | `Blind On` | Prevent stage flashes during the store loop. |

#### Block variants (XBlock + XGroup)

When two Matricks commands are applied in sequence, `Shuffle` alone is not sufficient, XBlock anchors to the selection order active before the shuffle and ignores it unless that order is committed first. `Grid UseMatricksPositions` must be called immediately after `Shuffle` to commit the randomised order into Matricks before XBlock is applied. (An earlier draft of this document attributed this to "patch order"; that was incorrect, patch order is a real but unrelated concept specific to `SelFix`, see section 2.)

| Step | Command | Notes |
|------|---------|-------|
| 1 | `Store Sequence 9990 /Overwrite` | Stash programmer levels immediately. |
| 2 | `Shuffle` *(shuffleMode == "before" only)* | Randomise selection order. |
| 3 | `Grid UseMatricksPositions` *(shuffleMode == "before" only)* | **Required for block variants.** Commits the shuffled order so XBlock respects it. |
| 4 | `Set Selection MAtricks XBlock [blockSize]` | Define contiguous block size. Apply before XGroup. |
| 5 | `Set Selection MAtricks XGroup [steps]` | Divide blocks into N chase steps. If the number of blocks exceeds the number of steps, multiple whole blocks are combined into the same step, see the Function List note on function 5. |
| 6 | `Shuffle` *(shuffleMode == "after" only)* | Randomise group firing order after Matricks is applied. |
| 7 | `Grid UseMatricksPositions` | Neutralise Selection Grid. Must be after all Matricks commands and before group stash. |
| 8 | `Store Group 9990 /Overwrite` | Stash selection order + Matricks. |
| 9 | `ClearAll` | Clears programmer, selection, and Matricks. |
| 10 | `Group 9990` | Restores selection order AND Matricks. |
| 11 | `Blind On` | Prevent stage flashes during the store loop. |

#### Wing variants (XWings + XGroup)

XWings collapses the selection into mirrored pairs, each pair occupying a single position on the X axis of the Selection Grid. `Shuffle` applies to all axes simultaneously, including within each wing pair on the Y axis. To shuffle only the order of wing pairs (X axis), Y and Z shuffle axes must be nulled immediately after `Shuffle`.

The `Set CurrentUserProfile Property` commands produce an "Illegal Property" error in the system monitor on some software versions. This is a known console bug and does not affect the result.

XWings and XGroup command order is interchangeable for this variant, final stage output is identical regardless of order. Note that Shuffle runs AFTER both XWings and XGroup here, not before, that ordering is intentional and confirmed via console testing: wing pairing has to already exist before the Y/Z nulling step means anything.

| Step | Command | Notes |
|------|---------|-------|
| 1 | `Store Sequence 9990 /Overwrite` | Stash programmer levels immediately. |
| 2 | `Set Selection MAtricks XWings [wings]` | Define mirrored pairing depth. |
| 3 | `Set Selection MAtricks XGroup [steps]` | Divide pairs into N chase steps. |
| 4 | `Shuffle` *(shuffleMode == "before" only)* | Randomise the order of wing pairs. Applies to all axes simultaneously. |
| 5 | `Set CurrentUserProfile Property "YShuffle" "None"` *(shuffleMode == "before" only)* | Null Y axis shuffle to prevent intra-pair scrambling. |
| 6 | `Set CurrentUserProfile Property "ZShuffle" "None"` *(shuffleMode == "before" only)* | Null Z axis shuffle to prevent intra-pair scrambling. |
| 7 | `Grid UseMatricksPositions` | Commit corrected state. Must be after all Matricks and shuffle-correction commands and before group stash. |
| 8 | `Store Group 9990 /Overwrite` | Stash selection order + Matricks. |
| 9 | `ClearAll` | Clears programmer, selection, and Matricks. |
| 10 | `Group 9990` | Restores selection order AND Matricks. |
| 11 | `Blind On` | Prevent stage flashes during the store loop. |

#### Wing Block variants (XBlock + XWings + XGroup)

Confirmed via console testing. Note the command order: XBlock runs before XWings, not after, an earlier version of this document assumed the opposite as an untested guess (see the superseded Open Question in v0.6 section 7).

For `shuffleMode == "none"`: XBlock, then XWings, then XGroup, with a single `Grid UseMatricksPositions` commit at the end. No intermediate commit is needed between XBlock and XWings when no shuffle is involved.

For `shuffleMode == "before"`: XBlock, then XWings, THEN a commit BEFORE Shuffle (confirmed required specifically for this combined variant, unlike the plain Wing variant which does not need a commit before its Shuffle). After Shuffle, YShuffle and ZShuffle are nulled, a second commit follows, and only then is XGroup applied. XGroup does not need its own trailing commit before the Group stash, the second commit carries through.

There is no "after" shuffle mode for this variant, it mirrors plain Wing Stabs in only supporting "none" and "before".

| Step | Command | Notes |
|------|---------|-------|
| 1 | `Store Sequence 9990 /Overwrite` | Stash programmer levels immediately. |
| 2 | `Set Selection MAtricks XBlock [blockSize]` | Define contiguous block size. |
| 3 | `Set Selection MAtricks XWings [wings]` | Define mirrored pairing depth, applied to the already-blocked selection. |
| 4 | `Grid UseMatricksPositions` *(shuffleMode == "before" only)* | Commit block + wing state before Shuffle runs. |
| 5 | `Shuffle` *(shuffleMode == "before" only)* | Randomise pair order. |
| 6 | `Set CurrentUserProfile Property "YShuffle" "None"` *(shuffleMode == "before" only)* | Null Y axis shuffle. |
| 7 | `Set CurrentUserProfile Property "ZShuffle" "None"` *(shuffleMode == "before" only)* | Null Z axis shuffle. |
| 8 | `Grid UseMatricksPositions` *(shuffleMode == "before" only)* | Second commit, carries through to the group stash. |
| 9 | `Set Selection MAtricks XGroup [steps]` | Divide into N chase steps. |
| 10 | `Grid UseMatricksPositions` *(shuffleMode == "none" only)* | Single commit for the no-shuffle path. |
| 11 | `Store Group 9990 /Overwrite` | Stash selection order + Matricks. |
| 12 | `ClearAll` | Clears programmer, selection, and Matricks. |
| 13 | `Group 9990` | Restores selection order AND Matricks. |
| 14 | `Blind On` | Prevent stage flashes during the store loop. |

### 3.10 Iteration Loop Order in _run

Each iteration in `_run` must follow this exact order:

| Step | Command | Reason |
|------|---------|--------|
| 1 | `Next` | Activate next Matricks group in the programmer. |
| 2 | `At Sequence 9990 Cue 1` | Recall the stash onto the current group. Forces a programmer change so MA3 stores correctly. |
| 3 | `Store Sequence [n] Cue [stepCounter] /Overwrite` | Store the current programmer state to the cue. Changed from `/Merge` in this version, running the plugin over an existing sequence is documented as erasing that sequence's data (section 3.18), and `/Overwrite` is what actually makes each stored cue a clean replacement rather than a blend with whatever was there before. |
| 4 | `Label Sequence [n] Cue [stepCounter] "---"` | Apply a placeholder label. |
| 5 | Increment `MS_stepCounter` | Advance the counter for the next iteration. |
| 6 | `CmdIndirect` back to `_run` (or to `_finish`) | Loop or terminate. |

### 3.11 Sequence Properties (applied in multiStabs_finish)

Confirmed working CLI commands. Property names sourced from the original MA3 macro:

```
Set Sequence [seqIndex] Property "Wraparound" "1"
Set Sequence [seqIndex] Property "Restartmode" "Next Cue"
Set Sequence [seqIndex] Cue "OffCue" "CueFade" "[offTime]"
Set Sequence [seqIndex] Property "Tracking" "0"
```

`[offTime]` is `shared.offTime`, entered by the user in `multiStabs_menu` (section 3.19). It replaces the fixed `0.5` value used through v0.6.

### 3.12 Stash Pool Numbers

Sequence 9990 and Group 9990 are used as temp stash objects. Both must be deleted in `multiStabs_finish`. 9990 is chosen as safely out of range for any realistic showfile.

### 3.13 CmdIndirect Plugin Syntax

To call a Component from another Component via CLI:

```lua
CmdIndirect("Plugin 'Multi Stabs'.componentName")
```

Note: the plugin name requires single quotes in the CLI string because it contains a space.

### 3.14 MessageBox, Confirmed Syntax

The `MessageBox()` function accepts a table with the following confirmed keys: `title`, `titleTextColor`, `backColor`, `icon`, `message` (supports `\n`), `messageTextColor`, `autoCloseOnInput`, `timeout`, `timeoutResultCancel`, `timeoutResultID`, `commands` (value/name), `inputs` (name/value/blackFilter/whiteFilter/vkPlugin/maxTextLength), `states` (checkboxes, functionality not confirmed), and `selectors` (name/selectedValue/type 0=swipe or 1=radio/values).

```lua
local returnTable = MessageBox({
    title = "Title",
    message = "Message text",
    icon = "tools",
    backColor = "Global.Default",
    commands = {
        { value = 1, name = "Run" },
        { value = 0, name = "Cancel" }
    },
    inputs = {
        { name = "Steps", value = "8", whiteFilter = "0123456789", vkPlugin = "NumericInput" }
    },
    selectors = {
        { name = "My Selector", selectedValue = 1, type = 0, values = { ["Option A"] = 1, ["Option B"] = 2 } }
    },
})
```

Return values:
- `returnTable.success`, boolean, false if the dialog was dismissed unexpectedly
- `returnTable.result`, numeric value of the command button pressed
- `returnTable.inputs["Field Name"]`, current value of the input field (string)
- `returnTable.selectors["Selector Name"]`, numeric value of the selected option

Confirmed via testing:
- `inputs` and `selectors` can both be present in the same `MessageBox()` call. This plugin's main menu uses both at once (Function selector, Button Function selector, Off Time input).
- Selector options display in ALPHABETICAL order by key name, not insertion order. Prefix with numbers to control display order where needed, for example `"1 Straight Stabs"`, `"2 Straight Shuffle Stabs"`, etc. An underscore after the digit is not required.
- `returnTable.selectors["Selector Name"]` returns the NUMERIC VALUE assigned to the selected option, not the string key name.
- `type = 0` is a swipe selector. Use this for menus with more than about 3 options, radio buttons (`type = 1`) overflow the fixed dialog size.
- There is no confirmed mechanism for `MessageBox()` to live-update its own text based on an in-progress selector change. This is why `multiStabs_help` exists as a separate, static reference screen rather than dynamically updating the main menu's description text per function (section 3.21).

### 3.15 Executor Discovery and Button Property Assignment

#### Finding the executor(s) a sequence is assigned to

Use `GetReferences()` on the sequence handle, filtering for class `'Exec'`:

```lua
local seqHandle = DataPool().Sequences[seqIndex]
for _, ref in ipairs(seqHandle:GetReferences()) do
    if ref:GetClass() == 'Exec' then
        local addr = ref:ToAddr()   -- confirmed format: "Page X.NNN"
        Printf(addr)
    end
end
```

A sequence can be assigned to multiple executors across multiple pages. `GetReferences()` returns all of them.

#### ToAddr() confirmed output format

```
"Page X.NNN"
```

There is NO `"Executor"` keyword in the string. Pattern match:

```lua
local pageNum, execNum = addr:match("Page (%d+)%.(%d+)")
```

`addr` can be used directly as the CLI target, no reconstruction needed.

#### Physical fader-stack columns and the "bottom button"

A sequence can be rubber-band assigned across an entire vertical fader stack at once (for example, executors 401, 301, 201, and 101 assigned together). Each of those executor numbers is a fully independent Exec object with its own single Key/KeyUnpress pair, an executor's knob, fader, and button are all just properties of that ONE exec, not separate objects. Confirmed via a console property dump (`GetExecutor(n)`, `ex:PropertyCount()`, `ex:PropertyName(i)`, `ex[name]`, 70 properties enumerated on a live executor): there is no second "bottom button" property on any single executor.

"The bottom button" means the lowest-numbered executor in a physical stack. This plugin computes a "column" for each Exec reference as `execNum % 100` (the last two digits, shared across pages), then within each column found on the CURRENT page only, sets button properties on the lowest-numbered executor. Scope is restricted to the current page so a sequence reused elsewhere on a different page is left untouched there.

If a sequence occupies more than one column on the current page, button settings are still applied to every column's bottom-most executor, but a modal warning is raised unless the columns are sequential (for example, columns 1 and 2, a deliberately widened sequence). Non-sequential columns most likely indicate an unintended or reused assignment. The exact wording of this warning is flagged as still needing a pass, see section 7.

Note on diagnostics: the property names and literal values documented below (`Key`, `KeyUnpress`, `KeyUnpressCommand`) were discovered using the property-dump technique above as a one-off console diagnostic, not as part of the shipped plugin. If a separate `GetPropertyNames`-style plugin exists in a showfile from this development process, it is unrelated scaffolding and can be safely removed, Multi Stabs has no dependency on it.

#### Setting button properties

| Property | Value | Meaning |
|----------|-------|---------|
| `Key` | `"Go+"` or `"Temp"` | What happens when the button is pressed. Both confirmed via console read-back as directly settable, literal string values. Selected by the user via `shared.buttonMode` (section 3.20). |
| `KeyUnpress` | `""` (cleared) | What happens when the button is released. |
| `KeyUnpressCommand` | (untouched) | Confirmed via console read-back to be empty/null under both Go+ and Temp configurations on a manually-configured executor. No explicit clearing needed. |

```lua
Cmd('Set ' .. addr .. ' Property "Key" "' .. keyValue .. '"')
Cmd('Set ' .. addr .. ' Property "KeyUnpress" ""')
```

An earlier version of this plugin set `KeyUnpress` to the literal string `"Off"` rather than clearing it. That is a real, executable function assignment, not an empty one, and does not match the natural, unconfigured state confirmed via console read-back on a manually set up Go+/Temp executor. This has been corrected to actually clear the property, confirmed working via console testing.

### 3.16 Release Behaviour, KeyUnpress and OffCue

Clearing `KeyUnpress` to empty on the executor button matches the natural, unconfigured state of a manually set up Go+/Temp executor. On release, the sequence's built-in `OffCue` determines fade timing. `multiStabs_finish` sets this fade to the user-entered `shared.offTime` (section 3.19, section 3.11).

The full press/release chain:
- Key down, `Go+` or `Temp` (per `shared.buttonMode`)
- Key up, `OffCue` fade (`shared.offTime` seconds out)

No cue parts, macros, or additional workarounds required.

### 3.17 shuffleMode, Consolidated Shuffle Architecture

All shuffle behaviour across all variants is controlled by a single `shared.shuffleMode` string, set in `multiStabs_menu` before dispatching to `_init`.

| Value | Meaning |
|-------|---------|
| `"none"` | No shuffle applied. |
| `"before"` | For Straight and Block variants, `Shuffle` runs before or during the Matricks commands, randomising which fixtures fall into each group. For Wing and Wing Block variants, `Shuffle` actually runs AFTER XWings/XBlock+XWings are applied and committed, "before" in that context means before the group gets stashed, not before every individual Matricks command. This is a known naming inconsistency between variant families, confirmed correct for each via separate console testing, worth knowing if reading `_init` code expecting one consistent meaning. Y and Z axes are nulled after Shuffle for wing-involving variants to prevent intra-pair scrambling. |
| `"after"` | `Shuffle` applied AFTER Matricks commands, randomising the group firing order. Used by Block variants only (function 4). |

**Rule:** `multiStabs_menu` always sets `shared.shuffleMode` before every `CmdIndirect` dispatch. Each `_init` component reads `shared.shuffleMode` and branches accordingly. No variant has its own separate shuffle component.

### 3.18 Pre-Flight Validation (Consolidated in multiStabs_menu)

All validation runs once, in `multiStabs_menu`, before the function-picker dialog even appears, so nothing is wasted picking a function if the console isn't in a runnable state. This replaced an earlier draft where the three newer checks were duplicated into each `_init` component.

| # | Check | Failure type | Behaviour |
|---|-------|--------------|-----------|
| 1 | Sequence selected? (`SelectedSequence()`) | Hard stop | Modal (single OK button) + `Printf`, then abort. |
| 2 | Fixtures selected? (`SelectionCount() == 0`) | Hard stop | Modal (single OK button) + `Printf`, then abort. |
| 3 | Sequence's executor on the current page? | Warning | Modal with Continue/Abort. Aborting stops the run; continuing proceeds, but executor button configuration will be skipped at the end since `multiStabs_finish` only scopes to the current page. |
| 4 | Real cue count (`#seqHandle:Children() - 2`) greater than 1? | Warning | Modal with Continue/Abort. Continuing deletes the sequence's existing numbered cues before proceeding (see below). |

CueZero and OffCue are always present on every MA3 sequence, they are the console's own bookkeeping, not something a programmer counts as real show data. Storing to an executor that has never been used adds one more blank real cue on top of those two specials, so a genuinely empty sequence has a real cue count of 0 or 1, not more. Check 4 reports and compares against this real count, not the raw one, and the warning text is explicit that continuing will erase and overwrite the sequence, not merge with it.

Continuing past check 4 also runs:

```lua
Cmd('Delete Sequence ' .. seqIndex .. ' Cue 1 Thru /NoConfirmation')
```

This clears cues 1 through the end of the sequence before the new stabs are stored. Without this, running a shorter step count over a sequence that previously held more steps (for example, replacing an 8-step run with a 4-step run) would leave the old sequence's higher-numbered cues (5 through 8) in place. `/NoConfirmation` is the confirmed exact option keyword (shorthand `/NC` or `/N`), not `/NoConfirm`. The range starts at 1, so CueZero is untouched, and OffCue is addressed by name elsewhere in the plugin, not by number, so it is untouched too.

### 3.19 Off Time (OffCue Fade) Configuration

The OffCue fade time is entered by the user as an `inputs` field in the same `MessageBox()` call as the Function and Button Function selectors in `multiStabs_menu`:

```lua
inputs = {
    { name = "Off Time", value = shared.lastOffTime or "0.5", whiteFilter = "0123456789.", vkPlugin = "NumericInput" }
}
```

`whiteFilter` restricts entry to digits and a decimal point. `tonumber()` on the result does the rest of the validation: it rejects anything malformed (multiple decimal points, a bare `.`, an empty string) by returning `nil`, which is treated as a hard-stop validation failure with its own error modal. No unit suffix or special-case time format is needed, the console always assumes seconds outside special cases this plugin doesn't touch. The value persists across runs via `shared.lastOffTime`, and is stored as `shared.offTime` for `multiStabs_finish` to consume (section 3.11).

### 3.20 Button Function Selection (Go+ vs Temp)

A "Button Function" selector in `multiStabs_menu` lets the user choose between `"Go+"` (advances to the next cue on press) and `"Temp"` (momentary/bump-style playback). The choice is stored as `shared.buttonMode` (`"go"` or `"temp"`) and consumed by `multiStabs_finish` when setting the `Key` property (section 3.15). The choice persists across runs via `shared.lastButtonChoice`.

### 3.21 Help Screen

`multiStabs_help` is a read-only reference screen listing every function with a plain-language description, reachable via a "Help" button in the main menu's `MessageBox()` alongside "Run" and "Cancel". Its only action is "Back", which `CmdIndirect`s back to `multiStabs_menu`. It exists specifically because `MessageBox()` has no confirmed mechanism to live-update descriptive text as the user changes the Function selector (section 3.14), so a separate static screen was the only reliable option found.

### 3.22 Known Limitation: Custom Images and Icons

`MessageBox()`'s `icon` field can only reference an existing static texture already present in the console's built-in `TextureCollect/Textures` library, by name or number. It cannot point at an arbitrary user-supplied image file, and there is no confirmed mechanism anywhere in the documented Lua plugin API for animated content of any kind, including gifs.

An unofficial alternative exists (`ScreenOverlay`-based custom dialogs, reverse-engineered by the community and not present in MA Lighting's own documented API index), which can reference static images from MA3's Images pool via elements like `AppearancePreview`, but this requires hand-building a UI tree from scratch (nested `Append()` calls, manual pixel dimensions, manual `Anchors` layout) and shipping a separate XML installer to embed the image data. This was evaluated and deliberately not pursued for this plugin, the added complexity and installer requirement were judged not worth it for a help screen. `multiStabs_help` remains text-only.

### 3.23 Usage Note: Fixture Selection Method Matters

Every Matricks command this plugin depends on (XBlock, XGroup, XWings, Shuffle) operates on the Selection Grid, which respects selection order, never patch order (section 2). But how that selection order is established depends on how fixtures were selected:

- Clicking fixtures individually adds them to the Selection Grid in strict linear order, whatever order they were clicked in.
- Rubber-band (marquee) selecting a group of fixtures instead derives their Selection Grid position from their spatial placement in the Layout View (X/Y/Z), since a marquee gesture has no click sequence to draw from.

This plugin is intended for use on fixtures selected in a genuinely linear fashion, such as a line of fixtures on a truss. If a cluster of fixtures is rubber-band selected out of a two-dimensional layout, which may introduce Y or Z positions into the grid, the resulting groupings, blocks, or wing pairings may not follow the order a user would expect from looking at the rig. This is documented in `multiStabs_help` as well as here.

### 3.24 Distribution: Exporting the Plugin as XML

For release, export the finished plugin to a single XML file rather than asking users to copy and paste eleven components by hand.

From the console: open the plugin in the Plugin Pool ("Edit UserPlugin" dialog for Multi Stabs) and tap Export. Equivalently, from the CLI: `Export Plugin "Multi Stabs"` (options like `/NoDependencies` and `/Gaps` exist but generally aren't needed here). This produces one `.xml` file containing the plugin and all of its components. Importing it back in on another station is the mirror image: create a new plugin, tap Import, point it at the XML file.

Before exporting for release, confirm that none of the components are set with `Installed = Yes` (which happens when editing components as external `.lua` files and reloading with something like `ReloadAllPlugins`, a common workflow for editing outside the console's own text box). If any component is in that state, the exported XML only stores a reference to the external file, not the actual code, and the plugin will be broken for anyone who imports it without that exact local file present. Set `Installed` to `No`, or make sure the final code is pasted directly into the console's built-in editor for each component, before exporting. Test the reimport on a second station before shipping, see section 7.

---

## 4. Architecture

| Property | Value |
|----------|-------|
| Plugin name | `Multi Stabs` |
| Function naming | camelCase (e.g. `straightStabs`, `blockShuffleStabs`) |
| Component naming | `functionName_init` / `functionName_run` for variants; `multiStabs_finish`, `multiStabs_menu`, and `multiStabs_help` shared/entry-point components |
| UserVars keys | `MS_stepCounter` only, all other state is Lua-scoped via the shared table |
| Comments | Aggressive, every non-obvious line explains what it does AND why |
| Stash pool numbers | Sequence 9990, Group 9990 (both deleted in `multiStabs_finish`) |
| Entry point | `multiStabs_menu`, MUST be the first component in the plugin |

### 4.1 Component Execution Flow

```
User calls plugin
    -> multiStabs_menu (auto-runs, first component)
        -> pre-flight validation (sequence, fixtures, executor page, real cue count)
        -> user selects function, button mode, off time
        -> hits "Help" -> multiStabs_help -> "Back" -> multiStabs_menu (loop)
        -> hits "Run"
            -> sets shared.shuffleMode, shared.buttonMode, shared.offTime, shared.seqIndex
            -> CmdIndirect -> [functionName]_init
                -> CmdIndirect -> [functionName]_run (loops via CmdIndirect)
                    -> CmdIndirect -> multiStabs_finish (universal, shared by all variants)
```

### 4.2 Standard Three-Component Structure

Every function variant uses `_init` and `_run` components specific to that variant, plus the shared `multiStabs_finish`. Validation that used to live in `_init` (sequence selected, fixtures selected, executor page, cue count) has moved to `multiStabs_menu` (section 3.18), each `_init` now simply reads `shared.seqIndex` directly.

| Component | Responsibility |
|-----------|----------------|
| `_init` | Read `shared.seqIndex` -> dialog (variant-specific inputs, e.g. Steps, Block Size, Wings) -> validate input -> write `shared.steps` -> write `MS_stepCounter` to UserVars -> `Store Sequence 9990` -> conditional shuffle/Matricks setup per `shared.shuffleMode` -> `Grid UseMatricksPositions` -> `Store Group 9990` -> `ClearAll` -> recall group -> `Blind On` -> `CmdIndirect` to `_run` |
| `_run` | Read `MS_stepCounter` from UserVars, read `shared.steps` + `shared.seqIndex` -> check counter vs steps -> `Next` -> `At Sequence 9990 Cue 1` -> `Store .../Overwrite` -> `Label` -> increment counter -> `CmdIndirect` to self or to `multiStabs_finish` |
| `multiStabs_finish` | `ClearAll` -> `Blind Off` -> set sequence properties (including user offTime) -> `ClearAll` -> `Delete Sequence 9990` -> `Delete Group 9990` -> set executor button properties, scoped by column and current page -> nil `MS_stepCounter` -> `Printf` complete |

### 4.3 UserVar Keys

Only one UserVar key is used across the entire plugin:

| Key | Type | Set in | Read in | Purpose |
|-----|------|--------|---------|---------|
| `MS_stepCounter` | integer | `_init` | `_run`, `multiStabs_finish` | Iteration counter. Must survive repeated `CmdIndirect` hops back into `_run`. |

All other state (`seqIndex`, `steps`, `shuffleMode`, `buttonMode`, `offTime`, and the remembered last-choice values) is Lua-scoped via `shared.*` and requires no UserVar.

### 4.4 Coding Conventions

Do not use em-dashes anywhere in Lua source, including comments and strings. They have no equivalent in the console's Lua text editor and are silently converted to spaces when typed or pasted, which can corrupt comments and, more importantly, corrupt any string literal that relies on exact wording. Use commas, colons, or parentheses instead.

---

## 5. Function List

| # | Status | Function Name | Division | Shuffle Behaviour |
|---|--------|---------------|----------|-------------------|
| 1 | DONE | `straightStabs` | XGroup N | None |
| 2 | DONE | `straightShuffleStabs` | XGroup N | `Shuffle` BEFORE XGroup |
| 3 | DONE | `blockStabs` | XBlock N + XGroup N | None |
| 4 | DONE | `blockShuffleStabs` | XBlock N + XGroup N | `Shuffle` AFTER XGroup |
| 5 | DONE | `shuffleBlockStabs` | XBlock N + XGroup N | `Shuffle` BEFORE XBlock |
| 6 | DONE | `wingStabs` | XWings N + XGroup N | None |
| 7 | DONE | `wingShuffleStabs` | XWings N + XGroup N | `Shuffle` AFTER XWings + XGroup, then Y/Z nulled |
| 8 | DONE | `wingBlockStabs` | XBlock N + XWings N + XGroup N | None |
| 9 | DONE | `wingShuffleBlockStabs` | XBlock N + XWings N + XGroup N | `Shuffle` AFTER XBlock + XWings, then Y/Z nulled, then XGroup |

All nine functions are complete and console-tested as of this version.

Note on function 5 (Shuffle Block Stabs): block size only determines the true concurrent-fixture count per cue when the number of blocks produced (fixture count divided by block size) is less than or equal to the step count. In the far more common case where there are more blocks than steps, XGroup necessarily combines multiple whole blocks into the same step. Because those blocks were built from already-shuffled, non-contiguous fixtures, once several of them share a step the result is visually indistinguishable from running Straight Shuffle Stabs with a larger effective group size, the persistent pairing constraint that makes a block a block (its members always fire together) becomes buried in the noise of everything else lighting at the same time. Ordinarily there isn't much reason to reach for this function over Straight Shuffle Stabs, unless the selection is small, the block size large, or the step count high enough that blocks stay one-per-step.

### 5.1 Input Parameters by Variant

Collected once in `multiStabs_menu` for every variant: Function, Button Function, Off Time (sections 3.19, 3.20). Collected per variant in each `_init` dialog:

| Function type | Dialog inputs |
|---------------|---------------|
| XGroup only (1, 2) | Steps |
| XBlock + XGroup (3, 4, 5) | Block Size + Steps |
| XWings + XGroup (6, 7) | Wings + Steps |
| XBlock + XWings + XGroup (8, 9) | Wings + Block Size + Steps |

---

## 6. Working Code

### 6.1 multiStabs_menu (Entry Point, MUST BE FIRST COMPONENT)

```lua
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
--   4. Does the sequence contain more real cues than an empty one would?
--      (warning, Continue/Abort. CueZero and OffCue are always present and
--      are not counted as real cues, see below. Continuing clears the
--      sequence's existing numbered cues before proceeding)
--
-- Because all of this only depends on the currently selected sequence and
-- fixtures, not on which stabs variant gets picked, it belongs here once,
-- not duplicated across straightStabs_init / blockStabs_init / wingStabs_init /
-- wingBlockStabs_init. Each _init now reads shared.seqIndex directly.
--
-- shuffleMode values:
--   "none"   no shuffle
--   "before" Shuffle applied before or during Matricks (randomises
--            fixture-to-group assignment). For wing variants this actually
--            runs AFTER XWings/XBlock+XWings are applied and the group is
--            committed, "before" here means before the group gets stashed,
--            not before every individual Matricks command. This naming is a
--            known inconsistency between the block and wing variant families,
--            confirmed correct via console testing for each, but worth
--            knowing if you're reading the _init code expecting one
--            consistent meaning.
--   "after"  Shuffle applied AFTER Matricks is applied (randomises group
--            firing order). Block variants only.
--
-- buttonMode values:
--   "go"   executor Key = "Go+" (advances to next cue on press)
--   "temp" executor Key = "Temp" (momentary/bump-style playback)
--
-- offTime: OffCue fade time in seconds, entered by the user here instead of a
-- fixed value. whiteFilter restricts input to digits and a single decimal
-- point, and tonumber() on the result does the rest of the validation for
-- free: it rejects anything malformed (multiple decimal points, a bare ".",
-- an empty string) by returning nil, which is treated as a hard-stop
-- validation failure. No unit suffix or special-case time format is needed,
-- the console always assumes seconds outside special cases this plugin
-- doesn't touch.
--
-- Selector display note: MA3 selectors display in ALPHABETICAL order by key
-- name, not insertion order (confirmed). The Function selector keeps a bare
-- leading digit (no underscore) to hold the 1-9 grouping in order, single
-- digits sort correctly both alphabetically and numerically. Button Function
-- has no prefix, "Go+"/"Temp" already sort alphabetically as desired.
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
--   8  Wing Block Stabs         XBlock + XWings + XGroup, no shuffle
--   9  Wing Shuffle Block Stabs XBlock + XWings + XGroup, shuffle before

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

        -- 4. Warning: sequence contains more real (non-special) cues than an
        -- "empty" sequence would have. CueZero and OffCue are always present
        -- on every MA3 sequence, they're the console's own bookkeeping, not
        -- something a programmer counts as real show data, so they're
        -- subtracted out before anything is shown to the user. Storing to
        -- an executor that's never been used adds one more blank real cue on
        -- top of the two specials, so a genuinely empty sequence has 0 or 1
        -- real cues, not more.
        local cueCount = #seqHandle:Children()
        local realCueCount = cueCount - 2
        if realCueCount > 1 then
            local warnResult = MessageBox({
                title = "Multi Stabs: Warning",
                message = "Sequence " .. seqIndex .. " already contains " .. realCueCount
                    .. " cues (more than the 0-1 expected for an empty sequence).\n"
                    .. "Running this plugin will erase and overwrite the selected sequence.\n\nContinue anyway?",
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

            -- User chose to continue despite existing cues. Clear cues 1
            -- through the end now, otherwise a shorter run (e.g. 4 steps
            -- replacing a previous 8-step run) would leave the old sequence's
            -- higher-numbered cues (5-8) behind. CueZero and OffCue are
            -- untouched since the range starts at 1 and OffCue is addressed
            -- by name, not by number.
            Cmd('Delete Sequence ' .. seqIndex .. ' Cue 1 Thru /NoConfirmation')
            Printf("Multi Stabs: cleared existing cues 1 thru end on Sequence " .. seqIndex .. ".")
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
```

### 6.2 straightStabs_init

```lua
-- straightStabs_init
-- Entry point for Straight Stabs and Straight Shuffle Stabs.
-- Dispatched from multiStabs_menu for selections 1 and 2.
-- Reads shared.shuffleMode to determine whether to apply Shuffle before XGroup.
-- Reads shared.seqIndex, already validated in multiStabs_menu before dispatch
-- (sequence selected, fixtures selected, executor page, cue count), no need
-- to re-check any of that here.
--
-- Straight Stabs only ever shuffles before XGroup (to randomise fixture-to-group
-- assignment), so only the "before" case is needed here. "after" is not applicable
-- to a single-Matricks variant and will never be set by the menu for this component.
--
-- Note: unlike block variants, Shuffle before a single XGroup command works correctly
-- without an intermediate Grid UseMatricksPositions call. XGroup operates on whatever
-- selection order is currently active, which is the shuffled order.

local shared = select(3, ...)

local function main()
    local seqIndex = shared.seqIndex

    -- Present the user input dialog.
    local resultTable = MessageBox({
        title = "Straight Stabs",
        message = "Ensure your selection and programmer levels are set before running.\nStoring to Sequence " .. seqIndex .. ".",
        inputs = {
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
        Printf("Straight Stabs: cancelled.")
        return
    end

    local steps = tonumber(resultTable.inputs["Steps"])
    if not steps or steps < 1 then
        Printf("Straight Stabs: invalid step count.")
        return
    end

    -- seqIndex is already set by multiStabs_menu, only steps needs storing.
    shared.steps = steps

    SetVar(UserVars(), "MS_stepCounter", 1)

    Printf("Straight Stabs: shuffleMode=" .. tostring(shared.shuffleMode) .. ", Steps=" .. steps .. ", Sequence=" .. seqIndex)

    Cmd("Store Sequence 9990 /Overwrite")

    if shared.shuffleMode == "before" then
        Cmd("Shuffle")
    end

    Cmd("Set Selection MAtricks XGroup " .. steps)
    Cmd("Grid UseMatricksPositions")
    Cmd("Store Group 9990 /Overwrite")
    Cmd("ClearAll")
    Cmd("Group 9990")
    Cmd("Blind On")

    CmdIndirect("Plugin 'Multi Stabs'.straightStabs_run")
end

return main
```

### 6.3 straightStabs_run

```lua
-- straightStabs_run
-- Iteration component for Straight Stabs and Straight Shuffle Stabs.
-- Called repeatedly via CmdIndirect until stepCounter exceeds steps,
-- at which point it hands off to multiStabs_finish.
--
-- Reads seqIndex and steps from the shared state table (Lua-scoped).
-- Reads/writes stepCounter via UserVars (must survive CmdIndirect hops).
--
-- Store uses /Overwrite, not /Merge. Running this plugin over an existing
-- sequence is documented (multiStabs_menu, section 3.18) as erasing that
-- sequence's data, and /Overwrite is what makes each stored cue a clean
-- replacement instead of a blend with whatever was there before.

local shared = select(3, ...)

local function main()
    local stepCounter = GetVar(UserVars(), "MS_stepCounter")
    local steps       = shared.steps
    local seqIndex    = shared.seqIndex

    if not stepCounter or not steps or not seqIndex then
        Printf("Straight Stabs: missing state, aborting. stepCounter=" .. tostring(stepCounter) .. " steps=" .. tostring(steps) .. " seqIndex=" .. tostring(seqIndex))
        return
    end

    if stepCounter > steps then
        CmdIndirect("Plugin 'Multi Stabs'.multiStabs_finish")
        return
    end

    Printf("Straight Stabs: storing cue " .. stepCounter .. " of " .. steps)

    Cmd("Next")
    Cmd("At Sequence 9990 Cue 1")
    Cmd("Store Sequence " .. seqIndex .. " Cue " .. stepCounter .. " /Overwrite")
    Cmd('Label Sequence ' .. seqIndex .. ' Cue ' .. stepCounter .. ' "---"')

    SetVar(UserVars(), "MS_stepCounter", stepCounter + 1)

    CmdIndirect("Plugin 'Multi Stabs'.straightStabs_run")
end

return main
```

### 6.4 blockStabs_init

```lua
-- blockStabs_init
-- Entry point for Block Stabs, Block Shuffle Stabs, and Shuffle Block Stabs.
-- Dispatched from multiStabs_menu for selections 3, 4, and 5.
-- Reads shared.shuffleMode to determine when (if at all) to apply Shuffle.
-- Reads shared.seqIndex, already validated in multiStabs_menu before dispatch
-- (sequence selected, fixtures selected, executor page, cue count), no need
-- to re-check any of that here.
--
-- shuffleMode behaviour for block variants:
--   "none"   XBlock then XGroup, no shuffle.
--   "before" Shuffle + Grid UseMatricksPositions to commit shuffled order,
--            THEN XBlock + XGroup. The UseMatricksPositions call is required
--            here because XBlock would otherwise anchor to the prior selection
--            order, ignoring the shuffle.
--   "after"  XBlock then XGroup, then Shuffle to randomise group firing order.
--
-- blockSize is local to _init only, once baked into the stashed group it is not needed.

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
```

### 6.5 blockStabs_run

```lua
-- blockStabs_run
-- Iteration component for Block Stabs (all three shuffle variants).
-- The Matricks setup and any shuffle was handled entirely in blockStabs_init
-- and is baked into the stashed group, the run loop is identical for all variants.
--
-- Called repeatedly via CmdIndirect until stepCounter exceeds steps,
-- at which point it hands off to multiStabs_finish.
--
-- Store uses /Overwrite, not /Merge, see the note in straightStabs_run.

local shared = select(3, ...)

local function main()
    local stepCounter = GetVar(UserVars(), "MS_stepCounter")
    local steps       = shared.steps
    local seqIndex    = shared.seqIndex

    if not stepCounter or not steps or not seqIndex then
        Printf("Block Stabs: missing state, aborting. stepCounter=" .. tostring(stepCounter) .. " steps=" .. tostring(steps) .. " seqIndex=" .. tostring(seqIndex))
        return
    end

    if stepCounter > steps then
        CmdIndirect("Plugin 'Multi Stabs'.multiStabs_finish")
        return
    end

    Printf("Block Stabs: storing cue " .. stepCounter .. " of " .. steps)

    Cmd("Next")
    Cmd("At Sequence 9990 Cue 1")
    Cmd("Store Sequence " .. seqIndex .. " Cue " .. stepCounter .. " /Overwrite")
    Cmd('Label Sequence ' .. seqIndex .. ' Cue ' .. stepCounter .. ' "---"')

    SetVar(UserVars(), "MS_stepCounter", stepCounter + 1)

    CmdIndirect("Plugin 'Multi Stabs'.blockStabs_run")
end

return main
```

### 6.6 wingStabs_init

```lua
-- wingStabs_init
-- Entry point for Wing Stabs and Wing Shuffle Stabs.
-- Dispatched from multiStabs_menu for selections 6 and 7.
-- Reads shared.shuffleMode to determine whether to apply Shuffle.
-- Reads shared.seqIndex, already validated in multiStabs_menu before dispatch
-- (sequence selected, fixtures selected, executor page, cue count), no need
-- to re-check any of that here.
--
-- shuffleMode behaviour for wing variants:
--   "none"   XWings then XGroup, no shuffle.
--   "before" XWings then XGroup, then Shuffle to randomise the order of wing
--            pairs. Y and Z shuffle axes are nulled immediately after Shuffle
--            because Shuffle applies to all axes simultaneously and would
--            otherwise scramble fixtures within each wing pair. Grid
--            UseMatricksPositions then commits the corrected state before
--            stashing.
--
-- Note: Store Sequence 9990 is performed immediately, it captures only the
-- target programmer levels and has no dependency on selection order or Matricks.
--
-- Note: XWings and XGroup command order is interchangeable for this variant,
-- final stage output is identical regardless of order.
--
-- wings is local to _init only, once baked into the stashed group it is not needed.

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
```

### 6.7 wingStabs_run

```lua
-- wingStabs_run
-- Iteration component for Wing Stabs and Wing Shuffle Stabs.
-- Called repeatedly via CmdIndirect until stepCounter exceeds steps,
-- at which point it hands off to multiStabs_finish.
--
-- The Matricks setup and any shuffle was handled entirely in wingStabs_init
-- and is baked into the stashed group, the run loop is identical for all variants.
--
-- Store uses /Overwrite, not /Merge, see the note in straightStabs_run.

local shared = select(3, ...)

local function main()
    local stepCounter = GetVar(UserVars(), "MS_stepCounter")
    local steps       = shared.steps
    local seqIndex    = shared.seqIndex

    if not stepCounter or not steps or not seqIndex then
        Printf("Wing Stabs: missing state, aborting. stepCounter=" .. tostring(stepCounter) .. " steps=" .. tostring(steps) .. " seqIndex=" .. tostring(seqIndex))
        return
    end

    if stepCounter > steps then
        CmdIndirect("Plugin 'Multi Stabs'.multiStabs_finish")
        return
    end

    Printf("Wing Stabs: storing cue " .. stepCounter .. " of " .. steps)

    Cmd("Next")
    Cmd("At Sequence 9990 Cue 1")
    Cmd("Store Sequence " .. seqIndex .. " Cue " .. stepCounter .. " /Overwrite")
    Cmd('Label Sequence ' .. seqIndex .. ' Cue ' .. stepCounter .. ' "---"')

    SetVar(UserVars(), "MS_stepCounter", stepCounter + 1)

    CmdIndirect("Plugin 'Multi Stabs'.wingStabs_run")
end

return main
```

### 6.8 wingBlockStabs_init

```lua
-- wingBlockStabs_init
-- Entry point for Wing Block Stabs and Wing Shuffle Block Stabs.
-- Dispatched from multiStabs_menu for selections 8 and 9.
-- Reads shared.seqIndex, already validated in multiStabs_menu before dispatch
-- (sequence selected, fixtures selected, executor page, cue count), no need
-- to re-check any of that here.
--
-- shuffleMode behaviour for this variant (confirmed via console testing):
--   "none"   XBlock, XWings, XGroup, single Grid UseMatricksPositions commit.
--            No intermediate commit needed between XBlock and XWings without
--            shuffle involved.
--   "before" XBlock, XWings, THEN a commit BEFORE Shuffle (confirmed required
--            specifically for this combined variant). After Shuffle, YShuffle/
--            ZShuffle are nulled, a second commit follows, and only then is
--            XGroup applied. XGroup does NOT need its own trailing commit
--            before the Group stash, the second commit carries through.
--   There is no "after" mode for this variant, mirrors plain Wing Stabs.
--
-- Note on why this uses the Group 9990 stash/recall and NOT SelFix from a stored
-- Sequence: confirmed that SelFix Sequence [n] brings fixtures into the
-- Programmer in patch order, not their original selection order. Patch order IS
-- a real, confirmed phenomenon, it's specifically a SelFix-into-Programmer
-- behaviour, unrelated to how the Selection Grid handles fixture order (the
-- Selection Grid and every Matricks command operate on selection order only).
-- Group 9990 remains the only confirmed way to preserve original fixture
-- selection order (and Matricks state) through a ClearAll.
--
-- wings and blockSize are local to _init only, once baked into the stashed
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
```

### 6.9 wingBlockStabs_run

```lua
-- wingBlockStabs_run
-- Iteration component for Wing Block Stabs and Wing Shuffle Block Stabs.
-- Called repeatedly via CmdIndirect until stepCounter exceeds steps,
-- at which point it hands off to multiStabs_finish.
--
-- The Matricks setup and any shuffle was handled entirely in wingBlockStabs_init
-- and is baked into the stashed group, the run loop is identical for all variants,
-- matching the pattern used by every other _run component in this plugin.
--
-- Store uses /Overwrite, not /Merge, see the note in straightStabs_run.

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

    Cmd("Next")
    Cmd("At Sequence 9990 Cue 1")
    Cmd("Store Sequence " .. seqIndex .. " Cue " .. stepCounter .. " /Overwrite")
    Cmd('Label Sequence ' .. seqIndex .. ' Cue ' .. stepCounter .. ' "---"')

    SetVar(UserVars(), "MS_stepCounter", stepCounter + 1)

    CmdIndirect("Plugin 'Multi Stabs'.wingBlockStabs_run")
end

return main
```

### 6.10 multiStabs_finish (Universal, shared by all variants)

```lua
-- multiStabs_finish
-- Universal finalisation component for all stabs variants.
-- Called by any variant's _run component when the iteration loop is complete.
-- Reads seqIndex, buttonMode, and offTime from the shared state table
-- (Lua-scoped, no UserVars needed).
--
-- Responsibilities:
--   1. ClearAll + Blind Off
--   2. Set sequence properties, including the user-configured OffCue fade time
--   3. ClearAll (final)
--   4. Delete stash objects
--   5. Set executor button properties (Key = buttonMode, KeyUnpress cleared)
--   6. Clean up UserVars (stepCounter only)
--   7. Print completion message
--
-- Note on executor button configuration:
-- A sequence can be assigned across an entire physical fader stack at once (a
-- vertical rubber-band drag spanning e.g. 401/301/201/101), and each of those
-- executor numbers is a fully independent Exec object with its own single
-- Key/KeyUnpress pair, an executor's knob, fader, and button are all just
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
-- gets Key/KeyUnpress set, this always happens regardless of how many columns
-- are found. If more than one column is found, a modal alert is raised UNLESS
-- the columns are sequential (e.g. columns 1 and 2, a deliberately widened
-- sequence). Non-sequential columns most likely indicate an unintended/reused
-- assignment, which is treated as an error condition worth surfacing
-- immediately rather than a silent log line. Wording on this specific modal
-- is still flagged for revision, see the spec's Open Questions section.
--
-- Button function: shared.buttonMode (set in multiStabs_menu) selects between
-- "Go+" (advances to next cue on press) and "Temp" (momentary/bump-style
-- playback). Both confirmed via console property read-back as directly
-- settable literal strings for the Key property. KeyUnpress is explicitly
-- CLEARED (set to an empty string), not assigned the value "Off". An earlier
-- version of this component set KeyUnpress to the literal string "Off", which
-- is a real, executable function assignment, not an empty one. That does not
-- match the natural, unconfigured state confirmed via console read-back on a
-- manually set up Go+/Temp executor, so it has been corrected to actually
-- clear the property instead. Confirmed working via console testing.

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
    -- Property names sourced from original MA3 macro. CueFade uses the
    -- user-entered Off Time from multiStabs_menu instead of a fixed value.
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

        -- Apply Key=<keyValue>, clear KeyUnpress on the bottom-most executor of
        -- EVERY column found, this happens regardless of how many columns
        -- there are. KeyUnpressCommand is confirmed empty/null under both
        -- button modes, so it is left untouched.
        for _, addr in ipairs(bottomAddrs) do
            Cmd('Set ' .. addr .. ' Property "Key" "' .. keyValue .. '"')
            Cmd('Set ' .. addr .. ' Property "KeyUnpress" ""')
            Printf("Multi Stabs: set Key=" .. keyValue .. ", cleared KeyUnpress on " .. addr)
        end

        -- If more than one column was found, only alert if they are NOT
        -- sequential. Sequential columns (e.g. 1 and 2) indicate a deliberately
        -- widened sequence, expected, if rare. A gap (e.g. columns 1 and 5)
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
                        .. "is unexpected for this plugin, please verify the assignment.",
                    icon = "tools",
                    commands = { { value = 1, name = "OK" } }
                })
            end
        end
    else
        Printf("Multi Stabs: could not get sequence handle for executor button config.")
    end

    -- Clean up UserVars. Only stepCounter lives in UserVars, everything else
    -- was Lua-scoped via the shared state table and needs no cleanup.
    SetVar(UserVars(), "MS_stepCounter", nil)

    Printf("Multi Stabs: complete.")
end

return main
```

### 6.11 multiStabs_help

```lua
-- multiStabs_help
-- Read-only reference screen listing every Multi Stabs function. Dispatched
-- from multiStabs_menu when the user presses "Help" instead of "Run". The
-- only action is "Back", which returns to multiStabs_menu. This screen does
-- not launch anything itself.

local shared = select(3, ...)

local function main()
    MessageBox({
        title = "Multi Stabs: Function Reference",
        message =
            "This plugin is based on an MA2 macro created by EarlyBird Visual. It simplifies and speeds up the creation of several different lighting stabs, and sets the function of the buttons for the executors. The plugin expects the following workflow: the user selects lights, adjusts some attributes (dimmer, color, for instance) and then enters the configuration options for the executor. Each cue that is created will have a 0-second fadetime, followed by a user-inputtable offtime. The plugin expects the user to have created an empty executor and to have selected it. Once called, you can choose from a variety of stab styles, which are listed below. This plugin does NOT linearize fixtures before creating the stabs, and so it will respect your selection order, including oddities introduced by the Selection Grid.\n\n" ..
            "That Selection Grid quirk is rather important: Rubber-band (marquee) selecting a group of fixtures derives their Selection Grid position from their spatial placement in the Layout View. This plugin is intended for use on fixtures selected in a genuinely linear fashion, like a line of fixtures on a truss. If you rubber-band select a cluster of fixtures out of a two-dimensional layout which might introduce Y or Z positions in the grid, the resulting groupings, blocks, or wing pairings may not follow the order you'd expect.\n\n" ..
            "1  Straight Stabs\n" ..
            "Stabs in order of selection, in however many steps specified.\n\n" ..
            "2  Straight Shuffle Stabs\n" ..
            "Stabs in however many steps specified, but shuffled first.\n\n" ..
            "3  Block Stabs\n" ..
            "Fixtures are chunked into contiguous blocks of the chosen size, in selection order, then distributed across the chosen number of steps.\n\n" ..
            "4  Block Shuffle Stabs\n" ..
            "Stabs with blocks of contiguous n fixtures, but the blocks themselves are shuffled.\n\n" ..
            "5  Shuffle Block Stabs\n" ..
            "Stabs with blocks of non-contiguous n fixtures. Differs from straight shuffle stabs in that you can select your block size. Ordinarily, there's not much of a reason to choose this one over Straight Shuffle Stabs, unless you have a small selection, a large block size, or lots of steps.\n\n" ..
            "6  Wing Stabs\n" ..
            "Stabs in order of selection, in however many steps, with n wings.\n\n" ..
            "7  Wing Shuffle Stabs\n" ..
            "Stabs in order of selection, in however many steps, with wings applied, then shuffled.\n\n" ..
            "8  Wing Block Stabs\n" ..
            "Stabs in order of selection of block n fixtures, with wings applied.\n\n" ..
            "9  Wing Shuffle Block Stabs\n" ..
            "Stabs in order of selection of block n fixtures and n wings, then (contiguous) blocks are shuffled. Blocks fire randomly across n wings.",
        icon = "tools",
        commands = {
            { value = 1, name = "Back" }
        },
    })

    -- Regardless of how the dialog closed, return to the main menu.
    CmdIndirect("Plugin 'Multi Stabs'.multiStabs_menu")
end

return main
```

---

## 7. Open Questions / TBD

- The exact wording of the non-sequential-columns warning modal in `multiStabs_finish` still needs a revision pass, flagged as "for later" and not yet done.
- Whether `MessageBox()` message text auto-wraps on long unbroken strings, or needs manual `\n` breaks, has not been formally tested. `multiStabs_help`'s long overview paragraphs currently rely on natural wrapping.
- `CurrentExecPage().index` is community-confirmed rather than confirmed against MA Lighting's own documentation. It has been exercised repeatedly through this session's testing without apparent issue, but has not been the subject of its own dedicated confirmation test.
- Before public release, confirm that the exported plugin XML (section 3.24) actually reimports cleanly on a second station with no local `.lua` files present, to catch the `Installed = Yes` gotcha before a user hits it.
- Whether the shared table (`select(3,...)`) persists across plugin calls in a new show session, or only within a single continuous run, remains unconfirmed (carried over from v0.6).

Resolved since v0.6, removed from this list: the Wing Block Stabs command order and input parameters (confirmed XBlock then XWings then XGroup, Wings + Block Size + Steps inputs, section 3.9 and 5.1); whether Y/Z shuffle nulling is required for the combined variant (confirmed yes, same pattern as plain Wing Stabs); whether `Set ... Property "KeyUnpress" ""` actually clears the property (confirmed working via console testing).

The individual `_init` dialogs still have their own Cancel buttons. Now that `multiStabs_menu` handles top-level cancellation and validation, the Cancel button in each `_init` dialog allows backing out after selecting a function but before committing, this is desirable and should be retained.

---

## 8. References

- GrandMA3 API Documentation (community): https://github.com/MacTirney/GrandMA3-API-Documentation
- MessageBox() example: https://github.com/MacTirney/GrandMA3-API-Documentation/blob/main/modules/Object%20Free%20API%20Functions/Functions/General%20Functions/M/MessageBox()/messageBoxFuncExample.lua
- MA Lighting official Lua docs: https://help2.malighting.com/Page/grandMA3/what_is_lua/en/1.9
- MessageBox() official reference: https://help.malighting.com/grandMA3/2.3/HTML/lua_objectfree_messagebox.html
- Delete keyword: https://help.malighting.com/grandMA3/2.2/HTML/keyword_delete.html
- /NoConfirmation option keyword: https://help.malighting.com/grandMA3/2.0/HTML/ok_noconfirmation.html
- Thru keyword: https://help.malighting.com/grandMA3/2.2/HTML/keyword_thru.html
- Plugins (export/import): https://help.malighting.com/grandMA3/2.0/HTML/plugins.html
- Import/Export overview: https://help.malighting.com/grandMA3/2.0/HTML/import-export.html
- Export keyword: https://help.malighting.com/grandMA3/2.4/HTML/keyword_export.html
- Original `Shuffle_Stabs` MA3 Macro XML, provided by user, used as reference for CLI command syntax and logic flow, originally created by EarlyBird Visual
- Song Setup plugin (MA2, Jason Giaffo), reference for shared state pattern
- FindProperty plugin (Yury Belousov), reference for MessageBox and object tree traversal