extends Node

# ! == extra info
# == modtool "must keep" info (still just a comment)
# ? == modtool asked for me to say something

const MOD_DIR := "kuuk-SmartGPUManager" # Name of the directory that this file is in
const LOG_NAME := "kuuk-SmartGPUManager:Main" # Full ID of the mod (AuthorName-ModName)

var mod_dir_path := ""
var translations_dir_path := ""
var windows_dir_path := ""


func _init() -> void:    
    mod_dir_path = ModLoaderMod.get_unpacked_dir().path_join(MOD_DIR)
    translations_dir_path = mod_dir_path.path_join("translations")
    windows_dir_path = "../../"+mod_dir_path.trim_prefix("res://").path_join("scenes/windows")
    
    # Add translations    
    
    ModLoaderMod.add_translation(translations_dir_path.path_join("SmartGPUManager.en.translation"))
    
    var version = JSON.parse_string(FileAccess.get_file_as_string(mod_dir_path+"/manifest.json")).version_number
    if version == null: version = "unknown"
    
    ModLoaderLog.success("Initialized, version: %s" % version, LOG_NAME)
    
    

    

    
func _ready() -> void:
    if !has_node("/root/Data"):
        ModLoaderLog.error("No data singleton found!", LOG_NAME)
        return
    _add_to_data()    
    # literally no one asked for this
    ModLoaderLog.info("Translation Demo: " + tr("sgm_main_ready"), LOG_NAME)

func _add_to_data() -> void:
    var node_name: String = "smart_gpu_manager"
    var window_name: String = "window_%s" % node_name
    if !Data.windows.has(node_name):
        Data.windows[node_name] = {
            "name": window_name,
            "icon": "brain",
            "description": "window_sgm_desc",
            "scene": windows_dir_path.path_join(window_name),
            "group": "",
            "category": "gpu",
            "sub_category": "management",
            "level": 0,
            "requirement": "research.gpu_manager",
            "hidden": true,
            "attributes":{
                "limit": -1
            },
            "data": {},
            "guide": ""
        }
    else:
        ModLoaderLog.error(node_name+" already exists in Data", LOG_NAME)
    
    if !Attributes.window_attributes.has(node_name):
        Attributes.window_attributes[node_name] = {}
        for attr_name: String in Data.windows[node_name].attributes:
            var attr_value = Data.windows[node_name].attributes[attr_name]
            Attributes.window_attributes[node_name][attr_name] = Attribute.new(attr_value)
    else:
        ModLoaderLog.error(node_name+" already exists in Attributes", LOG_NAME)
        
    ModLoaderLog.success("window registered: %s" % node_name, LOG_NAME)
