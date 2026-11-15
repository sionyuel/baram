# 바람 사이트 검증

최초 브라우저 검증일: 2026-11-14. 아래 시각 증거는 당시 비공개 미리보기의 기록입니다. 2026-11-15에 공개 프리릴리스 문구·다운로드·설치 경고를 갱신하고 데스크톱과 모바일을 다시 확인했습니다.

## 확인 결과

| 항목 | 결과 |
|---|---|
| 프레임워크 | 기존 저장소에 웹 프레임워크 없음. buildless HTML/CSS/JavaScript, 새 의존성 없음 |
| 빌드 | `node site/baram/build.mjs` 성공 |
| 정적 검증 | `node site/baram/verify.mjs` 성공: 한 개 h1, 한국어 lang, 유일 ID, 모든 내부 앵커, 로컬 자산, 원본 자산 체크섬, 공개 다운로드와 미공증 경고 |
| JavaScript | app.js와 build.mjs `node --check` 성공 |
| HTTP | 로컬 서버 `/` HTTP 200, 모든 브라우저 자산 응답 200 |
| 반응형 | 320 / 390 / 768 / 1024 / 1440px에서 document scrollWidth와 viewport 폭 일치 |
| 예시 | `s→f→j` 선택 시 `ㄴ · ㅏ · ㅇ`, `j→s→f` 키보드 Enter 선택 시 `ㅇ · ㄴ · ㅏ`. 결과와 설명은 시뮬레이션으로 표시 |
| 접근성 | 한 개 주 제목·landmark·skip link·fieldset/legend·aria-pressed·polite 결과·native details/summary·3px focus-visible 확인 |
| 테마 | 시스템→밝게→어둡게 버튼 전환 확인. 각 명시 테마로 스크린샷 생성 |
| 동작 줄이기 | reduce emulation에서 scroll-behavior=auto, 예시 animation 억제 |
| 공개 배포 상태 | `1.0.0-rc.1` ZIP 링크, robots Allow, index/follow. Developer ID·Apple 공증 없음과 자동 업데이트 비활성 표시 |
| 외부 요청 | 글꼴·분석·스크립트 등 외부 리소스 요청 0개. 외부 이동은 명시적 링크만 |
| 자산 | v0.3 원본 master/small SVG와 브랜드 토큰 복사, `dist/asset-provenance.json`에 원본 경로·SHA-256 기록 |
| 제품 사실 | 독립 Gureum 기반·역사적 Baram 비공식 관계·macOS 목표·미공증 Debug 상태·실기 미검증·입력 관찰/진단 위험 구분 |

## 시각 증거

- `desktop-light.png` / `desktop-dark.png`: 1440px 전체 페이지.
- `mobile-light.png` / `mobile-dark.png`: 390px 전체 페이지.
- `desktop-*-fold.png`: 1440×1000 첫 화면.
- `mobile-*-fold.png`: 390×844 첫 화면.

모든 파일을 직접 열어 올바른 테마·텍스트·심볼·내용이 표시되고 잘림이 없음을 확인했습니다. 장식 wind path는 hero 내부에서 의도적으로 잘립니다. 브라우저 검증은 Ego Lite를 사용했습니다. 웹 서버와 검증용 브라우저 공간은 완료 후 종료합니다.

## 2026-11-15 공개 전환 검증

- 지원 세벌식 전용 양방향 자동 전환, 도메인 복원, 현재 음절/완료 음절의 삭제 경계, 키·Shift 반응 미리보기와 방향별 1.8초 HUD를 반영했습니다.
- 백업 검증·복구 절차 링크와 `Baram-1.0.0-rc.1` 프리릴리스 다운로드를 추가했습니다.
- `node site/baram/build.mjs`, `node site/baram/verify.mjs`, Worker JavaScript 구문, Wrangler dry-run, `git diff --check`가 통과했습니다.
- Ego Lite로 1440×1000 데스크톱과 390×844 모바일 전체 페이지를 다시 확인했습니다. 두 폭 모두 수평 오버플로가 없고 다운로드·미공증 경고·설치·복구 문구가 잘리지 않았습니다.

## 정식 1.0.0까지 남은 작업

Developer ID·공증, 더 넓은 실기 권한·입력·복구 검증, 업데이트 피드 활성화가 남아 있습니다. VoiceOver 실기와 다른 브라우저·OS 글꼴 대체 조합도 정식판 전에 별도 확인합니다.
