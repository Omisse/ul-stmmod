extends OptionButton

var dragged: bool

# ALL OF THE LINES BELOW ARE SCARY VANILLA CODE THAT I DO NOT UNDERSTAND
# I JUST HIT IT WITH A STICK UNTIL IT WORKS AS I WANT IT TO IN SOME WAY

# i have no gui coding experience pls have mercy

func _init() -> void :
    button_mask = 0
    toggle_mode = true

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch || event.is_released():
        get_viewport().gui_release_focus()
    if event is InputEventScreenTouch:
        if event.index >= 1 || event.is_pressed():
            Signals.movement_input.emit(event, global_position)
            return
        elif event.is_released():
            if !dragged && !disabled:
                self.button_pressed = !button_pressed
            dragged = false
    elif event is InputEventScreenDrag:
        if event.index >= 1:
            Signals.movement_input.emit(event, global_position)
            return
        dragged = dragged or event.velocity.length_squared() >= 10000
        self.button_pressed = !dragged
        Signals.movement_input.emit(event, global_position)
    else:
        Signals.movement_input.emit(event, global_position)


func _toggled(toggled_on: bool) -> void:
    if toggled_on:
        show_popup()
        button_down.emit()
    else:
        get_popup().hide()
        button_up.emit()
