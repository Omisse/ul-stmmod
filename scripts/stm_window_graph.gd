class_name STMWindowGraph extends Object

signal graph_changed

var nodes: Dictionary[String, Dictionary]
var manager: WindowBase

func _init(manager: WindowBase) -> void:
    self.manager = manager
    _add_node(manager)
    filter_connections(manager)
    nodes.erase(manager.name)
    _cleanup_sides()

func _reinit() -> void:
    nodes.clear()
    _add_node(manager)
    filter_connections(manager)
    nodes.erase(manager.name)
    _cleanup_sides()
    graph_changed.emit()

func _add_node(window: WindowBase):   
    if window == null || nodes.has(window.name): return
    
    var left: Dictionary = {}
    var right: Dictionary = {}
    
    
    var left_containers = window.containers.filter(func(c): return c.is_in_group("input"))
    var right_containers = window.containers.filter(func(c): return c.is_in_group("output"))
    
    var left_windows = left_containers.map(func(c): return _get_parent_window(c.input))
    var right_windows = []
    for container in right_containers:
        right_windows.append_array(container.outputs.map(_get_parent_window))
    
    for container:ResourceContainer in left_containers:
        left[container.id] = _get_parent_window(container.input).name if _get_parent_window(container.input) != null else ""
        container.connection_in_set.connect(_on_connections_changed.bind(window.name), Object.ConnectFlags.CONNECT_REFERENCE_COUNTED)
    
    for container:ResourceContainer in right_containers:
        right[container.id] = container.outputs.map(func(c): return _get_parent_window(c).name if _get_parent_window(c) != null else "")
        container.connection_out_set.connect(_on_connections_changed.bind(window.name), Object.ConnectFlags.CONNECT_REFERENCE_COUNTED)
    
    
    var window_structure = {
        "window": window,
        "left": left,
        "right": right,
    }
    nodes[window.name] = window_structure
    
    for next in left_windows:
        _add_node(next)
        
    for next in right_windows:
        _add_node(next)

func filter_connections(source_window: WindowBase):
    for key in nodes.keys():
        if !_filter_dependants(key, source_window.name):
            nodes.erase(key)
            
func _filter_dependants(key: String, source: String):
    var left_depends = nodes[key].left.values().map(func(s: String): return nodes.get(s)).filter(func(n): return n != null).any(_depends_on.bind(source))
    var right_depends := false
    for array in nodes[key].right.values():
        right_depends = right_depends || array.map(func(s: String): return nodes.get(s)).filter(func(n): return n != null).any(_depends_on.bind(source)) as bool
    return _depends_on(nodes[key], source) || left_depends || right_depends
                        
                        
func _depends_on(node: Dictionary, source_name: String) -> bool:
    if !node: return false
    
    return node.left.values().has(source_name)

func _cleanup_sides() -> void:
    for key in nodes.keys():
        for subkey in nodes[key].left.keys():
            nodes[key].left[subkey] = nodes[key].left[subkey] if nodes.has(nodes[key].left[subkey]) || nodes[key].left[subkey] == manager.name else ""
        for subkey in nodes[key].right.keys():
            nodes[key].right[subkey] = nodes[key].right[subkey].filter(func(s): return nodes.has(s))
            
            
func _on_connections_changed(name: String):
    if !nodes.has(name): return
    
    _reinit()
    
func _get_dependants_count(name: String, visited: Array = [], increment:int = 0) -> int:
    if !nodes.has(name) || visited.has(name): return 0
    
    visited.append(name)
    
    for array in nodes[name].right.values():
        for next in array:
            if next != null:
                increment += _get_dependants_count(next, visited, increment+1)
    
    return increment
    
            
    

func _get_parent_window(n: Node) -> WindowBase:
        if n == null : return null
        
        if !n.has_meta("parent_window"):
            var window = n
            while !window.is_in_group("window"):
                window = window.get_parent()
            n.set_meta("parent_window", window)
        return n.get_meta("parent_window", null)
