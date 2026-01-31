"""
ScrollableListBlocks - A scrollable selection list widget for Makie.

Usage:
    sl = ScrollableList(fig[1,1], items = [...])

Items are tuples of (icon::Char, label::String).
Click an item to toggle hide/show, click the chevron (right 10%) to configure.
"""
module ScrollableListBlocks

using Makie: @Block, Block, Observable, GridLayout, lift, on, onany, Consume, is_mouseinside,
             campixel!, translate!, translation, RGBf, Point2f, Rect2f, Rect2i,
             poly!, text!, Figure, Scene, Mouse, BBox, Makie, COLOR_ACCENT_DIMMED,
             COLOR_ACCENT, Auto, Inside, screen_relative, theme, to_value
using GeometryBasics: origin, width, height
using ..ConfigurePlot

export ScrollableList, OnClickHideHandler, OnClickConfigureHandler

# Required for @Block macro to work outside Makie
make_block_docstring(T, docstring) = Makie.make_block_docstring(T, docstring)

@Block ScrollableList begin
    @attributes begin
        "The height setting of the list."
        height = Auto()
        "The width setting of the list."
        width = nothing
        "Controls if the parent layout can adjust to this element's width"
        tellwidth = true
        "Controls if the parent layout can adjust to this element's height"
        tellheight = true
        "The horizontal alignment of the list in its suggested bounding box."
        halign = :center
        "The vertical alignment of the list in its suggested bounding box."
        valign = :center
        "The alignment of the list in its suggested bounding box."
        alignmode = Inside()
        "The list items as Vector of (icon::String, label::String) tuples"
        items = [("●", "Item 1"), ("●", "Item 2")]
        "Height of each item row"
        item_height = 36
        "Font size of the item labels"
        fontsize = @inherit(:fontsize, 14.0f0)
        "Font size of the icons"
        icon_fontsize = 18.0f0
        "Padding around text (left, right, bottom, top)"
        textpadding = (12, 40, 8, 8)
        "Background color of items"
        cell_color = RGBf(0.95, 0.95, 0.95)
        "Hover color of items"
        cell_color_hover = RGBf(0.88, 0.88, 0.88)
        "Color when item is hidden/inactive"
        cell_color_hidden = RGBf(0.7, 0.7, 0.7)
        "Color of the chevron"
        chevron_color = RGBf(0.5, 0.5, 0.5)
        "Color of item text"
        textcolor = :black
        "Speed of scrolling"
        scroll_speed = 20.0
        "Border color between items"
        strokecolor = RGBf(0.85, 0.85, 0.85)
        "Border width between items"
        strokewidth = 1
        "Observable BitVector tracking which items are hidden (read this for state)"
        hidden = BitVector()
        "Callback for item click: (index::Int, action::Symbol) -> nothing where action is :hide or :show"
        on_item_click = nothing
        "Callback for chevron/configure click: (index::Int) -> nothing"
        on_configure_click = nothing
    end
end

