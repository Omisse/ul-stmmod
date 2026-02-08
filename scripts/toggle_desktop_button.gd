extends DesktopButton

func handle_press_event(event: InputEvent) -> void:
    if event.is_released():
        if !dragged and (click_disabled or !disabled) and !cancel_press:
            button_pressed = !button_pressed
        dragged = false

func _gui_input(event: InputEvent) -> void :
    if event.device == -1: return
    if event is InputEventScreenTouch:
        get_viewport().gui_release_focus()
        if event.index == 0:
            handle_press_event(event)
    elif event is InputEventMouseButton:
        get_viewport().gui_release_focus()
        if event.button_index == MOUSE_BUTTON_LEFT:
            handle_press_event(event)
    elif event is InputEventScreenDrag:
        if event.index == 0:
            handle_drag_input(event)
    elif event is InputEventMouseMotion:
        if event.button_mask == MOUSE_BUTTON_LEFT:
            handle_drag_input(event)

    Signals.unhandled_input.emit(event, global_position)
