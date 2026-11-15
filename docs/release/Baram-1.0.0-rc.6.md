# Baram 1.0.0-rc.6

반복 한글 자모를 영문 반복 키로 잘못 복원하는 문제를 막은 여섯 번째 프리릴리스입니다.

## 주요 변경

- `ㅎㅎㅎㅎ`, `ㅋㅋㅋㅋ`, `ㅠㅠ`처럼 같은 한글 자모가 반복된 채팅 표현을 한글로 보존
- 공백·Return·Tab 확정과 마침표 입력 모두에서 반복 자모 우선
- `mmmm → ㅎㅎㅎㅎ`, `0000 → ㅋㅋㅋㅋ` 회귀 테스트 추가
- RC5의 도메인 즉시 전환, 기술용어, 숫자·기호 보존과 토스트 연속성 유지

## 배포 상태

- Release 구성, macOS 12 이상
- `arm64`와 `x86_64`를 포함한 Universal 앱
- ad-hoc 코드 서명
- Developer ID 서명과 Apple 공증 없음
- 자동 업데이트 비활성

## 검증

- 전체 macOS 단위 테스트 290개
- 자동 한영 전환 회귀 테스트 98개
- 반복 자모에 강한 영문 사전 판정을 주입해도 한글 보존 확인
- GitHub Actions build/test, Baram Release 계약, ShellCheck, Swift format

## 알려진 제한

- Apple 개발자 등록 전이라 Gatekeeper가 기본 실행을 차단합니다.
- 특정 편집기의 조합 범위 처리에 따라 자동전환 버퍼가 시작되지 않을 수 있습니다.
- 자동 업데이트는 정식 서명·공증 릴리스 전까지 동작하지 않습니다.

보안 문제는 공개 이슈 대신 [비공개 보안 권고](https://github.com/sionyuel/baram/security/advisories/new)로 알려 주세요.
