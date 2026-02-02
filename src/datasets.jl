import GeoDataFrames
import Rasters
import ArchGDAL, NCDatasets
import GeometryOps as GO
import GeoInterface as GI
using GeometryOps.GeometryOpsCore: get_geometries
import Tables
using Colors: Colorant, @colorant_str
using Makie: scatter!, lines!, poly!, heatmap!, surface!, NoShading, LinearAlgebra, convert_arguments, Surface

"""
    discover_datasets(dir)

Walk through all toplevel files in `dir` and discover geospatial datasets.

Returns a list of `Pair{Symbol, String}` where the key is the dataset type (`:Vector` or `:Raster`)
and the value is the path to the dataset.
"""
function discover_datasets(dir)
    children = readdir(dir; join = true)
    files = filter(isfile, children)
    dirs = filter(isdir, children)

    datasets = Pair{Symbol, String}[]
    for file in files
        ext = splitext(file)[2]
        if ext in (".tiff", ".geotiff", ".tif", ".nc", ".nc4", ".h5")
            push!(datasets, :Raster => file)
        elseif ext in (".shp", ".gpkg", ".geojson", ".parquet", ".pq", ".arrow", ".feather", ".fgb", ".shp.zip")
            push!(datasets, :Vector => file)
        end
    end
    # find multi-file datasets - currently only for shapefiles.
    for dir in dirs
        dir_files = readdir(dir)
        for shp_file in filter(endswith(".shp"), dir_files)
            push!(datasets, :Vector => joinpath(dir, shp_file))
        end
    end
    return datasets
end

function load_vector_dataset(path)
    return GeoDataFrames.read(path)
end

function load_raster_dataset(path)
    return Rasters.Raster(path; lazy = true)
end

function plot_vector_dataset!(axis, dataset; color = missing, attrs...)
    # Obtain geometries from the dataset
    geometry = get_geometries(dataset)
    # Obtain colors - either a single color which needs to be expanded to a vector of rgbaf
    # or a column name, whose values need to be extracted.
    if ismissing(color)
        colnames = Tables.columnnames(dataset)
        real_col_idx = findfirst(colnames) do colname
            col_eltype = eltype(identity.(Tables.getcolumn(dataset, colname)))
            (col_eltype <: Real) && 
            (col_eltype !== Missing)
        end

        if isnothing(real_col_idx)
            color = NaN
        else
            color = Symbol(colnames[real_col_idx])
        end
    end
    final_color = if color isa Colorant
        fill(color, length(geometry))
    elseif color isa Symbol
        if !(color in Tables.columnnames(dataset))
            error("Column $color not found in dataset, use a colorant or a column name.")
            fill(NaN, length(geometry))
        else
            _c = Tables.getcolumn(dataset, color)
            # @assert eltype(_c) <: Real "Column $color must be a real number, got $(eltype(_c))"
            identity.(_c)
        end
    elseif color isa Number
        fill(color, length(geometry))
    end

    # identify the types of geometry in the dataset
    unique_traits = unique(GI.trait.(geometry))
    plotting_trait = if length(unique_traits) == 1
        t = only(unique_traits)
        if t isa GI.PointTrait
            GI.PointTrait()
        elseif t isa GI.AbstractCurveTrait
            GI.LineStringTrait()
        elseif t isa GI.AbstractPolygonTrait || t isa GI.AbstractMultiPolygonTrait
            GI.PolygonTrait()
        else
            error("Unsupported trait $t, use a point, line, or polygon dataset.")
        end
    else # many traits
        # Check if all traits are polygon-like (Polygon or MultiPolygon)
        all_polygon_like = all(t -> t isa GI.AbstractPolygonTrait || t isa GI.AbstractMultiPolygonTrait, unique_traits)
        # Check if all traits are line-like (LineString or MultiLineString)
        all_line_like = all(t -> t isa GI.AbstractCurveTrait, unique_traits)

        if all_polygon_like
            GI.PolygonTrait()
        elseif all_line_like
            GI.LineStringTrait()
        else
            error("Multiple incompatible traits found in dataset, use a single trait dataset.\nFound traits: $unique_traits")
        end
    end

    # finally, plot the geometries in the appropriate way.
    final_plt = if plotting_trait isa GI.PointTrait
        scatter!(axis, geometry; color = final_color, attrs...)
    elseif plotting_trait isa GI.LineStringTrait
        lines!(axis, geometry; color = final_color, attrs...)
    elseif plotting_trait isa GI.PolygonTrait
        poly!(axis, geometry; color = final_color, attrs...)
    else
        error("This should never happen, please report this as a bug.")
    end
    return final_plt
end

function plot_raster_dataset!(axis, dataset::Rasters.Raster; area_of_interest = nothing, attrs...)
    xdim = Rasters.dims(dataset, Rasters.DimensionalData.XDim)
    ydim = Rasters.dims(dataset, Rasters.DimensionalData.YDim)

    can_be_meshimage = all(Rasters.Lookups.isregular, (xdim, ydim))
    has_other_dims = !isempty(Rasters.otherdims(dataset, (xdim, ydim)))

    if has_other_dims
        error("Raster dataset with more than two dimensions not supported yet.")
    end

    reduced_dataset = isnothing(area_of_interest) ? dataset : Rasters.crop(dataset, area_of_interest)
    if prod(size(reduced_dataset)) > prod((15000, 15000))
        error("""
        The given dataset is too large to be plotted!
        We are planning to add support for pyramid-rendering
        but that's a bit more in the future.
        """)
    end
    x, y, col = convert_arguments(Surface, reduced_dataset)

    xreversed = !issorted(x)
    yreversed = !issorted(y)

    uv_transform = if issorted(x) && issorted(y)
        LinearAlgebra.I
    elseif xreversed && yreversed
        :flip_xy
    elseif xreversed && !yreversed
        :flip_x
    elseif !xreversed && yreversed
        :flip_y
    else
        error("This should never happen, please report this as a bug.")
    end

    # Handle reversed axes by permuting the color matrix
    plot_col = if xreversed && yreversed
        reverse(reverse(col, dims=1), dims=2)
    elseif xreversed
        reverse(col, dims=1)
    elseif yreversed
        reverse(col, dims=2)
    else
        col
    end

    final_plot = if can_be_meshimage
        heatmap!(axis, sort(collect(x)), sort(collect(y)), plot_col; attrs...)
    else
        surface!(axis, x, y, zeros(size(col)); color = col, shading = NoShading, attrs...)
    end

    return final_plot
end