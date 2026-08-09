# grandMA3 Multi Stabs
## A grandMA3 programming aid
## Function reference

**Multi Stabs** is based on an MA2 macro created by (as far as I know) **EarlyBird Visual**. This version duplicates that macro's functionality, in part, but in Lua. The Lua rewrite was done because several functions that the macro relied upon are no longer available in the MA3 macro syntax (such as conditionals.) It simplifies and speeds up the creation of several different lighting stab patterns, while also setting the function of the buttons on the executors.

## How It Works

The expected workflow is:

1. Select the fixtures you want to use.
2. Adjust any desired attributes, such as dimmer or color.
3. Select an executor with an empty seqeunce, or an executor with a sequence you wish to overwrite.
4. Call the plugin and choose the desired stab style.
5. Configure the options for the selected stab style.

Each cue created by the plugin uses a **0-second fade time**, followed by a user-defined **off time**.

> **Note:** Multi Stabs does **not** linearize fixtures before creating the stabs. It respects the existing selection order, including any ordering quirks introduced by the Selection Grid.

## Important: Selection Grid Behavior

Selection order is particularly important when using Multi Stabs.

When fixtures are selected using a rubber-band (marquee) selection off a layout view, their Selection Grid positions are derived from their spatial placement from that layout view.

Multi Stabs is intended primarily for fixtures selected in a genuinely linear fashion; for example, a line of fixtures across a truss.

If you rubber-band select a cluster of fixtures from a two-dimensional layout, the resulting Selection Grid may introduce Y or Z positions on the grid. This will affect the behavior of `Next` for:

- Grouping
- Blocks
- Wings
- Shuffle patterns

As a result, the generated stabs will probably not follow the order you expect or want. Check your Selection Grid, or build groups for use with this plugin.

---

## Stab Styles

### 1. Straight Stabs

Stabs fire in the order the fixtures were selected, distributed across the specified number of steps.

### 2. Straight Shuffle Stabs

Like **Straight Stabs**, but the fixture order is shuffled before the stabs are created.

### 3. Block Stabs

Fixtures are divided into contiguous blocks of the chosen size, following the original selection order. The blocks are then distributed across the specified number of steps.

### 4. Block Shuffle Stabs

Fixtures are divided into contiguous blocks of the chosen size, but the **blocks themselves are shuffled** before being distributed.

### 5. Shuffle Block Stabs

Fixtures are divided into blocks of the chosen size, but the fixtures within those blocks are **non-contiguous**.

This differs from **Straight Shuffle Stabs** because you can explicitly choose the block size. In most situations, Straight Shuffle Stabs is the simpler choice, unless you have:

- A small fixture selection
- A large block size
- A large number of steps

### 6. Wing Stabs

Fixtures fire in selection order across the specified number of steps, with the chosen number of wings applied.

### 7. Wing Shuffle Stabs

Fixtures are arranged in selection order across the specified number of steps, with wings applied. The resulting arrangement is then shuffled.

### 8. Wing Block Stabs

Fixtures are divided into blocks of the chosen size, distributed across the specified number of steps, with the chosen number of wings applied.

### 9. Wing Shuffle Block Stabs

Fixtures are divided into blocks of the chosen size and arranged with the chosen number of wings. The contiguous blocks are then shuffled, causing the blocks to fire randomly across the specified number of wings.

## How to install

Copy the `multi stabs.xml` file to `gma3_library\datapools\plugins` (On either the USB drive you're using, or if you're using OnPC, it's (probably) in `C:\ProgramData\MALightingTechnology\`. Then in grandMA, use Setup menu -> Show Creator -> Import -> Plugins.
