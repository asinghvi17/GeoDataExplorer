module GeoDataExplorer

include("datasets.jl")

include("configure_plot.jl")
using .ConfigurePlot: configure
export configure

include("scrollable_list_block.jl")

using .ScrollableListBlocks: ScrollableList, OnClickHideHandler, OnClickConfigureHandler
export ScrollableList
public OnClickHideHandler, OnClickConfigureHandler

# include("data_explorer_block.jl")
# using .DataExplorerBlock: DataExplorer
# export DataExplorer

include("load_and_plot.jl")
export load_and_plot

end # module GeoDataExplorer
