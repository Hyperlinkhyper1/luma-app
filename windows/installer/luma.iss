; Inno Setup script for luma.
;
; Installs to %LOCALAPPDATA%\Programs\luma (per-user, no admin rights needed —
; this is what lets the in-app updater (lib/app/update/) run the installer
; silently and swap files without a UAC prompt).
;
; MyAppVersion is passed from CI via: ISCC /DMyAppVersion=1.0.42 luma.iss
#define MyAppName "luma"
#define MyAppExeName "luma.exe"
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

[Setup]
AppId={{8F1B2C3D-4E5F-4A6B-9C7D-1E2F3A4B5C6D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=Hyperlinkhyper1
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Per-user install — no UAC prompt, and the updater can silently re-run this
; installer to update itself.
PrivilegesRequired=lowest
OutputBaseFilename=luma-setup
OutputDir=..\..\dist
Compression=lzma2
SolidCompression=yes
; Closes a running luma.exe before copying files, and we relaunch it via the
; [Run] entry below — together this makes silent updates seamless.
CloseApplications=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
SetupIconFile=..\runner\resources\app_icon.ico

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; No "skipifsilent" — this must also fire during a silent updater-driven
; install so the app relaunches itself automatically after updating.
Filename: "{app}\{#MyAppExeName}"; Description: "Launch luma"; Flags: nowait postinstall
