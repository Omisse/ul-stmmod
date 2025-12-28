class_name SmartResourceContainer extends "res://scenes/resource_container.gd"

var demand: float = 0.0
var window_binds: Dictionary[WindowBase, WindowData]
var old_demands: Dictionary = {}

func _ready() -> void:
    super()
    Signals.new_upgrade.connect(_on_new_upgrade)

func _on_new_upgrade() -> void:
    for wd: WindowData in window_binds.values():
        wd.update()
    
func update_connections() -> void:
    super()
    _bind_windows(transfer)
    _cleanup_demands()
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
        
func _get_parent_window(n: Node) -> WindowBase:
    if !n.has_meta("parent_window"):
        var window = n
        while !window.is_in_group("window"):
            window = window.get_parent()
        n.set_meta("parent_window", window)
    return n.get_meta("parent_window", null)
    
func _cleanup_demands():
    var erase_keys = old_demands.keys().filter(func(key): return !window_binds.values().has(key))
    for key in erase_keys:
        old_demands.erase(key)
        
func _sum_goal(accum: float, window: WindowData) -> float:
    return accum+window.goal

func _sort_min_demand(left: WindowData, right: WindowData, demands:Dictionary) -> bool:
    #possbile crash source if demands does not have such key
    return demands[left] < demands[right]

var zero_demands: int = 0

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
    var main_ratio = clampf(count/demand, 0.0, 1.0) if !is_zero_approx(demand) else clampf(count, 0.0, 1.0)
    
    if demand <= remaining:
        #distribute as much as needed
        for target:WindowData in targets:
            target.set_count(demands[target])
            remaining -= demands[target]
            
    elif !is_zero_approx(demand):
        #targets.filter(func(t: WindowData): return t.goal > 0)
        targets.sort_custom(_sort_min_demand.bind(demands))
        var current_zeroes = demands.values().reduce(func(acc, val): return acc+int(is_zero_approx(val)), 0)
        var current = 0
        for target:WindowData in targets:
            var target_amount = demands[target]
            if current_zeroes == zero_demands:
                #faster stabilization
                if !old_demands.has(target):
                    old_demands[target] = target_amount
                target_amount = 0.5*(target_amount+old_demands[target])
            var amount = min(target_amount, remaining)
            if amount == remaining:
                amount /= targets.size()-current
            target.set_count(amount)
            old_demands[target] = amount
            remaining -= amount
            current += 1
        zero_demands = current_zeroes             
        
    #even distribution between other connections
    if !is_zero_approx(remaining) && targets.size() > 0:
        targets = targets.filter(func(wd:WindowData): return is_zero_approx(wd.goal))
        var connections: int = 0
        for target:WindowData in targets:
            connections += target.own_sources.size()
        for target:WindowData in targets:
            target.set_count(remaining*target.own_sources.size()/connections)
            









class WindowData extends Object:
    var window: WindowBase
    var goal: float = 0.0
    var inputs_filtered: Dictionary[ResourceContainer, InputContainerData]
    
    var own_sources: Array[ResourceContainer]
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
        
                        
    func _init(window: WindowBase) -> void:
        self.window = window
        _refilter_inputs()
        
    
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
    
