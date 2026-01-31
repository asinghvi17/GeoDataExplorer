using Makie: Figure, Axis, xlims!, ylims!, AbstractPlot, DataAspect

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
