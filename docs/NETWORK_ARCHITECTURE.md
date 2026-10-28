# GD-Sync 네트워크 구조

온라인 대전은 GD-Sync만 사용합니다. LAN 호스트, IP 직접 참가, Tailscale, `ENetMultiplayerPeer`, Godot RPC는 사용하지 않습니다.

## 역할과 권한

- `OFFLINE`: 로컬 게임 또는 온라인 방에 들어가기 전 상태
- `HOST`: GD-Sync 방장, 흑돌, 게임 규칙·난수·물리·승패의 권위자
- `CLIENT`: GD-Sync 참가자, 백돌, 입력을 방장에게 요청하고 결과를 적용

방은 `AA-` 접두사와 6자리 숫자 코드로 식별하며 최대 2명입니다. 참가자의 준비, 배치, 발사, 증강 선택과 액티브 스킬 입력은 방장이 순서 번호와 게임 상태를 검증합니다.

## 프로토콜 v4

v4는 큰 전체 상태를 매 프레임 보내지 않도록 전송을 두 종류로 나눕니다.

1. 빠른 상태는 돌 위치·속도, 턴, 라운드, 승패와 같은 물리·게임 진행 값입니다. 최대 20Hz로 unreliable 전송하며, 변화 직후 두 번 제한 재전송합니다. 변화가 없으면 쉬고 1초마다 heartbeat를 보냅니다.
2. 느린 상태는 보유 증강의 사용 횟수·재사용 대기·무작위 결과와 임시 벽입니다. 내용이 바뀔 때만 별도의 reliable `receive_world_extras` 메시지로 보냅니다.

heartbeat는 이동하지 않는 돌과 중요한 진행 상태가 장시간 갱신되지 않는 문제를 막습니다. 긴 유휴 뒤 받은 스냅샷은 유휴 시간을 보간 시간으로 사용하지 않습니다. 새 게임, 로비 복귀, 참가자 종료, 방 종료 때는 캐시를 초기화해 첫 전송이 항상 전체 최신 상태를 포함하게 합니다.

로비 데이터의 `protocol` 값이 현재 버전과 다르면 게임 준비 전에 방을 나가고 오류를 표시합니다.

## 전송량 확인

`AlkkagiNetworkManager.get_snapshot_metrics()`는 현재 경기에서 보낸 빠른 상태와 부가 상태의 횟수, 직렬화 바이트 합계, 최대 크기를 반환합니다.

- `fast_count`, `fast_bytes`, `fast_max_bytes`
- `extras_count`, `extras_bytes`, `extras_max_bytes`

이 값은 게임 payload의 `var_to_bytes` 크기이며 암호화·압축·GD-Sync envelope를 포함한 실제 회선 크기는 아닙니다. 실제 회선 크기는 GD-Sync profiler로 확인합니다. ENet MTU를 GD-Sync 한도로 간주하지 않습니다.

## 종료와 재접속

방장 또는 참가자가 나가면 준비 상태, 증강 선택 단계, 후보, 새로고침 사용 여부, 자유 배치 완료 상태, 모드 설정, 방 코드, 상대 ID와 스냅샷 캐시를 초기화합니다. 참가자는 메인 메뉴로 돌아가며 같은 프로세스에서 새 방을 만들거나 참가할 수 있습니다.

## 회귀 테스트

- `tests/test_snapshot_throttle.gd`
- `tests/test_augment_network_sync.gd`
- `tests/test_network_disconnect.gd`
- `tests/test_guest_rng_isolation.gd`
- `tests/test_setup_modes.gd`

실제 서비스 검증은 `tests/gdsync_lobby_driver.gd`로 두 프로세스를 실행해 방 생성·참가·준비·배치·선택·발사·승패를 확인합니다.
