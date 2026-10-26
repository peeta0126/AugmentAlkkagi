# 공동 개발 환경 설정

두 노트북 모두 Godot 4.7.2에서 같은 Git 저장소를 사용합니다. 실행 파일이나 ZIP은 공유하지 않습니다.

## 최초 1회 설정

1. 저장소를 clone합니다.
2. `addons/GD-Sync/keys.cfg.example`을 `addons/GD-Sync/keys.cfg`로 복사합니다.
3. 팀에서 공유하는 GD-Sync public/private key를 `keys.cfg`에 입력합니다.
4. Godot에서 `project.godot`을 열고 실행합니다.

PowerShell에서는 다음 명령으로 예제 파일을 복사할 수 있습니다.

```powershell
Copy-Item addons/GD-Sync/keys.cfg.example addons/GD-Sync/keys.cfg
```

`keys.cfg`는 Git에서 제외되므로 각 노트북에 로컬로 유지됩니다. 키 값은 메신저보다 비밀번호 관리자 같은 별도 보안 채널로 최초 한 번만 전달합니다.

## 평소 작업 흐름

작업 시작 전 최신 코드를 받고, 변경 사항은 일반적인 Git 작업 흐름으로 공유합니다.

```powershell
git pull
# Godot에서 개발 및 온라인 테스트
git add <변경한 파일>
git commit -m "변경 내용"
git push
```

다른 노트북은 다시 `git pull`한 뒤 Godot에서 바로 실행합니다. 로컬의 `keys.cfg`는 pull해도 삭제되거나 덮어써지지 않습니다.

## 주의사항

- `addons/GD-Sync/keys.cfg`와 키가 내장된 배포 파일을 커밋하지 않습니다.
- `build/*.exe`와 `build/*.zip`은 로컬 산출물로 계속 무시됩니다.
- 키가 Git 기록이나 공개 파일에 노출되면 GD-Sync 대시보드에서 즉시 교체합니다.
