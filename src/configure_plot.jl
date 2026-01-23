"""
ConfigurePlot - A popup window for editing plot attributes in Makie.
"""
module ConfigurePlot

using Makie: Figure, Colorbar, Menu, Textbox, Label, GridLayout, on, Observable, RGBAf
using Colors: parse

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

end # module
