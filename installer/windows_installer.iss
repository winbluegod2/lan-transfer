; ============================================================
; LAN Transfer - Inno Setup 安装脚本
; 构建命令：iscc installer\windows_installer.iss
; ============================================================

#define AppName "LAN Transfer"
#define AppVersion "1.0.0"
#define AppPublisher "LAN Transfer"
#define AppExeName "lan_transfer.exe"
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{8F4A2C1B-3D9E-4F7A-B2C5-6E8D9F0A1B2C}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
AllowNoIcons=yes
; 输出目录
OutputDir=output
OutputBaseFilename=LanTransferSetup
; 压缩
Compression=lzma2/ultra64
SolidCompression=yes
; UI
WizardStyle=modern
WizardResizable=yes
; 图标（使用 Flutter 默认图标）
; SetupIconFile=..\windows\runner\resources\app_icon.ico
; 最低系统要求
MinVersion=10.0
; 64位安装
ArchitecturesInstallIn64BitMode=x64compatible
; 安装后不需要重启
RestartIfNeededByRun=no
; 版本信息
VersionInfoVersion={#AppVersion}
VersionInfoDescription={#AppName} Installer
VersionInfoProductName={#AppName}

[Languages]
; 简体中文
Name: "chinesesimp"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
; 英文备用
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加图标："
Name: "startupicon"; Description: "开机自动启动"; GroupDescription: "附加图标："; Flags: unchecked

[Files]
; 复制所有 Flutter Windows 构建产物
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
; 开始菜单
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\卸载 {#AppName}"; Filename: "{uninstallexe}"
; 桌面快捷方式
Name: "{commondesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon
; 开机启动
Name: "{userstartup}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: startupicon

[Registry]
; 注册防火墙例外（允许 53317 端口）
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules"; \
  ValueType: string; \
  ValueName: "LanTransfer-In"; \
  ValueData: "v2.30|Action=Allow|Active=TRUE|Dir=In|Protocol=6|LPort=53317|Name=LAN Transfer|Desc=LAN Transfer file sharing|App={app}\{#AppExeName}|"; \
  Flags: uninsdeletevalue; MinVersion: 6.0

[Run]
; 安装完成后启动程序
Filename: "{app}\{#AppExeName}"; \
  Description: "立即启动 {#AppName}"; \
  Flags: nowait postinstall skipifsilent

[UninstallDelete]
; 卸载时删除 AppData 中的数据（可选）
; Type: filesandordirs; Name: "{localappdata}\lan_transfer"

[Code]
// 安装前检查 Windows 版本
function InitializeSetup(): Boolean;
begin
  Result := True;
  if not IsWin64 then begin
    MsgBox('LAN Transfer 需要 64 位 Windows 10 或更高版本。', mbError, MB_OK);
    Result := False;
  end;
end;
