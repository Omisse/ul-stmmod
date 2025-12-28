class_name STMOutputResourceContainer extends "res://scenes/resource_container.gd"

var demand: float = 0.0

func _ready() -> void:
    super()
    update_connections()


func update_connections() -> void:
    super()
    demand = 0.0

func tick() -> void :
    #vanilla
    for i: ResourceContainer in looping:
        i.count = 0
    
    var remaining: float = count
    var consumer_containers = transfer.filter(_is_consumer)
    var unlimited_containers = transfer.filter(func(a): return !_is_consumer(a))
    demand = consumer_containers.reduce(func(accum: float, next: ResourceContainer) -> float: return accum+_get_demand(next), 0.0)
    
    var split_multiplier = clampf(remaining/demand, 0.0, 1.0)
    if is_zero_approx(demand) || demand <= 0.0:
        consumer_containers.clear()
        
    for i: ResourceContainer in consumer_containers:
        var window = _get_window(i)
        var amount: float = 0.0
        var single_demand: float = _get_demand(i)
        
        amount = split_multiplier*single_demand
        i.count = amount
        remaining -= amount   
    
    for i: ResourceContainer in unlimited_containers:
        i.count = remaining / unlimited_containers.size()

func _get_window(w) -> Node:
    # small optimization to avoid node->parent travels every tick
    if !w.has_meta("parent_window"):
        var node = w as Node
        while !node.is_in_group("window"):    
            node = node.get_parent()
        w.set_meta("parent_window", node)
    
    return w.get_meta("parent_window")

func _is_limited(c: ResourceContainer) -> bool:
    return c.limit >= 0

func _is_unlimited_consumer(c: ResourceContainer) -> bool:
    return _get_input_containers(_get_window(c), "clock_speed").size() > 0

func _is_consumer(c: ResourceContainer) -> bool:
    return _is_limited(c) || _is_unlimited_consumer(c)

func _get_operation_count(c: ResourceContainer) -> float:
    var result := 0.0
    var is_first: bool = true
    #dont count limited here since their opcount == 0, but goal is the limit
    if _is_unlimited_consumer(c):
        var containers = _get_input_containers(_get_window(c), "clock_speed")
        for container: ResourceContainer in containers:
            var divisor = container.required if !(container.required <= 0.0 || is_zero_approx(container.required)) else 1.0
            if is_first:
                result = container.production / divisor
                is_first = false
            else:
                result = min(container.production / divisor, result)
    #else result = 0.0
    return result

func _get_goal(c: ResourceContainer) -> float:
    if _is_limited(c):
        return c.limit
    elif _is_unlimited_consumer(c):
        # all such consumers i've seen had "goal" property. May change in the next updates
        return _get_window(c).goal
    else:
        return 0.0

func _get_demand(c: ResourceContainer) -> float:
    return _get_operation_count(c)*_get_goal(c)

func _get_children_deep_flat(n: Node) -> Array:
    var children = n.get_children()
    for child:Node in children:
        children.append_array(_get_children_deep_flat(child).filter(func(c): return !children.has(c)))
    return children

func _get_children_in_group(n: WindowContainer, g: String) -> Array:
    return _get_children_deep_flat(n).filter(func(c): return c.is_in_group(g))

func _get_input_containers(w: Node, exclude_resource: String = "") -> Array:
    # yes i keep meta in other instances. What now?
    if !w.has_meta("input_containers"):
        w.set_meta("input_containers", _get_children_in_group(w, "input"))        
    return w.get_meta("input_containers").filter(func(i) -> bool: return (i.resource != exclude_resource))
