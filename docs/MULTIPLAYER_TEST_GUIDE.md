# 친구와 멀티플레이 테스트

## 1. Tailscale 준비

1. 두 Windows PC에 Tailscale을 설치하고 같은 tailnet에 로그인합니다.
2. 호스트 PC에서 Tailscale의 IPv4 주소(`100.x.x.x`)를 확인합니다.
3. Windows Defender 방화벽에서 게임 실행 파일의 사설 네트워크 통신을 허용합니다. 직접 규칙을 만들 때는 인바운드 UDP 7777을 허용합니다.
4. 참가자 PC에서 `ping 호스트의_Tailscale_IP`로 VPN 연결을 먼저 확인합니다.

## 2. 호스트

1. 게임을 실행하고 `방 만들기`를 누릅니다.
2. `UDP 7777` 대기 메시지를 확인합니다.
3. 시작 바둑알 수를 3/4/5 중 선택합니다.
4. `준비`를 켜고 친구의 접속과 준비를 기다립니다.
5. 양쪽 준비 후 활성화되는 `게임 시작`을 누릅니다.

## 3. 참가자

1. 게임을 실행하고 `방 참가하기`를 누릅니다.
2. 호스트의 Tailscale IPv4와 포트 `7777`을 입력합니다.
3. 로비 입장 후 `준비`를 켭니다.
4. 백돌 증강 후보 3개 중 하나를 선택합니다. 이후 백돌 차례에만 입력할 수 있습니다.

## 4. 같은 PC에서 사전 확인

게임 실행 파일을 두 번 실행합니다. 첫 창은 방을 만들고 두 번째 창은 `127.0.0.1:7777`로 참가합니다. 설정 동기화, 준비, 증강 선택, 양쪽 발사, 탈락과 연결 종료까지 확인합니다.

자동 localhost 통합 검사는 개발용 포트 7787을 사용합니다. 호스트와 클라이언트 하네스를 동시에 실행해야 합니다.

```powershell
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/network_host_harness.gd
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/network_client_harness.gd
```

## 5. Windows 빌드

Godot 4.7.2에서 `Editor > Manage Export Templates`로 같은 버전의 템플릿을 설치합니다. 그 다음 `Project > Export > Windows Desktop > Export Project`를 선택합니다. 프리셋 출력은 `build/AugmentAlkkagi.exe`이며 PCK가 실행 파일에 포함됩니다. 친구에게 EXE 하나를 전달할 수 있습니다.

CLI에서는 다음 명령을 사용할 수 있습니다.

```powershell
New-Item -ItemType Directory -Force build
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --export-release 'Windows Desktop' build\AugmentAlkkagi.exe
```

## 문제 해결

- 접속 실패: 두 PC의 Tailscale 연결, IPv4 오타, UDP 7777 방화벽, 호스트가 먼저 방을 만들었는지 확인합니다.
- 시작 버튼 비활성: 참가자가 실제로 연결되어 있고 양쪽 `준비`가 켜졌는지 확인합니다.
- 호스트 종료: 참가자는 메인 메뉴로 돌아갑니다. 새 방을 만든 뒤 다시 접속해야 합니다.
- 지연: 호스트 물리가 기준이므로 참가자 화면은 약간 늦을 수 있습니다. 연속 클릭해도 sequence와 턴 검사로 중복 발사는 거절됩니다.
