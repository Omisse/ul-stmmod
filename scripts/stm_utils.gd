class_name STMUtils extends Object

static func get_parent_window(n: Node) -> WindowBase:
        if n == null : return null        
        if !n.has_meta("parent_window"):
            var window = n
            while window && !window.is_in_group("window"):
                window = window.get_parent()
            n.set_meta("parent_window", window)
        return n.get_meta("parent_window", null)
