class_name WindowGraph extends Object

var nodes: Dictionary[String, Dictionary]

func _init(window: WindowBase) -> void:
    _add_node(window)
    
func _add_node(window: WindowBase):
    assert(window != null)
    
    if nodes.has(window.name): return
    
    var left_windows = window.containers\
            .filter(func(c): return c.is_in_group("input"))\
            .map(func(c:ResourceContainer): return _get_parent_window(c.input))\
            .filter(func(w): return w!=null)
            
    var right_windows = []
    for container:ResourceContainer in window.containers.filter(func(c): return c.is_in_group("output")):
            right_windows.append_array(\
                    container.outputs\
                            .map(_get_parent_window)\
                            .filter(func(w): return w!=null))
    #deduplication
    var buffer = {}
    for wn in left_windows:
        buffer[wn] = false
    left_windows = buffer.keys()
    buffer.clear()
    for wn in right_windows:
        buffer[wn] = false
    right_windows = buffer.keys()
    
    var window_structure = {
        "window": window,
        "left": left_windows.map(func(w): return w.name),
        "right": right_windows.map(func(w): return w.name),
    }
    nodes[window.name] = window_structure
    
    for next in left_windows:
        _add_node(next)
        
    for next in right_windows:
        _add_node(next)
    
func _get_parent_window(n: Node) -> WindowBase:
        if n == null : return null
        
        if !n.has_meta("parent_window"):
            var window = n
            while !window.is_in_group("window"):
                window = window.get_parent()
            n.set_meta("parent_window", window)
        return n.get_meta("parent_window", null)
        
