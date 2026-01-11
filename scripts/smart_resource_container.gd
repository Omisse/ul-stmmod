class_name SmartResourceContainer extends ResourceContainer

var demand: float = 0.0
var window_data: Dictionary[StringName, STMWindowData]
var window_graph: STMWindowGraph = null
var old_demands: Dictionary[StringName, float]

var consumers: Array = [] # Array[StringName]
var line_suppliers: Array = [] # Array[StringName]
var line_receivers: Array = [] # Array[StringName]

var managers: Array = []

var storages: Array = []
var storage_connections: int = 0

var multiplier = 0.5

var must_update = true

var distribution_mode: STMContainerMode = STMContainerMode.LOGIC_DEFAULT:
    get:
        return distribution_mode
    set(value):
        _update_callable(value)
        must_update = true
        
var distribution_callable: Callable

enum STMContainerMode {
    LOGIC_DEFAULT,
    LOGIC_DEMAND,
    LOGIC_GRAPH,
}

func _ready() -> void:
    super()
    Signals.new_upgrade.connect(_on_new_upgrade)
    window_graph = STMWindowGraph.new(STMUtils.get_parent_window(self))
    window_graph.changed.connect(_on_graph_changed)
    window_graph.request_filter_depth(self, 0)

func _on_new_upgrade() -> void:
    # actually that won't change anything in 2.0.19
    for wd: STMWindowData in window_data.values():
        wd.update()
        
func _on_graph_changed() -> void:
    # we do this just because our update must _always_ happen before the tick
    must_update = true

    
func update_connections() -> void:
    super()
    # we do this just because our update must _always_ happen before the tick
    must_update = true
    if (!should_tick()): tick()
    
func tick() -> void :
    # we do this just because our update must _always_ happen before the tick
    if must_update:
        _update_data()
    # vanilla
    for i: ResourceContainer in looping:
        i.count = 0
    
    #gotta be global tbh
    var state = {}
    
    distribution_callable.call(count, state)
    
    demand = state.get_or_add("demand", 0.0)
    
    
    
    
    
    
    
    
    
    
func _update_callable(mode: STMContainerMode):
    match mode:
        STMContainerMode.LOGIC_DEFAULT:
            distribution_callable = _distribution_default
        STMContainerMode.LOGIC_DEMAND:
            distribution_callable = _distribution_demand
        STMContainerMode.LOGIC_GRAPH:
            distribution_callable = _distribution_graph
        

    
func _update_data() -> void:
    _update_windows()
    _filter_demands()
    _update_lines()
    multiplier = 0.5
    must_update = false
        
func _update_windows() -> void:
    _bind_windows(transfer)
    _filter_windows()

func _bind_windows(target_inputs: Array[ResourceContainer]):
    var windows := target_inputs\
            .map(STMUtils.get_parent_window)\
            .filter(func(w): return w!=null)
    
    var ids = target_inputs\
            .map(func(rc: ResourceContainer): return rc.id)
            
    for window in windows:
        window_data\
                .get_or_add(window.name, STMWindowData.new(window))\
                .set_containers(ids)
                
    var names = windows.map(func(w): return w.name)
    for key:StringName in window_data.keys():
        if !names.has(key):
            window_data.erase(key)
        

func _filter_windows():
    consumers = window_data.keys()\
            .filter(func(n):\
                return window_data[n].role == STMWindowData.STMWindowRoles.STM_CONSUMER)
    managers = window_data.keys()\
            .filter(func(n):\
                return window_data[n].role == STMWindowData.STMWindowRoles.STM_MANAGER)
    storages = window_data.keys()\
            .filter(func(n):\
                return window_data[n].role == STMWindowData.STMWindowRoles.STM_STORAGE)
                    
    storage_connections = storages.reduce(func(acc,n:StringName): return acc+window_data[n].provided.size(), 0)
        
func _filter_demands():
    for key in old_demands.keys():
        if !window_data.has(key):
            old_demands.erase(key)


func _update_lines() -> void:
    line_suppliers = consumers\
            .filter(func(n: StringName):\
                return window_graph.filtered[0][n].suppliers == 0)
    line_receivers = consumers\
            .filter(func(n: StringName): return !line_suppliers.has(n))
            
func _get_demands() -> Dictionary:
    var out = {}
    for cname:StringName in consumers:
        out[cname] = window_data[cname].get_demand()
    for cname:StringName in managers:
        out[cname] = window_data[cname].get_demand()
    return out











    
func _distribution_default(value: float, state: Dictionary):
    var remaining = value
    var demands = _get_demands()
    var total = demands.values().reduce(func(acc, flt): return acc+flt, 0.0)
    var ratio = clampf(remaining/total, 0.0, 1.0)
    for key in demands.keys():
        var amount = demands[key]*ratio
        window_data[key].set_count(amount)
        remaining -= amount
    state.demand = total
    _set_storages(clampf(remaining, 0.0, INF))
    
func _distribution_demand(value: float, state: Dictionary):
    var demands: Dictionary = _get_demands()
    state.demand = demands.values().reduce(func(acc, flt): return acc+flt, 0.0)
    
    if is_zero_approx(value):
        for wd in window_data.values():
            wd.set_count(0.0)
            return
    
    var remaining: float = value
    var targets = consumers.duplicate()
    targets.append_array(managers)
    _set_storages(_set_targets_demand(value, targets, demands, state))
    
