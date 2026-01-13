extends WindowIndexed

@onready var input = $PanelContainer / MainContainer / Input
@onready var output = $PanelContainer / MainContainer / Output
@onready var progress_bar = $PanelContainer / MainContainer / Progress / ProgressBar
@onready var demand_label = $PanelContainer / MainContainer / Progress / ProgressContainer / DemandsLabel
@onready var percent_label = $PanelContainer / MainContainer / Progress / ProgressContainer / PercentLabel
@onready var mode_button = $OptionButton

#would be export but modloader dont care
var default_mode = 1

var demand:
    get():
        return output.demand

var on_load_mode = default_mode

@onready var container_mode:
    get:
        return output.get("distribution_mode")
    set(value):
        on_load_mode = value
        if output.get("distribution_mode") != value:
            output.set("distribution_mode", value)
        
func _ready() -> void:
    super()
    container_mode = on_load_mode
    mode_button.select(mode_button.get_item_index(on_load_mode))
    
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
    dict["on_load_mode"] = on_load_mode
    return dict

func save() -> Dictionary:
    var dict = super()
    dict["filename"] = "../../".path_join(ModLoaderMod.get_mod_data("kuuk-SmartThreadManager").dir_path.trim_prefix("res://")).path_join("scenes/windows/window_smart_thread_manager.tscn")
    dict["on_load_mode"] = on_load_mode
    return dict


func _on_option_button_item_selected(index: int) -> void:
    container_mode = mode_button.get_item_id(index)
