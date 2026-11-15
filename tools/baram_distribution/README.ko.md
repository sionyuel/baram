# Baram 2.0.0 프리릴리스

이 묶음은 Release 구성으로 빌드한 Apple Silicon·Intel Universal 앱입니다. Developer ID 서명과 Apple 공증은 없으며 ad-hoc 서명은 파일 무결성 검사만 제공합니다. 공개 시험용이며 자동 업데이트 피드에는 연결하지 않습니다.

`Baram.app`, `build-info.json`, `LICENSES/`, `Sources/`, `SHA256SUMS`가 함께 제공됩니다. 압축 파일 옆의 `.sha256`은 ZIP 전체 체크섬입니다. 풀어 놓은 디렉터리에서는 다음으로 파일 무결성을 확인합니다.

```sh
shasum -a 256 -c SHA256SUMS
codesign --verify --deep --strict Baram.app
```

이 패키저는 앱을 설치하거나 입력 소스를 바꾸지 않습니다. 실제 설치·업데이트·복구는 저장소 README와 `tools/install_baram.sh`의 개발자용 절차를 따릅니다. Gatekeeper·격리 속성·입력 모니터링 권한을 변경하는 스크립트는 포함하지 않습니다. macOS가 차단하면 체크섬을 확인한 뒤 시스템 설정 → 개인정보 보호 및 보안의 ‘확인 없이 열기’를 사용하세요.

업데이트 확인은 꺼져 있습니다. 자동 한영 전환은 지원 세벌식 자판에서 실험 기능이며, 실제 앱별 호환성은 별도 검증이 필요합니다. 물리적 동시입력은 기본 꺼짐 상태의 실험 기능입니다.

소스: https://github.com/sionyuel/baram
