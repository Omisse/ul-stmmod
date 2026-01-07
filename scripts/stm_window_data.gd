class_name STMWindowData extends Object
var window: WindowBase
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
    return get_min_prod()*get_goal()

func set_count(value: float) -> void:
    for source in own_sources:
        source.count = value/own_sources.size()
    
func get_min_prod() -> float:
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

func get_max_prod() -> float:
    if inputs_filtered.values().size() == 0:
        return 0.0
    
    return inputs_filtered.values().map(func(cd: InputContainerData): return cd.get_prod()).reduce(max)

func get_goal() -> float:
    return window.goal if "goal" in window else 0.0

func update():
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
    
