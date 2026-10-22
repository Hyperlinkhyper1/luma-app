$ErrorActionPreference = 'Stop'
$assetPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'assets/cs2_translator/cs2-voice-recorder.ps1'
$script = [IO.File]::ReadAllText($assetPath)
$match = [regex]::Match($script, "(?s)Add-Type -TypeDefinition @'\r?\n(.*?)\r?\n'@")
if (-not $match.Success) { throw 'Could not find the bundled capture source.' }
$fake = @'
public sealed class LumaTestWaveInput : ILumaWaveInput {
    public uint Length = 32000;
    public int Failure;
    public readonly System.Collections.Generic.List<string> Calls = new System.Collections.Generic.List<string>();
    private System.IntPtr header;
    public int Open(out System.IntPtr device, ref LumaWaveFormat format) {
        Calls.Add("open");
        device = Failure == 1 ? System.IntPtr.Zero : new System.IntPtr(42);
        if (format.FormatTag != 1 || format.Channels != 1 || format.SamplesPerSecond != 16000 ||
            format.AverageBytesPerSecond != 32000 || format.BlockAlign != 2 || format.BitsPerSample != 16)
            throw new System.Exception("Invalid device format.");
        return Failure == 1 ? 5 : 0;
    }
    public int Prepare(System.IntPtr device, System.IntPtr value, uint size) {
        Calls.Add("prepare"); header = value;
        if (size != System.Runtime.InteropServices.Marshal.SizeOf(typeof(LumaWaveHeader)))
            throw new System.Exception("Invalid native header size.");
        return Failure == 2 ? 5 : 0;
    }
    public int AddBuffer(System.IntPtr device, System.IntPtr value, uint size) {
        Calls.Add("add"); return Failure == 3 ? 5 : 0;
    }
    public int Start(System.IntPtr device) { Calls.Add("start"); return Failure == 4 ? 5 : 0; }
    public int Reset(System.IntPtr device) {
        Calls.Add("reset");
        if (header != System.IntPtr.Zero) {
            var wave = (LumaWaveHeader)System.Runtime.InteropServices.Marshal.PtrToStructure(header, typeof(LumaWaveHeader));
            wave.BytesRecorded = Length;
            if (Length <= wave.BufferLength) {
                var samples = new byte[Length];
                for (var i = 0; i < samples.Length; i++) samples[i] = (byte)(i % 251);
                System.Runtime.InteropServices.Marshal.Copy(samples, 0, wave.Data, samples.Length);
            }
            System.Runtime.InteropServices.Marshal.StructureToPtr(wave, header, false);
        }
        return 0;
    }
    public int Unprepare(System.IntPtr device, System.IntPtr value, uint size) { Calls.Add("unprepare"); return 0; }
    public int Close(System.IntPtr device) { Calls.Add("close"); return 0; }
    public string Error(int code) { return "test microphone error"; }
}
'@
Add-Type -TypeDefinition ($match.Groups[1].Value + [Environment]::NewLine + $fake)

function Assert-True($condition, [string]$message) {
    if (-not $condition) { throw $message }
}

foreach ($count in @(6400, 32000, 960000)) {
    $inputDevice = New-Object LumaTestWaveInput
    $inputDevice.Length = $count
    $capture = New-Object LumaVoiceCapture($inputDevice)
    try {
        $capture.Start()
        $wav = $capture.Stop()
        Assert-True ($wav.Length -eq 44 + $count) 'Wrong WAV length.'
        Assert-True ([Text.Encoding]::ASCII.GetString($wav, 0, 4) -eq 'RIFF') 'Missing RIFF header.'
        Assert-True ([BitConverter]::ToInt32($wav, 4) -eq 36 + $count) 'Wrong RIFF size.'
        Assert-True ([Text.Encoding]::ASCII.GetString($wav, 8, 8) -eq 'WAVEfmt ') 'Missing PCM format.'
        Assert-True ([BitConverter]::ToInt32($wav, 24) -eq 16000) 'Wrong sample rate.'
        Assert-True ([BitConverter]::ToInt16($wav, 34) -eq 16) 'Wrong sample depth.'
        Assert-True ([BitConverter]::ToInt32($wav, 40) -eq $count) 'Wrong audio duration.'
        Assert-True ($wav[44 + $count - 1] -eq (($count - 1) % 251)) 'Audio samples were lost.'
    } finally { $capture.Dispose() }
    $capture.Dispose()
    Assert-True (($inputDevice.Calls -join ',') -eq 'open,prepare,add,start,reset,unprepare,close') 'Capture did not release its buffers and device exactly once.'
}

