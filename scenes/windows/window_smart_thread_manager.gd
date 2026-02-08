extends WindowIndexed

@onready var input = $PanelContainer / MainContainer / Input
@onready var output = $PanelContainer / MainContainer / Output
@onready var progress_bar = $PanelContainer / MainContainer / Progress / ProgressBar
@onready var demand_label = $PanelContainer / MainContainer / Progress / ProgressContainer / DemandsLabel
@onready var percent_label = $PanelContainer / MainContainer / Progress / ProgressContainer / PercentLabel
@onready var mode_button = $OptionButton
@onready var use_count_button = $PanelContainer / MainContainer / UseCountButton

var demand:
    get():
        return output.demand
        
var container_mode = 1:
    get:
        if "distribution_mode" in output:
            return output.get("distribution_mode")
        return container_mode
    set(value):
        container_mode = value
        #set on load
        if !is_node_ready():
            ready.connect(func(): container_mode = value, CONNECT_ONE_SHOT)
            ready.connect(func(): mode_button.select(mode_button.get_item_index(value)), CONNECT_ONE_SHOT)
            return
        if "distribution_mode" in output:
            if output.distribution_mode != value:
                output.set("distribution_mode", value)
            
var use_count: bool = false:
    get:
        if "use_count" in output:
            return output.use_count
        return use_count
    set(value):
        #set_on_load
        use_count = value
        if !is_node_ready():
            ready.connect(func(): use_count = value, CONNECT_ONE_SHOT)
            ready.connect(func(): use_count_button.button_pressed = value, CONNECT_ONE_SHOT)
            ready.connect(usecount_set_button_text.bind(value))
            return
        if "use_count" in output:
            output.use_count = value

func _ready() -> void:
    super()
    if "use_count" in output:
        output.use_count = use_count
    if "distribution_mode" in output:
        output.distribution_mode = container_mode    

func process(delta: float) -> void :
    output.count = input.count
    var progress_value = input.count / demand if !is_zero_approx(demand) else 0.0
    progress_bar.value = lerpf(progress_bar.min_value, progress_bar.max_value, progress_value)
    demand_label.text = Utils.print_string(input.count)+input.suffix+"/"+Utils.print_string(demand)+output.suffix
    percent_label.text = Utils.print_string(100.0*progress_value, false)+"%"
    
    
# Thats actually a thing about files with different types etc.
func _on_input_resource_set() -> void :
    output.set_resource(input.resource)


func export() -> Dictionary:
    var dict = super()
    dict["filename"] = "../../".path_join(ModLoaderMod.get_mod_data("kuuk-SmartThreadManager").dir_path.trim_prefix("res://")).path_join("scenes/windows/window_smart_thread_manager.tscn")
    dict["container_mode"] = container_mode
    dict["use_count"] = use_count
    return dict

func save() -> Dictionary:
    var dict = super()
    dict["filename"] = "../../".path_join(ModLoaderMod.get_mod_data("kuuk-SmartThreadManager").dir_path.trim_prefix("res://")).path_join("scenes/windows/window_smart_thread_manager.tscn")
    dict["container_mode"] = container_mode
    dict["use_count"] = use_count
    return dict


func _on_option_button_item_selected(index: int) -> void:
    container_mode = mode_button.get_item_id(index)


func _on_use_count_button_toggled(toggled_on: bool) -> void:
    use_count = toggled_on
    usecount_set_button_text(toggled_on)

func usecount_set_button_text(toggle: bool) -> void:
    use_count_button.text =  tr("stm_count_text") if toggle else tr("stm_cps_text")
    
