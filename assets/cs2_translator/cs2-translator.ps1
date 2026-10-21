# CS2 chat translator
# Reads CS2's console.log (written by the -condebug launch option), shows every
# chat line in a color-coded transparent overlay, translates foreign-language messages,
# and hides each line after a set number of seconds.
# It never touches the game's memory or files, so it is VAC-safe.

param(
    [string]$LogPath = "",
    [string]$TargetLang = "en",
    [int]$NetconPort = 2121,
    [int]$HideAfterSeconds = 20,
    [int]$MaxLines = 8,
    [int]$OverlayX = 20,
    [int]$OverlayY = -1,       # -1 = automatic (bottom-left, above the chat area)
    [string]$Snapshot = "",    # render the overlay with sample lines to a PNG and exit (for checking the look)
    [switch]$NoOverlay,
    [switch]$Test
)

$ErrorActionPreference = "Stop"
# luma reads this script's output through a pipe, so it has to be UTF-8 for Cyrillic and CJK text to survive
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Web, System.Windows.Forms, System.Drawing

# Without this Windows renders the overlay small and stretches it on scaled displays, which makes the text blurry
Add-Type -TypeDefinition 'using System.Runtime.InteropServices; public static class DpiAware { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }'
[void][DpiAware]::SetProcessDPIAware()
$g = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
$DpiScale = $g.DpiX / 96
$g.Dispose()

$LangNames = @{ ru = "Russian"; uk = "Ukrainian"; be = "Belarusian"; bg = "Bulgarian"; sr = "Serbian"; kk = "Kazakh"; mk = "Macedonian" }

# Colors, matched to CS2's chat: T = gold, CT = blue
$Colors = @{
    T     = [System.Drawing.Color]::FromArgb(255, 208, 90)
    CT    = [System.Drawing.Color]::FromArgb(120, 180, 255)
    ALL   = [System.Drawing.Color]::FromArgb(235, 235, 235)
    Dot   = [System.Drawing.Color]::FromArgb(90, 220, 90)
    Loc   = [System.Drawing.Color]::FromArgb(120, 210, 120)
    Msg   = [System.Drawing.Color]::FromArgb(150, 200, 255)
    Trans = [System.Drawing.Color]::FromArgb(210, 210, 210)
}

# Real lines look like: "10/21 17:39:22  [ALL] Name‎ [DEAD]: msg" or "[T] Name‎﹫Location: msg"
# (a timestamp prefix, invisible direction marks after the name, and "﹫" instead of "@")
$ChatRegex = [regex]'\[(?<team>ALL|T|CT|Spec)\]\s*(?<dot>[●•]\s*)?(?<name>[^@\uFE6B\uFF20:]+?)[\u200E\u200F\s]*(?:[@\uFE6B\uFF20]\s*(?<loc>[^:\[]+?)[\u200E\u200F\s]*)?(?<dead>\[DEAD\])?\s*:\s(?<msg>.+)$'
$CyrillicRegex = [regex]'[\u0400-\u04FF]'

function Find-ConsoleLog {
    $roots = @()
    try { $roots += (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction Stop).SteamPath } catch {}
    $roots += "C:\Program Files (x86)\Steam"

    $libraries = @()
    foreach ($root in $roots | Select-Object -Unique) {
        $vdf = Join-Path $root "steamapps\libraryfolders.vdf"
        $libraries += $root
        if (Test-Path $vdf) {
            foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) {
                $libraries += $m.Groups[1].Value -replace '\\\\', '\'
            }
        }
    }
    foreach ($lib in $libraries | Select-Object -Unique) {
        $csgo = Join-Path $lib "steamapps\common\Counter-Strike Global Offensive\game\csgo"
        if (Test-Path $csgo) { return Join-Path $csgo "console.log" }
    }
    return $null
}

function New-WebClient {
    $wc = New-Object System.Net.WebClient
    $wc.Encoding = [System.Text.Encoding]::UTF8
    $wc.Headers.Add("User-Agent", "Mozilla/5.0")
    return $wc
}

