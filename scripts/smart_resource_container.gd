class_name SmartResourceContainer extends "res://scenes/resource_container.gd"

var demand: float = 0.0
var window_binds: Dictionary[WindowBase, WindowData]
var old_demands: Dictionary = {}

var consumers: Array[WindowData] = []
var zero_demands: int = 0

var storages: Array[WindowData] = []
var storage_connections: int = 0

func _ready() -> void:
    super()
    Signals.new_upgrade.connect(_on_new_upgrade)

func _on_new_upgrade() -> void:
    for wd: WindowData in window_binds.values():
        wd.update()
    
func update_connections() -> void:
    super()
    _bind_windows(transfer)
    _filter_windows()
    #_cleanup_demands()
    old_demands.clear()
    if (!should_tick()): tick()

func _bind_windows(target_inputs: Array[ResourceContainer]):
    var windows := target_inputs.map(_get_parent_window)
    var queued_for_deletion := window_binds.keys()\
            .filter(func(key) -> bool:\
                    return !windows.has(key))
    for key in queued_for_deletion:
        window_binds.erase(key)
            
    for c: ResourceContainer in target_inputs:
        var window = _get_parent_window(c)
        if window_binds.has(window):
            window_binds[window].add_source(c)
        else:
            window_binds[window] = WindowData.new(window)
            window_binds[window].add_source(c)
    
    for d: WindowData in window_binds.values():
        d.refill_sources(target_inputs)
        d.update()

func _filter_windows():
    consumers = window_binds.values().filter(func(w): return w.goal > 0)
    storages = window_binds.values().filter(func(w): return is_zero_approx(w.goal))
    storage_connections = storages.reduce(func(acc,w): return acc+w.own_sources.size(), 0)
        
func _cleanup_demands():
    var erase_keys = old_demands.keys().filter(func(key): return !window_binds.values().has(key))
    for key in erase_keys:
        old_demands.erase(key)
        
func _get_parent_window(n: Node) -> WindowBase:
    if !n.has_meta("parent_window"):
        var window = n
        while !window.is_in_group("window"):
            window = window.get_parent()
        n.set_meta("parent_window", window)
    return n.get_meta("parent_window", null)

func _sort_min_demand(left: WindowData, right: WindowData, demands:Dictionary) -> bool:
    #possbile crash source if demands does not have such key
    return demands[left] < demands[right]

func _sort_max_demand(left: WindowData, right: WindowData, demands:Dictionary) -> bool:
    return demands[left] > demands[right]
    
func _sort_min_prod(left: WindowData, right:WindowData) -> bool:
    return left._get_min_prod() < right._get_min_prod()
    
func _sort_complex(left: WindowData, right:WindowData, demands:Dictionary) -> bool:
    var prod_left = left._get_min_prod()
    var prod_right = right._get_min_prod()
    return prod_left*demands[left] < prod_right*demands[right]
    #return prod_left < prod_right || (is_equal_approx(prod_left, prod_right) && (demands[left] < demands[right]))

func tick() -> void :
    #vanilla
    for i: ResourceContainer in looping:
        i.count = 0
    
    var remaining: float = count
    var targets = window_binds.values()    
    
    var demands: Dictionary = {}
    
    for target:WindowData in targets:
        demands[target] = target.get_demand()
    demand = targets.reduce(func(accum: float, window: WindowData) -> float: return accum+demands[window], 0.0)
    
    var windows = transfer.map(_get_parent_window)
    for window in windows:
        pass
        #_add_graph_node(window)
    
    var lines = _get_line_starters(self, windows).map(_get_line_connected.bind(windows))
    lines.sort_custom(func(line_a, line_b): return line_a.size() < line_b.size())
    lines = lines.map(func(l: Array[WindowBase]): return l.filter(func(w: WindowBase): return transfer.has))
    
    #deduplication
    for line:Array[WindowBase] in lines:
        var other_lines = lines.duplicate()
        other_lines.erase(line)
        var other_windows_flat = []
        for other_line in other_lines:
            other_windows_flat.append_array(other_line)
        line = line.filter(func(w:WindowBase): return !other_windows_flat.has(w))
    
    

