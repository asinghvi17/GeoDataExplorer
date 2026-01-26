# GeoDataExplorer.jl

A Julia package for exploring and visualizing geospatial datasets with Makie.

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/anshulsinghvi/GeoDataExplorer.jl")
```

## Features

### Dataset Discovery

Scan a directory to find all geospatial datasets:

```julia
using GeoDataExplorer

datasets = discover_datasets("/path/to/data")
# Returns: [(:Raster => "/path/to/dem.tif"), (:Vector => "/path/to/roads.geojson"), ...]
```

Supported formats:
- **Raster**: `.tif`, `.tiff`, `.geotiff`, `.nc`, `.nc4`, `.h5`
- **Vector**: `.shp`, `.gpkg`, `.geojson`, `.parquet`, `.pq`, `.arrow`, `.feather`, `.fgb`

### Loading Datasets

```julia
# Load vector data (returns a GeoDataFrame)
gdf = load_vector_dataset("/path/to/roads.geojson")

# Load raster data (returns a lazy Raster)
raster = load_raster_dataset("/path/to/elevation.tif")
```

### Plotting Geospatial Data

Plot vector datasets with automatic geometry type detection:

```julia
using GLMakie

fig = Figure()
ax = Axis(fig[1, 1])

# Plot with a solid color
plt = plot_vector_dataset!(ax, gdf; color = colorant"steelblue")

# Plot with color mapped to a numeric column
plt = plot_vector_dataset!(ax, gdf; color = :population)

display(fig)
```

The function automatically detects geometry types (points, lines, polygons) and uses the appropriate Makie plot type (`scatter!`, `lines!`, or `poly!`).

Plot raster datasets:

```julia
fig = Figure()
ax = Axis(fig[1, 1])

plt = plot_raster_dataset!(ax, raster)

# Optionally crop to an area of interest
plt = plot_raster_dataset!(ax, raster; area_of_interest = extent)

display(fig)
```

### Interactive Plot Configuration

Open a popup window to edit plot attributes in real-time:

```julia
# Basic usage
configure(plt)

# With dataset for dynamic color selection
configure(plt; dataset = gdf)
```

When a dataset is provided for vector plots (Poly, Lines, Scatter), a "Color" field appears that accepts:
- **Column names**: Type a numeric column name (e.g., `population`) to color by that data
- **Color strings**: Type a color name (e.g., `red`, `#ff5500`) for solid coloring

Invalid input shows a red border; valid input applies immediately.

**Available controls by plot type:**

| Control | All Plots | Poly | Lines | Scatter |
|---------|-----------|------|-------|---------|
| Color (with dataset) | - | Yes | Yes | Yes |
| Colormap | Yes | Yes | Yes | Yes |
| Colorscale | Yes | Yes | Yes | Yes |
| Color Range | Yes | Yes | Yes | Yes |
| Alpha | Yes | Yes | Yes | Yes |
| Strokecolor | - | Yes | Yes | - |
| Strokewidth | - | Yes | Yes | - |
| Linewidth | - | - | Yes | - |
| Marker | - | - | - | Yes |
| Markersize | - | - | - | Yes |

**Colorscale options**: identity, log10, sqrt, asinh

**Colormap options**: viridis, plasma, inferno, grays, RdBu, coolwarm, BrBG, terrain, oslo, turbo

### Layer Management Widget

A scrollable list widget for managing multiple layers:

```julia
using GLMakie
using GeoDataExplorer

fig = Figure()
ax = Axis(fig[1, 1])

# Create some plots
plots = [
    poly!(ax, ...),
    lines!(ax, ...),
    scatter!(ax, ...)
]

# Create layer list
items = [("■", "Polygons"), ("—", "Roads"), ("●", "Points")]

sl = ScrollableList(fig[1, 2];
    items = items,
    on_item_click = OnClickHideHandler(plots),      # Click to toggle visibility
    on_configure_click = OnClickConfigureHandler(plots)  # Click chevron to configure
)

display(fig)
```

## Complete Example

```julia
using GLMakie
using GeoDataExplorer
using DataFrames

# Discover and load data
datasets = discover_datasets("./data")
gdf = load_vector_dataset(first(filter(d -> d.first == :Vector, datasets)).second)

# Create figure and plot
fig = Figure(size = (1200, 800))
ax = Axis(fig[1, 1], aspect = DataAspect())

plt = plot_vector_dataset!(ax, gdf; color = :value)

display(fig)

# Open configuration popup with dataset for dynamic color selection
configure(plt; dataset = gdf)
```

## Dependencies

- Makie.jl / GLMakie.jl - Visualization
- GeoDataFrames.jl - Vector data I/O
- Rasters.jl - Raster data I/O
- GeometryOps.jl - Geometry operations
- Tables.jl - Tabular data interface
- Colors.jl - Color handling

## License

MIT
