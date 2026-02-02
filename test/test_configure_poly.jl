using GLMakie
using GeometryBasics
using DataFrames
using GeoDataExplorer.ConfigurePlot

# Create fake polygon data - simple squares
function make_square(x, y, size=1.0)
    Point2f[
        Point2f(x, y),
        Point2f(x + size, y),
        Point2f(x + size, y + size),
        Point2f(x, y + size),
        Point2f(x, y)  # Close the polygon
    ]
end

# Create a grid of polygons
polygons = [Polygon(make_square(i, j)) for i in 0:2 for j in 0:2]

# Create a DataFrame with numeric columns
df = DataFrame(
    geometry = polygons,
    population = [100.0, 250.0, 500.0, 150.0, 300.0, 450.0, 200.0, 350.0, 600.0],
    area = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
    density = [100.0, 250.0, 500.0, 150.0, 300.0, 450.0, 200.0, 350.0, 600.0]
)

# Create figure and plot polygons with color mapped to population
fig = Figure(size=(800, 600))
ax = Axis(fig[1, 1], title="Test Poly Plot")

# Plot with numeric color
poly_plot = poly!(ax, polygons, color=df.population, colormap=:viridis,
                  strokewidth=1, strokecolor=:black)

# Add colorbar
Colorbar(fig[1, 2], poly_plot)

# Display the main figure
display(fig)

# Now open configure dialog and save screenshot
println("Opening configure dialog...")
config_fig = configure(poly_plot; dataset=df)

# Wait a moment for the window to render
sleep(1.0)

# Save the configure dialog as an image
save("/Users/anshul/.julia/dev/geo/wildfire/GeoDataExplorer/test/configure_poly_screenshot.png", config_fig)
println("Saved screenshot to test/configure_poly_screenshot.png")

# Also print some debug info about the plot
println("\nPlot info:")
println("  Type: ", typeof(poly_plot))
println("  Has plots field: ", hasproperty(poly_plot, :plots))
if hasproperty(poly_plot, :plots)
    println("  Number of child plots: ", length(poly_plot.plots))
    for (i, child) in enumerate(poly_plot.plots)
        println("    Child $i: ", typeof(child))
    end
end

# Check if plot has .plots as a property vs field
println("\nChecking .plots access:")
try
    plots_val = poly_plot.plots
    println("  poly_plot.plots exists: ", plots_val)
    println("  typeof: ", typeof(plots_val))
    println("  length: ", length(plots_val))
catch e
    println("  Error accessing poly_plot.plots: ", e)
end

# Check colorrange
println("\nColorrange info:")
try
    cr = poly_plot.colorrange[]
    println("  poly_plot.colorrange[]: ", cr, " (type: ", typeof(cr), ")")
catch e
    println("  Error accessing poly_plot.colorrange[]: ", e)
end

# Check has_colormap and get_colorbar_plot
println("\nColorbar debug:")
println("  has_colormap(poly_plot): ", ConfigurePlot.has_colormap(poly_plot))
colorbar_plot = ConfigurePlot.get_colorbar_plot(poly_plot)
println("  get_colorbar_plot result: ", colorbar_plot)
println("  get_colorbar_plot type: ", typeof(colorbar_plot))

# Check child plot colorrange
println("\nChild plot colorrange:")
children = poly_plot.plots
if !isempty(children)
    mesh_child = children[1]
    println("  Mesh child type: ", typeof(mesh_child))
    try
        cr = mesh_child.colorrange[]
        println("  mesh_child.colorrange[]: ", cr, " (type: ", typeof(cr), ")")
    catch e
        println("  Error accessing mesh_child.colorrange[]: ", e)
    end
end
