extends Control

@export var source_container: ResourceContainer

var holder: Node = null
var should_show:bool = false

func _ready()->void:
    holder = self.get_tree().root.get_node("/root/ModLoader/kuuk-SmartThreadManager")


func _on_desktop_button_pressed() -> void:
    should_show = !should_show
    if should_show:
        _draw_from_source()
    else:
        if holder:
            for child in holder.get_children():
                child.queue_free()

func _draw_from_source():
    var windows: = source_container.outputs.map(_get_parent_window)
    for window:WindowBase in windows:
        window.remove_meta("line_order")
    var lines = _get_line_starters(windows).map(func(starter): return _get_line_connected(starter, windows))
    lines.sort_custom(func(linea, lineb): return linea.size() > lineb.size())
    var longest_line = lines[0]
    for line in lines:
        var line_color = Color(randf(), randf(), randf())
        var order = 0
        for window in line:
            if line == longest_line || !longest_line.has(window):
                _draw_graph_node(window, order, line_color)
                order+=1
                
        
        
func _get_line_starters(windows: Array) -> Array[WindowBase]:
    var result: Array[WindowBase] = []
    for window:WindowBase in windows:
        var remote_windows = window.containers\
                .filter(func(c): return c.is_in_group("input"))\
                .map(func(c:ResourceContainer): return _get_parent_window(c.input))\
                .filter(func(w): return (_get_parent_window(source_container) != w) && !windows.has(w))
        if remote_windows.size() > 0: result.append(window)
    return result
    
func _get_line_connected(starter: WindowBase, windows: Array) -> Array[WindowBase]:
    var result: Array[WindowBase] = [starter]
    var valid_outputs = starter.containers\
            .filter(func(c): return c.is_in_group("output"))\
            .map(func(c:ResourceContainer): return c.outputs)
    var flat_windows_array = []
    for outputs in valid_outputs:
        flat_windows_array.append_array(outputs.map(_get_parent_window))
    flat_windows_array = flat_windows_array.filter(func(w): return windows.has(w))
    
    for window in flat_windows_array:
        result.append_array(_get_line_connected(window, windows))
    return result

func _draw_graph_node(window: WindowBase, order: int, color: Color = Color.RED):
    var panel_container = PanelContainer.new()
    panel_container.custom_minimum_size = Vector2(100, 100)
    panel_container.global_position = window.global_position
    panel_container.z_index = 10
    panel_container.theme_type_variation = "WindowPanelContainer"
    panel_container.self_modulate = Color(color, 0.5)
    var label = Label.new()
    label.text = str(order)
    label.global_position = window.global_position
    holder.add_child(panel_container)
    panel_container.add_child.call_deferred(label)


func _get_parent_window(n: Node) -> WindowBase:
    if !n.has_meta("parent_window"):
        var window = n
        while !window.is_in_group("window"):
            window = window.get_parent()
        n.set_meta("parent_window", window)
    return n.get_meta("parent_window", null)
    
