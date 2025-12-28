extends WindowIndexed

@onready var input: = $PanelContainer / MainContainer / Input
@onready var output: = $PanelContainer / MainContainer / Output0 / ResourceContainer
@onready var progress_bar = $PanelContainer / MainContainer / Progress / ProgressBar
@onready var demand_label = $PanelContainer / MainContainer / Progress / ProgressContainer / DemandsLabel
@onready var percent_label = $PanelContainer / MainContainer / Progress / ProgressContainer / PercentLabel


func _ready() -> void :
    super()
    output.set_resource(input.resource)


func process(delta: float) -> void :
    output.count = input.count
    var progress_value = input.count / output.demand if !is_zero_approx(output.demand) else 0.0
    progress_bar.value = lerpf(progress_bar.min_value, progress_bar.max_value, progress_value)
    demand_label.text = Utils.print_string(input.count)+input.suffix+"/"+Utils.print_string(output.demand)+output.suffix
    percent_label.text = Utils.print_string(100.0*progress_value, false)+"%"
    
    

# Remains of the base code, never seen it being called
func _on_input_resource_set() -> void :
    output.set_resource(input.resource)
    ModLoaderLog.debug("Resource set", "kuuk-SmartThreadManager:window_smart_thread_manager")

func export() -> Dictionary:
    var dict = super()
    dict["filename"] = "../../".path_join(ModLoaderMod.get_mod_data("kuuk-SmartThreadManager").dir_path.trim_prefix("res://")).path_join("scenes/windows/window_smart_thread_manager.tscn")
    return dict

func save() -> Dictionary:
    var dict = super()
    dict["filename"] = "../../".path_join(ModLoaderMod.get_mod_data("kuuk-SmartThreadManager").dir_path.trim_prefix("res://")).path_join("scenes/windows/window_smart_thread_manager.tscn")
    return dict
