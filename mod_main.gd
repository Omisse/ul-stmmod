extends Node

# ! == extra info
# == modtool "must keep" info (still just a comment)
# ? == modtool asked for me to say something

const MOD_DIR := "kuuk-SmartThreadManager" # Name of the directory that this file is in
const LOG_NAME := "kuuk-SmartThreadManager" # Full ID of the mod (AuthorName-ModName)

var mod_dir_path := ""
var extensions_dir_path := ""
var translations_dir_path := ""
var windows_dir_path := ""


func _init() -> void:    
    mod_dir_path = ModLoaderMod.get_unpacked_dir().path_join(MOD_DIR)
    extensions_dir_path = mod_dir_path.path_join("extensions")
    windows_dir_path = "../../"+mod_dir_path.trim_prefix("res://").path_join("scenes/windows")
    
    # Add extensions

    # Add translations    
    translations_dir_path = mod_dir_path.path_join("translations")
    ModLoaderMod.add_translation(translations_dir_path.path_join("SmartThreadManager.en.translation"))
    
    ModLoaderLog.success("Initialized", LOG_NAME)
    
    var version = JSON.parse_string(FileAccess.get_file_as_string(mod_dir_path+"/manifest.json")).version_number
    if version != null:
        ModLoaderLog.info("Mod version: %s" % version, LOG_NAME)

    

    
func _ready() -> void:
    if !has_node("/root/Data"):
        ModLoaderLog.error("No data singleton found!", LOG_NAME)
        return
    _add_to_data()    
    
    # literally no one asked for this
    # ModLoaderLog.info("Translation Demo: " + tr("MODNAME_READY_TEXT"), LOG_NAME)
    ModLoaderLog.info("Ready", LOG_NAME)

func _add_to_data() -> void:
    if !Data.windows.has("smart_thread_manager"):
        Data.windows["smart_thread_manager"] = {
            "name": "window_smart_thread_manager",
            "icon": "brain",
            "description": "window_stm_desc",
            "scene": windows_dir_path.path_join("window_smart_thread_manager"),
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
            "guide": ""
        }
        ModLoaderLog.debug("Added window to the Data singleton", LOG_NAME)
    
    
    if !Attributes.window_attributes.has("smart_thread_manager"):
        Attributes.window_attributes["smart_thread_manager"] = {}
        for attr_name: String in Data.windows["smart_thread_manager"].attributes:
            var attr_value = Data.windows["smart_thread_manager"].attributes[attr_name]
            Attributes.window_attributes["smart_thread_manager"][attr_name] = Attribute.new(attr_value)
        ModLoaderLog.debug("Initialized window attributes for smart_thread_manager", LOG_NAME)
    ModLoaderLog.success("Added window to the game files", LOG_NAME)
