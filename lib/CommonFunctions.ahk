#Requires AutoHotkey v2

ConvertCCValueToScale(value, minimum_value, maximum_value) {
	if (value > maximum_value) {
		value := maximum_value
	} else if (value < minimum_value) {
		value := minimum_value
	}
	return (value - minimum_value) / (maximum_value - minimum_value)
}

ResizeWindowUnderMouse(width, height) {
    MouseGetPos , , &hwnd
    if (hwnd) {
        try {
            WinMove(, , width, height, hwnd)
            ToolTip "Window resized to " width "x" height
            SetTimer () => ToolTip(), -1000
        } catch as err {
            ToolTip "Error resizing window: " err.Message
            SetTimer () => ToolTip(), -2000
        }
    }
}

ToggleBorderlessUnderMouse() {
    static WindowStates := Map()
    MouseGetPos , , &hwnd
    if (!hwnd) {
        ToolTip "Error: No window found under mouse"
        SetTimer () => ToolTip(), -1000
        return
    }

    if (WindowStates.Has(hwnd)) {
        ; Restore
        try {
            WinSetStyle("+0xC00000", hwnd) ; WS_CAPTION
            if (WindowStates[hwnd].Has("ThickFrame")) {
                WinSetStyle("+0x40000", hwnd) ; WS_SIZEBOX
            }
            WinRedraw(hwnd)
            WindowStates.Delete(hwnd)
            ToolTip "Window borders restored"
        } catch as err {
            ToolTip "Error restoring: " err.Message
        }
    } else {
        ; Go Borderless
        try {
            style := WinGetStyle(hwnd)
            if (style & 0xC00000) { ; WS_CAPTION
                savedState := Map()
                savedState["Style"] := style
                
                ; Check and remove sizing border too for true borderless feel
                if (style & 0x40000) {
                     savedState["ThickFrame"] := true
                     WinSetStyle("-0x40000", hwnd) ; WS_SIZEBOX
                }

                WindowStates[hwnd] := savedState
                WinSetStyle("-0xC00000", hwnd)
                WinRedraw(hwnd)
                ToolTip "Window borders removed"
            } else {
                ToolTip "Window is already borderless (Style: " Format("0x{:X}", style) ")"
            }
        } catch as err {
            ToolTip "Error setting borderless: " err.Message
        }
    }
    SetTimer () => ToolTip(), -2000
}
