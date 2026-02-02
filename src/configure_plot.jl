"""
ConfigurePlot - A popup window for editing plot attributes in Makie.
"""
module ConfigurePlot

using Makie: Figure, Colorbar, Menu, Textbox, Label, GridLayout, on, Observable, RGBAf, RGBf,
             AbstractPlot, Poly, Lines, Scatter, extract_colormap
using Colors: parse
import Tables

using GLMakie: GLMakie

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

# Colorscale options (use tuples, not pairs, for Menu compatibility)
const COLORSCALES = [
    ("identity", identity),
    ("log10", log10),
    ("sqrt", sqrt),
    ("asinh", asinh)
]

# Marker options for scatter plots
const MARKERS = [:circle, :rect, :diamond, :cross, :utriangle, :star5]

"""
    has_colormap(plot)

Check if a plot has colormap data that can be displayed in a Colorbar.
Returns true if the plot has valid colormap data, false otherwise.
"""
function has_colormap(plot)
    try
        # Try to extract colormap - returns nothing if not available
        cm = extract_colormap(plot)
        # If extract_colormap returns nothing, the plot has no colormap data
        return cm !== nothing
    catch
        return false
    end
end

"""
    get_child_plots(plot)

Safely get child plots from a plot object. Returns empty vector if none.
Note: hasproperty doesn't work correctly for Makie plots, so we use try-catch.
"""
function get_child_plots(plot)
    try
        children = plot.plots
        if children isa AbstractVector && !isempty(children)
            return children
        end
    catch
    end
    return []
end

"""
    get_colorbar_plot(plot)

Get the appropriate plot to use for a Colorbar. For Poly plots that have
multiple colormaps (e.g., MultiPolygon), returns the underlying mesh plot.
For other plots, returns the plot itself if it has a colormap.
"""
function get_colorbar_plot(plot)
    # First try the plot directly
    if has_colormap(plot)
        try
            # This will throw if there are multiple colormaps
            extract_colormap(plot)
            return plot
        catch
            # Multiple colormaps found - look for child plot with colormap
        end
    end

    # For Poly and similar plots, check child plots
    children = get_child_plots(plot)
    for child in children
        if has_colormap(child)
            return child
        end
    end

    return nothing
end

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
    if sym in Tables.columnnames(dataset)
        col = Tables.getcolumn(dataset, sym)
        if eltype(col) <: Real
            return (:column, col)
        end
    end

    # Otherwise, try to parse as color
    try
        parsed = parse(RGBAf, input)
        # Get row count by checking first column's length
        first_col_name = first(Tables.columnnames(dataset))
        n = length(Tables.getcolumn(dataset, first_col_name))
        return (:color, fill(parsed, n))
    catch
        return (:invalid, nothing)
    end
end

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

"""
    get_current_colormap_name(plot)

Get the current colormap name from a plot, returning a string suitable for Menu default.
"""
function get_current_colormap_name(plot)
    try
        cmap = plot.colormap[]
        # Handle Symbol colormaps
        if cmap isa Symbol
            return string(cmap)
        end
        # For other types, try to find a matching name in COLORMAPS
        for cm in COLORMAPS
            if cm == cmap
                return string(cm)
            end
        end
    catch
    end
    return string(COLORMAPS[1])  # Default to first colormap
end

"""
    get_current_colorscale_name(plot)

Get the current colorscale function name from a plot by looking it up in COLORSCALES.
"""
function get_current_colorscale_name(plot)
    try
        scale_func = plot.colorscale[]
        # Look up the function in COLORSCALES
        for (name, func) in COLORSCALES
            if func === scale_func
                return name
            end
        end
    catch
    end
    return "identity"  # Default
end

"""
    get_current_colorrange(plot)

Get the current colorrange from a plot as a (min, max) tuple.
Returns nothing if colorrange is automatic or unavailable.
"""
function get_current_colorrange(plot)
    try
        cr = plot.colorrange[]
        # Handle tuple directly
        if cr isa Tuple && length(cr) >= 2
            return (Float64(cr[1]), Float64(cr[2]))
        end
        # Handle Vec2 or similar array-like
        if cr isa AbstractVector && length(cr) >= 2
            return (Float64(cr[1]), Float64(cr[2]))
        end
        # Try indexing directly (some types support this)
        if applicable(getindex, cr, 1) && applicable(getindex, cr, 2)
            return (Float64(cr[1]), Float64(cr[2]))
        end
    catch e
        @debug "Could not extract colorrange" exception=e
    end
    # Try to get from calculated colorrange if available
    try
        if hasproperty(plot, :calculated_colorrange)
            ccr = plot.calculated_colorrange[]
            if ccr isa Tuple && length(ccr) >= 2
                return (Float64(ccr[1]), Float64(ccr[2]))
            end
        end
    catch
    end
    return nothing
end

