extends WindowIndexed

@onready var input: ResourceContainer = $PanelContainer / MainContainer / Input
#kinda need to remove Output0, but it will possibly break a thing or two on clients
@onready var output: SmartResourceContainer = $PanelContainer / MainContainer / Output0 / ResourceContainer
@onready var progress_bar = $PanelContainer / MainContainer / Progress / ProgressBar
@onready var demand_label = $PanelContainer / MainContainer / Progress / ProgressContainer / DemandsLabel
@onready var percent_label = $PanelContainer / MainContainer / Progress / ProgressContainer / PercentLabel

@onready var button_group: ButtonGroup = $PanelContainer/MainContainer/ButtonsMarginContainer/ButtonsContainer/ButtonSimpleScript.button_group
@onready var simple_logic_button: BaseButton = $PanelContainer/MainContainer/ButtonsMarginContainer/ButtonsContainer/ButtonSimpleLogic
@onready var graph_logic_button: BaseButton = $PanelContainer/MainContainer/ButtonsMarginContainer/ButtonsContainer/ButtonGraphLogic

var demand:
    get():
        return output.demand
        
var container_mode: SmartResourceContainer.STMContainerMode = SmartResourceContainer.STMContainerMode.LOGIC_DEFAULT:
    get:
        return output.distribution_mode if output else null
    set(value):
        if output.distribution_mode != value:
            output.distribution_mode = value
        
func _ready() -> void:
    super()
    button_group.pressed.connect(_on_script_button_pressed)
    
func _on_script_button_pressed(button: BaseButton) -> void:
    ModLoaderLog.debug(button.name, "kuuk:STM:STMWindow")
    container_mode = _get_logic(button_group.get_pressed_button())
    
func _get_logic(button: BaseButton) -> SmartResourceContainer.SMTContainerMode:
    match button:
        simple_logic_button:
            return SmartResourceContainer.STMContainerMode.LOGIC_SIMPLE
        graph_logic_button:
            return SmartResourceContainer.STMContainerMode.LOGIC_GRAPH
        _:
            return SmartResourceContainer.STMContainerMode.LOGIC_DEFAULT
    
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
    return dict

func save() -> Dictionary:
    var dict = super()
    dict["filename"] = "../../".path_join(ModLoaderMod.get_mod_data("kuuk-SmartThreadManager").dir_path.trim_prefix("res://")).path_join("scenes/windows/window_smart_thread_manager.tscn")
    return dict
