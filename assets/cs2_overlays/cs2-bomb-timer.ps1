# CS2 bomb timer overlay
# A small transparent always-on-top window that counts the C4 down after a plant.
# luma listens to CS2's official Game State Integration and sends one command
# per line over a loopback socket (-CommandPort):
#   PLANT <milliseconds left>   start (or correct) the countdown
#   DEFUSED / EXPLODED          show the outcome for a moment
#   CLEAR                       hide the timer
#   PREVIEW                     show a placeholder so the window can be moved
# The game itself is never touched, which keeps it VAC-safe.
# When luma closes the socket, the overlay closes with it.

param(
    [int]$CommandPort = 0,
    [int]$OverlayX = -1,          # -1 = automatic (centered)
    [int]$OverlayY = -1,          # -1 = automatic (below CS2's round timer)
    [int]$FuseSeconds = 40,
    [string]$LabelKit = "Kit only",
    [string]$LabelLate = "Too late",
    [string]$LabelDefused = "Defused",
    [string]$LabelExploded = "Exploded",
    [string]$LabelPreview = "Bomb timer",
    [string]$LabelMove = "Drag to move",
    [string]$Snapshot = "",       # render one frame to a PNG and exit (for checking the look)
    [double]$SnapshotSeconds = 7
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

Add-Type -TypeDefinition 'using System.Runtime.InteropServices; public static class DpiAware { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }'
[void][DpiAware]::SetProcessDPIAware()
$g = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
$DpiScale = $g.DpiX / 96
$g.Dispose()

$OverlayCode = @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

public class BombOverlay : Form
{
    enum Mode { Idle, Preview, Planted, Result }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct BLENDFUNCTION { public byte BlendOp; public byte BlendFlags; public byte SourceConstantAlpha; public byte AlphaFormat; }

    [DllImport("user32.dll", SetLastError = true)]
    static extern bool UpdateLayeredWindow(IntPtr hwnd, IntPtr hdcDst, IntPtr pptDst, ref Size psize, IntPtr hdcSrc, ref Point pprSrc, int crKey, ref BLENDFUNCTION pblend, int dwFlags);
    [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr hWnd);
    [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);
    [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleDC(IntPtr hDC);
    [DllImport("gdi32.dll")] static extern bool DeleteDC(IntPtr hdc);
    [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr hDC, IntPtr hObject);
    [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr hObject);

    public string LabelKit = "Kit only", LabelLate = "Too late", LabelDefused = "Defused",
        LabelExploded = "Exploded", LabelPreview = "Bomb timer", LabelMove = "Drag to move";

    static readonly Color Safe = Color.FromArgb(245, 245, 245);
    static readonly Color Kit = Color.FromArgb(255, 190, 70);
    static readonly Color Late = Color.FromArgb(255, 90, 80);
    static readonly Color Good = Color.FromArgb(110, 220, 120);
    static readonly Color Muted = Color.FromArgb(175, 175, 180);

    int W, H;
    float scale;
    double fuse;
    Font big, small, mid;
    Mode mode = Mode.Idle;
    DateTime endsAt, until;
    string resultText;
    Color resultColor;
    System.Windows.Forms.Timer ticker;
    int requestedX, requestedY;

    public BombOverlay(int x, int y, float scale, double fuse)
    {
        this.scale = scale;
        this.fuse = fuse;
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        TopMost = true;
        AutoScaleMode = AutoScaleMode.None;
        StartPosition = FormStartPosition.Manual;

        big = new Font("Segoe UI", 38 * scale, FontStyle.Bold, GraphicsUnit.Pixel);
        mid = new Font("Segoe UI", 15 * scale, FontStyle.Bold, GraphicsUnit.Pixel);
        small = new Font("Segoe UI", 12 * scale, FontStyle.Bold, GraphicsUnit.Pixel);
        W = (int)(200 * scale);
        H = (int)(72 * scale);
        requestedX = x;
        requestedY = y;

        ticker = new System.Windows.Forms.Timer();
        ticker.Interval = 100;
        ticker.Tick += delegate { Tick(); };
    }

    /// Widens the window to fit the longest label, then places it. Called once
    /// the labels are set, since translations can run longer than English.
    public void Fit()
    {
        using (Bitmap probe = new Bitmap(1, 1))
        using (Graphics g = Graphics.FromImage(probe))
        {
            float widest = 0;
            foreach (string label in new string[] { LabelKit, LabelLate, LabelPreview, LabelMove })
                widest = Math.Max(widest, g.MeasureString(label, small).Width);
            float textX = 14 * scale + g.MeasureString("40", big).Width + 2 * scale;
            W = Math.Max(W, (int)Math.Ceiling(textX + widest + 14 * scale));
        }
        Rectangle screen = Screen.PrimaryScreen.Bounds;
        int x = requestedX < 0 ? screen.Left + (screen.Width - W) / 2 : requestedX;
        int y = requestedY < 0 ? screen.Top + (int)(screen.Height * 0.11) : requestedY;
        Location = new Point(x, y);
        Size = new Size(W, H);
    }

    protected override CreateParams CreateParams
    {
        get
        {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= 0x80000 | 0x80 | 0x08000000;   // layered, tool window, no-activate
            return cp;
        }
    }

    protected override bool ShowWithoutActivation { get { return true; } }

    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);
        Render();
        ticker.Start();
        Thread reader = new Thread(ReadCommands);
        reader.IsBackground = true;
        reader.Start();
    }

    // Commands come over a loopback socket luma listens on, not standard input:
    // the PowerShell host reads a redirected stdin itself, so the overlay would
    // never see them. When luma closes the socket (or quits), the overlay closes.
    public int CommandPort;

    void ReadCommands()
    {
        try
        {
            using (TcpClient client = new TcpClient())
            {
                client.Connect(IPAddress.Loopback, CommandPort);
                using (StreamReader input = new StreamReader(client.GetStream()))
                {
                    string line;
                    while ((line = input.ReadLine()) != null)
                    {
                        string command = line;
                        try { BeginInvoke(new Action(delegate { RunCommand(command); })); } catch { }
                    }
                }
            }
        }
        catch { }
        try { BeginInvoke(new Action(Close)); } catch { }
    }

    public void RunCommand(string line)
    {
        string[] parts = line.Trim().Split(' ');
        switch (parts[0].ToUpperInvariant())
        {
            case "PLANT":
                double ms;
                if (parts.Length < 2 || !double.TryParse(parts[1], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out ms)) ms = fuse * 1000;
                mode = Mode.Planted;
                endsAt = DateTime.UtcNow.AddMilliseconds(ms);
                break;
            case "DEFUSED": ShowResult(LabelDefused, Good); break;
            case "EXPLODED": ShowResult(LabelExploded, Late); break;
            case "CLEAR": mode = Mode.Idle; break;
            case "PREVIEW":
                if (mode == Mode.Idle) { mode = Mode.Preview; until = DateTime.UtcNow.AddSeconds(8); }
                break;
        }
        Console.WriteLine("OK " + parts[0].ToUpperInvariant() + " " + mode);
        Render();
    }

    void ShowResult(string text, Color color)
    {
        if (mode == Mode.Idle) return;
        mode = Mode.Result;
        resultText = text;
        resultColor = color;
        until = DateTime.UtcNow.AddSeconds(3);
    }

    void Tick()
    {
        DateTime now = DateTime.UtcNow;
        if (mode == Mode.Planted && now >= endsAt) ShowResult(LabelExploded, Late);
        else if ((mode == Mode.Preview || mode == Mode.Result) && now >= until) mode = Mode.Idle;
        else if (mode == Mode.Idle) return;
        Render();
    }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == 0x84)   // WM_NCHITTEST: draggable while visible, see-through while hidden
        {
            m.Result = (IntPtr)(mode == Mode.Idle ? -1 : 2);   // HTTRANSPARENT : HTCAPTION
            return;
        }
        if (m.Msg == 0xA5) { Close(); return; }   // right-click closes the overlay
        if (m.Msg == 0x232) Console.WriteLine("POS " + Left + " " + Top);   // WM_EXITSIZEMOVE: luma remembers the spot
        base.WndProc(ref m);
    }

    static GraphicsPath Rounded(RectangleF r, float radius)
    {
        GraphicsPath p = new GraphicsPath();
        float d = radius * 2;
        p.AddArc(r.X, r.Y, d, d, 180, 90);
        p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }

    void Shadowed(Graphics g, string text, Font f, Color c, float x, float y)
    {
        using (SolidBrush shadow = new SolidBrush(Color.FromArgb(200, 0, 0, 0))) g.DrawString(text, f, shadow, x + 1, y + 1);
        using (SolidBrush b = new SolidBrush(c)) g.DrawString(text, f, b, x, y);
    }

    public Bitmap Draw(DateTime now)
    {
        Bitmap bmp = new Bitmap(W, H, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(bmp))
        {
            g.Clear(Color.Transparent);
            if (mode == Mode.Idle) return bmp;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;

            RectangleF box = new RectangleF(1, 1, W - 2, H - 2);
            using (GraphicsPath path = Rounded(box, 12 * scale))
            {
                using (SolidBrush bg = new SolidBrush(Color.FromArgb(185, 14, 14, 18))) g.FillPath(bg, path);
                using (Pen edge = new Pen(Color.FromArgb(60, 255, 255, 255), 1)) g.DrawPath(edge, path);
            }

            float pad = 14 * scale;
            if (mode == Mode.Result)
            {
                SizeF size = g.MeasureString(resultText, mid);
                Shadowed(g, resultText, mid, resultColor, (W - size.Width) / 2, (H - size.Height) / 2);
                return bmp;
            }

            double left = mode == Mode.Planted ? Math.Max(0, (endsAt - now).TotalSeconds) : fuse;
            int seconds = (int)Math.Ceiling(left);
            Color color = mode == Mode.Preview ? Muted : left >= 10 ? Safe : left >= 5 ? Kit : Late;
            string number = seconds.ToString();
            SizeF numberSize = g.MeasureString(number, big);
            Shadowed(g, number, big, color, pad - 4 * scale, (H - numberSize.Height) / 2 - 2 * scale);

            float textX = pad + Math.Max(numberSize.Width, g.MeasureString("40", big).Width) + 2 * scale;
            string caption = mode == Mode.Preview ? LabelPreview : "C4";
            string hint = mode == Mode.Preview ? LabelMove : left >= 10 ? "" : left >= 5 ? LabelKit : LabelLate;
            Shadowed(g, caption, small, Muted, textX, 16 * scale);
            if (hint.Length > 0) Shadowed(g, hint, small, mode == Mode.Preview ? Muted : color, textX, 34 * scale);

            float barW = W - pad * 2;
            float fraction = (float)Math.Min(1, left / fuse);
            using (SolidBrush track = new SolidBrush(Color.FromArgb(50, 255, 255, 255)))
                g.FillRectangle(track, pad, H - 10 * scale, barW, 3 * scale);
            using (SolidBrush fill = new SolidBrush(color))
                g.FillRectangle(fill, pad, H - 10 * scale, barW * fraction, 3 * scale);
        }
        return bmp;
    }

    public void Snapshot(string path, double secondsLeft)
    {
        if (secondsLeft < 0) { mode = Mode.Preview; }
        else { mode = Mode.Planted; endsAt = DateTime.UtcNow.AddSeconds(secondsLeft); }
        using (Bitmap bmp = Draw(DateTime.UtcNow)) bmp.Save(path, ImageFormat.Png);
    }

    void Render()
    {
        if (!IsHandleCreated) return;
        using (Bitmap bmp = Draw(DateTime.UtcNow))
        {
            IntPtr screenDc = GetDC(IntPtr.Zero);
            IntPtr memDc = CreateCompatibleDC(screenDc);
            IntPtr hBmp = IntPtr.Zero, old = IntPtr.Zero;
            try
            {
                hBmp = bmp.GetHbitmap(Color.FromArgb(0));
                old = SelectObject(memDc, hBmp);
                Size size = new Size(bmp.Width, bmp.Height);
                Point src = new Point(0, 0);
                BLENDFUNCTION bf = new BLENDFUNCTION();
                bf.BlendOp = 0; bf.BlendFlags = 0; bf.SourceConstantAlpha = 255; bf.AlphaFormat = 1;
                UpdateLayeredWindow(Handle, screenDc, IntPtr.Zero, ref size, memDc, ref src, 0, ref bf, 2);
            }
            finally
            {
                ReleaseDC(IntPtr.Zero, screenDc);
                if (hBmp != IntPtr.Zero) { SelectObject(memDc, old); DeleteObject(hBmp); }
                DeleteDC(memDc);
            }
        }
    }
}
'@

Add-Type -TypeDefinition $OverlayCode -ReferencedAssemblies System.Windows.Forms, System.Drawing
$overlay = New-Object BombOverlay -ArgumentList $OverlayX, $OverlayY, ([single]$DpiScale), ([double][Math]::Max(1, $FuseSeconds))
$overlay.LabelKit = $LabelKit
$overlay.LabelLate = $LabelLate
$overlay.LabelDefused = $LabelDefused
$overlay.LabelExploded = $LabelExploded
$overlay.LabelPreview = $LabelPreview
$overlay.LabelMove = $LabelMove
$overlay.CommandPort = $CommandPort
$overlay.Fit()

if ($Snapshot) {
    $overlay.Snapshot($Snapshot, $SnapshotSeconds)
    Write-Host "Saved $Snapshot"
    return
}

Write-Host "READY"
[System.Windows.Forms.Application]::Run($overlay)
