# Plot Configure Popup Design

A popup Makie window that allows editing colormap and plot-specific attributes with live updates.

## Function Signature

```julia
function configure(plot::Makie.AbstractPlot) -> Figure
```

Takes any Makie plot, opens a separate GLMakie window, and mutates the plot's attributes as controls change.

## UI Layout

```
┌───────────────────────────────────────────┐
│  Configure Plot                           │
├───────────────────────────────────────────┤
│  Colormap:   [▼ viridis    ]  ┌────────┐  │
│  Colorscale: [▼ identity   ]  │        │  │
│  Range min:  [_0.0_________]  │ Color  │  │
│  Range max:  [_1.0_________]  │  bar   │  │
│                               │        │  │
│                               └────────┘  │
├───────────────────────────────────────────┤
│  (Plot-specific section)                  │
│  Strokecolor: [_black_________]           │
│  Strokewidth: [_1.0___________]           │
└───────────────────────────────────────────┘
```

- Top section: Color controls on left, `Colorbar(fig, plot)` on right
- Bottom section: Plot-specific controls (conditionally shown based on plot type)
- Widgets: `Menu` for dropdowns, `Textbox` for text/numeric input, `Label` for labels

## Behavior

- **Live updates**: Changes apply immediately as controls are adjusted
- **Separate window**: Opens as independent GLMakie `Figure()`
- **Colorbar syncs automatically**: Bound to the plot, reflects all color changes

## Universal Controls (All Plot Types)

### Colormap Dropdown

```julia
const COLORMAPS = [
    # Sequential
    :viridis, :plasma, :inferno, :grays,
    # Diverging
    :RdBu, :coolwarm, :BrBG,
    # Geospatial
    :terrain, :oslo, :turbo
]
```

### Colorscale Dropdown

```julia
const COLORSCALES = [
    "identity" => identity,
    "log10" => log10,
    "sqrt" => sqrt,
    "asinh" => asinh
]
```

### Colorrange (Min/Max Text Fields)

Two `Textbox` widgets, parsed to `Float64`.

## Plot-Specific Controls

### Poly Plots

- `strokecolor`: Text field, parsed via `parse(RGBAf, s)`
- `strokewidth`: Text field, parsed to `Float64`

### Lines Plots

- `strokecolor`: Text field, parsed via `parse(RGBAf, s)`
- `strokewidth`: Text field, parsed to `Float64`
- `linewidth`: Text field, parsed to `Float64`

### Scatter Plots

- `marker`: Dropdown menu
- `markersize`: Text field, parsed to `Float64`

```julia
const MARKERS = [:circle, :rect, :diamond, :cross, :utriangle, :star5]
```

## Implementation Structure

```julia
function configure(plot::Makie.AbstractPlot)
    fig = Figure(size = (400, 350))

    # Universal: colormap controls + colorbar
    build_colormap_controls!(fig[1, 1], plot)
    Colorbar(fig[1, 2], plot)

    # Plot-specific controls
    row = 2

    if plot isa Makie.Poly
        build_stroke_controls!(fig[row, 1:2], plot)
        row += 1
    end

    if plot isa Makie.Lines
        build_line_controls!(fig[row, 1:2], plot)
        row += 1
    end

    if plot isa Makie.Scatter
        build_scatter_controls!(fig[row, 1:2], plot)
        row += 1
    end

    display(fig)
    return fig
end
```

## Widget Binding Pattern

```julia
# Dropdown example
menu = Menu(fig, options = zip(names, values))
on(menu.selection) do val
    plot.attribute = val
end

# Text field example
tb = Textbox(fig, stored_string = string(current_value))
on(tb.stored_string) do s
    try
        plot.attribute = parse(Type, s)
    catch
        # Keep previous value on parse failure
    end
end
```

## Error Handling

- Wrap `parse()` calls in try-catch
- On parse failure, silently keep the previous value (don't update the plot attribute)

## Initial Values

- Read current plot attribute values to initialize widget states
- e.g., `stored_string = string(plot.colorrange[][1])`
