; Forja — Windows Installer (Inno Setup 6)
; Built from: apps/forja/build/windows/x64/runner/Release/
; CI: iscc /DMyAppVersion=1.0.9 /DMyOutputBaseFilename=Forja-1.0.9-windows-setup setup.iss

#ifndef MyAppVersion
  #define MyAppVersion "1.0.10"
#endif
#ifndef MyOutputBaseFilename
  #define MyOutputBaseFilename "Forja-Windows-Setup"
#endif

#define MyAppName      "Forja"
#define MyAppPublisher "Forja"
#define MyAppExeName   "forja.exe"
#define MyAppURL       "https://github.com/mGhassen/Forja"

[Setup]
AppId={{F1A2B3C4-D5E6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
SetupIconFile=..\..\apps\forja\windows\runner\resources\app_icon.ico
OutputDir=Output
OutputBaseFilename={#MyOutputBaseFilename}
Compression=lzma2/ultra64
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
PrivilegesRequired=lowest
DisableProgramGroupPage=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\..\apps\forja\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
Type: filesandordirs; Name: "{app}\data\flutter_assets\*"
Type: files; Name: "{app}\*.dll.old"

[Icons]
Name: "{group}\{#MyAppName}";    Filename: "{app}\{#MyAppExeName}"
Name: "{userdesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
