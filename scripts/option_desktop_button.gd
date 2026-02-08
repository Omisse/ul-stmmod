extends OptionButton

@export var click_disabled: bool

var dragged: bool
var cancel_press: bool



const kdrag_len_squared = 10000
# ALL OF THE LINES BELOW ARE SCARY VANILLA CODE THAT I DO NOT UNDERSTAND
# I JUST HIT IT WITH A STICK UNTIL IT WORKS AS I WANT IT TO IN SOME WAY

# i have no gui coding experience pls have mercy

func _init() -> void :
    button_mask = 0
    mouse_force_pass_scroll_events = false
    toggle_mode = true

func _toggled(toggled_on: bool) -> void:
    if toggled_on:
        show_popup()
        button_down.emit()
    else:
        get_popup().hide()
        button_up.emit()

func handle_drag_input(event: InputEvent) -> void :
    dragged = dragged or event.velocity.length_squared() >= kdrag_len_squared
    self.button_pressed = !dragged
    
func _gui_input(event: InputEvent) -> void :
    if event.device == -1: return
    if event is InputEventScreenTouch:
        get_viewport().gui_release_focus()
        if event.index == 0:
            button_pressed = event.is_pressed()
            if event.is_pressed():
                button_down.emit()
            elif event.is_released():
                if !dragged and (click_disabled or !disabled) and !cancel_press:
                    pressed.emit()
                dragged = false
                button_up.emit()
                return
    elif event is InputEventMouseButton:
        get_viewport().gui_release_focus()
        if event.button_index == MOUSE_BUTTON_LEFT:
            button_pressed = event.is_pressed()
            if event.is_pressed():
                button_down.emit()
            elif event.is_released():
                if !dragged:
                    pressed.emit()
                dragged = false
                button_up.emit()
                return
    elif event is InputEventScreenDrag:
        if event.index == 0:
            handle_drag_input(event)
    elif event is InputEventMouseMotion:
        if event.button_mask == MOUSE_BUTTON_LEFT:
            handle_drag_input(event)

    Signals.unhandled_input.emit(event, global_position)
