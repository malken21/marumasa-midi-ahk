#Requires AutoHotkey v2

ProcessNote(device, channel, note, velocity, isNoteOn) {
    ; キーが押された以外の場合は return
    if (!isNoteOn) {
        return
    }
    DisplayOutput("NoteOn", note)
    switch (note) {
        case 36: ; 国際式 C2
        {
            ; 5秒後 シャットダウン
            Run("shutdown -s -t 5")
        }
        case 38: ; 国際式 D2
        {
            Run("..\Reboot-VirtualDesktop\start.bat")
        }
        case 39: ; 国際式 D#2
        {
            ; スクリプトを終了
            ExitApp()
        }
        case 40: ; 国際式 E2
        {
            ; スクリプトをリロード
            Reload()
        }
        case 41: ; 国際式 F2
        {
            ; SteamVR を起動
            Run("steam://rungameid/250820")
        }
        case 84: ; 国際式 C6
        {
            ; https://github.com/malken21/Discord-VoiceMute-Switch
            ; Discord のボイスチャットのミュートを切り替え
            Run("curl http://localhost:55685/", , "Hide")
        }
    }
}

ProcessCC(device, channel, cc, value) {
}

ProcessPC(device, channel, note, velocity) {
}

ProcessPitchBend(device, channel, value) {
}
