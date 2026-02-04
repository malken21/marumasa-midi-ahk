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
