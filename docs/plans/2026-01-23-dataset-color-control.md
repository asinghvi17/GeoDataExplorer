# Dataset Color Control Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an optional `dataset` parameter to `configure()` that enables a "Color:" textbox for Poly/Lines/Scatter plots, accepting either numeric column names or color strings.

**Architecture:** Extend `configure(plot; dataset=nothing)` with a new `build_color_control!` helper. When dataset is provided and plot is a vector type (Poly/Lines/Scatter), show a textbox that parses input as either a column name (if numeric) or a color string. Invalid input shows a red border.

**Tech Stack:** Makie.jl (Textbox, GridLayout), Tables.jl (column access), Colors.jl (color parsing)

---

### Task 1: Add Tables import to ConfigurePlot module

**Files:**
- Modify: `src/configure_plot.jl:1-12`

**Step 1: Add the Tables import**

In `src/configure_plot.jl`, update the imports at the top of the module. After line 8 (`using Colors: parse`), add:

```julia
import Tables
```

**Step 2: Verify module loads**

Run in Julia REPL:
```julia
using Pkg; Pkg.activate(".")
using GeoDataExplorer
```

Expected: No errors, module loads successfully.

**Step 3: Commit**

```bash
git add src/configure_plot.jl
git commit -m "feat(configure): add Tables import for dataset support"
```

---

### Task 2: Implement get_numeric_columns helper

**Files:**
- Modify: `src/configure_plot.jl`

**Step 1: Add the helper function**

Add after the `has_colormap` function (after line 50), before `build_stroke_controls!`:

```julia
"""
    get_numeric_columns(dataset)

Return a vector of column names (as Symbols) that have Real-typed elements.
"""
function get_numeric_columns(dataset)
    names = Tables.columnnames(dataset)
    return filter(names) do name
        col = Tables.getcolumn(dataset, name)
        eltype(col) <: Real
    end
end
```

**Step 2: Verify module loads**

Run in Julia REPL:
```julia
using Pkg; Pkg.activate(".")
using GeoDataExplorer
```

Expected: No errors.

**Step 3: Commit**

```bash
git add src/configure_plot.jl
git commit -m "feat(configure): add get_numeric_columns helper"
```

---

### Task 3: Implement try_parse_color_input helper

**Files:**
- Modify: `src/configure_plot.jl`

**Step 1: Add the helper function**

Add after `get_numeric_columns` function:

```julia
"""
    try_parse_color_input(input::String, dataset)

Parse color input string. Returns:
- `(:column, data)` if input is a numeric column name
- `(:color, filled_vector)` if input parses as a color
- `(:invalid, nothing)` if neither
"""
function try_parse_color_input(input::String, dataset)
    sym = Symbol(input)

    # First, check if it's a numeric column name
    if Tables.hascolumn(dataset, sym)
        col = Tables.getcolumn(dataset, sym)
        if eltype(col) <: Real
            return (:column, col)
        end
    end

    # Otherwise, try to parse as color
    try
        parsed = parse(RGBAf, input)
        n = length(first(Tables.columns(dataset)))
        return (:color, fill(parsed, n))
    catch
        return (:invalid, nothing)
    end
end
```

**Step 2: Verify module loads**

Run in Julia REPL:
```julia
using Pkg; Pkg.activate(".")
using GeoDataExplorer
```

Expected: No errors.

**Step 3: Commit**

```bash
git add src/configure_plot.jl
git commit -m "feat(configure): add try_parse_color_input helper"
```

---

### Task 4: Implement build_color_control! helper

**Files:**
- Modify: `src/configure_plot.jl`

**Step 1: Add RGBf to Makie imports**

Update line 6-7 to include `RGBf`:

```julia
using Makie: Figure, Colorbar, Menu, Textbox, Label, GridLayout, on, Observable, RGBAf, RGBf,
             AbstractPlot, Poly, Lines, Scatter, extract_colormap
```

**Step 2: Add the build_color_control! function**

Add after `try_parse_color_input` function:

```julia
"""
    build_color_control!(grid, plot, dataset)

Build a color textbox that accepts column names or color strings.
Shows red border on invalid input.
"""
function build_color_control!(grid, plot, dataset)
    layout = GridLayout(grid)

    Label(layout[1, 1], "Color:", halign = :right)
    tb_color = Textbox(layout[1, 2], stored_string = "", width = 120)

    on(tb_color.stored_string) do s
        isempty(s) && return

        result = try_parse_color_input(s, dataset)

        if result[1] == :column
            plot.color = result[2]
            tb_color.bordercolor = RGBf(0.8, 0.8, 0.8)
        elseif result[1] == :color
            plot.color = result[2]
            tb_color.bordercolor = RGBf(0.8, 0.8, 0.8)
        else  # :invalid
            tb_color.bordercolor = RGBf(0.9, 0.2, 0.2)
        end
    end

    return layout
end
```

**Step 3: Verify module loads**

Run in Julia REPL:
```julia
using Pkg; Pkg.activate(".")
using GeoDataExplorer
```

