# Baram 1.0.0-rc.2

첫 공개 후보의 입력 동작을 확장한 두 번째 프리릴리스입니다. 현대 두벌식 자동 한영 전환과 한 토큰 안의 영문·한글 경계 처리를 추가했습니다.

## 주요 변경

- 현대 두벌식(`2-full`)과 기존 지원 세벌식에서 양방향 자동 한영 전환
- 두벌식 `dkssud → 안녕`, `rksk → 가나`
- 두벌식 `githubdptj → github에서`, 세벌식 최종 `githubjcnt → github에서`
- 영문 접두어가 확실하고 한글 접미어가 완전히 조합되는 유일한 경계만 변환
- `v2`, `build.sh`, `foo/bar`, `--flag`, `key=value` 같은 코드형 토큰 보존
- 두벌식 고유 재음절화와 Backspace 동작 보존
- 두벌식 옛글(`2y-full`)은 이번 자동 전환 범위에서 제외

## 배포 상태

- Release 구성, macOS 12 이상
- `arm64`와 `x86_64`를 포함한 Universal 앱
- ad-hoc 코드 서명
- Developer ID 서명과 Apple 공증 없음
- 자동 업데이트 비활성
- 자동 한영 전환과 물리적 동시입력은 기본 꺼짐인 실험 기능

macOS가 앱을 차단하면 ZIP의 SHA-256을 확인한 뒤 앱을 한 번 열고 `시스템 설정 → 개인정보 보호 및 보안 → 확인 없이 열기`를 사용하세요. 보안 기능 전체를 끄거나 격리 속성을 제거하지 마세요.

## 검증

- 전체 macOS 단위 테스트 261개
- 두벌식 자동 전환 켬/끔의 Backspace 결과를 입력 단계마다 비교
- 혼합 토큰, 코드형 토큰, 보안 입력, 중복 삽입 방지 회귀 테스트
- GitHub Actions build/test, Baram Release 계약, ShellCheck, Swift format
- Baram 번들 ID·defaults suite·InputMethodKit connection·숨긴 내부 Roman 확인
- 직접 입력 소스 아이콘과 Universal 아키텍처 확인
- 패키지 내부 파일과 외부 ZIP SHA-256 제공
- libhangul / libhangul-objc 대응 소스와 라이선스 포함

## 알려진 제한

- Apple 개발자 등록 전이라 Gatekeeper가 기본 실행을 차단합니다.
- 두벌식 한 음절 조사만 붙인 혼합 토큰은 보수적으로 변환하지 않을 수 있습니다.
- 실제 앱의 조합 문자열 처리에 따라 자동 전환 동작이 다를 수 있습니다.
- 문제가 생기면 ABC나 기존 한글 입력기로 전환하고, 기존 입력기는 제거하지 마세요.
- 자동 업데이트는 정식 서명·공증 릴리스 전까지 동작하지 않습니다.

보안 문제는 공개 이슈 대신 [비공개 보안 권고](https://github.com/sionyuel/baram/security/advisories/new)로 알려 주세요.
