# Plot Configure Popup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a popup Makie window that allows editing colormap, colorrange, colorscale, and plot-specific attributes with live updates.

**Architecture:** A `configure(plot)` function opens a separate Figure window with Menu/Textbox widgets bound to plot attributes. Universal colormap controls appear for all plots; plot-specific controls (stroke, marker, etc.) appear conditionally based on plot type.

**Tech Stack:** Makie.jl (Menu, Textbox, Colorbar, GridLayout), Colors.jl (parse RGBAf)

---

### Task 1: Create configure_plot.jl module skeleton

**Files:**
- Create: `src/configure_plot.jl`
- Modify: `src/GeoDataExplorer.jl`

**Step 1: Create the module file with constants**

Create `src/configure_plot.jl`:

```julia
"""
ConfigurePlot - A popup window for editing plot attributes in Makie.
"""
module ConfigurePlot

using Makie: Figure, Colorbar, Menu, Textbox, Label, GridLayout, on, Observable
using Colors: parse, RGBAf

export configure

# Curated colormap list
const COLORMAPS = [
    # Sequential
    :viridis, :plasma, :inferno, :grays,
    # Diverging
    :RdBu, :coolwarm, :BrBG,
    # Geospatial
    :terrain, :oslo, :turbo
]

# Colorscale options
const COLORSCALES = [
    "identity" => identity,
    "log10" => log10,
    "sqrt" => sqrt,
    "asinh" => asinh
]

# Marker options for scatter plots
const MARKERS = [:circle, :rect, :diamond, :cross, :utriangle, :star5]

end # module
```

**Step 2: Include the module in GeoDataExplorer.jl**

Add to `src/GeoDataExplorer.jl` after the existing includes:

```julia
include("configure_plot.jl")
using .ConfigurePlot: configure
export configure
```

**Step 3: Verify module loads**

Run in Julia REPL:
```julia
using Pkg; Pkg.activate(".")
using GeoDataExplorer
```

Expected: No errors, module loads successfully.

**Step 4: Commit**

```bash
git add src/configure_plot.jl src/GeoDataExplorer.jl
git commit -m "feat: add ConfigurePlot module skeleton with constants"
```

---

### Task 2: Implement build_colormap_controls! helper

**Files:**
- Modify: `src/configure_plot.jl`

**Step 1: Add the helper function**

Add to `src/configure_plot.jl` before `end # module`:

```julia
"""
    build_colormap_controls!(grid, plot)

Build colormap, colorscale, and colorrange controls in the given grid position.
Returns the GridLayout containing the controls.
"""
function build_colormap_controls!(grid, plot)
    layout = GridLayout(grid)

    # Colormap dropdown
    Label(layout[1, 1], "Colormap:", halign = :right)
    colormap_options = collect(zip(string.(COLORMAPS), COLORMAPS))
    menu_colormap = Menu(layout[1, 2], options = colormap_options, default = string(COLORMAPS[1]))
    on(menu_colormap.selection) do cmap
        plot.colormap = cmap
    end

    # Colorscale dropdown
    Label(layout[2, 1], "Colorscale:", halign = :right)
    menu_colorscale = Menu(layout[2, 2], options = COLORSCALES, default = "identity")
    on(menu_colorscale.selection) do scale_func
        plot.colorscale = scale_func
    end

    # Colorrange min
    Label(layout[3, 1], "Range min:", halign = :right)
    current_min = try string(plot.colorrange[][1]) catch; "0.0" end
    tb_min = Textbox(layout[3, 2], stored_string = current_min, validator = Float64)
    on(tb_min.stored_string) do s
        try
            new_min = parse(Float64, s)
            current_range = plot.colorrange[]
            plot.colorrange = (new_min, current_range[2])
        catch
            # Keep previous value on parse failure
        end
    end

    # Colorrange max
    Label(layout[4, 1], "Range max:", halign = :right)
    current_max = try string(plot.colorrange[][2]) catch; "1.0" end
    tb_max = Textbox(layout[4, 2], stored_string = current_max, validator = Float64)
    on(tb_max.stored_string) do s
        try
            new_max = parse(Float64, s)
            current_range = plot.colorrange[]
            plot.colorrange = (current_range[1], new_max)
        catch
            # Keep previous value on parse failure
        end
    end

    return layout
end
```

**Step 2: Verify syntax**

Run in Julia REPL:
```julia
using Pkg; Pkg.activate(".")
using GeoDataExplorer
```

Expected: No errors.

**Step 3: Commit**

```bash
git add src/configure_plot.jl
git commit -m "feat: add build_colormap_controls! helper function"
```

---

### Task 3: Implement build_stroke_controls! helper (for Poly/Lines)

**Files:**
- Modify: `src/configure_plot.jl`

**Step 1: Add the helper function**

Add to `src/configure_plot.jl` before `end # module`:

```julia
"""
    build_stroke_controls!(grid, plot)

Build strokecolor and strokewidth controls for Poly/Lines plots.
"""
function build_stroke_controls!(grid, plot)
    layout = GridLayout(grid)

    # Strokecolor text input
    Label(layout[1, 1], "Strokecolor:", halign = :right)
    current_strokecolor = try string(plot.strokecolor[]) catch; "black" end
    tb_strokecolor = Textbox(layout[1, 2], stored_string = current_strokecolor)
    on(tb_strokecolor.stored_string) do s
        try
            plot.strokecolor = parse(RGBAf, s)
        catch
            # Keep previous value on parse failure
        end
    end

    # Strokewidth text input
    Label(layout[2, 1], "Strokewidth:", halign = :right)
    current_strokewidth = try string(plot.strokewidth[]) catch; "1.0" end
    tb_strokewidth = Textbox(layout[2, 2], stored_string = current_strokewidth, validator = Float64)
    on(tb_strokewidth.stored_string) do s
        try
            plot.strokewidth = parse(Float64, s)
        catch
            # Keep previous value on parse failure
        end
    end

    return layout
end
```

**Step 2: Verify syntax**

Run in Julia REPL:
```julia
using Pkg; Pkg.activate(".")
using GeoDataExplorer
```

Expected: No errors.

**Step 3: Commit**

```bash
git add src/configure_plot.jl
git commit -m "feat: add build_stroke_controls! helper function"
```

---

### Task 4: Implement build_line_controls! helper (for Lines)

**Files:**
- Modify: `src/configure_plot.jl`

**Step 1: Add the helper function**

Add to `src/configure_plot.jl` before `end # module`:

```julia
"""
    build_line_controls!(grid, plot)

Build strokecolor, strokewidth, and linewidth controls for Lines plots.
"""
function build_line_controls!(grid, plot)
    layout = GridLayout(grid)

    # Strokecolor text input
    Label(layout[1, 1], "Strokecolor:", halign = :right)
    current_strokecolor = try string(plot.strokecolor[]) catch; "black" end
    tb_strokecolor = Textbox(layout[1, 2], stored_string = current_strokecolor)
    on(tb_strokecolor.stored_string) do s
        try
            plot.strokecolor = parse(RGBAf, s)
        catch
            # Keep previous value on parse failure
        end
    end

    # Strokewidth text input
    Label(layout[2, 1], "Strokewidth:", halign = :right)
    current_strokewidth = try string(plot.strokewidth[]) catch; "1.0" end
    tb_strokewidth = Textbox(layout[2, 2], stored_string = current_strokewidth, validator = Float64)
    on(tb_strokewidth.stored_string) do s
        try
            plot.strokewidth = parse(Float64, s)
        catch
            # Keep previous value on parse failure
        end
    end

    # Linewidth text input
    Label(layout[3, 1], "Linewidth:", halign = :right)
    current_linewidth = try string(plot.linewidth[]) catch; "1.0" end
    tb_linewidth = Textbox(layout[3, 2], stored_string = current_linewidth, validator = Float64)
    on(tb_linewidth.stored_string) do s
        try
            plot.linewidth = parse(Float64, s)
        catch
            # Keep previous value on parse failure
        end
    end

    return layout
end
```

**Step 2: Verify syntax**

Run in Julia REPL:
```julia
using Pkg; Pkg.activate(".")
using GeoDataExplorer
```

Expected: No errors.

**Step 3: Commit**

```bash
git add src/configure_plot.jl
git commit -m "feat: add build_line_controls! helper function"
```

---

### Task 5: Implement build_scatter_controls! helper (for Scatter)

**Files:**
- Modify: `src/configure_plot.jl`

**Step 1: Add the helper function**

Add to `src/configure_plot.jl` before `end # module`:

```julia
"""
    build_scatter_controls!(grid, plot)

Build marker and markersize controls for Scatter plots.
"""
function build_scatter_controls!(grid, plot)
    layout = GridLayout(grid)

    # Marker dropdown
    Label(layout[1, 1], "Marker:", halign = :right)
    marker_options = collect(zip(string.(MARKERS), MARKERS))
    menu_marker = Menu(layout[1, 2], options = marker_options, default = string(MARKERS[1]))
    on(menu_marker.selection) do m
        plot.marker = m
    end

    # Markersize text input
    Label(layout[2, 1], "Markersize:", halign = :right)
    current_markersize = try string(plot.markersize[]) catch; "10.0" end
    tb_markersize = Textbox(layout[2, 2], stored_string = current_markersize, validator = Float64)
    on(tb_markersize.stored_string) do s
        try
            plot.markersize = parse(Float64, s)
        catch
            # Keep previous value on parse failure
        end
    end

    return layout
end
```

**Step 2: Verify syntax**

Run in Julia REPL:
```julia
using Pkg; Pkg.activate(".")
using GeoDataExplorer
```

Expected: No errors.

**Step 3: Commit**

```bash
git add src/configure_plot.jl
git commit -m "feat: add build_scatter_controls! helper function"
```

---

### Task 6: Implement the main configure function

**Files:**
- Modify: `src/configure_plot.jl`

**Step 1: Add the configure function**

Add to `src/configure_plot.jl` before `end # module`:

```julia
"""
    configure(plot::Makie.AbstractPlot) -> Figure

Open a popup window to configure plot attributes interactively.
Changes apply immediately as controls are adjusted.

Supports:
- All plots: colormap, colorscale, colorrange
- Poly: strokecolor, strokewidth
- Lines: strokecolor, strokewidth, linewidth
- Scatter: marker, markersize
"""
function configure(plot::Makie.AbstractPlot)
    fig = Figure(size = (450, 400))

    # Title
    Label(fig[0, 1:2], "Configure Plot", fontsize = 18, halign = :center)

    # Universal: colormap controls on left
    build_colormap_controls!(fig[1, 1], plot)

    # Colorbar on right (syncs automatically with plot)
    Colorbar(fig[1, 2], plot, width = 20)

    # Plot-specific controls
    row = 2

    if plot isa Makie.Poly
        Label(fig[row, 1:2], "Poly Settings", fontsize = 14, halign = :left)
        row += 1
        build_stroke_controls!(fig[row, 1:2], plot)
        row += 1
    end

    if plot isa Makie.Lines
        Label(fig[row, 1:2], "Lines Settings", fontsize = 14, halign = :left)
        row += 1
        build_line_controls!(fig[row, 1:2], plot)
        row += 1
    end

    if plot isa Makie.Scatter
        Label(fig[row, 1:2], "Scatter Settings", fontsize = 14, halign = :left)
        row += 1
        build_scatter_controls!(fig[row, 1:2], plot)
        row += 1
    end

    display(fig)
    return fig
end
```

**Step 2: Add Makie imports for plot types**

Update the `using Makie` line at the top of the module to include plot types:

```julia
using Makie: Figure, Colorbar, Menu, Textbox, Label, GridLayout, on, Observable,
             AbstractPlot, Poly, Lines, Scatter
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
git commit -m "feat: implement main configure function with plot type dispatch"
```

---

### Task 7: Integration test with ScrollableListBlock

**Files:**
- Modify: `src/scrollable_list_block.jl`

**Step 1: Update the configure method for Heatmap**

Replace the stub `configure(plt::Makie.Heatmap)` function in `src/scrollable_list_block.jl`:

```julia
function configure(plt::Makie.Heatmap)
    ConfigurePlot.configure(plt)
end
```

**Step 2: Add import for ConfigurePlot**

Add at the top of the `ScrollableListBlocks` module, after the existing `using` statements:

```julia
using ..ConfigurePlot
```

**Step 3: Update the generic configure fallback**

Replace the generic `configure(plt::Makie.AbstractPlot)` to use the new module:

```julia
function configure(plt::Makie.AbstractPlot)
    ConfigurePlot.configure(plt)
end
```

**Step 4: Verify integration**

Run in Julia REPL with GLMakie:
```julia
using Pkg; Pkg.activate(".")
using GLMakie
using GeoDataExplorer

# Create a test heatmap
fig = Figure()
ax = Axis(fig[1, 1])
hm = heatmap!(ax, rand(10, 10))
display(fig)

# Test configure popup
configure(hm)
```

Expected: A popup window appears with colormap controls and a colorbar.

**Step 5: Commit**

```bash
git add src/scrollable_list_block.jl
git commit -m "feat: integrate ConfigurePlot with ScrollableListBlock"
```

---

### Task 8: Manual integration test with different plot types

**Files:**
- None (manual testing only)

**Step 1: Test with Scatter plot**

Run in Julia REPL:
```julia
using Pkg; Pkg.activate(".")
using GLMakie
using GeoDataExplorer

fig = Figure()
ax = Axis(fig[1, 1])
sc = scatter!(ax, rand(20), rand(20), color = rand(20))
display(fig)

configure(sc)
```

Expected: Popup shows colormap controls + scatter controls (marker, markersize).

**Step 2: Test with Lines plot**

Run in Julia REPL:
```julia
fig = Figure()
ax = Axis(fig[1, 1])
ln = lines!(ax, 1:10, rand(10), color = 1:10)
display(fig)

configure(ln)
```

Expected: Popup shows colormap controls + lines controls (strokecolor, strokewidth, linewidth).

**Step 3: Test with Poly plot**

Run in Julia REPL:
```julia
using GeometryBasics

fig = Figure()
ax = Axis(fig[1, 1])
rect = Rect2f(0, 0, 1, 1)
pl = poly!(ax, rect, color = :blue)
display(fig)

configure(pl)
```

Expected: Popup shows colormap controls + poly controls (strokecolor, strokewidth).

**Step 4: Document test results**

Note any issues found during manual testing for follow-up fixes.

---

## Summary

| Task | Description |
|------|-------------|
| 1 | Module skeleton with constants |
| 2 | build_colormap_controls! helper |
| 3 | build_stroke_controls! helper |
| 4 | build_line_controls! helper |
| 5 | build_scatter_controls! helper |
| 6 | Main configure function |
| 7 | Integration with ScrollableListBlock |
| 8 | Manual testing with different plot types |