function Makie.initialize_block!(sl::ScrollableList)
    blockscene = sl.blockscene

    # Observables for layout
    listheight = Observable(0.0; ignore_equal_values = true)
    n_items_obs = Observable(0; ignore_equal_values = true)

    # Update n_items and hidden vector when items change
    on(blockscene, sl.items; update = true) do items
        n = length(items)
        n_items_obs[] = n
        if length(sl.hidden[]) != n
            sl.hidden[] = falses(n)
        end
        listheight[] = n * sl.item_height[]
    end

    on(blockscene, sl.item_height) do ih
        listheight[] = n_items_obs[] * ih
    end

    # Scene area matches the computed bbox
    scenearea = Observable(Rect2i(0, 0, 0, 0); ignore_equal_values = true)

    on(blockscene, sl.layoutobservables.computedbbox; update = true) do bbox
        scenearea[] = Makie.round_to_IRect2D(bbox)
    end

    # Create the scrollable list scene
    list_scene = Scene(blockscene, scenearea, camera = campixel!, clear = true)
    translate!(list_scene, 0, 0, 100)

    # Constrain scroll when area or listheight changes
    onany(blockscene, scenearea, listheight) do area, lh
        t = translation(list_scene)[]
        y = t[2]
        new_y = max(min(0, y), height(area) - lh)
        translate!(list_scene, t[1], new_y, t[3])
    end

    # Item layout observables
    item_rects = Observable(Rect2f[]; ignore_equal_values = true)
    item_colors = Observable(RGBf[]; ignore_equal_values = true)
    list_y_bounds = Ref(Float32[])
    hovered_idx = Ref(0)

    function update_option_colors!(hovered::Int)
        n = n_items_obs[]
        n == 0 && return
        colors = item_colors[]
        resize!(colors, n)
        hidden_vec = sl.hidden[]
        for i in 1:n
            if i <= length(hidden_vec) && hidden_vec[i]
                colors[i] = sl.cell_color_hidden[]
            elseif i == hovered
                colors[i] = sl.cell_color_hover[]
            else
                colors[i] = sl.cell_color[]
            end
        end
        notify(item_colors)
    end

    function update_layout!()
        n = n_items_obs[]
        n == 0 && return

        ih = sl.item_height[]
        lh = n * ih
        listheight[] = lh

        # Compute Y bounds for geometric picking
        heights = fill(Float32(ih), n)
        heights_cumsum = [0f0; cumsum(heights)]
        list_y_bounds[] = lh .- heights_cumsum

        # Update item rectangles
        area = scenearea[]
        w = width(area)
        rects = item_rects[]
        resize!(rects, n)
        for i in 1:n
            rects[i] = Rect2f(0, lh - heights_cumsum[i + 1], w, ih)
        end
        notify(item_rects)
        update_option_colors!(0)
    end

    onany(blockscene, scenearea, sl.items, sl.item_height) do _, _, _
        update_layout!()
    end

    # Draw item backgrounds
    poly!(list_scene, item_rects, color = item_colors,
          strokewidth = sl.strokewidth, strokecolor = sl.strokecolor,
          inspectable = false)

    # Text positions - reactive to layout changes
    icon_positions = lift(blockscene, scenearea, sl.items, sl.item_height, sl.textpadding) do _, items, ih, pad
        n = length(items)
        lh = n * ih
        [Point2f(pad[1], lh - (i - 0.5) * ih) for i in 1:n]
    end

    text_positions = lift(blockscene, scenearea, sl.items, sl.item_height, sl.textpadding, sl.icon_fontsize) do _, items, ih, pad, ifs
        n = length(items)
        lh = n * ih
        [Point2f(pad[1] + ifs + 8, lh - (i - 0.5) * ih) for i in 1:n]
    end

    chevron_positions = lift(blockscene, scenearea, sl.items, sl.item_height) do area, items, ih
        n = length(items)
        w = width(area)
        lh = n * ih
        [Point2f(w - 20, lh - (i - 0.5) * ih) for i in 1:n]
    end

    icon_chars = lift(blockscene, sl.items) do items
        [string(item[1]) for item in items]
    end

    text_labels = lift(blockscene, sl.items) do items
        [string(item[2]) for item in items]
    end

    chevron_texts = lift(blockscene, sl.items) do items
        fill(">", length(items))
    end

    text!(list_scene, icon_positions, text = icon_chars,
          fontsize = sl.icon_fontsize, align = (:left, :center),
          color = sl.textcolor, inspectable = false)
    text!(list_scene, text_positions, text = text_labels,
          fontsize = sl.fontsize, align = (:left, :center),
          color = sl.textcolor, inspectable = false)
    text!(list_scene, chevron_positions, text = chevron_texts,
          fontsize = 20, align = (:center, :center),
          color = sl.chevron_color, inspectable = false)

    # Geometric picking function (same approach as Menu)
    function pick_entry(y)
        ytrans = y - translation(list_scene)[][2]
        bounds = list_y_bounds[]
        length(bounds) < 2 && return 1
        return argmin(
            i -> abs(ytrans - 0.5 * (bounds[i + 1] + bounds[i])),
            1:(length(bounds) - 1)
        )
    end

    # Scroll handling
    on(blockscene, list_scene.events.scroll; priority = 61) do (_, y)
        if is_mouseinside(list_scene)
            t = translation(list_scene)[]
            step = sl.scroll_speed[] * y
            viewport_h = height(list_scene.viewport[])
            lower_bound = viewport_h - listheight[]
            new_y = clamp(t[2] - step, lower_bound, 0)
            translate!(list_scene, t[1], new_y, t[3])
            return Consume(true)
        end
        return Consume(false)
    end

    # Mouse interaction state
    was_inside = Ref(false)
    was_pressed = Ref(false)

    function mouse_up(butt)
        if butt.button == Mouse.left
            if butt.action == Mouse.press
                was_pressed[] = true
                return false
            elseif butt.action == Mouse.release && was_pressed[]
                was_pressed[] = false
                return true
            end
        end
        was_pressed[] = false
        return false
    end

    e = list_scene.events
    onany(blockscene, e.mouseposition, e.mousebutton; priority = 64) do position, butt
        is_inside = is_mouseinside(list_scene)

        if is_inside
            was_inside[] = true
            mp = screen_relative(list_scene, position)
            idx = pick_entry(mp[2])
            item_width = width(list_scene.viewport[])

            if mouse_up(butt)
                # Check if click is in chevron area (right 10%)
                if mp[1] > item_width * 0.9
                    cb = sl.on_configure_click[]
                    if cb !== nothing
                        cb(idx)
                    end
                else
                    # Toggle hidden state
                    h = copy(sl.hidden[])
                    if idx <= length(h)
                        h[idx] = !h[idx]
                        sl.hidden[] = h
                        action = h[idx] ? :hide : :show
                        cb = sl.on_item_click[]
                        if cb !== nothing
                            cb(idx, action)
                        end
                    end
                end
                update_option_colors!(idx)
                return Consume(true)
            else
                # Hover state
                if hovered_idx[] != idx
                    hovered_idx[] = idx
                    update_option_colors!(idx)
                end
            end
            return Consume(true)
        else
            was_pressed[] = false
            if was_inside[]
                was_inside[] = false
                hovered_idx[] = 0
                update_option_colors!(0)
            end
        end
        return Consume(false)
    end

    # React to external hidden state changes
    on(blockscene, sl.hidden) do _
        update_option_colors!(hovered_idx[])
    end

    # Set autosize based on items
    function update_autosize()
        items = sl.items[]
        ih = sl.item_height[]
        n = length(items)
        h = min(n * ih, 300)  # Cap default height at 300
        w = 250  # Default width
        sl.layoutobservables.autosize[] = (w, h)
    end
    onany(blockscene, sl.items, sl.item_height) do _, _
        update_autosize()
    end
    update_autosize()  # Initial call

    # Trigger initial layout
    notify(sl.layoutobservables.suggestedbbox)

    return nothing
