#class_name STMDistribution extends Object
static func distribution_ratio(value: float, state: Dictionary):
    var wdata = state.wdata #mutable
    var demands = state.demands #const
    
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
    distribution_ratio(value, state)
    
    _state_average_demands(state)
    state.demand = _get_demand_sum(state.demands)
    
    if is_zero_approx(value):
        for wd in state.wdata.values():
            wd.set_count(0.0)
            return
            
    _set_storages(_set_targets_demand(value, state), state)

    
static func distribution_graph(value: float, state: Dictionary) -> void:
    _state_average_demands(state)
    state.demand = _get_demand_sum(state.demands)
    var consumers = state.consumers
    
    var remaining = value
    
    remaining = _set_targets_graph(remaining, state)
    
    _set_storages(remaining, state)
    






static func _set_targets_demand(value: float,  state: Dictionary):
    var wdata = state.wdata #mutable
    var demands = state.demands #const
    var targets = state.consumers+state.managers #const
    var key_multipliers = state.get_or_add("key_multipliers", {})
    var old_amounts = state.get_or_add("old_amounts", {})
    var remaining = value
    
    if is_zero_approx(value):
        for name in targets:
            wdata[name].set_count(0.0)
        return 0.0
    
    targets.sort_custom(func(a,b): return demands[a] < demands[b])
    
    var unsaturated = []
    
    for name:StringName in targets:
        if (demands[name] < remaining):
            #saturated
            wdata[name].set_count(demands[name])
            remaining-=demands[name]
        else:
            if is_zero_approx(demands[name]):
                wdata[name].set_count(0.0)
                continue
            #unsaturated
            var multiplier = key_multipliers.get_or_add(name, 1.0)
            var suggested = demands[name]*multiplier
            var old = old_amounts.get_or_add(name, 0.0)
            var max = max(old, suggested)
            var change_rate = remap(absf(suggested-old)/max if max > 0.0 else 1.0, 0.0, 1.0, 1e-14, 1e-1)
            var amount = min(remaining, suggested)
            
            if amount == remaining:
                if name != targets.back():
                    amount *= 0.9
                key_multipliers[name] = clampf(multiplier-multiplier*change_rate, 1e-14, 1.0)
            else:
                key_multipliers[name] = clampf(multiplier+multiplier*change_rate, 1e-14, 1.0)
                
            wdata[name].set_count(amount)
            remaining-=amount
            old_amounts[name] = suggested
    
    return 0.0 if value < state.demand else clampf(remaining, 0.0, INF)









static func _set_targets_graph(remaining: float, state: Dictionary) -> float:
    var multi = state.get_or_add("multiplier", 1.0)
    
    var demands = state.demands #const
    var wdata = state.wdata #mutable
    var line_suppliers = state.get_or_add("line_suppliers", []) #const
    var line_receivers = state.get_or_add("line_receivers", []) #const
    
    if is_zero_approx(remaining):
        for name in state.get_or_add("targets", state.consumers+state.managers):
            wdata[name].set_count(0)
    else:
        var start_remaining = remaining
        #fill the start of our line, that thing will affect everything else
        for name in line_suppliers:
            var amount = min(remaining, demands[name]*multi)
            wdata[name].set_count(amount)
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
            
        for name in line_receivers:
            var amount = min(remaining,demands[name]*rem_mult)
            wdata[name].set_count(amount)
            remaining -= amount
        
        if multi < 1.0:
            state.demand = start_remaining/multi
            remaining = 0.0
        remaining = clampf(remaining, 0.0, INF)
    
    state.multiplier = multi
    
    return remaining        
 




static func _set_storages(remaining: float, state: Dictionary) -> void:
    var storages = state.storages #const
    var wdata = state.wdata #mutable
    var connections = state.storage_connections #const
    
    for name in storages:
        var data = wdata[name]
        data.set_count(remaining*data.provided.size()/connections)
        
        
        
        
        
        
        

static func _state_average_demands(state: Dictionary) -> void:
    const step = 0.5
    
    var old = state.get_or_add("old_demands", {})
    var current = state.get_or_add("demands", {})
    
    for key in current:
        current[key] = lerpf(old.get_or_add(key, 0.0), current[key], step)
        old[key] = current[key]
    

static func _get_demand_sum(demands: Dictionary) -> float:
    return demands.values().reduce(_sum_acc, 0.0)

static func _sum_acc(acc: float, val: float) -> float:
    return acc+val
