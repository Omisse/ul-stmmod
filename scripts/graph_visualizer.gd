extends Control

@export var source_container: ResourceContainer

var holder: Node = null
var should_show:bool = false
var graph: STMWindowGraph = null

func _ready()->void:
    holder = self.get_tree().root.get_node("/root/ModLoader/kuuk-SmartThreadManager")


func _on_desktop_button_pressed() -> void:
    should_show = !should_show
    if !graph:
        graph = STMWindowGraph.new(_get_parent_window(source_container))
        graph.graph_changed.connect(_redraw_graph)
        _redraw_graph()
        
    _hide_graph(!should_show)

func _hide_graph(state: bool = true):
    if !holder: return
    for child in holder.get_children():
        if 'visible' in child:
            child.visible = state

func _clear_graph():
    if holder:
        for child in holder.get_children():
            child.queue_free()

func _redraw_graph():
    _clear_graph()    
    var color: Color = Color(randf_range(0.5,1.0), randf_range(0.5,1.0), randf_range(0.5,1.0))
    for wnode_name in graph.nodes.keys():
        _draw_graph_node(graph, wnode_name, color)

func _draw_graph_node(graph: STMWindowGraph, node_name: String, color: Color = Color.RED):
    assert(graph.nodes.has(node_name))
    var node = graph.nodes[node_name]
    
    var panel_container = PanelContainer.new()
    panel_container.custom_minimum_size = Vector2(100, 100)
    panel_container.global_position = node.window.global_position
    panel_container.z_index = 2
    panel_container.theme_type_variation = "WindowPanelContainer"
    panel_container.self_modulate = Color(color, 0.5)
    var label = Label.new()
    label.text = str("")
    label.global_position = node.window.global_position
    holder.add_child(panel_container)
    panel_container.add_child.call_deferred(label)
    for connection in node.left.values():
        var line = Line2D.new()
        line.default_color = color
        line.add_point(node.window.global_position)
        line.add_point(graph.nodes.get(connection, node).window.global_position+Vector2(150,150))
        line.z_index = 1
        holder.add_child(line)
        
        


func _get_parent_window(n: Node) -> WindowBase:
    if !n: return
    
    if !n.has_meta("parent_window"):
        var window = n
        while !window.is_in_group("window"):
            window = window.get_parent()
        n.set_meta("parent_window", window)
    return n.get_meta("parent_window", null)