foreach ($count in @(0, 6401, 960002)) {
    $inputDevice = New-Object LumaTestWaveInput
    $inputDevice.Length = $count
    $capture = New-Object LumaVoiceCapture($inputDevice)
    $rejected = $false
    try { $capture.Start(); $null = $capture.Stop() } catch { $rejected = $true } finally { $capture.Dispose() }
    Assert-True $rejected 'Invalid or empty audio was accepted.'
    Assert-True ($inputDevice.Calls[-1] -eq 'close') 'Invalid audio left the microphone open.'
}

foreach ($failure in 1..4) {
    $inputDevice = New-Object LumaTestWaveInput
    $inputDevice.Failure = $failure
    $capture = New-Object LumaVoiceCapture($inputDevice)
    $rejected = $false
    try { $capture.Start() } catch { $rejected = $_.Exception.Message.Contains('test microphone error') } finally { $capture.Dispose() }
    Assert-True $rejected 'Device errors were not reported.'
    if ($failure -gt 1) { Assert-True ($inputDevice.Calls[-1] -eq 'close') 'Startup failure leaked the microphone.' }
}

$cancelInput = New-Object LumaTestWaveInput
$capture = New-Object LumaVoiceCapture($cancelInput)
$capture.Start()
$capture.Dispose()
Assert-True (($cancelInput.Calls -join ',') -eq 'open,prepare,add,start,reset,unprepare,close') 'Cancellation did not release the device.'

$directory = Join-Path ([IO.Path]::GetTempPath()) ('luma-recorder-test-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $directory
$fixture = $script.Replace($match.Groups[1].Value, $match.Groups[1].Value + [Environment]::NewLine + $fake)
$fixture = $fixture.Replace('$capture = New-Object LumaVoiceCapture', '$capture = New-Object LumaVoiceCapture((New-Object LumaTestWaveInput))')
$fixture = $fixture.Replace('Read-LumaCommand $CommandDirectory 31000', 'Read-LumaCommand $CommandDirectory 300')
$fixturePath = Join-Path $directory 'recorder.ps1'
$commandPath = Join-Path $directory 'commands'
[IO.File]::WriteAllText($fixturePath, $fixture)
try {
    foreach ($command in @('stop', 'cancel', 'no-command')) {
        if (Test-Path -LiteralPath $commandPath) { Remove-Item -LiteralPath $commandPath -Recurse -Force }
        $null = New-Item -ItemType Directory -Path $commandPath
        $info = New-Object Diagnostics.ProcessStartInfo
        $info.FileName = 'powershell.exe'
        $info.Arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $fixturePath + '" "' + $commandPath + '"'
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        $process = [Diagnostics.Process]::Start($info)
        try {
            $ready = $process.StandardOutput.ReadLineAsync()
            Assert-True ($ready.Wait(15000)) 'Helper did not start.'
            Assert-True (($ready.Result | ConvertFrom-Json).event -eq 'recording') 'Helper did not announce recording.'
            if ($command -ne 'no-command') {
                [IO.File]::WriteAllText((Join-Path $commandPath $command), '')
            }
            $result = $process.StandardOutput.ReadLineAsync()
            Assert-True ($result.Wait(3000)) 'Helper stop/cancel/timeout did not return promptly.'
            $event = $result.Result | ConvertFrom-Json
            Assert-True ($process.WaitForExit(3000)) 'Helper did not exit.'
            if ($command -eq 'stop') {
                Assert-True ($event.event -eq 'audio') 'Stop did not return audio.'
                Assert-True ([Convert]::FromBase64String($event.data).Length -eq 32044) 'Helper corrupted audio.'
            } else { Assert-True ($event.event -eq 'error') 'Cancel/timeout returned audio.' }
        } finally {
            if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
            $process.Dispose()
        }
    }
} finally {
    # Only the explicitly created test files are removed.
    Remove-Item -LiteralPath $fixturePath -Force
    if (Test-Path -LiteralPath $commandPath) { Remove-Item -LiteralPath $commandPath -Recurse -Force }
    Remove-Item -LiteralPath $directory -Force
}
Write-Output 'Passed: buffered WAV capture, failure cleanup, cancellation, and real Windows PowerShell stop/cancel/timeout protocol (synthetic audio; no microphone access).'
