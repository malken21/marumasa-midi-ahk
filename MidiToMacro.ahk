#Requires AutoHotkey v2
#SingleInstance
#Warn
Persistent()

#Include lib\Config.ahk
#Include lib\Gui.ahk

MaybeOpenMidiInput() {
	global appConfig, currentMidiInputDeviceIndex

	; Try to open the device at the stored index if it matches the name
	if (appConfig.midiInDevice >= 0) {
		deviceName := GetMidiDeviceName(appConfig.midiInDevice)
		if (StrLen(appConfig.midiInDeviceName) == 0 || deviceName == appConfig.midiInDeviceName) {
			OpenMidiInput(appConfig.midiInDevice, OnMidiData)
			return true
		}
	}

	; Fallback: If we have a stored name, search for it among all devices
	if (StrLen(appConfig.midiInDeviceName) > 0) {
		numPorts := DllCall("winmm.dll\midiInGetNumDevs")
		Loop numPorts {
			index := A_Index - 1
			if (GetMidiDeviceName(index) == appConfig.midiInDeviceName) {
				OpenMidiInput(index, OnMidiData)
				; Update config with the new index
				WriteConfigMidiDevice(index, appConfig.midiInDeviceName)
				return true
			}
		}
	}

	return false
}

Main() {
	global appConfig, currentMidiInputDeviceIndex
	OnExit(CloseMidiInput)
	A_TrayMenu.Add() ; Add a menu separator line
	A_TrayMenu.Add("Show on Startup", ToggleShowOnStartup)
	A_TrayMenu.Add("MIDI Monitor", ShowMidiMonitor)
	ReadConfig()
	wasMidiOpened := MaybeOpenMidiInput()
	if (appConfig.showOnStartup) {
		A_TrayMenu.Check("Show on Startup")
	} else {
		A_TrayMenu.Uncheck("Show on Startup")
	}

	if (!wasMidiOpened || appConfig.showOnStartup) {
		ShowMidiMonitor()
	}
}

Main()
