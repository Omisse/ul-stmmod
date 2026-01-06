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
    var graphs: Array[WindowGraph] = []
    for window:WindowBase in windows:
        if !graphs.any(func(wg: WindowGraph): return wg.names.has(window.name)):
            graphs.append(WindowGraph.new(window))
    
    for graph:WindowGraph in graphs:
        var color: Color = Color(randf()**2, randf()**2, randf()**2)
        for wnode_name in graph.names.keys():
            _draw_graph_node(graph.get_node_by_name(wnode_name), color)

func _draw_graph_node(node: WindowGraph.WindowNode, color: Color = Color.RED):
    var panel_container = PanelContainer.new()
    panel_container.custom_minimum_size = Vector2(100, 100)
    panel_container.global_position = node.window.global_position
    panel_container.z_index = 10
    panel_container.theme_type_variation = "WindowPanelContainer"
    panel_container.self_modulate = Color(color, 0.5)
    var label = Label.new()
    label.text = str(WindowGraph.get_left_dist_max(node))
    label.global_position = node.window.global_position
    holder.add_child(panel_container)
    panel_container.add_child.call_deferred(label)


func _get_parent_window(n: Node) -> WindowBase:
    if !n.has_meta("parent_window"):
        var window = n
        while !window.is_in_group("window"):
            window = window.get_parent()
        n.set_meta("parent_window", window)
    return n.get_meta("parent_window", null)
    
    
class WindowGraph extends Object:
    var root: WindowNode = null
    var names: Dictionary[String, Array] = {}
    
    func _init(window: WindowBase) -> void:
        root = WindowNode.new(window)
        _map_names(root)
    
    #i really do not like that thing, steps is dumb and hopeless
    func _map_names(current: WindowNode, steps_done: Array[int] = []) -> void:
        var window_name = current.window.name
        if names.has(window_name): return
        
        #theoretically, no need to dupe that one
        names[window_name] = steps_done
        var steps_current = steps_done.duplicate()
        var pos = steps_current.size()
        steps_current.resize(pos+1)
        steps_current[pos] = 0
        for node: WindowNode in current.left:
            steps_current[pos] -= 1
            _map_names(node, steps_current.duplicate())
        
        steps_current[pos] = 0
        for node: WindowNode in current.right:
            steps_current[pos] += 1
            _map_names(node, steps_current.duplicate())
        
    func _get_node_from_steps(steps: Array[int]) -> WindowNode:
        var node = root
        for step in steps:
            var search = node.left if step < 0 else node.right
            step = absi(step)-1
            node = search[step]
        return node

    func get_node_by_name(node_name: String) -> WindowNode:
        if !names.has(node_name): return null
        return _get_node_from_steps(names[node_name])
        
    func call_all(function: Callable):
        return _call_recursive(root, function, [])
            
    func _call_recursive(start: WindowNode, function:Callable, visited: Array[String]):
        var result = []
        if !start.window.name in visited:
            visited.append(start.window.name)
            result.append_array(start.left.map(_call_recursive.bind(function)))
            result.append(function.bind(start))
            result.append_array(start.right.map(_call_recursive.bind(function)))
        return result
    
    
    
    static func get_left_dist_max(node: WindowNode) -> int:
        var result = 0
        for left in node.left:
            result = 1+max(result, 1+get_left_dist_max(left))
        return result
        
        
        
        
    
    class WindowNode extends Object:
        var window: WindowBase = null
        var left: Array = [] #[WindowNode]
        var right: Array = [] #[WindowNode]
        
        func _get_parent_window(n: Node) -> WindowBase:
            if n == null : return null
            
            if !n.has_meta("parent_window"):
                var window = n
                while !window.is_in_group("window"):
                    window = window.get_parent()
                n.set_meta("parent_window", window)
            return n.get_meta("parent_window", null)
        
        func _init(root_window: WindowBase, names: Array[String] = []) -> void:
            if names.has(root_window.name): return
            
            window = root_window
            names.append(window.name)
            
            var left_windows = window.containers\
                .filter(func(c): return c.is_in_group("input"))\
                .map(func(c:ResourceContainer): return _get_parent_window(c.input))\
                .filter(func(w): return w!=null)\
                .filter(func(w): return !names.has(w.name))
            
            var right_windows = []
            for container:ResourceContainer in window.containers.filter(func(c): return c.is_in_group("output")):
                right_windows.append_array(\
                        container.outputs\
                                .map(_get_parent_window)\
                                .filter(func(w): return w!=null)\
                                .filter(func(w): return !names.has(w.name)))
                                            
            
            
            
            left = left_windows.map(func(w: WindowBase): return WindowNode.new(w, names)).filter(func(wn): return wn.window != null) as Array[WindowNode]
            names.append_array(left_windows.map(func(w: WindowBase): return w.name))
            right = right_windows.map(func(w: WindowBase): return WindowNode.new(w, names)).filter(func(wn): return wn.window != null) as Array[WindowNode]
            names.append_array(right_windows.map(func(w: WindowBase): return w.name))
            
