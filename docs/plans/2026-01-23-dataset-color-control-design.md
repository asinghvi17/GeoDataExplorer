# Dataset Color Control Design

Add dataset-aware color selection to ConfigurePlot, allowing users to type either a column name or a color string.

## Function Signature

```julia
function configure(plot::AbstractPlot; dataset=nothing) -> Figure
```

When `dataset` is provided and plot is Poly/Lines/Scatter, shows a "Color:" textbox that accepts either:
- A column name (if numeric, uses that column for color data)
- A color string (parsed and filled to match dataset length)

## UI Layout

```
┌───────────────────────────────────────────┐
│  Configure Plot                           │
├───────────────────────────────────────────┤
│  Color:      [_____________]  ┌────────┐  │  <- NEW (only with dataset)
│  Colormap:   [▼ viridis    ]  │        │  │
│  Colorscale: [▼ identity   ]  │ Color  │  │
│  Range min:  [_0.0_________]  │  bar   │  │
│  Range max:  [_1.0_________]  │        │  │
│  Alpha:      [_1.0_________]  └────────┘  │
├───────────────────────────────────────────┤
│  (Plot-specific section)                  │
└───────────────────────────────────────────┘
```

- Color textbox appears at top of colormap section (first row)
- Only shown when `dataset !== nothing` AND plot is Poly/Lines/Scatter
- Colormap controls remain visible regardless of color input type

## Behavior

### Input Parsing

When user types in the "Color:" textbox:

1. Check if input matches a column name in dataset where `eltype(col) <: Real`
   - If yes: `plot.color = Tables.getcolumn(dataset, Symbol(input))`
2. Otherwise, try to parse as color string via `parse(RGBAf, input)`
   - If successful: `plot.color = fill(parsed_color, length(first(Tables.columns(dataset))))`
3. If neither works: show red border on textbox, keep previous value

### Visual Feedback

- **Valid input**: Normal border color (gray)
- **Invalid input**: Red border (`RGBf(0.9, 0.2, 0.2)`)

### Initial State

- Textbox starts empty
- User explicitly chooses what to enter

## Implementation

### New Helper Functions

```julia
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
    if Tables.hascolumn(dataset, sym)
        col = Tables.getcolumn(dataset, sym)
        if eltype(col) <: Real
            return (:column, col)
        end
    end

    # Otherwise, try to parse as color
    try
        parsed = parse(RGBAf, input)
        n = length(first(Tables.columns(dataset)))
        return (:color, fill(parsed, n))
    catch
        return (:invalid, nothing)
    end
end
```

### New UI Builder

```julia
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
```

### Modified configure Function

```julia
function configure(plot::AbstractPlot; dataset=nothing)
    fig = Figure(size = (450, 400))

    Label(fig[0, 1:2], "Configure Plot", fontsize = 18, halign = :center)

    plot_has_colormap = has_colormap(plot)
    is_vector_plot = plot isa Union{Poly, Lines, Scatter}
    show_color_control = dataset !== nothing && is_vector_plot

    if plot_has_colormap || show_color_control
        layout = GridLayout(fig[1, 1])
        row = 1

        # Color textbox at top (only when dataset provided for vector plots)
        if show_color_control
            build_color_control!(layout[row, 1:2], plot, dataset)
            row += 1
        end

        # Colormap controls below (shifted down when color control present)
        if plot_has_colormap
            build_colormap_controls_inner!(layout[row, 1:2], plot)
        end

        # Colorbar on right
        Colorbar(fig[1, 2], plot, width = 20)
    else
        # No colormap, no dataset - just alpha control
        layout = GridLayout(fig[1, 1:2])
        Label(layout[1, 1], "Alpha:", halign = :right)
        # ... alpha textbox ...
    end

    # Plot-specific controls unchanged
    # ...
end
```

## Dependencies

Uses existing imports:
- `Tables` (already in datasets.jl)
- `Colors: parse` (already imported)
- `Makie: RGBAf, RGBf` (already imported)

## Scope

| Plot Type | Dataset Provided | Color Control Shown |
|-----------|------------------|---------------------|
| Poly      | Yes              | Yes                 |
| Lines     | Yes              | Yes                 |
| Scatter   | Yes              | Yes                 |
| Heatmap   | Yes              | No                  |
| Any       | No               | No                  |

## Error Handling

- Invalid input: Red border, previous value kept (silent, no exceptions)
- Empty input: Ignored (no action)
- Non-numeric column: Treated as invalid (tries color parse, fails, red border)
