$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class LumaVoiceCapture {
    [DllImport("winmm.dll", CharSet = CharSet.Unicode)]
    private static extern int mciSendString(string command, StringBuilder result, int size, IntPtr callback);
    [DllImport("winmm.dll", CharSet = CharSet.Unicode)]
    private static extern bool mciGetErrorString(int code, StringBuilder result, int size);
    public static void Send(string command) {
        int code = mciSendString(command, null, 0, IntPtr.Zero);
        if (code != 0) {
            var message = new StringBuilder(512);
            mciGetErrorString(code, message, message.Capacity);
            throw new InvalidOperationException(message.ToString());
        }
    }
}
'@

$opened = $false
$recordingPath = Join-Path ([IO.Path]::GetTempPath()) ('luma-voice-' + [Guid]::NewGuid().ToString('N') + '.wav')
try {
    [LumaVoiceCapture]::Send('open new type waveaudio alias lumaVoice')
    $opened = $true
    [LumaVoiceCapture]::Send('set lumaVoice time format milliseconds format tag pcm channels 1 samplespersec 16000 bitspersample 16 alignment 2 bytespersec 32000')
    [LumaVoiceCapture]::Send('record lumaVoice to 30000')
    [Console]::WriteLine('{"event":"recording"}')
    $inputTask = [Console]::In.ReadLineAsync()
    if (-not $inputTask.Wait(31000)) { throw 'Recording timed out.' }
    if ($inputTask.Result -ne 'stop') { throw 'Recording cancelled.' }
    [LumaVoiceCapture]::Send('stop lumaVoice')
    [LumaVoiceCapture]::Send('save lumaVoice "' + $recordingPath + '"')
    $bytes = [IO.File]::ReadAllBytes($recordingPath)
    if ($bytes.Length -le 44 -or $bytes.Length -gt 1000000) { throw 'The microphone returned no usable audio.' }
    [Console]::WriteLine((@{ event = 'audio'; data = [Convert]::ToBase64String($bytes) } | ConvertTo-Json -Compress))
} catch {
    [Console]::WriteLine((@{ event = 'error'; message = $_.Exception.Message } | ConvertTo-Json -Compress))
    exit 1
} finally {
    if ($opened) {
        try { [LumaVoiceCapture]::Send('close lumaVoice') } catch {}
    }
    if (Test-Path -LiteralPath $recordingPath) { Remove-Item -LiteralPath $recordingPath -Force }
}
