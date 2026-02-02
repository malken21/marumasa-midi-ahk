# MidiToMacro

これは、MIDI入力値をホットキーやマクロにマッピングするための Windows 用 AutoHotKey v2 スクリプトです。

このスクリプトを使用すると、CCメッセージをメディアキー（再生/一時停止/次へ）、ボリュームスライダー、または StreamLabs OBS などのプログラムで割り当て可能な珍しいキーボードの組み合わせ（CTRL+SHIFT+ALT+F13など）にバインドできます。

## 実行方法

`MidiToMacro.ahk` をダブルクリックします。

Windows の起動時にプログラムを起動するには、スタートメニューのスタートアップフォルダにファイルのショートカットを追加します。（WIN+R を押し、`shell:startup` と入力して ENTER を押すと素早くアクセスできます。）

スクリプトを実行すると、「MIDI Monitor」GUIが表示されます。ドロップダウンリストから MIDI 入力を選択してください。受信した MIDI メッセージは左側のリストに表示され、トリガーされたイベントは右側に表示されます。

「MIDI Monitor」ウィンドウを閉じても、スクリプトはバックグラウンドで実行され続けます。再度表示するには、トレイアイコンを右クリックして「MIDI Monitor」をクリックします。

デフォルトでは、スクリプトを実行するたびに「MIDI Monitor」GUIが表示されます。これを無効にするには、トレイアイコンを右クリックし、「Show on Startup」オプションのチェックを外します。

スクリプトが開始されると、選択した MIDI 入力デバイスを開こうとします。MIDI デバイスが（デバイスの追加や削除によって）変更された場合、MIDI デバイスが開かれないことがあります。その場合、（「Show on Startup」がオフであっても）GUI が表示され、MIDI デバイスを再度選択する必要があります。

## 設定

スクリプトは `MidiToMacro.ini` で設定できます。このファイルは、MIDI デバイスを選択するか、「Show on Startup」トレイメニューオプションを切り替えたときに、スクリプトと同じディレクトリに作成されます。手動でファイルを作成・編集することも可能です。

```ini
; GUIに表示するログの行数。デフォルトは10です。
MaxLogLines=10
; 選択されたMIDI入力デバイス。これは0から始まるインデックスです。
MidiInDevice=0
; 選択されたMIDI入力デバイスの名前。これは、接続されているMIDIデバイスが変更されたかどうかを確認するために使用されます。
MidiInDeviceName=Automap MIDI
; スクリプト開始時にGUIを無効にするには、これを0に設定します。
ShowOnStartup=1
```

## ルールの追加

`MidiRules.ahk` ファイルにルールを追加できます。

変更可能な4つのハンドラ関数があります：

- `ProcessNote`: ノートオン/オフイベントを処理します
- `ProcessCC`: CC（コントロールチェンジ、または連続コントロール）イベントを処理します
- `ProcessPC`: パッチチェンジイベントを処理します
- `ProcessPitchBend`: ピッチベンドイベントを処理します

各関数内で、一連の `if/else` ブロックを使用できます。

```
if (cc = 21) {
    ; ...
} else if (cc = 51) {
    ; ...
} else if (cc = 52 and value != 0) {
    ; ...
}
```

CC 51 を受信したときにミュートボタンを切り替えるルールは、次のようになります：

```
if (cc = 51) {
    Send("{Volume_Mute}")
    DisplayOutput("Volume", "Mute")
}
```

`Send("{Volume_Mute}")` は、キーボードの「ミュート」ボタンを押す操作をシミュレートします。`DisplayOutput("Volume", "Mute")` は、MidiMon GUI にメッセージをログ出力します。

再生/一時停止ボタンを押すルールは、次のようになります：

```
if (cc = 54 and value != 0) {
    Send("{Media_Play_Pause}")
    DisplayOutput("Media", "Play/Pause")
}
```

`value != 0` を使用することで、MIDI コントローラーのボタン押下を検出し、ボタン解放を無視できます。（この句がないと、ボタン押下時とボタン解放時でキーボードマクロが2回送信されてしまいます。）

スライダーからの連続コントロールをメインの Windows ミキサー音量にマップするルールは次のとおりです：

```
if (cc = 21 or cc = 29) {
    scaledValue := ConvertCCValueToScale(value, 0, 127)
    volume := scaledValue * 100
    SoundSetVolume(volume)
    DisplayOutput("Volume", Format('{1:.2f}', volume))
}
```

`ConvertCCValueToScale` は `lib\CommonFunctions.ahk` にあるユーティリティ関数です。これは、指定された範囲の値を 0 から 1 までの浮動小数点数に変換します。

特定のアプリケーション（この例では Sound Forge 9）でキーボードショートカットをトリガーするルールは次のとおりです：

```
if (cc = 58 and value != 0) {
    ; Sound Forge 9 にキューマーカーを配置
    try {
        ControlSend("{Alt down}m{Alt up}", , "ahk_class #32770")
        DisplayOutput("Sound Forge", "Place Cue Marker")
    } catch TargetError {
        ; ウィンドウが存在しない場合は何もしない
    }
}
```

AutoHotKey の「WindowSpy」スクリプトを使用して、`ahk_class` で使用するためのウィンドウやアプリケーション内のコントロールを特定できます。

[標準的なCCメッセージのリスト](https://web.archive.org/web/20231215150816/https://www.midi.org/specifications-old/item/table-3-control-change-messages-data-bytes-2)をオンラインで見つけることができます。20-31、52-63、102-119 など、特定のコントロール機能が割り当てられていないコントロール番号を使用することもできますが、どのコントロール番号でも正常に動作するはずです。

## AutoHotKey バージョン互換性

このスクリプトには AutoHotKey v2 が必要です。v1 のサポートが必要な場合は、[このスクリプトの古いバージョン](https://github.com/laurence-myers/midi-to-macro/tree/ahk-v1)を使用してください。

## v2 への移行

MidiToMacro v2 より前に書かれた既存の `MidiRules.ahk` がある場合は、[AHK v2 構文をサポートするように更新](https://www.autohotkey.com/docs/v2/v2-changes.htm)するだけです。必要な基本的な変更点は次のとおりです：

- 関数呼び出しの変更: `Send, ...` -> `Send(...)`
- 文字列の引用符: `Send, {Volume_up}` -> `Send("{Volume_up}")`

`DisplayOutput()` のような MidiToMacro が提供する関数に変更はありません。

## クレジット

このスクリプトは、様々な形や進化を経て、元々は以下の（順不同）AHKフォーラムメンバーによる成果に基づいています：

- genmce
- Orbik
- TomB
- Lazslo

`OpenMidiInput` を実装してくれた [William Wong](https://github.com/compulim) に感謝します。（[autohotkey-boss-fs-1-wl](https://github.com/compulim/autohotkey-boss-fs-1-wl) を参照）。
