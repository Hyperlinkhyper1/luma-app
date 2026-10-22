param([Parameter(Mandatory = $true)][string]$CommandPath)

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
        return waveInOpen(out device, uint.MaxValue, ref format, UIntPtr.Zero, UIntPtr.Zero, 0);
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
'@

# luma drops "stop" or "cancel" into this file. Stdin can't carry it: a line
# written by the app's Process.start pipe never reaches Console.In here.
function Read-LumaCommand([string]$path, [int]$timeoutMilliseconds) {
    $deadline = [DateTime]::UtcNow.AddMilliseconds($timeoutMilliseconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        if ([IO.File]::Exists($path)) { return ([IO.File]::ReadAllText($path)).Trim() }
        Start-Sleep -Milliseconds 30
    }
    return $null
}

$capture = New-Object LumaVoiceCapture
try {
    $capture.Start()
    [Console]::WriteLine('{"event":"recording"}')
    [Console]::Out.Flush()
    $command = Read-LumaCommand $CommandPath 31000
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
