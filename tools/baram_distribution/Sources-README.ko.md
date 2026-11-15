# 대응 소스와 출처

`baram-source.tar.gz`는 build-info의 sourceCommit에 해당하는 저장소 추적 파일입니다. sourceWorktreeDirty가 true이면 `baram-worktree.patch`를 적용해야 빌드 당시 추적 파일 변경이 반영됩니다. 이 경우 정식 출처가 고정된 배포물로 취급하지 않습니다.

`libhangul-objc-source.tar.gz`, `libhangul-source.tar.gz`는 빌드에 사용한 각각의 Git 커밋 전체 추적 파일입니다. 커밋과 tree ID는 `source-provenance.json`에 기록합니다. 두 LGPL 저장소는 변경되지 않은 상태에서만 패키징할 수 있습니다.

Baram 앱 코드의 기본 조건은 BSD이며 libhangul과 libhangul-objc는 각 COPYING의 LGPL 조건을 따릅니다. 상위 Gureum에서 물려받은 아이콘 고지는 별도 파일로 포함됩니다. 새 Baram 브랜드 자산의 최종 공개 라이선스 승인은 아직 릴리스 게이트이므로 이 로컬 후보를 정식 재배포물로 취급하지 않습니다. `LICENSES/`의 원문과 `Package.resolved`를 함께 확인하세요. 동적 프레임워크를 수정·재빌드하여 교체할 수 있으며, 변경 후 앱의 원래 무결성 서명은 무효가 됩니다. 본인의 로컬 변경 앱에 ad-hoc 서명을 적용할 수 있지만 Developer ID 인증이나 Apple 공증을 제공하지 않습니다.

빌드 도구는 저장소 HACKING.md에 설명되어 있습니다. 이 묶음에는 타사 글꼴 파일이 포함되지 않습니다.
