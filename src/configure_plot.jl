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

end # module
