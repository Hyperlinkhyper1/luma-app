param([string]$CommandDirectory = "", [int]$DeviceId = -1, [switch]$ListDevices, [switch]$Continuous)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

[StructLayout(LayoutKind.Sequential, Pack = 2)]
public struct LumaWaveFormat {
    public ushort FormatTag, Channels;
    public uint SamplesPerSecond, AverageBytesPerSecond;
    public ushort BlockAlign, BitsPerSample, ExtraSize;
}

[StructLayout(LayoutKind.Sequential)]
public struct LumaWaveHeader {
    public IntPtr Data;
    public uint BufferLength, BytesRecorded;
    public UIntPtr User;
    public uint Flags, Loops;
    public IntPtr Next;
    public UIntPtr Reserved;
}

public interface ILumaWaveInput {
    int Open(out IntPtr device, ref LumaWaveFormat format);
    int Prepare(IntPtr device, IntPtr header, uint size);
    int AddBuffer(IntPtr device, IntPtr header, uint size);
    int Start(IntPtr device);
    int Reset(IntPtr device);
    int Unprepare(IntPtr device, IntPtr header, uint size);
    int Close(IntPtr device);
    string Error(int code);
}

public sealed class LumaWaveInput : ILumaWaveInput {
    private readonly uint deviceId;
    public LumaWaveInput() : this(-1) {}
    public LumaWaveInput(int deviceId) { this.deviceId = unchecked((uint)deviceId); }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct WaveInCaps {
        public ushort Manufacturer, Product; public uint Version;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string Name;
        public uint Formats; public ushort Channels, Reserved;
    }
    [DllImport("winmm.dll")] private static extern uint waveInGetNumDevs();
    [DllImport("winmm.dll", CharSet = CharSet.Unicode)]
    private static extern int waveInGetDevCapsW(UIntPtr id, out WaveInCaps caps, uint size);
    public static string[] Devices() {
        var names = new string[waveInGetNumDevs()];
        for (uint i = 0; i < names.Length; i++) {
            WaveInCaps caps;
            names[i] = waveInGetDevCapsW((UIntPtr)i, out caps, (uint)Marshal.SizeOf(typeof(WaveInCaps))) == 0 ? caps.Name : "Unavailable";
        }
        return names;
    }
    [DllImport("winmm.dll")]
    private static extern int waveInOpen(out IntPtr device, uint deviceId,
        ref LumaWaveFormat format, UIntPtr callback, UIntPtr instance, uint flags);
    [DllImport("winmm.dll")]
    private static extern int waveInPrepareHeader(IntPtr device, IntPtr header, uint size);
    [DllImport("winmm.dll")]
    private static extern int waveInAddBuffer(IntPtr device, IntPtr header, uint size);
    [DllImport("winmm.dll")]
    private static extern int waveInStart(IntPtr device);
    [DllImport("winmm.dll")]
    private static extern int waveInReset(IntPtr device);
    [DllImport("winmm.dll")]
    private static extern int waveInUnprepareHeader(IntPtr device, IntPtr header, uint size);
    [DllImport("winmm.dll")]
    private static extern int waveInClose(IntPtr device);
    [DllImport("winmm.dll", CharSet = CharSet.Unicode)]
    private static extern int waveInGetErrorText(int code, StringBuilder message, uint size);

    public int Open(out IntPtr device, ref LumaWaveFormat format) {
        return waveInOpen(out device, deviceId, ref format, UIntPtr.Zero, UIntPtr.Zero, 0);
    }
    public int Prepare(IntPtr device, IntPtr header, uint size) { return waveInPrepareHeader(device, header, size); }
    public int AddBuffer(IntPtr device, IntPtr header, uint size) { return waveInAddBuffer(device, header, size); }
    public int Start(IntPtr device) { return waveInStart(device); }
    public int Reset(IntPtr device) { return waveInReset(device); }
    public int Unprepare(IntPtr device, IntPtr header, uint size) { return waveInUnprepareHeader(device, header, size); }
    public int Close(IntPtr device) { return waveInClose(device); }
    public string Error(int code) {
        var message = new StringBuilder(512);
        waveInGetErrorText(code, message, (uint)message.Capacity);
        return message.Length == 0 ? "Windows audio error " + code : message.ToString();
    }
}

public sealed class LumaVoiceCapture : IDisposable {
    private const int MaximumBytes = 30 * 32000;
    private readonly ILumaWaveInput input;
    private readonly uint headerSize = (uint)Marshal.SizeOf(typeof(LumaWaveHeader));
    private IntPtr device, buffer, header;
    private bool prepared, reset, disposed;

    public LumaVoiceCapture() : this(new LumaWaveInput()) {}
    public LumaVoiceCapture(int deviceId) : this(new LumaWaveInput(deviceId)) {}
    public LumaVoiceCapture(ILumaWaveInput input) { this.input = input; }

    private void Check(int result) {
        if (result != 0) throw new InvalidOperationException(input.Error(result));
    }