Expected: No errors.

**Step 4: Commit**

```bash
git add src/configure_plot.jl
git commit -m "feat(configure): add build_color_control! helper"
```

---

### Task 5: Refactor build_colormap_controls! to accept row offset

**Files:**
- Modify: `src/configure_plot.jl`

**Context:** Currently `build_colormap_controls!` creates its own GridLayout. We need the color control and colormap controls to share a layout so the color textbox appears at row 1 and colormap controls start at row 2. We'll refactor to pass in a layout and starting row.

**Step 1: Create build_colormap_controls_inner! that takes layout and row**

Add a new internal function after `build_color_control!`:

```julia
"""
    build_colormap_controls_inner!(layout, plot, start_row)

Build colormap controls starting at the given row in an existing layout.
Returns the next available row number.
"""
function build_colormap_controls_inner!(layout, plot, start_row)
    row = start_row

    # Colormap dropdown
    Label(layout[row, 1], "Colormap:", halign = :right)
    colormap_options = collect(zip(string.(COLORMAPS), COLORMAPS))
    menu_colormap = Menu(layout[row, 2], options = colormap_options, default = string(COLORMAPS[1]))
    on(menu_colormap.selection) do cmap
        plot.colormap = cmap
    end
    row += 1

    # Colorscale dropdown
    Label(layout[row, 1], "Colorscale:", halign = :right)
    menu_colorscale = Menu(layout[row, 2], options = COLORSCALES, default = "identity")
    on(menu_colorscale.selection) do scale_func
        plot.colorscale = scale_func
    end
    row += 1

    # Colorrange min
    Label(layout[row, 1], "Range min:", halign = :right)
    current_min = try string(plot.colorrange[][1]) catch; "0.0" end
    tb_min = Textbox(layout[row, 2], stored_string = current_min, validator = Float64, width = 120)
    on(tb_min.stored_string) do s
        try
            new_min = parse(Float64, s)
            current_range = plot.colorrange[]
            plot.colorrange = (new_min, current_range[2])
        catch
            # Keep previous value on parse failure
        end
    end
    row += 1

    # Colorrange max
    Label(layout[row, 1], "Range max:", halign = :right)
    current_max = try string(plot.colorrange[][2]) catch; "1.0" end
    tb_max = Textbox(layout[row, 2], stored_string = current_max, validator = Float64, width = 120)
    on(tb_max.stored_string) do s
        try
            new_max = parse(Float64, s)
            current_range = plot.colorrange[]
            plot.colorrange = (current_range[1], new_max)
        catch
            # Keep previous value on parse failure
        end
    end
    row += 1

    # Alpha (transparency)
    Label(layout[row, 1], "Alpha:", halign = :right)
    current_alpha = try string(plot.alpha[]) catch; "1.0" end
    tb_alpha = Textbox(layout[row, 2], stored_string = current_alpha, validator = Float64, width = 120)
    on(tb_alpha.stored_string) do s
        try
            new_alpha = parse(Float64, s)
            plot.alpha = clamp(new_alpha, 0.0, 1.0)
        catch
            # Keep previous value on parse failure
        end
    end
    row += 1

    return row
end
```

**Step 2: Update build_colormap_controls! to use the inner function**

Replace the existing `build_colormap_controls!` function (lines 93-153) with:

```julia
"""
    build_colormap_controls!(grid, plot)

Build colormap, colorscale, and colorrange controls in the given grid position.
Returns the GridLayout containing the controls.
"""
function build_colormap_controls!(grid, plot)
    layout = GridLayout(grid)
    build_colormap_controls_inner!(layout, plot, 1)
    return layout
end
```

**Step 3: Verify module loads**

Run in Julia REPL:
```julia
using Pkg; Pkg.activate(".")
using GeoDataExplorer
```

Expected: No errors.

**Step 4: Commit**

```bash
git add src/configure_plot.jl
git commit -m "refactor(configure): extract build_colormap_controls_inner! for row flexibility"
```

---

### Task 6: Update configure function signature and logic

**Files:**
- Modify: `src/configure_plot.jl`

**Step 1: Update the configure function**

Replace the entire `configure` function (starting around line 245) with:

