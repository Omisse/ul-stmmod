class_name STMGraph extends WindowGraph

var groups: Dictionary

func _init(window: WindowBase, stm_window: WindowBase) -> void:
    super(window)
    filter_connections(stm_window)
    nodes.erase(stm_window.name)
    _cleanup_sides()
    
func filter_connections(source_window: WindowBase):
    for key in nodes.keys():
        if !_test_filter(key, source_window.name):
            nodes.erase(key)

func _test_filter(key: String, source: String):
    return  _depends_on(nodes[key], source)\
                    || nodes[key].left\
                        .map(func(s: String): return nodes.get(s))\
                        .any(_depends_on.bind(source))\
                    || nodes[key].right\
                        .map(func(s: String): return nodes.get(s))\
                        .any(_depends_on.bind(source))
                        
func _depends_on(node: Dictionary, source_name: String) -> bool:
    if !node: return false
    
    return node.left.has(source_name)

func _cleanup_sides() -> void:
    for key in nodes.keys():
        nodes[key].left = nodes[key].left.filter(func(s): return nodes.has(s))
        nodes[key].right = nodes[key].right.filter(func(s): return nodes.has(s))
    

func _group_nodes() -> void:
    var node_names = nodes.keys()
    var current_group = 0
    while node_names.size() > 0:
        var erase = _set_group(node_names[0], current_group)
        current_group += 1
        for name in erase:
            node_names.erase(name)
        
func _set_group(name: String, group: int) -> Array[String]:
    var names = [name]
    nodes[name].group = group
    for next in nodes[name].left:
        names.append_array(_set_group(next, group))
    for next in nodes[name].right:
        names.append_array(_set_group(next, group))
    return names
        
        
    