    public void Start() {
        if (device != IntPtr.Zero || disposed) throw new InvalidOperationException("Microphone is already open or closed.");
        var format = new LumaWaveFormat {
            FormatTag = 1, Channels = 1, SamplesPerSecond = 16000,
            AverageBytesPerSecond = 32000, BlockAlign = 2, BitsPerSample = 16
        };
        try {
            Check(input.Open(out device, ref format));
            buffer = Marshal.AllocHGlobal(MaximumBytes);
            header = Marshal.AllocHGlobal((int)headerSize);
            Marshal.StructureToPtr(new LumaWaveHeader {
                Data = buffer, BufferLength = MaximumBytes
            }, header, false);
            Check(input.Prepare(device, header, headerSize));
            prepared = true;
            Check(input.AddBuffer(device, header, headerSize));
            Check(input.Start(device));
        } catch {
            Dispose();
            throw;
        }
    }

    public byte[] Stop() {
        if (device == IntPtr.Zero) throw new InvalidOperationException("Microphone is not open.");
        Check(input.Reset(device));
        reset = true;
        var wave = (LumaWaveHeader)Marshal.PtrToStructure(header, typeof(LumaWaveHeader));
        var count = checked((int)wave.BytesRecorded);
        if (count < 6400) throw new InvalidOperationException("Record at least 0.2 seconds before translating.");
        if (count > MaximumBytes || count % 2 != 0)
            throw new InvalidOperationException("The microphone returned invalid audio.");
        var samples = new byte[count];
        Marshal.Copy(buffer, samples, 0, count);
        using (var stream = new MemoryStream(44 + count))
        using (var writer = new BinaryWriter(stream)) {
            writer.Write(Encoding.ASCII.GetBytes("RIFF")); writer.Write(36 + count);
            writer.Write(Encoding.ASCII.GetBytes("WAVEfmt ")); writer.Write(16);
            writer.Write((ushort)1); writer.Write((ushort)1); writer.Write(16000);
            writer.Write(32000); writer.Write((ushort)2); writer.Write((ushort)16);
            writer.Write(Encoding.ASCII.GetBytes("data")); writer.Write(count);
            writer.Write(samples); writer.Flush();
            return stream.ToArray();
        }
    }

    public void Dispose() {
        if (disposed) return;
        disposed = true;
        if (device != IntPtr.Zero) {
            if (!reset) input.Reset(device);
            var released = !prepared || input.Unprepare(device, header, headerSize) == 0;
            var closed = input.Close(device) == 0;
            device = IntPtr.Zero;
            // A failing driver may still own the buffers. Process exit reclaims them.
            if (!released || !closed) return;
        }
        if (header != IntPtr.Zero) { Marshal.FreeHGlobal(header); header = IntPtr.Zero; }
        if (buffer != IntPtr.Zero) { Marshal.FreeHGlobal(buffer); buffer = IntPtr.Zero; }
    }

}

public sealed class LumaContinuousCapture : IDisposable {
    private const int BufferBytes = 5 * 32000;
    private const int BufferCount = 4;
    private readonly ILumaWaveInput input;
    private readonly uint headerSize = (uint)Marshal.SizeOf(typeof(LumaWaveHeader));
    private readonly IntPtr[] buffers = new IntPtr[BufferCount];
    private readonly IntPtr[] headers = new IntPtr[BufferCount];
    private readonly bool[] prepared = new bool[BufferCount];
    private IntPtr device;
    private int next;
    private bool disposed;

