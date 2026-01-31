# load_and_plot Design

## Overview

Unified function that scans a folder for geospatial datasets, plots them on a map, and provides a scrollable layer list for visibility toggling and configuration.

## Function Signature

```julia
function load_and_plot(dir::String; extent=nothing) -> Figure
```

### Parameters

- `dir` - folder to scan for datasets
- `extent` - optional named tuple `(; west, east, south, north)` for lat/lon bounds

### Return

Returns the `Figure` only (for simplicity).

## Behavior

1. Call `discover_datasets(dir)` to find all raster/vector files
2. For each dataset:
   - Rasters: load with `Rasters.Raster(path; lazy=true)`, crop to extent if provided
   - Vectors: load fully via `GeoDataFrames.read(path)` (no cropping)
3. Create figure with `Axis` at `[1,1]` and `ScrollableList` at `[1,2]`
4. Plot each dataset, collect plots in a vector
5. Wire up list callbacks using closures that capture plots/datasets vectors
6. If extent provided, set axis limits to match

## Layout

```
+---------------------------+------------------+
|                           |  ■ elevation     |
|                           |  ● roads         |
|        Map Axis           |  ● buildings     |
|        [1,1]              |  ■ landcover     |
|                           |     [1,2]        |
+---------------------------+------------------+
```

- List on right side
- Icons: ■ for raster, ● for vector
- Labels: filename without path/extension

## List Interactions

- Click item: toggle visibility (hide/show)
- Click chevron (>): open configure popup
- Configure popup receives dataset for vector plots (enables column-as-color feature)

## Area of Interest (Extent)

- Rasters: cropped at load time via `raster[Extent(X=(...), Y=(...))]`
- Vectors: loaded fully (no cropping)
- Axis limits set to extent bounds

## Edge Cases

- Empty folder: return figure with empty axis and empty list
- Raster doesn't intersect extent: skip with warning
- Mixed CRS: assume same CRS for now (reprojection deferred)

## Implementation Tasks

1. Add `load_and_plot` function to `datasets.jl`
2. Export from `GeoDataExplorer.jl`
3. Handle raster cropping with extent
4. Create figure layout with axis and list
5. Wire up callbacks with closure-captured datasets
