# load_and_plot Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a unified `load_and_plot` function that scans a folder, plots all datasets, and provides an interactive layer list.

**Architecture:** Single function in `datasets.jl` that orchestrates discovery, loading, plotting, and UI wiring. Uses existing `discover_datasets`, `load_*_dataset`, `plot_*_dataset!`, `ScrollableList`, and `configure` components.

**Tech Stack:** Julia, Makie/GLMakie, Rasters.jl, GeoDataFrames.jl, GeoInterface.jl

---

## Task 1: Add GLMakie and Makie imports to datasets.jl

**Files:**
- Modify: `src/datasets.jl:1-8`

**Step 1: Add required imports**

At the top of `datasets.jl`, add Makie imports after the existing imports:

```julia
import GeoDataFrames
import Rasters
import ArchGDAL, NCDatasets
import GeometryOps as GO
using GeometryOps.GeometryOpsCore: get_geometries
import Tables
using Colors: Colorant, @colorant_str
using Makie: Figure, Axis, xlims!, ylims!, AbstractPlot
using GLMakie: GLMakie
```

**Step 2: Verify module loads**

Run: `julia --project -e 'using GeoDataExplorer'`
Expected: No errors

**Step 3: Commit**

```bash
git add src/datasets.jl
git commit -m "feat(datasets): add Makie imports for load_and_plot"
```

---

## Task 2: Add load_and_plot function skeleton

**Files:**
- Modify: `src/datasets.jl` (append at end)

**Step 1: Add function skeleton**

Append to `datasets.jl`:

```julia
"""
    load_and_plot(dir::String; extent=nothing) -> Figure

Scan a folder for geospatial datasets, plot them on a map, and display
a scrollable layer list for visibility toggling and configuration.

# Arguments
- `dir`: Path to folder containing geospatial files
- `extent`: Optional named tuple `(; west, east, south, north)` for lat/lon bounds.
            Rasters are cropped to this extent; axis limits are set accordingly.

# Returns
A `Figure` containing the map axis and layer list.

# Example
```julia
fig = load_and_plot("/path/to/data"; extent=(; west=-122, east=-121, south=37, north=38))
```
"""
function load_and_plot(dir::String; extent=nothing)
    # 1. Discover datasets
    discovered = discover_datasets(dir)

    # 2. Load datasets
    datasets = Any[]
    types = Symbol[]
    names = String[]

    for (type, path) in discovered
        name = splitext(basename(path))[1]
        push!(names, name)
        push!(types, type)

        if type == :Raster
            raster = load_raster_dataset(path)
            if extent !== nothing
                raster = Rasters.crop(raster; to=Rasters.Extent(X=(extent.west, extent.east), Y=(extent.south, extent.north)))
                if prod(size(raster)) == 0
                    @warn "Raster $name does not intersect extent, skipping"
                    pop!(names)
                    pop!(types)
                    continue
                end
            end
            push!(datasets, raster)
        else
            push!(datasets, load_vector_dataset(path))
        end
    end

    # 3. Create figure layout
    fig = Figure(size=(1200, 800))
    ax = Axis(fig[1, 1]; aspect=DataAspect())

    # 4. Plot each dataset
    plots = AbstractPlot[]
    for (i, (type, data)) in enumerate(zip(types, datasets))
        plt = if type == :Raster
            plot_raster_dataset!(ax, data)
        else
            plot_vector_dataset!(ax, data)
        end
        push!(plots, plt)
    end

    # 5. Set axis limits if extent provided
    if extent !== nothing
        xlims!(ax, extent.west, extent.east)
        ylims!(ax, extent.south, extent.north)
    end

    # 6. Build list items
    items = [(type == :Raster ? "■" : "●", name) for (type, name) in zip(types, names)]

    # 7. Create scrollable list with callbacks
    list = ScrollableListBlocks.ScrollableList(fig[1, 2];
        items = items,
        width = 250,
        on_item_click = ScrollableListBlocks.OnClickHideHandler(plots),
        on_configure_click = idx -> begin
            dataset_for_configure = types[idx] == :Vector ? datasets[idx] : nothing
            ConfigurePlot.configure(plots[idx]; dataset=dataset_for_configure)
        end
    )

    return fig
end
```

**Step 2: Verify module loads**

Run: `julia --project -e 'using GeoDataExplorer'`
Expected: No errors

**Step 3: Commit**

```bash
git add src/datasets.jl
git commit -m "feat(datasets): add load_and_plot function"
```

---

## Task 3: Export load_and_plot from module

**Files:**
- Modify: `src/GeoDataExplorer.jl`

**Step 1: Add export**

After the existing exports, add:

```julia
include("datasets.jl")
using .Datasets: load_and_plot
export load_and_plot
```

Wait - looking at the current structure, `datasets.jl` is included directly (not as a submodule). So we need to just add the export:

In `GeoDataExplorer.jl`, add after line 7 (`export configure`):

```julia
export load_and_plot
```

**Step 2: Verify export works**

Run: `julia --project -e 'using GeoDataExplorer; @assert isdefined(GeoDataExplorer, :load_and_plot)'`
Expected: No errors

**Step 3: Commit**

```bash
git add src/GeoDataExplorer.jl
git commit -m "feat: export load_and_plot from GeoDataExplorer"
```

---

## Task 4: Fix module references in load_and_plot

**Files:**
- Modify: `src/datasets.jl`

**Step 1: Update module references**

The `ScrollableListBlocks` and `ConfigurePlot` modules are defined in their own files but included in the main module. We need to reference them correctly.

