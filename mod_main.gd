extends Node

const MOD_DIR := "kuuk-SmartThreadManager"
const LOG_NAME := "kuuk:STM:Main"

var mod_dir_path := ""
var translations_dir_path := ""
var windows_dir_path := ""

var instances: Dictionary


func _init() -> void:    
    mod_dir_path = ModLoaderMod.get_unpacked_dir().path_join(MOD_DIR)
    windows_dir_path = "../../"+mod_dir_path.trim_prefix("res://").path_join("scenes/windows")
    
    _add_translations()
    var version = JSON.parse_string(FileAccess.get_file_as_string(mod_dir_path+"/manifest.json")).version_number
    if version == null: version = "unknown"
    
    ModLoaderLog.success("Initialized, version: %s" % version, LOG_NAME)


func _ready() -> void:
    
    if !has_node("/root/Data"):
        ModLoaderLog.error("No data singleton found!", LOG_NAME)
        return
    _add_to_data()
    
    ModLoaderLog.info(tr("MODNAME_READY_TEXT"), LOG_NAME)

func _add_translations() -> void:
    translations_dir_path = mod_dir_path.path_join("translations")
    for name in Array(DirAccess.get_files_at(translations_dir_path)).filter(func(s: String): return s.ends_with(".translation")):
        ModLoaderMod.add_translation(translations_dir_path.path_join(name))    

func _add_to_data() -> void:
    const entry_name = "smart_thread_manager"
    const node_name = "window_smart_thread_manager"
    
    if !Data.windows.has(entry_name):
        Data.windows[entry_name] = {
            "name": node_name,
            "icon": "brain",
            "description": "window_stm_desc",
            "scene": windows_dir_path.path_join(node_name),
            "group": "",
            "category": "cpu",
            "sub_category": "management",
            "level": 0,
            "requirement": "perk.thread_manager",
            "hidden": true,
            "attributes":{
                "limit": -1
            },
            "data": {},
            "guide": node_name
        }
    else:
        ModLoaderLog.warning("Data window entry exists already.", LOG_NAME)
    if !Data.guides.has(node_name):
        Data.guides[node_name] = {
            "name": node_name,
            "icon": "brain",
            "type": 1,
            "entries":[
                {"text": "guide_"+node_name, "level": 0, "requirement": "perk.thread_manager"},
                {"text": "guide_"+node_name+"_chaining", "level": 0, "requirement": "perk.thread_manager"},
                {"text": "guide_"+node_name+"_ratio", "level": 0, "requirement": "perk.thread_manager"},
                {"text": "guide_"+node_name+"_demand", "level": 0, "requirement": "perk.thread_manager"},
                {"text": "guide_"+node_name+"_graph", "level": 0, "requirement": "perk.thread_manager"},
            ]
        }
    else:
        ModLoaderLog.warning("Data guide entry exists already.", LOG_NAME)
    
    if !Attributes.window_attributes.has(entry_name):
        Attributes.window_attributes[entry_name] = {}
        for attr_name: String in Data.windows[entry_name].attributes:
            var attr_value = Data.windows[entry_name].attributes[attr_name]
            Attributes.window_attributes[entry_name][attr_name] = Attribute.new(attr_value)
    else:
        ModLoaderLog.warning("Attributes window entry exists already", LOG_NAME)
        
    ModLoaderLog.info("Registered window", LOG_NAME)
