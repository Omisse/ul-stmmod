class_name SmartResourceContainer extends ResourceContainer

var demand: float = 0.0
var window_binds: Dictionary[WindowBase, STMWindowData]
var window_graph: STMWindowGraph
var old_demands: Dictionary = {}

var consumers: Array[STMWindowData] = []
var start_consumers: Array[STMWindowData] = []
var other_consumers: Array[STMWindowData] = []

var storages: Array[STMWindowData] = []
var storage_connections: int = 0

var multiplier = 0.5

func _ready() -> void:
    super()
    Signals.new_upgrade.connect(_on_new_upgrade)
    window_graph = STMWindowGraph.new(STMUtils.get_parent_window(self))
    window_graph.changed.connect(_on_graph_changed)
    window_graph.request_filter_depth(self, 0)
    window_graph.request_filter_depth(self, 1)
    
    
func update_connections() -> void:
    super()
    _update_windows()
    _filter_demands()
    multiplier = 0.5
    if (!should_tick()): tick()
    
func tick() -> void :
    #vanilla
    for i: ResourceContainer in looping:
        i.count = 0
        
    if consumers.size() == 0:
        _set_storages(count)
    else:
        _set_storages(_distribute_graph_based(_get_demands()))
        #if demand_mult > 1.0 && demand > count:
            #_set_storages(_distribute_saturated(demands))
        #else:
            #_set_storages(_distribute_graph_based(demand_mult, receiver_demand, demands))
            
    


func _get_demands() -> Dictionary:
    var demands = {}
    for consumer:STMWindowData in consumers:
        demands[consumer] = consumer.get_demand()
    return demands
    
        
    


func _on_new_upgrade() -> void:
    for wd: STMWindowData in window_binds.values():
        wd.update()
        
func _on_graph_changed() -> void:
    update_connections()
    consumers.sort_custom.bind(_sort_min_receivers)
    start_consumers = consumers.filter(func(wd: STMWindowData): return window_graph.filtered[0][wd.window.name].suppliers == 0)
    other_consumers = consumers.filter(func(wd): return !start_consumers.has(wd))

    
func _update_windows() -> void:
    _bind_windows(transfer)
    _filter_windows()

func _bind_windows(target_inputs: Array[ResourceContainer]):
    var windows := target_inputs.map(STMUtils.get_parent_window)
    var queued_for_deletion := window_binds.keys()\
            .filter(func(key) -> bool:\
                    return !windows.has(key))
    for key in queued_for_deletion:
        window_binds.erase(key)
            
    for c: ResourceContainer in target_inputs:
        var window = STMUtils.get_parent_window(c)
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
        
func _filter_demands():
    var erase_keys = old_demands.keys().filter(func(key): return !window_binds.values().has(key))
    for key in erase_keys:
        old_demands.erase(key)

func _sort_min_demand(left: STMWindowData, right: STMWindowData, demands:Dictionary) -> bool:
    #possbile crash source if demands does not have such key
    return demands[left] < demands[right]
    
func _sort_min_receivers(left: STMWindowData, right:STMWindowData):
    return window_graph.filtered[0][left.window.name].receivers < window_graph.filtered[0][right.window.name].receivers




func _distribute_graph_based(demands: Dictionary) -> float:
    if is_zero_approx(count):
        for consumer in consumers:
            consumer.set_count(0)
        return 0.0
    
    var receiver_demand = other_consumers.reduce(func(acc, wd): return acc+demands[wd], 0.0)
    var remaining = count
    var rem_mult = 1.0
    
    #fill the start of our line, that thing will affect everything else
    for consumer in start_consumers:
        var amount = min(remaining, 0.5*(old_demands.get_or_add(consumer, 0.0)+demands[consumer]*multiplier))
        consumer.set_count(amount)
        remaining -= amount
        old_demands[consumer] = amount
    
    var diff = remap(absf(1.0-clampf(remaining/receiver_demand, 0.0, 2.0)), 0.0, 1.0, 1e-14, 1.0)
    
    if remaining >= receiver_demand && multiplier < 1.0:
        multiplier = 0.5*(multiplier+multiplier*(1.0+diff))
        if multiplier > 1.0: multiplier = 1.0
    elif remaining < receiver_demand:
        rem_mult = remaining/receiver_demand if !is_zero_approx(receiver_demand) else 0.0
        multiplier = 0.5*(multiplier+multiplier*(1.0-diff))
    
    #no point in looking at something like 1-1e-14 < 1.0
    if is_equal_approx(rem_mult, 1.0): rem_mult = 1.0
    
    for consumer in other_consumers:
        var amount = demands[consumer]*rem_mult
        consumer.set_count(amount)
        remaining -= amount
    
    demand = count/multiplier if multiplier < 1.0 else count-remaining
    
    remaining = clampf(remaining, 0.0, INF)
    return remaining


func _distribute_low(demands: Dictionary):   
    var remaining:float = count
    
    var start_demand:float = start_consumers.reduce(func(acc, wd: STMWindowData): return acc+demands[wd], 0.0)
    var other_demand:float = demand-start_demand
    
    var other_mult = clampf(remaining/other_demand, 0.0, 1.0) if !is_zero_approx(other_demand) else 0.0
    remaining -= other_demand*other_mult
    var start_mult = clampf(remaining/start_demand, 0.0,1.0) if !is_zero_approx(start_demand) else 0.0
    
    for consumer in other_consumers:
        consumer.set_count(demands[consumer]*other_mult)
    
    for consumer in start_consumers:
        var new = demands[consumer]*start_mult
        var old = old_demands.get_or_add(consumer, new*0.0001)
        var big = max(new, old)
        var small = min(new, old)
        var diff = clampf(big/small, 1.0, 2.0) if !is_zero_approx(small) else 2.0
        #var multiplier = pow(remap(diff, 1.0, big*0.01, 1e-6, 1e-1), window_graph.filtered[1][consumer.window.name].receivers)
        var multiplier = remap(diff, 1.0, 2.0, 1e-6, 1e-1)
        var amount = min(remaining*0.9, lerpf(old, new, 0.5))
        consumer.set_count(amount)
        old_demands[consumer] = amount
        ModLoaderLog.debug("\tmulty: {0}".format([multiplier]), "kuuk:STM:SRC")
        remaining -= amount
    
    ModLoaderLog.debug("\trem: {0}".format([Utils.print_string(remaining)]), "kuuk:STM:SRC")

func _distribute_saturated(demands: Dictionary) -> float:
    var remaining = count
    for consumer:STMWindowData in consumers:
        consumer.set_count(demands[consumer])
        remaining -= demands[consumer]
    demand = count-remaining
    return clampf(remaining, 0.0, INF)
    
    
    

func _set_storages(remaining: float) -> void:
    for storage: STMWindowData in storages:
        storage.set_count(remaining*storage.own_sources.size()/storage_connections)
        
func _exit_tree() -> void:
    window_graph.release_filter_depth(self, 0)
    window_graph.release_filter_depth(self, 1)
