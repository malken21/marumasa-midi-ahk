#Requires AutoHotkey v2
#SingleInstance
#Warn
Persistent()

#Include lib\Config.ahk
#Include lib\Gui.ahk
#Include lib\DiscordRPC.ahk

global rpc

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

InitDiscord() {
    global rpc, appConfig

    if (appConfig.discordClientId == "YOUR_CLIENT_ID") {
        AppendMidiOutputRow("Discord", "Client ID not set")
        return
    }

    rpc := DiscordRPC(appConfig.discordClientId)

    ; イベントハンドラの設定
    rpc.On("READY", (data) => (
        rpc.user := data.user,
        AppendMidiOutputRow("Discord", "Ready: " . data.user.username)
    ))
    rpc.On("ERROR", (data) => AppendMidiOutputRow("Discord", "Error: " . (data.HasProp("message") ? data.message : JSON.Stringify(data))))
    rpc.On("DISCONNECTED", (msg) => (rpc.isAuthenticated := false, AppendMidiOutputRow("Discord", "Disconnected: " . msg)))

    ; AUTHENTICATE 成功ハンドラ
    rpc.On("AUTHENTICATE", (data) => (
        rpc.isAuthenticated := true,
        rpc.user := data.user,
        WriteConfigDiscordToken(appConfig.discordAccessToken),
        AppendMidiOutputRow("Discord", "Authenticated: " . data.user.username)
    ))

    ; SET_VOICE_SETTINGS レスポンスハンドラ（デバッグ用）
    rpc.On("SET_VOICE_SETTINGS", (data) => (
        AppendMidiOutputRow("Discord", "Mute: " . (data.HasProp("mute") ? (data.mute ? "ON" : "OFF") : "?"))
    ))

    ; AUTHORIZE 成功ハンドラ（Example.ahk 準拠、イベント名は AUTHORIZE が正しい）
    rpc.On("AUTHORIZE", (data) => (
        AppendMidiOutputRow("Discord", "Authorized, getting token..."),
        _AuthorizeCallback(data)
    ))

    _AuthorizeCallback(data) {
        if (!data.HasProp("code")) {
            AppendMidiOutputRow("Discord", "Authorize: no code in response")
            return
        }
        res := rpc.ExchangeCodeForToken(data.code, appConfig.discordClientSecret)
        if (res.HasProp("access_token")) {
            appConfig.discordAccessToken := res.access_token
            WriteConfigDiscordToken(res.access_token)
            rpc.Authenticate(res.access_token)
            AppendMidiOutputRow("Discord", "Token saved and authenticating...")
        } else {
            AppendMidiOutputRow("Discord", "Token exchange failed: " . (res.HasProp("error") ? res.error : "Unknown error"))
        }
    }

    if (!rpc.Connect()) {
        AppendMidiOutputRow("Discord", "Failed to connect to PIPE")
        return
    }
    AppendMidiOutputRow("Discord", "Connected to PIPE. Waiting for READY...")

    ; Example.ahk 準拠: Connect 後 500ms 遅延でトークン認証（READY より先に試みる）
    SetTimer(() => _TryAuthenticate(), -500)

    _TryAuthenticate() {
        if (!rpc || !rpc.hPipe)
            return
        if (appConfig.discordAccessToken) {
            AppendMidiOutputRow("Discord", "Auto-authenticating with saved token...")
            rpc.Authenticate(appConfig.discordAccessToken)
        } else {
            AppendMidiOutputRow("Discord", "No token. Requesting authorization...")
            rpc.Authorize(["rpc", "rpc.voice.read", "rpc.voice.write"])
        }
    }
}

ResetDiscordToken(*) {
    global rpc, appConfig
    WriteConfigDiscordToken("")
    appConfig.discordAccessToken := ""
    if (IsSet(rpc)) {
        rpc.Close()
    }
    AppendMidiOutputRow("Discord", "Token reset. Re-authorizing...")
    InitDiscord()
}

Main() {
	global appConfig, currentMidiInputDeviceIndex
	OnExit(CloseMidiInput)
	A_TrayMenu.Add() ; Add a menu separator line
	A_TrayMenu.Add("Show on Startup", ToggleShowOnStartup)
	A_TrayMenu.Add("MIDI Monitor", ShowMidiMonitor)
	A_TrayMenu.Add("Reset Discord Token", ResetDiscordToken)
	ReadConfig()
	wasMidiOpened := MaybeOpenMidiInput()
    
    InitDiscord()

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
