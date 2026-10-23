# 증강 알까기 (Augment Alkkagi)

Godot 4.7.2 기반 흑돌·백돌 물리 알까기 게임입니다. 로컬 2인 대전과 ENet 호스트 권위 방식의 1:1 네트워크 대전, 20종 증강을 지원합니다.

## 실행

Godot 4.7.2에서 `project.godot`를 열고 F5를 누릅니다.

- `로컬 대전`: 한 PC에서 흑돌과 백돌을 번갈아 플레이
- `방 만들기`: UDP 7777에서 호스트 시작
- `방 참가하기`: 호스트의 LAN 또는 Tailscale IPv4로 참가
- 네트워크 대전은 호스트가 흑돌, 참가자가 백돌입니다.

```powershell
& 'C:\Godot\Godot_v4.7.2-stable_win64.exe' --path .
```

## 네트워크 대전 요약

두 PC를 같은 Tailscale tailnet에 연결합니다. 호스트가 방을 만들고 참가자가 호스트의 `100.x.x.x` 주소와 포트 7777을 입력합니다. 양쪽이 준비하면 호스트가 게임을 시작합니다. 인터넷 방 코드나 중앙 서버가 아니라 Tailscale VPN 위의 직접 UDP 연결입니다.

상세 절차는 [멀티플레이 테스트 가이드](docs/MULTIPLAYER_TEST_GUIDE.md), 구조와 보안 경계는 [네트워크 아키텍처](docs/NETWORK_ARCHITECTURE.md)를 참고하세요.

## 구현 기능

- 중력 0의 `RigidBody2D` 알까기, CCD, 감속·정지·낙하·승리 판정
- 504×540px(14:15) 원목 보드, 19×19 격자, 화점 9개, 실제 비율 흑돌·백돌
- 3/4/5개 시작 설정과 로컬 턴제 플레이
- 시작 및 플레이어별 4턴 주기 증강 선택
- Passive, Active, Triggered, Transformation, Field, Victory 유형의 증강 20종
- ENet 로비, 준비, 호스트 설정 동기화, 권위 입력 검증, 20Hz 압축 스냅샷과 보간
- Windows Desktop x86_64 export 프리셋(PCK 내장)

## 자동 테스트

개별 테스트는 다음처럼 실행합니다.

```powershell
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_phase1.gd
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_game_scene.gd
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_board_geometry.gd
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_augments.gd
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_all_augments.gd
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_launch_balance.gd
```

네트워크 하네스는 호스트와 클라이언트를 동시에 실행합니다. 상세 결과는 [테스트 보고서](docs/TEST_REPORT.md)에 기록했습니다.

## Windows 빌드

동일한 4.7.2 Export Templates를 설치한 후 Godot의 `Project > Export > Windows Desktop`에서 내보냅니다. 기본 경로는 `build/AugmentAlkkagi.exe`이며 PCK가 실행 파일에 포함됩니다.
