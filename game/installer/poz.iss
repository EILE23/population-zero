; POZ 설치 파일(운영자 2026-10-06: "게임 실행이 설치 파일이어야 하고 자동 업데이트가 다른 게임 프로그램처럼") — CI(build-game-client.yml)의 Windows 단계가 Inno Setup 으로 굽는다.
; 사용자 폴더(%LOCALAPPDATA%\Programs\POZ)에 깐다 — 관리자 권한이 필요 없고, 게임이 제 폴더에 새 버전(POZ.pck)을 받아 바꿔 끼울 수 있다(client_update.gd).
; 시작 메뉴·바탕 화면 바로 가기, 제거 프로그램(설정 → 앱), 설치가 끝나면 바로 실행.
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{6E1C9F2B-5B7A-4C1E-9E0D-3F2A1B7C9D01}
AppName=POZ
AppVersion={#AppVersion}
AppVerName=POZ {#AppVersion}
AppPublisher=population.town
AppPublisherURL=https://population.town
AppSupportURL=https://population.town
DefaultDirName={localappdata}\Programs\POZ
DefaultGroupName=POZ
DisableProgramGroupPage=yes
DisableDirPage=yes
PrivilegesRequired=lowest
OutputDir=..\export
OutputBaseFilename=POZ-Setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\POZ.exe
CloseApplications=yes

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"

[Files]
Source: "..\export\windows\POZ.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\export\windows\POZ.pck"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\POZ"; Filename: "{app}\POZ.exe"
Name: "{group}\Uninstall POZ"; Filename: "{uninstallexe}"
Name: "{userdesktop}\POZ"; Filename: "{app}\POZ.exe"; Tasks: desktopicon

[Run]
; 조용한 설치(게임 안 자동 업데이트)도 끝나면 다시 켠다 — skipifsilent 를 빼서
Filename: "{app}\POZ.exe"; Description: "Play POZ now"; Flags: nowait postinstall

[UninstallDelete]
Type: files; Name: "{app}\POZ.pck.new"