func _distribution_graph(value: float, state: Dictionary) -> void:
    var remaining = count
    var demands = _get_demands()
    
    if !consumers.is_empty():
        remaining = _set_consumers_graph(remaining, demands, state)
    
    _set_storages(_set_managers(remaining, demands, state))
    






func _set_targets_demand(value: float, targets: Array, demands:Dictionary, state: Dictionary):
    if is_zero_approx(value):
        for name in targets:
            window_data[name].set_count(0.0)
        return 0.0
    
    targets.sort_custom(func(a,b): return demands[a] < demands[b])
    var remaining = value
    var multis = state.get_or_add("key_multipliers", {})
    var old_demands = state.get_or_add("old_demands", {})
    for name:StringName in targets:
        var multi = multis.get_or_add(name, 1.0)
        var target_amount = demands[name]*multi
        var amount = min(
                remaining,
                demands[name],
                0.5*(old_demands.get_or_add(name, 0.0)+target_amount)
        )
        
        if amount == remaining && name != targets.back():
            amount *= 0.5
            multis[name] = clampf(multi-remap(absf(1.0-remaining/target_amount), 0.0, 1.0, 1e-14, 1e-1), 1e-7, 1.0)
        elif demands[name] > amount:
            multis[name] = clampf(multi+remap(absf(1.0-target_amount/demands[name]), 0.0, 1.0, 1e-14, 1e-1), 1e-7, 1.0)
            
        window_data[name].set_count(amount)
        old_demands[name] = amount
        remaining -= amount
        
    state.merge({
        "key_multipliers": multis,
        "old_demands": old_demands,
    }, true)
    
    return 0.0 if value < state.demand else clampf(remaining, 0.0, INF)








func _set_consumers_graph(remaining: float, demands: Dictionary, state: Dictionary) -> float:
    var demand = state.get_or_add("demand", 0.0)
    var multi = state.get_or_add("multiplier", 1.0)
    var old_demands = state.get_or_add("old_demands", {})
    
    if is_zero_approx(remaining):
        for name in consumers:
            window_data[name].set_count(0)
        demand = 0.5*(demand+demands.values().reduce(func(acc, flt): return acc+flt, 0.0))
    else:
        var start_remaining = remaining
        #fill the start of our line, that thing will affect everything else
        for name in line_suppliers:
            var amount = min(remaining, 0.5*(old_demands.get_or_add(name, 0.0)+demands[name]*multi))
            window_data[name].set_count(amount)
            old_demands[name] = amount
            remaining -= amount
        
        var receiver_demand = line_receivers.reduce(func(acc, n): return acc+demands[n], 0.0)
        var is_zero_receiver = is_zero_approx(receiver_demand)
        var diff_ratio = remaining/receiver_demand if !is_zero_receiver else 0.0
        
        var rem_mult = clampf(diff_ratio, 0.0, 1.0)
        rem_mult = 1.0 if is_equal_approx(rem_mult,1.0) else rem_mult
        #at this point i don't really know _why_ exactly remap does the thing.
        var diff = remap(absf(1.0-clampf(diff_ratio, 0.0, 2.0)), 0.0, 1.0, 1e-14, 1.0)
        if (diff_ratio >= 1.0 || is_zero_receiver) && multi < 1.0:
            multi = clampf(0.5*(multi+multi*(1.0+diff)), 1e-14, 1.0)
        elif diff_ratio < 1.0 && !is_zero_receiver:
            multi = clampf(0.5*(multi+multi*(1.0-diff)), 1e-14, 1.0)
        
        #no point in looking at something like 1-1e-14 < 1.0
            
        for name in line_receivers:
            var amount = demands[name]*rem_mult
            window_data[name].set_count(amount)
            remaining -= amount
        
        
        state.demand = start_remaining/multi if multi < 1.0 else count-remaining
        
        remaining = 0.0 if start_remaining/demand < 1.0 else clampf(remaining, 0.0, INF)
    
    state.merge({
        "demand" = demand,
        "multiplier" = multi,
        "old_demands" = old_demands,
    }, true)
    
    return remaining 

func _set_managers(remaining: float, demands: Dictionary, state: Dictionary) -> float:
    if is_zero_approx(remaining):
        return 0.0
    
    var summary = managers.reduce(func(acc, n): return acc+demands[n], 0.0)
    var ratio = summary/remaining if !is_zero_approx(remaining) else 0.0
    for name in managers:
        var data = window_data[name]
        var amount = min(data.get_demand()*ratio, remaining)
        data.set_count(amount)
        remaining -= amount
    
    state.demand = state.get_or_add("demand",0.0)+summary
    
    return clampf(remaining, 0.0, INF)
        
 
func _set_storages(remaining: float) -> void:
    for name in storages:
        var data = window_data[name]
        data.set_count(remaining*data.provided.size()/storage_connections)
        
func _exit_tree() -> void:
    window_graph.release_filter_depth(self, 0)