end


"""
    OnClickHideHandler(plots::Vector{<: Makie.AbstractPlot})

A handler for item clicks that hides/shows the corresponding plot.

# Arguments
- `plots::Vector{<: Makie.AbstractPlot}`: The plots to hide/show.

To be used with the `on_item_click` attribute of the `ScrollableList` block.
"""
struct OnClickHideHandler
    plots::Vector{<: Makie.AbstractPlot}
end

function (h::OnClickHideHandler)(idx, action)
    println("Item $idx clicked: $action")
    plt = h.plots[idx]
    if action == :hide
        plt.visible[] = false
    else
        plt.visible[] = true
    end
end


struct OnClickConfigureHandler
    plots::Vector{<: Makie.AbstractPlot}
end

function (h::OnClickConfigureHandler)(idx)
    println("Item $idx clicked: configure")
    plt = h.plots[idx]
    configure(plt)
end

function configure(plt::Makie.AbstractPlot)
    ConfigurePlot.configure(plt)
end

function configure(plt::Makie.Heatmap)
    ConfigurePlot.configure(plt)
end

end # module


# ============================================================================
# Demo
# ============================================================================
#=
using GLMakie
using .ScrollableListBlock

    
fig = Figure(size = (450, 500))

items = [
    ("■", "Fire Layer"),
    ("●", "Water Layer"),
    ("▲", "Forest Layer"),
    ("◆", "Mountain Layer"),
    ("○", "Ocean Layer"),
    ("□", "Cloud Layer"),
    ("★", "Storm Layer"),
    ("▼", "Vegetation Layer"),
    ("◇", "Buildings Layer"),
    ("△", "Roads Layer"),
    ("◎", "Points of Interest"),
    ("▣", "Satellite Imagery"),
]

sl = ScrollableList(fig[2, 1];
    items = items,
    item_height = 36,
    height = 280,
    width = 320,
    on_item_click = (idx, action) -> println("$action layer #$idx: $(items[idx][2])"),
    on_configure_click = idx -> println("Configure layer #$idx: $(items[idx][2])")
)

Label(fig[1, 1], "Layer Selection", fontsize = 20, halign = :center)
Label(fig[3, 1], "Click to hide/show • Click > to configure",
        fontsize = 11, color = :gray, halign = :center)

d = display(fig)
=#