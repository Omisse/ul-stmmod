class_name SmartResourceContainer extends ResourceContainer

var demand: float = 0.0
var window_binds: Dictionary[WindowBase, STMWindowData]
var old_demands: Dictionary = {}
var old_demand: float = 0.0

var consumers: Array[STMWindowData] = []

var storages: Array[STMWindowData] = []
var storage_connections: int = 0

func _ready() -> void:
    super()
    Signals.new_upgrade.connect(_on_new_upgrade)

func _on_new_upgrade() -> void:
    for wd: STMWindowData in window_binds.values():
        wd.update()
    
func update_connections() -> void:
    super()
    _bind_windows(transfer)
    _filter_windows()
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
            window_binds[window] = STMWindowData.new(window)
            window_binds[window].add_source(c)
    
    for d: STMWindowData in window_binds.values():
        d.refill_sources(target_inputs)
        d.update()

func _filter_windows():
    consumers = window_binds.values().filter(func(w): return w.get_goal() > 0)
    storages = window_binds.values().filter(func(w): return is_zero_approx(w.get_goal()))
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

func _sort_min_demand(left: STMWindowData, right: STMWindowData, demands:Dictionary) -> bool:
    #possbile crash source if demands does not have such key
    return demands[left] < demands[right]
    
func _sort_min_prod(left: STMWindowData, right:STMWindowData):
    return left.get_min_prod() < right.get_min_prod()

func tick() -> void :
    #vanilla
    for i: ResourceContainer in looping:
        i.count = 0
    
    var targets = window_binds.values()    
    var demands: Dictionary = {}
    
    for consumer:STMWindowData in consumers:
        demands[consumer] = consumer.get_demand()  
    
    demand = consumers.reduce(func(accum: float, window: STMWindowData) -> float: return accum+demands[window], 0.0)
    
    if !is_finite(old_demand): old_demand = demand*2.0
    #if !is_zero_approx(demand):
     #   demand = lerpf(demand, old_demand, clampf(old_demand/demand, 0.1, 0.9))
    
    var remaining: float = 0.0
    
    if demand > count:
        _distribute_low(demands)
    else:
        remaining = _distribute_saturated(demands)
    
    _set_storages(remaining)
    old_demand = demand
    

func _distribute_low(demands: Dictionary):   
    consumers.sort_custom(_sort_min_demand.bind(demands))
    var max_diff = 0.000000
    var remaining = count
    var local_demand = demand
    for consumer:STMWindowData in consumers:
        var old = old_demands[consumer] if old_demands.has(consumer) else demands[consumer]
        var current = demands[consumer]
        var amount = 0.0
    
        old = max(old, current*0.01)
        amount = lerpf(old, current, 0.001)
                
        if amount > remaining:
            amount /= local_demand
            amount *= remaining
            
        consumer.set_count(amount)
        remaining = move_toward(remaining, 0, amount)
        local_demand = move_toward(local_demand, 0, amount)
        old_demands[consumer] = amount
        
    ModLoaderLog.debug("\trem: {0}".format([Utils.print_string(remaining)]), "kuuk:STM:SRC")

func _distribute_saturated(demands: Dictionary) -> float:
    var remaining = count
    for consumer:STMWindowData in consumers:
        consumer.set_count(demands[consumer])
        remaining -= demands[consumer]
    return clampf(remaining, 0.0, INF)
    
    
    

func _set_storages(remaining: float) -> void:
    for storage: STMWindowData in storages:
        storage.set_count(remaining*storage.own_sources.size()/storage_connections)