"""
    build_colormap_controls_inner!(layout, plot, start_row)

Build colormap controls starting at the given row in an existing layout.
Returns the next available row number.
"""
function build_colormap_controls_inner!(layout, plot, start_row)
    row = start_row

    # Colormap dropdown - pre-fill with current value
    Label(layout[row, 1], "Colormap:", halign = :right)
    colormap_options = collect(zip(string.(COLORMAPS), COLORMAPS))
    current_colormap = get_current_colormap_name(plot)
    menu_colormap = Menu(layout[row, 2], options = colormap_options, default = current_colormap)
    on(menu_colormap.selection) do cmap
        plot.colormap = cmap
    end
    row += 1

    # Colorscale dropdown - pre-fill with current value
    Label(layout[row, 1], "Colorscale:", halign = :right)
    current_colorscale = get_current_colorscale_name(plot)
    menu_colorscale = Menu(layout[row, 2], options = COLORSCALES, default = current_colorscale)
    on(menu_colorscale.selection) do scale_func
        plot.colorscale = scale_func
    end
    row += 1

    # Get current colorrange (may be nothing if automatic)
    current_range = get_current_colorrange(plot)

    # Colorrange min
    Label(layout[row, 1], "Range min:", halign = :right)
    current_min = current_range !== nothing ? string(current_range[1]) : ""
    tb_min = Textbox(layout[row, 2], stored_string = current_min,
                     placeholder = "auto", validator = Float64, width = 120)
    on(tb_min.stored_string) do s
        isempty(s) && return
        try
            new_min = parse(Float64, s)
            cr = get_current_colorrange(plot)
            max_val = cr !== nothing ? cr[2] : new_min + 1.0
            plot.colorrange = (new_min, max_val)
        catch
            # Keep previous value on parse failure
        end
    end
    row += 1

    # Colorrange max
    Label(layout[row, 1], "Range max:", halign = :right)
    current_max = current_range !== nothing ? string(current_range[2]) : ""
    tb_max = Textbox(layout[row, 2], stored_string = current_max,
                     placeholder = "auto", validator = Float64, width = 120)
    on(tb_max.stored_string) do s
        isempty(s) && return
        try
            new_max = parse(Float64, s)
            cr = get_current_colorrange(plot)
            min_val = cr !== nothing ? cr[1] : new_max - 1.0
            plot.colorrange = (min_val, new_max)
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

"""
    build_stroke_controls!(grid, plot)

Build strokecolor and strokewidth controls for Poly/Lines plots.
"""
function build_stroke_controls!(grid, plot)
    layout = GridLayout(grid)

    # Strokecolor text input
    Label(layout[1, 1], "Strokecolor:", halign = :right)
    current_strokecolor = try string(plot.strokecolor[]) catch; "black" end
    tb_strokecolor = Textbox(layout[1, 2], stored_string = current_strokecolor, width = 120)
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
    tb_strokewidth = Textbox(layout[2, 2], stored_string = current_strokewidth, validator = Float64, width = 120)
    on(tb_strokewidth.stored_string) do s
        try
            plot.strokewidth = parse(Float64, s)
        catch
            # Keep previous value on parse failure
        end
    end

    return layout
end

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
    tb_markersize = Textbox(layout[2, 2], stored_string = current_markersize, validator = Float64, width = 120)
    on(tb_markersize.stored_string) do s
        try
            plot.markersize = parse(Float64, s)
        catch
            # Keep previous value on parse failure
        end
    end

    return layout
end

"""
    build_line_controls!(grid, plot)

Build strokecolor, strokewidth, and linewidth controls for Lines plots.
"""
function build_line_controls!(grid, plot)
    layout = GridLayout(grid)

    # Strokecolor text input
    Label(layout[1, 1], "Strokecolor:", halign = :right)
    current_strokecolor = try string(plot.strokecolor[]) catch; "black" end
    tb_strokecolor = Textbox(layout[1, 2], stored_string = current_strokecolor, width = 120)
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
    tb_strokewidth = Textbox(layout[2, 2], stored_string = current_strokewidth, validator = Float64, width = 120)
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
    tb_linewidth = Textbox(layout[3, 2], stored_string = current_linewidth, validator = Float64, width = 120)
    on(tb_linewidth.stored_string) do s
        try
            plot.linewidth = parse(Float64, s)
        catch
            # Keep previous value on parse failure
        end
    end

    return layout
end

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
    fig = Figure(size = (450, 550))

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

        # Get the underlying child plot for reading colormap info (for colorbar)
        # Note: Setting attributes must go to the parent plot, child is read-only
        colorbar_source = get_colorbar_plot(plot)

        # Color textbox at top (only when dataset provided for vector plots)
        if show_color_control
            Label(layout[row, 1], "Color:", halign = :right)
            tb_color = Textbox(layout[row, 2], placeholder = "column or color", width = 120)
            on(tb_color.stored_string) do s
                isempty(s) && return
                result = try_parse_color_input(s, dataset)
                if result[1] == :column || result[1] == :color
                    try
                        plot.color = result[2]  # Set on parent plot, not child
                        tb_color.bordercolor = RGBf(0.8, 0.8, 0.8)
                    catch e
                        # Color assignment failed - likely type mismatch
                        # (e.g., plot initialized with literal colors can't accept numeric data)
                        @warn "Failed to set color" exception=e
                        tb_color.bordercolor = RGBf(0.9, 0.2, 0.2)
                    end
                else  # :invalid
                    tb_color.bordercolor = RGBf(0.9, 0.2, 0.2)
                end
            end
            row += 1
        end

        # Colormap controls below (show when plot has colormap OR dataset provided for potential numeric color)
        if plot_has_colormap || show_color_control
            build_colormap_controls_inner!(layout, plot, row)  # Set on parent plot
            # Colorbar on right - use child plot for reading colormap data
            if colorbar_source !== nothing
                Colorbar(fig[1, 2], colorbar_source, width = 20)
            end
        end
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

end # module