Looking at `GeoDataExplorer.jl`:
- `ConfigurePlot` is a submodule, accessed via `using .ConfigurePlot`
- `ScrollableListBlocks` is a submodule, accessed via `using .ScrollableListBlocks`

In `datasets.jl`, since it's included before these modules, we need to use the parent module's references. Update the list creation code:

```julia
    # 7. Create scrollable list with callbacks
    list = Main.GeoDataExplorer.ScrollableList(fig[1, 2];
        items = items,
        width = 250,
        on_item_click = Main.GeoDataExplorer.OnClickHideHandler(plots),
        on_configure_click = idx -> begin
            dataset_for_configure = types[idx] == :Vector ? datasets[idx] : nothing
            Main.GeoDataExplorer.configure(plots[idx]; dataset=dataset_for_configure)
        end
    )
```

Actually, looking more carefully at the include order in `GeoDataExplorer.jl`:
1. `datasets.jl` is included first
2. `configure_plot.jl` second
3. `scrollable_list_block.jl` third

This means `datasets.jl` can't directly reference the other modules. We have two options:
A. Move `load_and_plot` to a new file included last
B. Use a function that's defined later (closure pattern)

**Better approach:** Move `load_and_plot` to end of main module file or create a new file.

Create new file `src/load_and_plot.jl`:

```julia
"""
    load_and_plot(dir::String; extent=nothing) -> Figure

Scan a folder for geospatial datasets, plot them on a map, and display
a scrollable layer list for visibility toggling and configuration.

# Arguments
- `dir`: Path to folder containing geospatial files
- `extent`: Optional named tuple `(; west, east, south, north)` for lat/lon bounds.
            Rasters are cropped to this extent; axis limits are set accordingly.

# Returns
A `Figure` containing the map axis and layer list.

# Example
```julia
fig = load_and_plot("/path/to/data"; extent=(; west=-122, east=-121, south=37, north=38))
```
"""
function load_and_plot(dir::String; extent=nothing)
    # 1. Discover datasets
    discovered = discover_datasets(dir)

    # 2. Load datasets
    datasets = Any[]
    types = Symbol[]
    names = String[]

    for (type, path) in discovered
        name = splitext(basename(path))[1]
        push!(names, name)
        push!(types, type)

        if type == :Raster
            raster = load_raster_dataset(path)
            if extent !== nothing
                raster = Rasters.crop(raster; to=Rasters.Extent(X=(extent.west, extent.east), Y=(extent.south, extent.north)))
                if prod(size(raster)) == 0
                    @warn "Raster $name does not intersect extent, skipping"
                    pop!(names)
                    pop!(types)
                    continue
                end
            end
            push!(datasets, raster)
        else
            push!(datasets, load_vector_dataset(path))
        end
    end

    # 3. Create figure layout
    fig = Figure(size=(1200, 800))
    ax = Axis(fig[1, 1]; aspect=DataAspect())

    # 4. Plot each dataset
    plots = AbstractPlot[]
    for (i, (type, data)) in enumerate(zip(types, datasets))
        plt = if type == :Raster
            plot_raster_dataset!(ax, data)
        else
            plot_vector_dataset!(ax, data)
        end
        push!(plots, plt)
    end

    # 5. Set axis limits if extent provided
    if extent !== nothing
        xlims!(ax, extent.west, extent.east)
        ylims!(ax, extent.south, extent.north)
    end

    # 6. Build list items
    items = [(type == :Raster ? "■" : "●", name) for (type, name) in zip(types, names)]

    # 7. Create scrollable list with callbacks
    list = ScrollableList(fig[1, 2];
        items = items,
        width = 250,
        on_item_click = OnClickHideHandler(plots),
        on_configure_click = idx -> begin
            dataset_for_configure = types[idx] == :Vector ? datasets[idx] : nothing
            configure(plots[idx]; dataset=dataset_for_configure)
        end
    )

    return fig
end
```

**Step 2: Update GeoDataExplorer.jl**

Add at end of module (before `end # module`):

```julia
include("load_and_plot.jl")
export load_and_plot
```

**Step 3: Add required imports to load_and_plot.jl**

At top of `load_and_plot.jl`:

```julia
using Makie: Figure, Axis, xlims!, ylims!, AbstractPlot, DataAspect
```

**Step 4: Verify module loads**

Run: `julia --project -e 'using GeoDataExplorer; @assert isdefined(GeoDataExplorer, :load_and_plot)'`
Expected: No errors

**Step 5: Commit**

```bash
git add src/load_and_plot.jl src/GeoDataExplorer.jl
git commit -m "feat: add load_and_plot in separate file with correct module ordering"
```

---

## Task 5: Manual integration test

**Files:**
- None (manual testing)

**Step 1: Create test data folder**

```bash
mkdir -p /tmp/geodata_test
```

**Step 2: Test with empty folder**

Run in Julia REPL:
```julia
using GLMakie
using GeoDataExplorer
fig = load_and_plot("/tmp/geodata_test")
display(fig)
```

Expected: Figure with empty axis and empty list (no crash)

**Step 3: Test with sample data (if available)**

If you have sample geospatial data:
```julia
fig = load_and_plot("/path/to/real/data"; extent=(; west=-122, east=-121, south=37, north=38))
```

Expected: Figure with plotted layers and populated list

**Step 4: Commit any fixes**

If any issues found, fix and commit.

---

## Summary

Tasks:
1. ~~Add imports~~ → Skipped, moving to separate file
2. ~~Add function skeleton~~ → Combined with Task 4
3. Export from module
4. Create `load_and_plot.jl` with proper module ordering
5. Manual integration test

Total: 3 implementation tasks + 1 test task
