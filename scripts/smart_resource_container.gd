extends ResourceContainer

const STMWindowGraph = preload("res://mods-unpacked/kuuk-SmartThreadManager/scripts/global/stm_window_graph.gd")
const STMWindowData = preload("res://mods-unpacked/kuuk-SmartThreadManager/scripts/global/stm_window_data.gd")
const STMDistribution = preload("res://mods-unpacked/kuuk-SmartThreadManager/scripts/global/distribution_modes.gd")
const STMUtils = preload("res://mods-unpacked/kuuk-SmartThreadManager/scripts/global/stm_utils.gd")

@export var use_count: bool = false
@export var distribution_mode: STMContainerMode = STMContainerMode.CM_RATIO:
    get:
        return distribution_mode
    set(value):
        distribution_mode = value
        data_changed = true

var demand: float = 0.0
var graph = null

var state:Dictionary = {
    "wdata": {},
    "consumers": [],
    "managers": [],
    "storages": [],
    "storage_connections": 0
}

var state_keep = ["wdata"]        
var data_changed = false


        
var distribution_callable: Callable



enum STMContainerMode {
    CM_RATIO  =0,
    CM_DEMAND =1,
    CM_GRAPH  =2,
}

func _ready() -> void:
    super()
    data_changed = true

func _on_graph_changed() -> void:
    data_changed = true
    
func update_connections() -> void:
    super()
    data_changed = true
    
func tick() -> void:
    # update must _always_ happen before the tick
    if data_changed:
        _update_data()
        _update_callable(distribution_mode)
        data_changed = false
    # vanilla
    for i: ResourceContainer in looping:
        i.count = 0
    
    _update_state_tick()
    
    distribution_callable.call(count, state)
    
    demand = state.get_or_add("demand", 0.0)
    
    
    
    
    
func _update_callable(mode: STMContainerMode):
    match mode:
        STMContainerMode.CM_RATIO:
            distribution_callable = STMDistribution.distribution_ratio
        STMContainerMode.CM_DEMAND:
            distribution_callable = STMDistribution.distribution_demand
        STMContainerMode.CM_GRAPH:
            distribution_callable = STMDistribution.distribution_graph
        

func _clear_state():
    for key in state.keys():
        if !state_keep.has(key):
            state.erase(key)

    
func _update_data() -> void:
    _clear_state()
    _update_windows(state)
    _update_graph(state, distribution_mode == STMContainerMode.CM_GRAPH)
    
func _update_state_tick() -> void:
    state.demands = _get_demands(state)
    
        
func _update_windows(state: Dictionary) -> void:
    _update_wdata(transfer, state.wdata)
    _wdata_set_roles(state)
    
func _update_graph(state: Dictionary, need_graph: bool = true) -> void:
    if !need_graph && graph != null:
        graph.changed.disconnect(_on_graph_changed)
        graph = null
        
    if need_graph && !graph:
        graph = STMWindowGraph.new(STMUtils.get_parent_window(self))
        graph.request_filter_depth(self, 0)
        graph.changed.connect(_on_graph_changed)
    
    if graph:
        _wdata_set_graph_roles(state)
        

func _update_wdata(target_inputs: Array[ResourceContainer], wdata: Dictionary):
    var windows := target_inputs\
            .map(STMUtils.get_parent_window)\
            .filter(func(w): return w!=null)
    
    var ids = target_inputs\
            .map(func(rc: ResourceContainer): return rc.id)
            
    for window in windows:
        wdata\
                .get_or_add(window.name, STMWindowData.new(window))\
                .set_containers(ids)
                
    var names = windows.map(func(w): return w.name)
    for key:StringName in wdata.keys():
        if !names.has(key):
            wdata.erase(key)
        

func _wdata_set_roles(state: Dictionary):
    state.consumers = state.wdata.keys()\
            .filter(func(n):\
                return state.wdata[n].role == STMWindowData.STMWindowRoles.STM_CONSUMER)
    state.managers = state.wdata.keys()\
            .filter(func(n):\
                return state.wdata[n].role == STMWindowData.STMWindowRoles.STM_MANAGER)
    state.storages = state.wdata.keys()\
            .filter(func(n):\
                return state.wdata[n].role == STMWindowData.STMWindowRoles.STM_STORAGE)
                    
    state.storage_connections = state.storages.reduce(func(acc,n:StringName): return acc+state.wdata[n].provided.size(), 0)


func _wdata_set_graph_roles(state: Dictionary) -> void:
    state.line_suppliers = state.consumers\
            .filter(func(n: StringName):\
                return graph.filtered[0][n].suppliers == 0)
    state.line_suppliers.append_array(state.managers.filter(func(n): return !state.line_suppliers.has(n)))
    state.line_receivers = state.consumers\
            .filter(func(n: StringName): return !state.line_suppliers.has(n))
            
func _get_demands(state:Dictionary) -> Dictionary:
    var out = {}
    for cname in state.wdata.keys():
        out[cname] = state.wdata[cname].get_count_demand() if use_count else state.wdata[cname].get_demand()
    return out
