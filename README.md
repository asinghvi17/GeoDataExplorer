# GeoDataExplorer.jl

A Julia package for exploring and visualizing geospatial datasets with Makie.

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/anshulsinghvi/GeoDataExplorer.jl")
```

## Features

### Dataset Discovery

```julia
using GeoDataExplorer

datasets = discover_datasets("/path/to/data")
# Returns: [(:Raster => "/path/to/dem.tif"), (:Vector => "/path/to/roads.geojson"), ...]
```

**Supported formats:**
- **Raster**: `.tif`, `.tiff`, `.geotiff`, `.nc`, `.nc4`, `.h5`
- **Vector**: `.shp`, `.gpkg`, `.geojson`, `.parquet`, `.pq`, `.arrow`, `.feather`, `.fgb`

### Loading & Plotting

```julia
using GLMakie

# Vector data
gdf = load_vector_dataset("/path/to/roads.geojson")
fig, ax, plt = Figure(), Axis(fig[1, 1]), nothing

plt = plot_vector_dataset!(ax, gdf; color = colorant"steelblue")  # Solid color
plt = plot_vector_dataset!(ax, gdf; color = :population)          # Color by column

# Raster data
raster = load_raster_dataset("/path/to/elevation.tif")
plt = plot_raster_dataset!(ax, raster)
plt = plot_raster_dataset!(ax, raster; area_of_interest = extent)  # With cropping
```

Geometry types (points, lines, polygons) are auto-detected and mapped to appropriate Makie plots (`scatter!`, `lines!`, `poly!`).

### Interactive Configuration

```julia
configure(plt)                    # Open popup to edit plot attributes
configure(plt; dataset = gdf)     # Enable dynamic color selection by column
```

With a dataset, the Color field accepts column names (e.g., `population`) or color strings (e.g., `red`, `#ff5500`).

**Available controls:**

| Control | Poly | Lines | Scatter | Heatmap |
|---------|------|-------|---------|---------|
| Colormap/scale/range | Yes | Yes | Yes | Yes |
| Alpha | Yes | Yes | Yes | Yes |
| Strokecolor/width | Yes | Yes | - | - |
| Linewidth | - | Yes | - | - |
| Marker/size | - | - | Yes | - |

**Colorscales**: identity, log10, sqrt, asinh
**Colormaps**: viridis, plasma, inferno, grays, RdBu, coolwarm, BrBG, terrain, oslo, turbo

### Layer Management

```julia
fig = Figure()
ax = Axis(fig[1, 1])
plots = [poly!(ax, ...), lines!(ax, ...), scatter!(ax, ...)]

sl = ScrollableList(fig[1, 2];
    items = [("Polygons"), ("Roads"), ("Points")],
    on_item_click = OnClickHideHandler(plots),
    on_configure_click = OnClickConfigureHandler(plots)
)
```

## Complete Example

```julia
using GLMakie, GeoDataExplorer

datasets = discover_datasets("./data")
gdf = load_vector_dataset(first(filter(d -> d.first == :Vector, datasets)).second)

fig = Figure(size = (1200, 800))
ax = Axis(fig[1, 1], aspect = DataAspect())
plt = plot_vector_dataset!(ax, gdf; color = :value)

configure(plt; dataset = gdf)
display(fig)
```

## Dependencies

Makie.jl, GeoDataFrames.jl, Rasters.jl, GeometryOps.jl, Tables.jl, Colors.jl

## License

MIT
