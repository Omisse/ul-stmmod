extends Control

@export var source_container: SmartResourceContainer

var holder: Node = null
var should_show:bool = false
var graph: STMWindowGraph = null

var iteration: int = 0

func _ready()->void:
    holder = self.get_tree().root.get_node("/root/ModLoader/kuuk-SmartThreadManager")


func _on_desktop_button_pressed() -> void:
    should_show = !should_show
    if !graph:
        graph = source_container.window_graph
        graph.changed.connect(_redraw_graph)
        graph.request_filter_depth(self, 0)
        _redraw_graph()
    
    _show_graph(should_show)

func _show_graph(state: bool = true):
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
    iteration += 1
    for key in graph.filtered[0].keys():
        _draw_graph_node(graph, key, color)

func _draw_graph_node(graph: STMWindowGraph, node_name: String, color: Color = Color.RED):
    assert(graph.nodes.has(node_name))
    var node = graph.nodes[node_name] as STMWindowGraph.NodeData
    #if node.window == STMUtils.get_parent_window(source_container): return
    
    var panel_container = PanelContainer.new()
    panel_container.custom_minimum_size = Vector2(100, 100)
    panel_container.global_position = node.window.global_position
    panel_container.z_index = 2
    panel_container.theme_type_variation = "WindowPanelContainer"
    panel_container.self_modulate = Color(color, 0.5)
    var label = Label.new()
    label.text = str(graph.filtered[0][node_name].suppliers)
    label.global_position = node.window.global_position
    holder.add_child(panel_container)
    panel_container.add_child.call_deferred(label)
    for connection in node.left:
        if connection == STMUtils.get_parent_window(source_container).name: continue
        var line = Line2D.new()
        line.default_color = color
        line.add_point(node.window.global_position)
        line.add_point(graph.nodes.get(connection).window.global_position+Vector2(150,150))
        line.z_index = 1
        holder.add_child(line)
