"""
ConfigurePlot - A popup window for editing plot attributes in Makie.
"""
module ConfigurePlot

using Makie: Figure, Colorbar, Menu, Textbox, Label, GridLayout, on, Observable, RGBAf,
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
    tb_min = Textbox(layout[3, 2], stored_string = current_min, validator = Float64, width = 120)
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
    tb_max = Textbox(layout[4, 2], stored_string = current_max, validator = Float64, width = 120)
    on(tb_max.stored_string) do s
        try
            new_max = parse(Float64, s)
            current_range = plot.colorrange[]
            plot.colorrange = (current_range[1], new_max)
        catch
            # Keep previous value on parse failure
        end
    end

    # Alpha (transparency)
    Label(layout[5, 1], "Alpha:", halign = :right)
    current_alpha = try string(plot.alpha[]) catch; "1.0" end
    tb_alpha = Textbox(layout[5, 2], stored_string = current_alpha, validator = Float64, width = 120)
    on(tb_alpha.stored_string) do s
        try
            new_alpha = parse(Float64, s)
            plot.alpha = clamp(new_alpha, 0.0, 1.0)
        catch
            # Keep previous value on parse failure
        end
    end

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
    configure(plot::AbstractPlot) -> Figure

Open a popup window to configure plot attributes interactively.
Changes apply immediately as controls are adjusted.

Supports:
- All plots: colormap, colorscale, colorrange
- Poly: strokecolor, strokewidth
- Lines: strokecolor, strokewidth, linewidth
- Scatter: marker, markersize
"""
function configure(plot::AbstractPlot)
    fig = Figure(size = (450, 400))

    # Title
    Label(fig[0, 1:2], "Configure Plot", fontsize = 18, halign = :center)

    # Check if plot has colormap data
    plot_has_colormap = has_colormap(plot)

    if plot_has_colormap
        # Colormap controls on left
        build_colormap_controls!(fig[1, 1], plot)

        # Colorbar on right (syncs automatically with plot)
        Colorbar(fig[1, 2], plot, width = 20)
    else
        # No colormap - show alpha control only
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
