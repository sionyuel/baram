# Baram 1.0.0 Release Candidate Checklist

이 문서는 Baram 첫 공개 릴리스 후보를 만드는 검증 기록입니다. 자동 테스트 통과와 공개 준비 완료를 혼동하지 않습니다. 각 후보마다 복사해 실제 결과·날짜·담당자를 기록합니다.

## 후보 정보

- Version: `1.0.0-rc.N`
- Source commit:
- Tag candidate: `Baram-1.0.0-rc.N`
- Built at UTC:
- Xcode / macOS:
- Package SHA-256:
- Apple Developer team:
- Signing identity:
- Notarization submission ID:

## 자동 게이트

- [ ] Swift format lint
- [ ] 전체 macOS 단위 테스트
- [ ] Baram Release 변형 빌드
- [ ] `arm64`와 `x86_64` 포함
- [ ] 번들 ID `com.sionyuel.inputmethod.Baram`
- [ ] executable `Baram`
- [ ] defaults suite `com.sionyuel.Baram`
- [ ] IMK connection `Baram_Connection`
- [ ] product kind `baram`
- [ ] 내부 Roman 모드는 입력 소스 추가 목록에서 숨김
- [ ] RC에서는 `BaramUpdateFeedEnabled=false`
- [ ] 직접 입력 소스 아이콘 1x/2x 존재 및 크기 검증
- [ ] 앱 코드 서명 검증
- [ ] 패키지 내부 `SHA256SUMS` 재검증
- [ ] libhangul / libhangul-objc 대응 소스·라이선스 포함
- [x] `site/baram` 공개 build 및 다운로드·경고·인덱싱 계약 검증

## 설치·복구

Mac Studio와 MacBook에서 각각 수행합니다.

- [ ] 새 사용자 설치
- [ ] 기존 Baram 위 업데이트
- [ ] 기존 Gureum과 공존
- [ ] Lab이 설치되어 있지 않음
- [ ] 기존 Baram 설정 유지
- [ ] 기존 3F 선택 복구
- [ ] ABC 선택 상태에서 설치하면 ABC 유지
- [ ] 잘못된 번들 ID·심볼릭 링크 설치 거부
- [ ] 교체 실패 시 직전 Baram 복구
- [ ] 제거가 앱을 영구 삭제하지 않고 백업으로 이동
- [ ] 백업에서 복원 후 코드 서명·입력 소스 재등록 확인

## 입력 실기 QA

대상 앱: TextEdit, Safari, Chrome, Slack, Paseo, Terminal, System Settings 검색.

- [ ] Shift+Space를 두 번 눌러도 macOS 입력 소스가 Baram에 남음
- [ ] 세벌식 최종 기본 입력
- [ ] 세벌식 390 기본 입력
- [ ] 모아치기 `가`+`ㅗ` 역순이 `과`로 조합
- [ ] `jfshea ` → `안녕 ` 후 다음 입력은 한글
- [ ] 한글 모드에서 잘못 친 `apple ` → `apple ` 후 다음 입력은 영문
- [ ] `haezoom.com ` 도메인 복원
- [ ] 일반 영어 `apple `이 `appleapple `로 중복되지 않음
- [ ] `안녀 → 안ㄴ → 안 → 빈 문자열`
- [ ] 현재 첫 음절 `안 → 아 → ㅇ → 빈 문자열`
- [ ] 자동완성 선택·마우스 이동·포커스 변경 후 중복 없음
- [ ] Terminal과 Secure Input에서 자동 전환하지 않고 원문 유지
- [ ] 한자·이모지 후보와 자동 전환 버퍼가 충돌하지 않음
- [ ] 한글/영문 HUD 색상·1.8초 유지·Reduce Motion 확인
- [ ] 설정 키보드 미리보기의 실제 키·Shift 반응
- [ ] 설정 창을 닫았다 다시 열어도 키보드 미리보기 반응 유지
- [ ] `므너두 ` → `github `, `githubjcnt ` → `github에서 `
- [ ] `사용하다 보면 `이 `사용하다 ;vies `로 바뀌지 않음
- [ ] 자동 전환 직후 Backspace로 원문·이전 모드 복원, 두 번째 Backspace는 일반 삭제
- [ ] 다른 입력·커서 이동·클라이언트 변경·보안 입력 뒤에는 직전 변환을 복원하지 않음
- [ ] `haezoom.`에서 즉시 로마자 전환하고 `com`을 이어 입력
- [ ] `tailscale ` 복원과 즉시 Backspace 취소
- [ ] 세벌식 `5555`, `ㅋㅋㅋㅋ.`, `ㅎㅎㅎㅎ.` 보존
- [ ] 토스트 자연 종료·빠른 취소·교체 시 깜빡임 없음
- [ ] `ㅎㅎㅎㅎ `, `ㅋㅋㅋㅋ `, `ㅠㅠ `가 로마자로 역변환되지 않음
- [ ] 전화번호·인증번호 숫자 입력 뒤 marked range가 남지 않아 앱의 자동 하이픈과 충돌하지 않음
- [ ] `Control+Command+L`로 현재 단어 영문 학습, 다음 입력부터 자동 적용
- [ ] 자동변환 Backspace 취소가 자판별 한글 유지 예외로 저장됨
- [ ] 고급 설정에서 개인 학습 항목 개별 삭제·전체 초기화

## 서명·공증 게이트

아래 항목은 Sionyuel 소유 자격 증명이 필요합니다. 로컬 ad-hoc 후보에서는 완료로 표시하지 않습니다.

- [ ] Developer ID Application으로 앱 및 내장 코드 서명
- [ ] Developer ID Installer로 PKG 서명
- [ ] `xcrun notarytool submit --wait` 성공
- [ ] 앱/PKG staple 성공
- [ ] `codesign --verify --deep --strict --verbose=2`
- [ ] `spctl --assess --type execute --verbose=4 Baram.app`
- [ ] `spctl --assess --type install --verbose=4 Baram.pkg`
- [ ] 격리 속성이 있는 새 다운로드에서 Gatekeeper 설치 성공

## 공개 게이트

- [ ] 이름·상표·역사적 Baram 관계 문구 승인
- [ ] Baram 마크·앱 아이콘 배포 라이선스 승인
- [ ] GitHub prerelease와 `Baram-1.0.0-rc.9` 태그 생성
- [ ] ZIP/PKG/체크섬/대응 소스/릴리스 노트 업로드
- [ ] `baram.sionyuel.com`의 HTTPS·DNS·호스팅 검증
- [ ] 다운로드 URL과 SHA-256을 사이트에 연결
- [ ] 실제 릴리스보다 큰 버전만 알리는 `version.json` 배포
- [ ] 배포된 피드 검증 뒤에만 `BaramUpdateFeedEnabled=true`
- [x] robots/noindex/download 비활성 게이트를 의도적으로 해제
- [ ] SECURITY.md의 비공개 취약점 신고 경로 검증

## 중단·롤백 조건

다음 중 하나라도 발생하면 공개하지 않습니다.

- 입력 문자열 중복·누락·문서 범위 오염
- Baram에서 ABC로 빠져 단축키 복귀 불가
- Secure Input 또는 제외 앱에서 자동 변환
- 업데이트 피드가 Gureum 또는 미검증 URL을 사용
- universal architecture, 대응 소스, 라이선스, 체크섬 누락
- 서명·공증·Gatekeeper 검증 실패

