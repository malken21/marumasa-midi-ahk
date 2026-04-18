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

    ; 既存のRPCオブジェクトが存在する場合はプロセスを終了・破棄して初期化する
    if (IsSet(rpc) && rpc) {
        try rpc.Close()
        rpc := ""
    }

    rpc := DiscordRPC(appConfig.discordClientId)

    ; イベントハンドラの設定
    rpc.On("READY", (data) => (
        rpc.user := data.user,
        AppendMidiOutputRow("Discord", "Ready: " . data.user.username)
    ))
    rpc.On("ERROR", (data) => AppendMidiOutputRow("Discord", "Error: " . (data.HasProp("message") ? data.message : JSON.Stringify(data))))
    
    ; 切断時：インスタンス破棄を含む完全な再初期化ルートへ移行
    rpc.On("DISCONNECTED", (msg) => (
        AppendMidiOutputRow("Discord", "Disconnected: " . msg),
        ScheduleDiscordReconnect()
    ))

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

    ; AUTHORIZE 成功ハンドラ
    rpc.On("AUTHORIZE", (data) => (
        AppendMidiOutputRow("Discord", "Authorized, getting token..."),
        _AuthorizeCallback(data)
    ))

    _AuthorizeCallback(data) {
        if (!data.HasProp("code")) {
            AppendMidiOutputRow("Discord", "Authorize: no code in response")
            ScheduleDiscordReconnect()
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
            ScheduleDiscordReconnect()
        }
    }

    if (!rpc.Connect()) {
        AppendMidiOutputRow("Discord", "Failed to connect to PIPE. Retrying in 10s...")
        ScheduleDiscordReconnect()
        return
    }

    AppendMidiOutputRow("Discord", "Connected to PIPE. Waiting for READY...")
    SetTimer(_TryAuthenticate, -500)

    _TryAuthenticate() {
        if (!IsSet(rpc) || !rpc || !rpc.HasProp("hPipe") || !rpc.hPipe) {
            ScheduleDiscordReconnect()
            return
        }
        if (appConfig.discordAccessToken) {
            AppendMidiOutputRow("Discord", "Auto-authenticating with saved token...")
            rpc.Authenticate(appConfig.discordAccessToken)
        } else {
            AppendMidiOutputRow("Discord", "No token. Requesting authorization...")
            rpc.Authorize(["rpc", "rpc.voice.read", "rpc.voice.write"])
        }
    }
}

; 10秒後にInitDiscord自体を再実行する独立関数
ScheduleDiscordReconnect() {
    SetTimer(InitDiscord, -10000)
}

ResetDiscordToken(*) {
    global rpc, appConfig
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
