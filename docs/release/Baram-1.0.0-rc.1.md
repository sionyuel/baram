# Baram 1.0.0-rc.1

Baram의 첫 공개 프리릴리스입니다. 구름 입력기를 기반으로 독립 앱·입력 소스·설정 저장소와 바람 브랜드를 적용했습니다.

## 주요 변경

- 세벌식 최종·390 등 여러 한글 자판과 Universal Apple Silicon / Intel 앱
- 지원 세벌식에서 단어 단위 양방향 자동 한영 전환
- `jfshea → 안녕`, 영단어·`haezoom.com` 같은 도메인 복원
- 현재 음절은 자모 단위, 앞서 완성한 음절은 글자 단위로 지우는 Backspace 동작
- 키와 Shift에 반응하는 자판 미리보기
- 한글·영문 방향을 색과 문구로 구분하는 비활성 HUD
- macOS 기본 설정에 맞춘 간결한 설정 화면과 입력 소스 배지

## 배포 상태

- Release 구성, macOS 12 이상
- `arm64`와 `x86_64`를 포함한 Universal 앱
- ad-hoc 코드 서명
- Developer ID 서명과 Apple 공증 없음
- 자동 업데이트 비활성
- 물리적 동시입력과 자동 한영 전환은 실험 기능이며 기본 꺼짐

macOS가 앱을 차단하면 ZIP의 SHA-256을 확인한 뒤 앱을 한 번 열고 `시스템 설정 → 개인정보 보호 및 보안 → 확인 없이 열기`를 사용하세요. 보안 기능 전체를 끄거나 격리 속성을 제거하지 마세요.

## 검증

- 전체 macOS 단위 테스트 245개
- GitHub Actions build/test, Baram Release 계약, ShellCheck, Swift format
- Baram 번들 ID·defaults suite·InputMethodKit connection·숨긴 내부 Roman 확인
- 직접 입력 소스 아이콘과 Universal 아키텍처 확인
- 패키지 내부 파일과 외부 ZIP SHA-256 제공
- libhangul / libhangul-objc 대응 소스와 라이선스 포함

## 알려진 제한

- Apple 개발자 등록 전이라 Gatekeeper가 기본 실행을 차단합니다.
- 자동 한영 전환과 물리적 동시입력은 앱별 입력 처리에 따라 차이가 있을 수 있습니다.
- 문제가 생기면 ABC나 기존 한글 입력기로 전환하고, 기존 입력기는 제거하지 마세요.
- 자동 업데이트는 정식 서명·공증 릴리스 전까지 동작하지 않습니다.

보안 문제는 공개 이슈 대신 [비공개 보안 권고](https://github.com/sionyuel/baram/security/advisories/new)로 알려 주세요.