```julia
"""
    configure(plot::AbstractPlot; dataset=nothing) -> Figure

Open a popup window to configure plot attributes interactively.
Changes apply immediately as controls are adjusted.

Supports:
- All plots: colormap, colorscale, colorrange, alpha
- Poly: strokecolor, strokewidth
- Lines: strokecolor, strokewidth, linewidth
- Scatter: marker, markersize

When `dataset` is provided and plot is Poly/Lines/Scatter, shows a "Color:"
textbox that accepts either a numeric column name or a color string.
"""
function configure(plot::AbstractPlot; dataset=nothing)
    fig = Figure(size = (450, 400))

    # Title
    Label(fig[0, 1:2], "Configure Plot", fontsize = 18, halign = :center)

    # Check conditions
    plot_has_colormap = has_colormap(plot)
    is_vector_plot = plot isa Union{Poly, Lines, Scatter}
    show_color_control = dataset !== nothing && is_vector_plot

    if plot_has_colormap || show_color_control
        # Create layout for color controls
        layout = GridLayout(fig[1, 1])
        row = 1

        # Color textbox at top (only when dataset provided for vector plots)
        if show_color_control
            Label(layout[row, 1], "Color:", halign = :right)
            tb_color = Textbox(layout[row, 2], stored_string = "", width = 120)
            on(tb_color.stored_string) do s
                isempty(s) && return
                result = try_parse_color_input(s, dataset)
                if result[1] == :column
                    plot.color = result[2]
                    tb_color.bordercolor = RGBf(0.8, 0.8, 0.8)
                elseif result[1] == :color
                    plot.color = result[2]
                    tb_color.bordercolor = RGBf(0.8, 0.8, 0.8)
                else  # :invalid
                    tb_color.bordercolor = RGBf(0.9, 0.2, 0.2)
                end
            end
            row += 1
        end

        # Colormap controls below (if plot has colormap)
        if plot_has_colormap
            build_colormap_controls_inner!(layout, plot, row)
        end

        # Colorbar on right (syncs automatically with plot)
        Colorbar(fig[1, 2], plot, width = 20)
    else
        # No colormap, no dataset - show alpha control only
        layout = GridLayout(fig[1, 1:2])
        Label(layout[1, 1], "Alpha:", halign = :right)
        current_alpha = try string(plot.alpha[]) catch; "1.0" end
        tb_alpha = Textbox(layout[1, 2], stored_string = current_alpha, validator = Float64, width = 120)
        on(tb_alpha.stored_string) do s
            try
                new_alpha = parse(Float64, s)
                plot.alpha = clamp(new_alpha, 0.0, 1.0)
            catch
                # Keep previous value on parse failure
            end
        end
    end

    # Plot-specific controls
    row = 2

    if plot isa Poly
        Label(fig[row, 1:2], "Poly Settings", fontsize = 14, halign = :left)
        row += 1
        build_stroke_controls!(fig[row, 1:2], plot)
        row += 1
    end

    if plot isa Lines
        Label(fig[row, 1:2], "Lines Settings", fontsize = 14, halign = :left)
        row += 1
        build_line_controls!(fig[row, 1:2], plot)
        row += 1
    end

    if plot isa Scatter
        Label(fig[row, 1:2], "Scatter Settings", fontsize = 14, halign = :left)
        row += 1
        build_scatter_controls!(fig[row, 1:2], plot)
        row += 1
    end

    display(GLMakie.Screen(), fig; float = true, focus_on_show = true, title = "Plot Configurator")
    return fig
end
```

**Step 2: Verify module loads**

Run in Julia REPL:
```julia
using Pkg; Pkg.activate(".")
using GeoDataExplorer
```

Expected: No errors.

**Step 3: Commit**

```bash
git add src/configure_plot.jl
git commit -m "feat(configure): add dataset parameter with color control for vector plots"
```

---

### Task 7: Manual integration test

**Files:**
- None (manual testing only)

**Step 1: Test with a vector dataset**

Run in Julia REPL with GLMakie:
```julia
using Pkg; Pkg.activate(".")
using GLMakie
using GeoDataExplorer
using DataFrames

# Create a test dataset with numeric columns
df = DataFrame(
    geometry = [Rect2f(i, j, 1, 1) for i in 0:2, j in 0:2] |> vec,
    value = rand(9),
    category = rand(1:3, 9)
)

# Create a poly plot
fig = Figure()
ax = Axis(fig[1, 1])
colors = df.value
pl = poly!(ax, df.geometry, color = colors)
display(fig)

# Test configure with dataset
configure(pl; dataset = df)
```

Expected: Popup shows "Color:" textbox at top, followed by colormap controls.

**Step 2: Test color textbox with column name**

In the popup, type `value` in the Color textbox and press Enter.

Expected: Plot colors update to use the `value` column, textbox border stays gray.

**Step 3: Test color textbox with color string**

Type `red` in the Color textbox and press Enter.

Expected: Plot becomes solid red, textbox border stays gray.

**Step 4: Test color textbox with invalid input**

Type `notacolumn` in the Color textbox and press Enter.

Expected: Textbox border turns red, plot color unchanged.

**Step 5: Test without dataset (backward compatibility)**

```julia
# Test configure without dataset (should work as before)
configure(pl)
```

Expected: Popup shows colormap controls (no "Color:" textbox), works as before.

**Step 6: Document any issues**

Note any issues found during manual testing for follow-up fixes.

---

## Summary

| Task | Description |
|------|-------------|
| 1 | Add Tables import |
| 2 | Implement get_numeric_columns helper |
| 3 | Implement try_parse_color_input helper |
| 4 | Implement build_color_control! helper |
| 5 | Refactor build_colormap_controls! for row flexibility |
| 6 | Update configure function with dataset parameter |
| 7 | Manual integration test |
