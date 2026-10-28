# 테스트 보고서

최종 검증일: 2026-10-28

## 자동 회귀 테스트

Godot 4.7.2 headless 환경에서 다음 테스트가 모두 종료 코드 0과 PASS를 반환했습니다.

- `test_phase1.gd`: 기본 규칙과 턴 진행
- `test_game_scene.gd`: 씬 로드, 발사, 이동, 승리
- `test_augments.gd`, `test_all_augments.gd`, `test_new_augments_v2.gd`: 기존 증강과 개편 증강
- `test_setup_modes.gd`: 자유 배치, 새로고침·혼돈 모드 조합, 증강 선택 후 턴 유지
- `test_augment_network_sync.gd`: 증강 상태 스냅샷 동기화
- `test_network_interpolation.gd`: 참가자 스냅샷 보간
- `test_network_shot_clamp.gd`: 호스트 발사력 검증
- `test_client_active_skill.gd`: 참가자 액티브 스킬 입력
- `test_snapshot_throttle.gd`: 변화 기반 전송, heartbeat, reliable 부가 상태 분리
- `test_network_disconnect.gd`: 방장·참가자 종료 뒤 세션 전체 초기화
- `test_guest_rng_isolation.gd`: 호스트 권위 난수 결과 동기화

## GD-Sync 통합 테스트

실제 GD-Sync 서비스에 호스트와 참가자 Godot 프로세스를 연결해 다음 흐름을 확인했습니다.

- 6자리 코드 방 생성과 참가
- 2인 제한과 양쪽 준비 상태 동기화
- 게임 시작과 양쪽 자유 배치 완료
- 양쪽 증강 제안·선택·확정
- 호스트 발사와 참가자 발사 요청 검증
- 턴 변경, 스냅샷 반영, 호스트 승리 판정과 게임 오버 동기화

프로토콜 v4는 같은 PC의 독립된 호스트·참가자 프로세스로 다시 검증해 양쪽 PASS를 확인했습니다. 물리적으로 분리된 두 PC 환경의 v4 통합 테스트는 아직 다시 수행하지 않았습니다.

## 환경 경고

샌드박스 내부 실행에서는 Godot 사용자 로그 경로와 Windows 루트 인증서 저장소 접근이 제한됩니다. 온라인 통합 테스트는 해당 제한이 없는 환경에서 별도로 실행했습니다. GD-Sync 디버그 로거의 활성 디버거 부재 메시지와 일부 리소스 UID 대체 경고는 기존 경고이며 테스트 결과에는 영향을 주지 않았습니다.
