#class_name STMDistribution extends Object
static func distribution_ratio(value: float, state: Dictionary):
    var wdata = state.wdata
    var demands = state.demands
    
    var remaining = value
    var total = demands.values().reduce(func(acc, flt): return acc+flt, 0.0)
    var ratio = clampf(remaining/total, 0.0, 1.0) if !is_zero_approx(total) else 0.0
    for key in demands.keys():
        var amount = demands[key]*ratio
        wdata[key].set_count(amount)
        remaining -= amount
    state.demand = total
    _set_storages(clampf(remaining, 0.0, INF), state)
    
    
static func distribution_demand(value: float, state: Dictionary):
    state.demand = state.demands.values().reduce(func(acc, flt): return acc+flt, 0.0)
    
    if is_zero_approx(value):
        for wd in state.wdata.values():
            wd.set_count(0.0)
            return
            
    var targets = state.consumers+state.managers
    var remaining = _set_targets_demand(value, state)
    _set_storages(remaining, state)
    
    
static func distribution_graph(value: float, state: Dictionary) -> void:
    var consumers = state.consumers
    
    var remaining = value
    
    if !consumers.is_empty():
        remaining = _set_consumers_graph(remaining, state)
    
    remaining = _set_managers(remaining, state)
    
    _set_storages(remaining, state)
    






static func _set_targets_demand(value: float,  state: Dictionary):
    var wdata = state.wdata
    var demands = state.demands
    var targets = state.get_or_add("targets", state.consumers+state.managers)
    
    if is_zero_approx(value):
        for name in targets:
            wdata[name].set_count(0.0)
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
            
        wdata[name].set_count(amount)
        old_demands[name] = amount
        remaining -= amount
        
    state.merge({
        "key_multipliers": multis,
        "old_demands": old_demands,
    }, true)
    
    return 0.0 if value < state.demand else clampf(remaining, 0.0, INF)








static func _set_consumers_graph(remaining: float, state: Dictionary) -> float:
    var demand = state.get_or_add("demand", 0.0)
    var multi = state.get_or_add("multiplier", 1.0)
    var old_demands = state.get_or_add("old_demands", {})
    
    var demands = state.demands
    var wdata = state.wdata
    var consumers = state.consumers
    var line_suppliers = state.line_suppliers
    var line_receivers = state.line_receivers
    
    if is_zero_approx(remaining):
        for name in consumers:
            wdata[name].set_count(0)
        demand = 0.5*(demand+demands.values().reduce(func(acc, flt): return acc+flt, 0.0))
    else:
        var start_remaining = remaining
        #fill the start of our line, that thing will affect everything else
        for name in line_suppliers:
            var amount = min(remaining, 0.5*(old_demands.get_or_add(name, 0.0)+demands[name]*multi))
            wdata[name].set_count(amount)
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
            wdata[name].set_count(amount)
            remaining -= amount
        
        
        demand = start_remaining/multi if multi < 1.0 else start_remaining-remaining
        remaining = 0.0 if start_remaining/demand < 1.0 else clampf(remaining, 0.0, INF)
    
    state.demand = demand
    state.multiplier = multi
    state.old_demands = old_demands
    
    return remaining

static func _set_managers(remaining: float, state: Dictionary) -> float:
    var managers = state.managers
    var demands = state.demands
    var wdata = state.wdata
    var demand = state.get_or_add("demand", 0.0)
    
    var summary = managers.reduce(func(acc, n): return acc+demands[n], 0.0)  
    var ratio = summary/remaining if !is_zero_approx(remaining) else 0.0
    
    for name in managers:
        var data = wdata[name]
        var amount = min(data.get_demand()*ratio, remaining)
        data.set_count(amount)
        remaining -= amount
    
    state.demand = demand+summary
    
    return clampf(remaining, 0.0, INF)
        
 
static func _set_storages(remaining: float, state: Dictionary) -> void:
    var storages = state.storages
    var wdata = state.wdata
    var connections = state.storage_connections
    
    for name in storages:
        var data = wdata[name]
        data.set_count(remaining*data.provided.size()/connections)