# Google first (detects the language); MyMemory as a fallback when Google rate-limits
function Translate-Text([string]$text) {
    $q = [System.Web.HttpUtility]::UrlEncode($text)
    try {
        $url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$TargetLang&dt=t&q=$q"
        $json = (New-WebClient).DownloadString($url) | ConvertFrom-Json
        $translated = ($json[0] | ForEach-Object { $_[0] }) -join ""
        return @{ Text = $translated; Lang = [string]$json[2] }
    } catch {
        $source = if ($CyrillicRegex.IsMatch($text)) { "ru" } else { "Autodetect" }
        $url = "https://api.mymemory.translated.net/get?q=$q&langpair=$source|$TargetLang"
        $json = (New-WebClient).DownloadString($url) | ConvertFrom-Json
        if ($json.responseStatus -ne 200) { throw $json.responseDetails }
        $lang = [string]$json.responseData.detectedLanguage
        if (-not $lang -and $CyrillicRegex.IsMatch($text)) { $lang = "ru" }
        return @{ Text = [System.Web.HttpUtility]::HtmlDecode($json.responseData.translatedText); Lang = $lang }
    }
}

$script:cache = @{}

function Get-LangName([string]$code) {
    if ($LangNames[$code]) { return $LangNames[$code] }
    try { return [System.Globalization.CultureInfo]::GetCultureInfo($code).EnglishName -replace '\s*\(.*\)', '' } catch { return $code }
}

# Turns one console.log line into a chat item, or $null if it isn't a chat line
function Parse-Line([string]$line) {
    $m = $ChatRegex.Match($line)
    if (-not $m.Success) { return $null }

    $msg = $m.Groups["msg"].Value.Trim()
    $item = @{
        Team  = $m.Groups["team"].Value
        Dot   = $m.Groups["dot"].Success
        Dead  = $m.Groups["dead"].Success
        Name  = $m.Groups["name"].Value.Trim()
        Loc   = $m.Groups["loc"].Value.Trim()
        Msg   = $msg
        Trans = $null
        Lang  = $null
    }

    # Skip messages with no letters at all ("!!!", "1", etc.)
    if ($msg -notmatch '\p{L}') { return $item }
    # Short Latin-script words ("gg", "nice", "rush") are almost always English and language detection guesses wrong on them
    $letters = ([regex]::Matches($msg, '\p{L}')).Count
    $isCjk = $msg -match '[\u3040-\u30FF\u3400-\u9FFF\uAC00-\uD7AF]'
    if ($letters -lt 5 -and -not $isCjk -and -not $CyrillicRegex.IsMatch($msg)) { return $item }

    $key = $msg.ToLowerInvariant()
    if (-not $script:cache.ContainsKey($key)) {
        try {
            $script:cache[$key] = Translate-Text $msg
        } catch {
            # Translation unavailable: only flag it when it is clearly not English
            $script:cache[$key] = if ($CyrillicRegex.IsMatch($msg)) { @{ Text = "[translation failed]"; Lang = "ru" } } else { $null }
        }
    }
    $r = $script:cache[$key]
    if ($r) {
        $sameLang = $r.Lang -and ($r.Lang -split '-')[0] -eq ($TargetLang -split '-')[0]
        $unchanged = $r.Text.Trim().ToLowerInvariant() -eq $key.Trim()
        if (-not $sameLang -and -not $unchanged) {
            $item.Trans = $r.Text
            # Detection often calls Russian chat Serbian/Kyrgyz/etc.; in CS2 Cyrillic is almost always Russian
            $code = if ($CyrillicRegex.IsMatch($msg) -and $r.Lang -notin @('ru', 'uk', 'be')) { 'ru' } else { $r.Lang }
            $item.Lang = Get-LangName $code
        }
    }
    return $item
}

function Format-Plain($item) {
    if ($item.Trans) { return "$($item.Name): $($item.Trans)  (translated from $($item.Lang))" }
    return "$($item.Name): $($item.Msg)"
}

