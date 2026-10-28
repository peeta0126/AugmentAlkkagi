# 증강 알까기 (Augment Alkkagi)

Godot 4.7.2 기반 흑돌·백돌 물리 알까기 게임입니다. 한 PC에서 하는 로컬 2인 대전과 GD-Sync 기반 1:1 온라인 대전, 25종 증강을 지원합니다.

> 누가 무엇을 하는지는 이슈의 **📋 현황판**, 새로 바뀐 기능은 **🆕 변경 기록**에서 봅니다. 쓰는 법은 [팀 작업 안내](docs/TEAM_GUIDE.md).

## 실행

Godot 4.7.2에서 `project.godot`를 열고 F5를 누릅니다.

- `로컬 대전 시작`: 한 PC에서 흑돌과 백돌을 번갈아 플레이
- `온라인 방 만들기`: GD-Sync 방을 만들고 6자리 방 코드를 표시
- `온라인 방 코드 참가`: 전달받은 6자리 코드로 참가

```powershell
& 'C:\Godot\Godot_v4.7.2-stable_win64.exe' --path .
```

온라인 대전 방법은 [온라인 멀티플레이 안내](docs/ONLINE_MULTIPLAYER_GUIDE.md)를 참고하세요.

## 주요 기능

- 중력 0의 `RigidBody2D` 알까기 물리, CCD, 감속·정지·충돌 판정
- 504×540px(14:15) 보드, 19×19 격자, 화점 9개
- 3/4/5개 시작 설정과 자유 배치
- 시작 및 공동 3·6라운드 증강 선택, 플레이어별 최대 3개 제한
- 25종 증강과 Ver.3 개편 기능
- 증강 선택 후 턴 유지, 새로고침 모드, 혼돈 모드
- GD-Sync 로비, 준비, 6자리 방 코드, 호스트 권위 입력 검증, 변화 기반 스냅샷과 보간
- Windows Desktop x86_64 내보내기 프리셋

## 자동 테스트

개별 테스트는 다음처럼 실행합니다.

```powershell
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_phase1.gd
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_game_scene.gd
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_board_geometry.gd
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_augments.gd
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_all_augments.gd
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_setup_modes.gd
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_snapshot_throttle.gd
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_network_disconnect.gd
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_guest_rng_isolation.gd
```

온라인 동기화 구조와 프로토콜 변경 사항은 [네트워크 구조](docs/NETWORK_ARCHITECTURE.md)를 참고하세요.

## Windows 빌드

Godot 4.7.2 Export Templates를 설치한 뒤 `Project > Export > Windows Desktop`에서 내보냅니다. 기본 경로는 `build/AugmentAlkkagi.exe`이며 PCK가 실행 파일에 포함됩니다.
