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

    ; Stop any existing reconnection timer
    SetTimer(InitDiscord, 0)

    ; 既存のRPCオブジェクトが存在する場合はクリーンアップ
    if (IsSet(rpc) && rpc) {
        try rpc.Close()
        rpc := ""
    }

    ; イベントハンドラ（ネストされた関数として定義）
    _OnReady(data) {
        SetTimer(_OnConnectTimeout, 0) ; タイムアウトタイマーを停止
        rpc.user := data.user
        AppendMidiOutputRow("Discord", "Ready: " . data.user.username)
        _AuthenticateOrAuthorize()
    }

    _OnError(data) {
        AppendMidiOutputRow("Discord", "Error: " . (data.HasProp("message") ? data.message : JSON.Stringify(data)))
        ; code 4009 (Invalid Token) の場合はトークンをリセットして再試行
        if (data.HasProp("code") && data.code == 4009) {
            AppendMidiOutputRow("Discord", "Invalid token. Resetting...")
            SetTimer(ResetDiscordToken, -1)
        }
    }

    _OnDisconnected(msg) {
        AppendMidiOutputRow("Discord", "Disconnected: " . msg)
        ScheduleDiscordReconnect()
    }

    _OnAuthenticate(data) {
        rpc.isAuthenticated := true
        rpc.user := data.user
        AppendMidiOutputRow("Discord", "Authenticated: " . data.user.username)
    }

    _OnAuthorize(data) {
        AppendMidiOutputRow("Discord", "Authorized, exchanging code for token...")
        _HandleAuthorizeResponse(data)
    }

    ; 内部ヘルパー: 認証または認可の開始
    _AuthenticateOrAuthorize() {
        if (appConfig.discordAccessToken) {
            AppendMidiOutputRow("Discord", "Authenticating with saved token...")
            rpc.Authenticate(appConfig.discordAccessToken)
        } else {
            AppendMidiOutputRow("Discord", "No token. Requesting authorization...")
            rpc.Authorize(["rpc", "rpc.voice.read", "rpc.voice.write"])
        }
    }

    ; 内部ヘルパー: 認可レスポンスの処理
    _HandleAuthorizeResponse(data) {
        if (!data.HasProp("code")) {
            AppendMidiOutputRow("Discord", "Authorize failed: no code")
            ScheduleDiscordReconnect()
            return
        }
        res := rpc.ExchangeCodeForToken(data.code, appConfig.discordClientSecret)
        if (res.HasProp("access_token")) {
            appConfig.discordAccessToken := res.access_token
            WriteConfigDiscordToken(res.access_token)
            rpc.Authenticate(res.access_token)
            AppendMidiOutputRow("Discord", "Token saved.")
        } else {
            AppendMidiOutputRow("Discord", "Token exchange failed: " . (res.HasProp("error") ? res.error : "Unknown error"))
            ScheduleDiscordReconnect()
        }
    }

    ; 内部ヘルパー: 接続タイムアウト処理 (Watchdog)
    _OnConnectTimeout() {
        if (!rpc.isAuthenticated) {
            AppendMidiOutputRow("Discord", "Connection timeout (READY not received). Retrying...")
            ScheduleDiscordReconnect()
        }
    }

    rpc := DiscordRPC(appConfig.discordClientId)

    ; イベントハンドラの設定
    rpc.On("READY", _OnReady)
    rpc.On("ERROR", _OnError)
    rpc.On("DISCONNECTED", _OnDisconnected)
    rpc.On("AUTHENTICATE", _OnAuthenticate)
    rpc.On("AUTHORIZE", _OnAuthorize)

    ; 接続開始
    if (!rpc.Connect()) {
        AppendMidiOutputRow("Discord", "Pipe connection failed. Retrying in 10s...")
        ScheduleDiscordReconnect()
        return
    }

    AppendMidiOutputRow("Discord", "Pipe connected. Waiting for READY...")
    SetTimer(_OnConnectTimeout, -5000) ; 5秒待っても READY が来なければ再試行
}

; 再試行をスケジュールする (既存のタイマーを上書き)
ScheduleDiscordReconnect() {
    AppendMidiOutputRow("Discord", "Reconnection scheduled in 10s...")
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