# --- netcon (optional echo of translations into the CS2 console) ---
$script:netcon = $null
function Send-Netcon([string]$line) {
    try {
        if (-not $script:netcon -or -not $script:netcon.Connected) {
            $script:netcon = New-Object System.Net.Sockets.TcpClient
            $script:netcon.Connect("127.0.0.1", $NetconPort)
        }
        # Strip characters that would break the console command
        $safe = $line -replace '[";\r\n]', ''
        $bytes = [System.Text.Encoding]::UTF8.GetBytes("echo `"$safe`"`n")
        $script:netcon.GetStream().Write($bytes, 0, $bytes.Length)
    } catch {
        $script:netcon = $null
    }
}

# --- console.log tailing ---
$script:pos = -1
$script:partial = ""
function Read-NewLines {
    if (-not (Test-Path $LogPath)) { return @() }
    $fs = [System.IO.File]::Open($LogPath, 'Open', 'Read', 'ReadWrite, Delete')
    try {
        if ($script:pos -lt 0) { $script:pos = $fs.Length }      # start at the end on first run
        if ($fs.Length -lt $script:pos) { $script:pos = 0; $script:partial = "" }  # log was reset
        if ($fs.Length -eq $script:pos) { return @() }
        $fs.Seek($script:pos, 'Begin') | Out-Null
        $buf = New-Object byte[] ($fs.Length - $script:pos)
        $read = $fs.Read($buf, 0, $buf.Length)
        $script:pos += $read
    } finally { $fs.Close() }

    $text = $script:partial + [System.Text.Encoding]::UTF8.GetString($buf, 0, $read)
    $lines = $text -split "`r?`n"
    $script:partial = $lines[-1]
    if ($lines.Count -gt 1) { return $lines[0..($lines.Count - 2)] }
    return @()
}

# --- overlay window ---
# A layered window with per-pixel alpha: the text is anti-aliased straight into the window bitmap,
# so it stays solid and sharp (the old "black = transparent key" trick made the letter edges look thin and washed out).
# Only the dot in the top-left corner takes the mouse: left-drag moves the overlay, right-click closes it.
$OverlayCode = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class ChatOverlay : Form
{
    class Seg { public string Text; public Color Color; public bool Italic; }
    class Row { public List<Seg> Segs = new List<Seg>(); public DateTime Time; }

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

    int maxLines, W, H, dot, lineH;
    float scale;
    Font bold, italic;
    List<Row> rows = new List<Row>();

    public ChatOverlay(int x, int y, float scale, int maxLines)
    {
        this.scale = scale;
        this.maxLines = maxLines;
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        TopMost = true;
        AutoScaleMode = AutoScaleMode.None;
        StartPosition = FormStartPosition.Manual;

        dot = (int)(14 * scale);
        bold = new Font("Segoe UI", 16 * scale, FontStyle.Bold, GraphicsUnit.Pixel);
        italic = new Font("Segoe UI", 16 * scale, FontStyle.Italic, GraphicsUnit.Pixel);
        lineH = (int)Math.Ceiling(bold.GetHeight() + 5 * scale);
        W = (int)(1000 * scale);
        H = lineH * maxLines + (int)(10 * scale);
        Location = new Point(x, y);
        Size = new Size(W, H);
    }

    public int OverlayHeight { get { return H; } }

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

    protected override void OnShown(EventArgs e) { base.OnShown(e); Render(); }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == 0x84)   // WM_NCHITTEST: only the dot acts as a drag handle
        {
            long lp = m.LParam.ToInt64();
            int cx = (int)(short)(lp & 0xFFFF) - Left;
            int cy = (int)(short)((lp >> 16) & 0xFFFF) - Top;
            int pad = (int)(4 * scale);
            int d = (int)(4 * scale);
            bool onDot = cx >= d - pad && cx <= d + dot + pad && cy >= d - pad && cy <= d + dot + pad;
            m.Result = (IntPtr)(onDot ? 2 : 1);   // HTCAPTION : HTCLIENT
            return;
        }
        if (m.Msg == 0xA5) { Close(); return; }   // right-click on the dot closes the overlay
        base.WndProc(ref m);
    }

    public void AddLine(string[] texts, int[] argb, bool[] italics)
    {
        Row r = new Row();
        r.Time = DateTime.Now;
        for (int i = 0; i < texts.Length; i++)
        {
            Seg s = new Seg();
            s.Text = texts[i];
            s.Color = Color.FromArgb(argb[i]);
            s.Italic = italics[i];
            r.Segs.Add(s);
        }
        rows.Add(r);
        while (rows.Count > maxLines) rows.RemoveAt(0);
        Render();
    }

    public void Expire(double seconds)
    {
        DateTime cut = DateTime.Now.AddSeconds(-seconds);
        bool changed = false;
        while (rows.Count > 0 && rows[0].Time < cut) { rows.RemoveAt(0); changed = true; }
        if (changed) Render();
    }

    Bitmap Draw()
    {
        Bitmap bmp = new Bitmap(W, H, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(bmp))
        {
            g.Clear(Color.Transparent);
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;

            int d = (int)(4 * scale);
            using (SolidBrush sh = new SolidBrush(Color.FromArgb(120, 0, 0, 0))) g.FillEllipse(sh, d + 1, d + 1, dot, dot);
            using (SolidBrush wh = new SolidBrush(Color.FromArgb(245, 245, 245))) g.FillEllipse(wh, d, d, dot, dot);

            StringFormat fmt = new StringFormat(StringFormat.GenericTypographic);
            fmt.FormatFlags |= StringFormatFlags.MeasureTrailingSpaces | StringFormatFlags.NoWrap;
            float gap = 6 * scale;
            float y = 4 * scale;
            using (SolidBrush shadow = new SolidBrush(Color.FromArgb(200, 0, 0, 0)))
            {
                foreach (Row row in rows)
                {
                    float x = d + dot + 10 * scale;
                    foreach (Seg s in row.Segs)
                    {
                        Font f = s.Italic ? italic : bold;
                        float w = g.MeasureString(s.Text, f, 100000, fmt).Width;
                        g.DrawString(s.Text, f, shadow, x + 1, y + 1, fmt);
                        using (SolidBrush b = new SolidBrush(s.Color)) g.DrawString(s.Text, f, b, x, y, fmt);
                        x += w + gap;
                    }
                    y += lineH;
                }
            }
        }
        return bmp;
    }

    public void Snapshot(string path)
    {
        using (Bitmap bmp = Draw()) bmp.Save(path, ImageFormat.Png);
    }

    void Render()
    {
        if (!IsHandleCreated) return;
        using (Bitmap bmp = Draw())
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
                bf.BlendOp = 0; bf.BlendFlags = 0; bf.SourceConstantAlpha = 255; bf.AlphaFormat = 1;   // AC_SRC_OVER, AC_SRC_ALPHA
                UpdateLayeredWindow(Handle, screenDc, IntPtr.Zero, ref size, memDc, ref src, 0, ref bf, 2);   // ULW_ALPHA
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

function Add-ChatLine($item) {
    $teamColor = if ($Colors.ContainsKey($item.Team)) { $Colors[$item.Team] } else { $Colors.ALL }
    $team = if ($item.Team -eq "Spec") { "SPEC" } else { $item.Team }

    $texts = New-Object System.Collections.Generic.List[string]
    $argb = New-Object System.Collections.Generic.List[int]
    $italics = New-Object System.Collections.Generic.List[bool]
    $add = {
        param($text, $color, $isItalic)
        $texts.Add($text); $argb.Add($color.ToArgb()); $italics.Add([bool]$isItalic)
    }

    & $add "[$team]" $teamColor $false
    if ($item.Dot) { & $add "●" $Colors.Dot $false }
    & $add $item.Name $teamColor $false
    if ($item.Dead) { & $add "[DEAD]" $Colors.Trans $false }
    if ($item.Loc) { & $add "@ $($item.Loc)" $Colors.Loc $false }
    & $add ":" $teamColor $false
    & $add $item.Msg $Colors.Msg $false
    if ($item.Trans) { & $add "$($item.Trans)  (translated from $($item.Lang))" $Colors.Trans $true }

    $script:overlay.AddLine($texts.ToArray(), $argb.ToArray(), $italics.ToArray())
}

function Show-Line($item) {
    Write-Host (Format-Plain $item)
    if ($item.Trans) { Send-Netcon (Format-Plain $item) }
    if ($script:overlay) { Add-ChatLine $item }
}

function Update-Chat {
    foreach ($line in Read-NewLines) {
        $item = Parse-Line $line
        if ($item) { Show-Line $item }
    }
    if ($script:overlay) { $script:overlay.Expire($HideAfterSeconds) }
}

$script:overlay = $null

if ($Test) {
    foreach ($sample in @(("10/21 17:39:22  [ALL] Quattro" + [char]0x200E + ": ага"), ("10/21 17:08:05  [ALL] Hyperlinkhyper" + [char]0x200E + " [DEAD]: afk"), ("10/21 17:03:45  [T] `$_Franek_`$" + [char]0x200E + [char]0xFE6B + "T Start: hello"), "[T] ● Nic21 @ Palace Interior: Flashbang!", "[CT] Dmitri @ Mid: идите на б", "[ALL] Bob: hello", "[ALL] Ali: merhaba nasılsın", "[T] Joao: vamos para o bomb", "[CT] Wei: 我们去A点", "[ALL] Max: gg")) {
        $item = Parse-Line $sample
        Write-Host "$sample  ->  team=$($item.Team) name=$($item.Name) loc=$($item.Loc) dot=$($item.Dot) | $(Format-Plain $item)"
    }
    return
}

if ($Snapshot) {
    Add-Type -TypeDefinition $OverlayCode -ReferencedAssemblies System.Windows.Forms, System.Drawing
    $script:overlay = New-Object ChatOverlay -ArgumentList 0, 0, ([single]$DpiScale), $MaxLines
    Add-ChatLine @{ Team = "T"; Dot = $true; Dead = $false; Name = "Nic21"; Loc = "Palace Interior"; Msg = "Flashbang!"; Trans = $null; Lang = $null }
    Add-ChatLine @{ Team = "ALL"; Dot = $false; Dead = $true; Name = "Kas0n4ik"; Loc = ""; Msg = "это глупо"; Trans = "this is stupid"; Lang = "Russian" }
    Add-ChatLine @{ Team = "CT"; Dot = $false; Dead = $false; Name = "Dmitri"; Loc = "Mid"; Msg = "vamos para o bomb"; Trans = "let's go to the bomb"; Lang = "Portuguese" }
    $script:overlay.Snapshot($Snapshot)
    Write-Host "Saved $Snapshot"
    return
}

if (-not $LogPath) { $LogPath = Find-ConsoleLog }
if (-not $LogPath) {
    Write-Host "Could not find CS2. Run with -LogPath ""<...>\game\csgo\console.log"""
    exit 1
}
Write-Host "Watching $LogPath"
Write-Host "Make sure CS2 launch options include: -condebug -netconport $NetconPort"
Write-Host "Press Ctrl+C in this window to quit (or right-click the dot on the overlay)."

if ($NoOverlay) {
    while ($true) { Update-Chat; Start-Sleep -Milliseconds 300 }
}

Add-Type -TypeDefinition $OverlayCode -ReferencedAssemblies System.Windows.Forms, System.Drawing
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$y = if ($OverlayY -ge 0) { $OverlayY } else { $screen.Height - [int]((30 * $MaxLines + 10) * $DpiScale) - [int](380 * $DpiScale) }
$script:overlay = New-Object ChatOverlay -ArgumentList $OverlayX, $y, ([single]$DpiScale), $MaxLines

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 250
$timer.Add_Tick({ Update-Chat })
$timer.Start()

[System.Windows.Forms.Application]::Run($script:overlay)
