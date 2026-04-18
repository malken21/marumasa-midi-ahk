#Requires AutoHotkey v2

global appConfig

configFileName := A_ScriptDir . "\MidiToMacro.ini"

Class MidiToMacroConfig {
	__New() {
		this.maxLogLines := 10
		this.midiInDevice := -1
		this.midiInDeviceName := ""
		this.showOnStartup := true
		this.discordClientId := "YOUR_CLIENT_ID"
		this.discordClientSecret := "YOUR_CLIENT_SECRET"
		this.discordAccessToken := ""
	}
}

appConfig := MidiToMacroConfig()

ReadConfig() {
	if (FileExist(configFileName)) {
		appConfig.maxLogLines := IniRead(configFileName, "Settings", "MaxLogLines", 10)
		appConfig.midiInDevice := IniRead(configFileName, "Settings", "MidiInDevice", -1)
		appConfig.midiInDeviceName := IniRead(configFileName, "Settings", "MidiInDeviceName", "")
		appConfig.showOnStartup := IniRead(configFileName, "Settings", "ShowOnStartup", true)
		appConfig.discordClientId := IniRead(configFileName, "Settings", "DiscordClientId", "YOUR_CLIENT_ID")
		appConfig.discordClientSecret := IniRead(configFileName, "Settings", "DiscordClientSecret", "YOUR_CLIENT_SECRET")
		appConfig.discordAccessToken := IniRead(configFileName, "Settings", "DiscordAccessToken", "")
	}
}

WriteConfigDiscordToken(accessToken) {
	IniWrite(accessToken, configFileName, "Settings", "DiscordAccessToken")
	appConfig.discordAccessToken := accessToken
}

WriteConfigMidiDevice(midiInDevice, midiInDeviceName) {
	IniWrite(midiInDevice, configFileName, "Settings", "MidiInDevice")
	IniWrite(midiInDeviceName, configFileName, "Settings", "MidiInDeviceName")
	appConfig.midiInDevice := midiInDevice
	appConfig.midiInDeviceName := midiInDeviceName
}

WriteConfigShowOnStartup(showOnStartup) {
	IniWrite(showOnStartup, configFileName, "Settings", "ShowOnStartup")
	appConfig.showOnStartup := showOnStartup
}
