extends RefCounted

enum STMWindowRoles {
    STM_ARTIFACT,
    STM_CONSUMER,
    STM_STORAGE,
    STM_MANAGER,
}

var window: WindowBase
var inputs: Dictionary[String, ResourceContainer]
var role: STMWindowRoles = STMWindowRoles.STM_ARTIFACT

var provided: Array = []
var dependent: Array = []
var icdata: Dictionary[String, STMContainerData]

func _init(window: WindowBase) -> void:
    self.window = window
    var containers = window.containers\
            .filter(func(c): return c.is_in_group("input"))
    for container in containers:
        inputs.set(container.id, container)
    
    set_containers()
    
    if "demand" in window:
        role = STMWindowRoles.STM_MANAGER
    #dependent.is_empty() is a temporary solution so miners will work
    elif "goal" in window && !dependent.is_empty():
        role = STMWindowRoles.STM_CONSUMER
    elif window.is_in_group("window"):
        role = STMWindowRoles.STM_STORAGE
    else:
        role = STMWindowRoles.STM_ARTIFACT
    
    
    
func set_containers(sources: Array = []) -> void:
    provided = inputs.keys().filter(sources.has)
    dependent = inputs.keys().filter(func(n): return !provided.has(n) && _is_material(inputs[n]))
    for name in provided:
        icdata.erase(name)
    for name in dependent:
        if !icdata.has(name): 
            icdata[name] = STMContainerData.new(inputs[name])
    
func get_demand() -> float:
    if provided.is_empty():
        return 0.0
    if role == STMWindowRoles.STM_MANAGER:
        return window.demand
    return get_min_prod()*get_goal()
    
func get_count_demand() -> float:
    if provided.is_empty():
        return 0.0
    if role == STMWindowRoles.STM_MANAGER:
        return window.demand
    return get_min_count()*get_goal()

func set_count(value: float) -> void:
    var size = provided.size()
    for container in provided.map(func(s): return inputs[s]):
        container.count = value/size
    
func get_min_prod() -> float:
    if dependent.is_empty():
        return 0.0
    if dependent.size() == 1:
        return icdata[dependent[0]].get_prod()
    return dependent.map(func(name): return icdata[name].get_prod()).reduce(min)
    
func get_min_count() -> float:
    if dependent.is_empty():
        return 0.0
    if dependent.size() == 1:
        return icdata[dependent[0]].get_count()
    return dependent.map(func(name): return icdata[name].get_count()).reduce(min)
    

func get_goal() -> float:
    return window.goal if role == STMWindowRoles.STM_CONSUMER else 0.0

func update():
    for cd in icdata.values():
        cd.update()
        
func _is_material(c: ResourceContainer) -> bool:
    return c.type == Utils.resource_types.MATERIAL || c.type == Utils.resource_types.MATERIAL_LIMITED


class STMContainerData extends RefCounted:
    var container: ResourceContainer
    var multiplier: float = 0.0
    
    func _init(c: ResourceContainer) -> void:
        container = c
        multiplier = _get_multi()
    
    func get_prod() -> float:
        return multiplier*container.production
    
    func get_count() -> float:
        return multiplier*container.count
    
    func _get_multi() -> float:
        var divisor = container.required if !is_zero_approx(container.required) else 1.0
        return pow(divisor,-1)
    
    func update() -> void:
        multiplier = _get_multi()
    
