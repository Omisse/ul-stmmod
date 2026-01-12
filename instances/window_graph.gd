extends Node

var LOG_NAME = "kuuk:WindowGraph"

signal changed
signal _internal_update

var nodes: Dictionary[String, RefCounted] #nodes[name] = {window:WindowBase, left: Array[name], right:Array[name], connection_ids:Array[id]}
var container_binds: Dictionary #binds[id] = name for nodes[name]
var DataClass = NodeData

func _init() -> void:
    _connect_signals()

func set_data_holder(type):
    DataClass = type

func add_node(window: WindowBase) -> void:
    if _add_node_silent(window):
        _internal_update.emit()
        
func remove_node(name: String):
    if _remove_node_silent(name):
        _internal_update.emit()

func add_node_chained(window: WindowBase, trigger_update = true):
    if window == null || nodes.has(window.name):
        return
    _add_node_silent(window)
    for next in DataClass.get_inputs_as_window(window):
        add_node_chained(next, false)
    for next in DataClass.get_outputs_as_window(window):
        add_node_chained(next, false)
    if trigger_update:
        _internal_update.emit()

func _add_node_silent(window: WindowBase) -> bool:
    if window == null || nodes.has(window.name):
        return false
    nodes[window.name] = DataClass.new(window)
    for id in nodes[window.name].container_ids:
        container_binds[id] = window.name
    return true


func _remove_node_silent(name: String) -> bool:
    if !nodes.has(name):
        return false
    for other in nodes[name].left:
        _disconnect_name(other, name)
    for other in nodes[name].right:
        _disconnect_name(other, name)
    for id in nodes[name].container_ids:
        container_binds.erase(id)
    nodes.erase(name)
    return true
        


func _connect_signals() -> void:
    if !Signals:
        ModLoaderLog.error("Signals not found", LOG_NAME+":_connect_signals")
    if !Signals.is_node_ready():
        Signals.ready.connect(Signals.connection_created.connect.bind(_on_connections_changed))
        Signals.ready.connect(Signals.connection_deleted.connect.bind(_on_connections_changed))
        Signals.ready.connect(Signals.window_deleted.connect.bind(_on_window_deleted))
    else:
        Signals.window_deleted.connect(_on_window_deleted)
        Signals.connection_created.connect(_on_connections_changed)
        Signals.connection_deleted.connect(_on_connections_changed)
    
    _internal_update.connect(_on_internal_update)

func _on_internal_update() -> void:
    call_deferred("emit_signal", "changed")

func _on_connections_changed(output: String, input: String) -> void:
    if !container_binds.has(output) && !container_binds.has(input): return
    
    if container_binds.has(input):
        _update_node(container_binds[input])

    if container_binds.has(output):
        _update_node(container_binds[output])


func _update_node(name: String):
    if !nodes.has(name): return
    nodes[name].update_connections()
    for window in DataClass.get_inputs_as_window(nodes[name].window):
        add_node_chained(window, false)
    for window in DataClass.get_outputs_as_window(nodes[name].window):
        add_node_chained(window, false)
    _internal_update.emit()
        
    
func _on_window_deleted(window: WindowContainer):
    if !window:
        ModLoaderLog.error("Window doesn't exist.", LOG_NAME+":_on_window_deleted")
        return
    remove_node(window.name)
        

func _disconnect_name(existing: String, disconnected: String):
    if !nodes.has(existing): return
    
    nodes[existing].left = nodes[existing].left.filter(func(n): return n != disconnected)
    nodes[existing].right = nodes[existing].right.filter(func(n): return n != disconnected)



func is_receiver(node: String, source: String, depth: int = 0, visited: Array = []) -> bool:
    var result = false
    if !nodes.has(node)\
            || !nodes.has(source)\
            || visited.has(node)\
            || node == source:
        return result
    result = _depends_on(node, source)
    if depth > 0 && !result:
        result = nodes[node].left\
                .filter(func(n): return !visited.has(n))\
                .any(is_receiver.bind(source, depth-1, visited))
    return result
    
func is_supplier(node: String, target: String, depth: int = 0, visited: Array = []) -> bool:
    var result = false
    if !nodes.has(node)\
            || !nodes.has(target)\
            || visited.has(node)\
            || node == target:
        return result
    result = _source_for(node, target)
    if depth > 0 && !result:
        result = nodes[node].right\
                .filter(func(n): return !visited.has(n))\
                .any(is_supplier.bind(target, depth-1, visited))
    return result

func has_connection(node: String, to: String, depth: int = 0, visited: Array = []) -> bool:
    if !nodes.has(node) || !nodes.has(to) || visited.has(node): return false
    if node == to: return true
    var connection = _depends_on(node, to) || _source_for(node, to)
    visited.append(node)
    if depth > 0 && !connection:
        connection = nodes[node].left\
                .filter(func(n): return !visited.has(n))\
                .any(has_connection.bind(to, depth-1, visited))\
            || nodes[node].right\
                .filter(func(n): return !visited.has(n))\
                .any(has_connection.bind(to, depth-1, visited))
    return connection
                            
                        
func _depends_on(node_name:String, target: String) -> bool:
    if !nodes.has(node_name): return false
    return nodes[node_name].left.has(target)

func _source_for(node_name: String, target:String) -> bool:
    if !nodes.has(node_name): return false
    return nodes[node_name].right.has(target)
        
        
        
class NodeData extends RefCounted:
    const LOG_NAME = "kuuk:WindowGraph:NodeData"

    var window: WindowBase = null
    var left: Array = []
    var right: Array = []
    var container_ids: Array = []

    static func get_inputs_as_window(source: WindowBase) -> Array:
        if source:
            return source.containers.map(func(c): return c.input).filter(func(i): return i != null).map(get_parent_window)
        else:
            ModLoaderLog.error("Window doesn't exist.", LOG_NAME+":_get_inputs_as_window")
            return []

    static func get_outputs_as_window(source: WindowBase) -> Array:
        if source:
            var result = []
            for array in source.containers.map(func(c): return c.outputs).filter(func(a): return a != null && a.size() > 0):
                result.append_array(array.map(get_parent_window).filter(func(w): return w!=null))
            return result
        else:
            ModLoaderLog.error("Window doesn't exist.", LOG_NAME+":_get_outputs_as_window")
            return []
    
    static func get_parent_window(n: Node) -> WindowBase:
        if n == null : return null        
        if !n.has_meta("parent_window"):
            var window = n
            while window && !window.is_in_group("window"):
                window = window.get_parent()
            n.set_meta("parent_window", window)
        return n.get_meta("parent_window", null)

        
        
    func _init(window: WindowBase) -> void:
        self.window = window
        container_ids = window.containers.map(func(c): return c.id)
        update_connections()

    func update_connections() -> void:
        left = get_inputs_as_window(window).map(func(w): return w.name)
        right = get_outputs_as_window(window).map(func(w): return w.name)
    