func _get_line_starters(source: ResourceContainer, windows: Array) -> Array[WindowBase]:
    var result: Array[WindowBase] = []
    for window:WindowBase in windows:
        var remote_windows = window.containers\
                .filter(func(c): return c.is_in_group("input"))\
                .map(func(c:ResourceContainer): return _get_parent_window(c.input))\
                .filter(func(w): return (_get_parent_window(source) != w) && !windows.has(w))
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
    
    #that thing makes it so that the 'line' is only calculated for connected windows
    #at the point of 2.0.21, we have things like trojans that are created by separate node
    #yet the only place they fit is another part of the line, trojan injector
    #flat_windows_array = flat_windows_array.filter(func(w): return windows.has(w))
    
    for window in flat_windows_array:
        result.append_array(_get_line_connected(window, windows))
    return result


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

    func _get_node_by_name(node_name: String) -> WindowNode:
        if !names.has(node_name): return null
        return _get_node_from_steps(names[node_name])
    
    class WindowNode extends Object:
        var window: WindowBase = null
        var left: Array[WindowNode] = []
        var right: Array[WindowNode] = []
        
        func _get_parent_window(n: Node) -> WindowBase:
            if !n.has_meta("parent_window"):
                var window = n
                while !window.is_in_group("window"):
                    window = window.get_parent()
                n.set_meta("parent_window", window)
            return n.get_meta("parent_window", null)
        
        func _init(root_window: WindowBase, names:Array[String] = []) -> void:
            if names.has(root_window.name): return
            
            window = root_window
            names.append(window.name)
            
            var left_windows = window.containers\
                .filter(func(c): return c.is_in_group("input"))\
                .map(func(c:ResourceContainer): return _get_parent_window(c.input))\
                .filter(func(w): return !names.has(w.name))
            
            var right_windows = []
            for container:ResourceContainer in window.containers.filter(func(c): return c.is_in_group("output")):
                right_windows.append_array(\
                        container.outputs\
                                .map(_get_parent_window)\
                                .filter(func(w): return !names.has(w.name)))
                                            
            names.append_array(left_windows.map(func(w: WindowBase): return w.name))
            names.append_array(right_windows.map(func(w: WindowBase): return w.name))
            
            left = left_windows.map(func(w: WindowBase): return WindowNode.new(w, names))
            right = right_windows.map(func(w: WindowBase): return WindowNode.new(w, names))
                    
            
        
        
        


class WindowData extends Object:
    var window: WindowBase
    var goal: float = 0.0
    var inputs_filtered: Dictionary[ResourceContainer, InputContainerData]
    
    var own_sources: Array[ResourceContainer]
    
    func _init(window: WindowBase) -> void:
        self.window = window
        _refilter_inputs()
    
    func add_source(container: ResourceContainer) -> void:
        if !own_sources.has(container):
            own_sources.append(container)
        _refilter_inputs()
    func erase_source(container: ResourceContainer) -> void:
        if own_sources.has(container):
            own_sources.erase(container)
        _refilter_inputs()
    func clear_sources() -> void:
        own_sources.clear()
        _refilter_inputs()
    func refill_sources(inputs: Array[ResourceContainer]) -> void:
        # since that containers are already childs of this window,
        # there will be no situation when previously added input points onto different window
        own_sources = own_sources.filter(inputs.has)
        _refilter_inputs()
        
    
    func _refilter_inputs() -> void:
        var containers = window.containers\
                .filter(func(c: ResourceContainer) -> bool:\
                        return c.is_in_group("input") && !own_sources.has(c))
        for container in containers:
            if !inputs_filtered.has(container):
                inputs_filtered[container] = InputContainerData.new(container)
        
        for key in inputs_filtered.keys():
            if !containers.has(key):
                inputs_filtered.erase(key)
        
    
    func get_demand() -> float:
        if own_sources.size() <= 0:
            return 0.0
        return _get_min_prod()*_get_goal()
    
    func set_count(value: float) -> void:
        for source in own_sources:
            source.count = value/own_sources.size()
        
    func _get_min_prod() -> float:
        var result: float = 0.0
        if inputs_filtered.values().size() == 0:
            return result
            
        var first: bool = true
        for container_data in inputs_filtered.values():
            if first:
                result = container_data.get_prod()
                first = false
            else:
                result = min(result, container_data.get_prod())
        return result
    
    func _get_goal() -> float:
        return window.goal if "goal" in window else 0.0
    
    func update():
        goal = _get_goal()
        for container_data in inputs_filtered.values():
            container_data.update()
        

class InputContainerData:
    var container: ResourceContainer
    var multiplier: float = 0.0
    
    func _init(c: ResourceContainer) -> void:
        container = c
        multiplier = _get_multi()
    
    func get_prod() -> float:
        return container.production*multiplier
    
    func _get_multi() -> float:
        var divisor = container.required if !is_zero_approx(container.required) else 1.0
        return pow(divisor,-1)
    
    func update() -> void:
        multiplier = _get_multi()
    
