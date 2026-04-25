extends Node

const MOD_DIR := "kuuk-SmartThreadManager"
const LOG_NAME := "kuuk:STM:Main"

var mod_dir_path := ""
var translations_dir_path := ""
var windows_dir_path := ""

var instances: Dictionary

static func sanitize_semantics(in_array: Array)->Array:
    var regex = RegEx.create_from_string("^([0-9]*)(\\.[0-9]*)*$")
    return in_array.filter(func(item)->bool: return regex.search(item) != null)

static func _get_compat_array(manifest: Dictionary)->Array:
    return sanitize_semantics(manifest.get("extra", {})\
        .get("compatible_game_version", "")\
        .split(",", false))
        
static func is_good_version(manifest: Dictionary)->bool:
    var project_ver = ProjectSettings.get_setting("application/config/version", "0.0.0")
    return _get_compat_array(manifest).any(func(item: String)->bool: return item == project_ver)
    

func _init() -> void:
    mod_dir_path = ModLoaderMod.get_unpacked_dir().path_join(MOD_DIR)
    windows_dir_path = "../../"+mod_dir_path.trim_prefix("res://").path_join("scenes/windows")
    
    var manifest:Dictionary = JSON.parse_string(FileAccess.get_file_as_string(mod_dir_path+"/manifest.json"))
    
    if !is_good_version(manifest):
        ModLoaderLog.warning("Game version is incompatible, yet allowed mod to load. Expect anything.", LOG_NAME)
        
    _add_translations()
    ModLoaderLog.info("Translation test: %s" % tr("MODNAME_READY_TEXT"), LOG_NAME)    
    
    ModLoaderLog.success("Initialized, version: %s" % manifest.get("version_number", "0.0.0"), LOG_NAME)
    

    
    


func _ready() -> void:
    ModLoaderLog.info("Post-init window registration started...", LOG_NAME)
    if !has_node("/root/Data"):
        ModLoaderLog.error("No data singleton found. Loading process stopped.", LOG_NAME)
    else:
        _add_to_data()
        

func _add_translations() -> void:
    translations_dir_path = mod_dir_path.path_join("translations")
    for name in Array(DirAccess.get_files_at(translations_dir_path)).filter(func(s: String): return s.ends_with(".translation")):
        ModLoaderMod.add_translation(translations_dir_path.path_join(name))    

func _add_to_data() -> void:
    var success: bool = true
    
    var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(mod_dir_path.path_join("data/stm_data.json")))
    for key in data.keys():
        for entry in data[key].keys():
            if !Data[key].has(data[key][entry]):
                Data[key][entry] = data[key][entry]
            else:
                ModLoaderLog.error("Data."+key+"."+entry+" already exists. Did not overwrite.", LOG_NAME)
                success = false
    if success:
        if data.keys().has("windows"):
            for entry in data.windows.keys():
                if !Attributes.window_attributes.has(entry):
                    Attributes.window_attributes[entry] = {}
                    for attr_name: String in Data.windows[entry].attributes:
                        Attributes.window_attributes[entry][attr_name] = Attribute.new(Data.windows[entry].attributes[attr_name])        
        else:
            ModLoaderLog.error("Attributes window entry exists already. Did not overwrite.", LOG_NAME)
            success = false
    
    if success:
        ModLoaderLog.success("Registered window", LOG_NAME)
    else:
        ModLoaderLog.error("Error registering window", LOG_NAME)