    public LumaContinuousCapture(int deviceId) : this(new LumaWaveInput(deviceId)) {}
    public LumaContinuousCapture(ILumaWaveInput input) { this.input = input; }
    private void Check(int result) {
        if (result != 0) throw new InvalidOperationException(input.Error(result));
    }
    public void Start() {
        var format = new LumaWaveFormat { FormatTag = 1, Channels = 1,
            SamplesPerSecond = 16000, AverageBytesPerSecond = 32000,
            BlockAlign = 2, BitsPerSample = 16 };
        try {
            Check(input.Open(out device, ref format));
            for (int i = 0; i < BufferCount; i++) {
                buffers[i] = Marshal.AllocHGlobal(BufferBytes);
                headers[i] = Marshal.AllocHGlobal((int)headerSize);
                Marshal.StructureToPtr(new LumaWaveHeader {
                    Data = buffers[i], BufferLength = BufferBytes
                }, headers[i], false);
                Check(input.Prepare(device, headers[i], headerSize));
                prepared[i] = true;
                Check(input.AddBuffer(device, headers[i], headerSize));
            }
            Check(input.Start(device));
        } catch { Dispose(); throw; }
    }
    public byte[] Next() {
        LumaWaveHeader wave;
        var deadline = DateTime.UtcNow.AddSeconds(15);
        do {
            System.Threading.Thread.Sleep(10);
            if (DateTime.UtcNow >= deadline) throw new InvalidOperationException("The recording device stopped delivering audio.");
            wave = (LumaWaveHeader)Marshal.PtrToStructure(headers[next], typeof(LumaWaveHeader));
        } while ((wave.Flags & 1) == 0);
        int count = checked((int)wave.BytesRecorded);
        if (count != BufferBytes) throw new InvalidOperationException("The recording device returned incomplete audio.");
        var samples = new byte[count];
        Marshal.Copy(buffers[next], samples, 0, count);
        Check(input.AddBuffer(device, headers[next], headerSize));
        next = (next + 1) % BufferCount;
        using (var stream = new MemoryStream(44 + count))
        using (var writer = new BinaryWriter(stream)) {
            writer.Write(Encoding.ASCII.GetBytes("RIFF")); writer.Write(36 + count);
            writer.Write(Encoding.ASCII.GetBytes("WAVEfmt ")); writer.Write(16);
            writer.Write((ushort)1); writer.Write((ushort)1); writer.Write(16000);
            writer.Write(32000); writer.Write((ushort)2); writer.Write((ushort)16);
            writer.Write(Encoding.ASCII.GetBytes("data")); writer.Write(count);
            writer.Write(samples); writer.Flush();
            return stream.ToArray();
        }
    }
    public static bool Audible(byte[] wav) {
        double sum = 0;
        for (int i = 44; i < wav.Length; i += 2) {
            double sample = BitConverter.ToInt16(wav, i);
            sum += sample * sample;
        }
        return Math.Sqrt(sum / ((wav.Length - 44) / 2)) >= 200;
    }
    public void Dispose() {
        if (disposed) return;
        disposed = true;
        if (device != IntPtr.Zero) {
            input.Reset(device);
            bool released = true;
            for (int i = 0; i < BufferCount; i++) {
                if (prepared[i] && input.Unprepare(device, headers[i], headerSize) != 0) released = false;
            }
            bool closed = input.Close(device) == 0;
            device = IntPtr.Zero;
            if (!released || !closed) return;
        }
        for (int i = 0; i < BufferCount; i++) {
            if (headers[i] != IntPtr.Zero) Marshal.FreeHGlobal(headers[i]);
            if (buffers[i] != IntPtr.Zero) Marshal.FreeHGlobal(buffers[i]);
        }
    }
}
'@

# luma creates an empty "stop" or "cancel" file in this folder. Stdin can't
# carry it: a line written by the app's Process.start pipe never reaches
# Console.In here.
function Read-LumaCommand([string]$directory, [int]$timeoutMilliseconds) {
    $deadline = [DateTime]::UtcNow.AddMilliseconds($timeoutMilliseconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        if ([IO.File]::Exists((Join-Path $directory 'cancel'))) { return 'cancel' }
        if ([IO.File]::Exists((Join-Path $directory 'stop'))) { return 'stop' }
        Start-Sleep -Milliseconds 30
    }
    return $null
}

if ($ListDevices) {
    $devices = [LumaWaveInput]::Devices()
    $items = @()
    for ($i = 0; $i -lt $devices.Length; $i++) { $items += @{ id = $i; name = $devices[$i] } }
    [Console]::WriteLine((ConvertTo-Json -InputObject $items -Compress))
    return
}
if ($Continuous) {
    $capture = New-Object LumaContinuousCapture -ArgumentList $DeviceId
    try {
        $capture.Start()
        [Console]::WriteLine('{"event":"recording"}')
        [Console]::Out.Flush()
        while (-not [IO.File]::Exists((Join-Path $CommandDirectory 'cancel'))) {
            $bytes = $capture.Next()
            if ([LumaContinuousCapture]::Audible($bytes)) {
                [Console]::WriteLine((@{ event = 'audio'; data = [Convert]::ToBase64String($bytes) } | ConvertTo-Json -Compress))
                [Console]::Out.Flush()
            }
        }
    } catch {
        [Console]::WriteLine((@{ event = 'error'; message = $_.Exception.Message } | ConvertTo-Json -Compress))
        [Console]::Out.Flush()
        exit 1
    } finally { $capture.Dispose() }
    return
}

$capture = New-Object LumaVoiceCapture
try {
    $capture.Start()
    [Console]::WriteLine('{"event":"recording"}')
    [Console]::Out.Flush()
    $command = Read-LumaCommand $CommandDirectory 31000
    if ($command -ne 'stop') { throw 'Recording cancelled or timed out.' }
    $bytes = $capture.Stop()
    $capture.Dispose()
    [Console]::WriteLine((@{ event = 'audio'; data = [Convert]::ToBase64String($bytes) } | ConvertTo-Json -Compress))
    [Console]::Out.Flush()
} catch {
    [Console]::WriteLine((@{ event = 'error'; message = $_.Exception.Message } | ConvertTo-Json -Compress))
    [Console]::Out.Flush()
    exit 1
} finally {
    $capture.Dispose()
}
