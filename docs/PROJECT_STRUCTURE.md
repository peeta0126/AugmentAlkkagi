# 프로젝트 구조

```text
res://
├─ resources/augments/                 # 20개 AugmentDefinition .tres
├─ resources/balance/                  # 기본 발사·물리 Balance Resource
├─ scripts/
│  ├─ core/game_manager.gd             # 턴·UI·대상 선택·효과 조율
│  ├─ core/game_state_machine.gd
│  ├─ augments/
│  │  ├─ augment_definition.gd
│  │  ├─ augment_manager.gd            # 카탈로그·소유·이벤트 집계
│  │  └─ effects/                      # 증강별 독립 스크립트 20개
│  ├─ gameplay/
│  │  ├─ board.gd
│  │  ├─ gameplay_rules.gd
│  │  ├─ physics_balance.gd            # 조정 가능한 단일 물리 데이터 모델
│  │  ├─ skill_projectile.gd           # 코드 드로잉 투사체
│  │  └─ temporary_wall.gd             # 월마리아 StaticBody2D
│  └─ physics/piece.gd                 # 상태·변신·물리 복원
└─ tests/
   ├─ test_phase1.gd
   ├─ test_game_scene.gd
   ├─ test_board_geometry.gd
   ├─ test_augments.gd
   └─ test_all_augments.gd
```

새 증강은 Resource와 Effect를 추가하고 카탈로그에 등록한다. 개별 효과는 공통 이벤트를 재정의하며 GameManager의 거대한 ID 조건문을 사용하지 않는다. UI는 Effect의 공통 사용 상태를 읽는다.
