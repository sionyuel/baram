<p align="center">
  <img src="docs/brand/baram/assets/baram-app-icon-concept-128.png" width="112" height="112" alt="바람 입력기 아이콘">
</p>

# 바람 입력기

**Baram Input Method**는 macOS용 오픈소스 한글 입력기입니다. [구름 입력기](https://github.com/gureum/gureum)의 검증된 기반을 이어받아 세벌식 모아치기, 현대적인 설정 화면, 독립적인 브랜드와 업데이트 경로를 다듬고 있습니다.

> 현재 상태: `1.0.0-rc.4` 공개 프리릴리스입니다. Universal Release 앱이지만 Apple Developer ID 서명·공증은 아직 없습니다.

[![platform](https://img.shields.io/badge/macOS-12%2B-111827?logo=apple)](https://github.com/sionyuel/baram)
[![architectures](https://img.shields.io/badge/architecture-Apple%20Silicon%20%7C%20Intel-458C80)](https://github.com/sionyuel/baram)
[![license](https://img.shields.io/badge/license-BSD--2--Clause%20%2B%20LGPL--2.1-blue)](COPYING)

## 주요 기능

- 두벌식, 세벌식 최종·390·순아래·옛글·2011·2012 등 여러 한글 자판
- 로마자, QWERTY, Dvorak, Colemak 계열 입력 소스
- 초성·중성·종성 순서가 바뀐 낱자를 보정하는 모아치기
- 실제 키 누름과 Shift에 반응하는 한글 자판 미리보기
- grave(백틱) 및 Shift+grave 키에 자주 쓰는 문자 한 글자 지정
- 선택한 앱에서만 Esc 또는 `Control+[`로 로마자 전환
- 현대 두벌식과 지원 세벌식에서 잘못 선택한 한글·영문 입력 모드를 단어 단위로 자동 전환
- Apple Silicon과 Intel을 함께 지원하는 Universal 빌드
- 구름 입력기와 분리된 앱·입력 소스·설정·업데이트 식별자

지원 자판과 자판별 주의사항은 [지원 자판 문서](docs/keyboards/README.md)를 참고하세요.

### 자동 한영 전환

`고급 → 앱별 동작 → 실험 · 자동 한영 전환`에서 `모든 앱에서 사용`을 고르거나 여러 앱을 선택하면 켜집니다. 기본값은 꺼짐입니다. 바람의 로마자 모드에서 `jfshea`를 입력한 뒤 공백을 누르면 마지막 한글 자판으로 다시 조합해 `안녕 `으로 바꾸고 한글 모드로 전환합니다. 반대로 한글 모드에서 영단어 `apple`에 해당하는 물리 키를 누르면 공백에서 `apple `로 복원하고 로마자 모드로 전환합니다. 다음 키부터는 전환된 모드로 바로 입력됩니다. Apple ABC를 직접 선택한 동안에는 동작하지 않습니다.

자동 전환은 양방향 모두 현대 두벌식(`2-full`)과 지원 세벌식 자판에서 동작합니다. 두벌식 옛글(`2y-full`)은 적용하지 않으며 수동 한영 전환과 기존 한글 조합·삭제를 사용합니다. 자동 전환용 Baram Roman은 내부 입력 모드이며 입력 소스 추가 목록에는 따로 노출하지 않습니다. 로마자에서 한글로 바꿀 때는 여러 자판을 추측하지 않고 마지막으로 사용한 지원 두벌식·세벌식 자판 하나만 적용합니다. 물리적 동시입력 묶기는 계속 지원 세벌식 전용입니다. Shift+Space로 내부 모드를 바꿔도 macOS 입력 소스는 Baram에 남습니다.

자동 전환 중인 단어는 밑줄이 있는 조합 문자열로 표시하고 공백·Return·Tab에서 한 번에 확정합니다. 한글 방향은 최소 세 개의 물리 키가 완성형 한글 한 음절 이상과 문장부호로 조합될 때 변환하며, `j/r → 왜`, `kgo4B → 그쵸?`도 지원합니다. 두벌식은 우연히 한글로 조합되는 영문이 많아 더 보수적으로 두 음절 이상이 완성될 때만 변환하고(`dkssud → 안녕`, `rksk → 가나`), 영문 복원은 불완전 낱자가 보이는 4글자 이상 단어에만 적용합니다. 한 토큰 안의 영문 접두어와 한글 접미어는 접두어가 확실한 영단어이고 접미어가 완전히 조합될 때만 나눠 바꿉니다(두벌식 `githubdptj → github에서`, 세벌식 최종 `githubjcnt → github에서`). `github`는 시스템 사전과 무관하게 확실한 기술 용어로 인식하며, 세벌식 최종에서 잘못 입력한 `므너두`도 `github`로 복원합니다. `;vies → 보면`처럼 선행 문장부호를 버렸을 때만 영단어가 되는 키열은 한글로 보존합니다. `v2`, `build.sh`, `foo/bar`, `--flag`, `key=value` 같은 코드·경로·파일명 토큰은 영문으로 유지합니다. 두벌식 한글 모드의 Backspace는 자동 전환 없이 쓸 때와 같이 동작합니다. 영문 방향은 시스템 사전에서 확인되는 단어나 `haezoom.com`처럼 지원 TLD를 가진 유효한 도메인을 복원합니다. 짧은 충돌은 한글로 보존합니다. 조합이 불완전하거나 보안 입력·제외 앱에서는 원문을 유지합니다.

Backspace는 현재 조합 중인 음절을 자모 단위로 지우고, 앞에서 이미 완성된 음절은 한 글자 단위로 지웁니다. 예를 들어 `안녀 → 안ㄴ → 안 → 빈 문자열`로 삭제됩니다. 자동 전환 직후 첫 Backspace는 변환 전 단어와 이전 입력 모드를 복원하고 공백·Return·Tab은 유지하며, 두 번째 Backspace부터 일반 삭제로 동작합니다. 다른 키 입력·커서 이동·클라이언트 변경·보안 입력에서는 이 취소 기회를 폐기합니다. 마우스·단축키·외부 조기 커밋은 원문을 확정합니다. 전환에 성공하면 한글은 비취색, 영문은 갈색 HUD가 `⌫ 되돌리기` 안내와 함께 기본 1.8초 표시됩니다. 문구와 색을 함께 사용하며, 시스템의 동작 줄이기 설정도 따릅니다.

앱의 표준 조합 문자열 API를 사용하며 이미 확정한 앞 문장을 다시 읽거나 교체하지 않습니다. 실행 취소와 비밀번호 필드 감지는 앱마다 다를 수 있어 실제 앱별 검증이 필요합니다. 키열은 해당 입력 세션의 현재 단어만 메모리에 보관하며 저장하거나 네트워크로 전송하지 않습니다.

## 설치

### 공개 배포

공식 배포 주소는 [baram.sionyuel.com](https://baram.sionyuel.com)입니다. `1.0.0-rc.4` 프리릴리스 ZIP과 SHA-256은 [GitHub Release](https://github.com/sionyuel/baram/releases/tag/Baram-1.0.0-rc.4)에서 함께 제공합니다. Developer ID 서명·Apple 공증이 없으므로 체크섬을 확인한 뒤 시험용으로 설치하고 기존 입력기를 남겨 두세요.

압축을 푼 `Baram.app`을 `~/Library/Input Methods/`에 복사합니다. macOS가 차단하면 앱을 한 번 연 뒤 `시스템 설정 → 개인정보 보호 및 보안 → 확인 없이 열기`를 사용합니다. 보안 기능 전체를 끄거나 격리 속성을 강제로 제거하지 마세요.

### 소스에서 시험 빌드

요구 환경은 macOS 12 이상과 전체 Xcode입니다. 아래의 `make init`은 Homebrew로 ShellCheck를, RubyGems로 xcpretty를 준비하므로 Homebrew와 RubyGems도 필요합니다. 이미 서브모듈과 도구를 준비했다면 `make init`을 생략할 수 있습니다.

```sh
git clone --recurse-submodules https://github.com/sionyuel/baram.git
cd baram
make init
GUREUM_BARAM_ARCHS='arm64 x86_64' tools/install_baram.sh --install
```

설치 후 `시스템 설정 → 키보드 → 텍스트 입력 → 편집`에서 `Baram ·`으로 시작하는 자판을 추가하세요. 입력 소스가 바로 나타나지 않으면 로그아웃 후 다시 로그인해야 할 수 있습니다.

설치 스크립트는 기존 Baram 앱을 `~/Library/Application Support/Baram/Backups/`에 보존합니다. 구름 입력기나 다른 입력기는 변경하지 않습니다.

```sh
tools/baram_input_source.sh list
tools/baram_input_source.sh select han3final
```

## 제거

먼저 ABC 또는 다른 입력기로 전환한 다음 아래 명령을 실행하세요.

```sh
tools/install_baram.sh --uninstall
```

Baram 앱은 백업 폴더로 이동하며 사용자 설정은 자동 삭제하지 않습니다.

### 이전 Baram 버전으로 복구

먼저 ABC 또는 기존 한글 입력기로 전환하세요. Finder의 `이동 → 폴더로 이동`에서 `~/Library/Application Support/Baram/Backups/`를 열고 복구할 `baram.XXXXXX/Baram.app`을 선택합니다. 다음 예시의 `baram_backup`에는 그 앱의 절대 경로를 넣습니다.

```sh
baram_backup="/선택한/백업/Baram.app"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$baram_backup/Contents/Info.plist")" = 'com.sionyuel.inputmethod.Baram'
/usr/bin/codesign --verify --deep --strict "$baram_backup"
```

두 검증이 모두 성공한 뒤 현재 앱을 보존하고 백업을 복사합니다. 선택한 백업 원본과 사용자 설정은 유지됩니다.

```sh
tools/install_baram.sh --uninstall
/usr/bin/ditto "$baram_backup" "$HOME/Library/Input Methods/Baram.app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$HOME/Library/Input Methods/Baram.app"
tools/baram_input_source.sh activate han3final
```

`han3final`은 세벌식 최종입니다. 다른 배열을 사용한다면 `tools/baram_input_source.sh list`에서 확인한 배열 접미사를 넣으세요. 선택이 거절되면 시스템 설정에서 Baram 자판을 다시 추가하고, 필요한 경우 작업을 저장한 뒤 로그아웃·로그인합니다. 이 수동 복구 예시는 설치된 앱을 교체하므로 실제 복구가 필요할 때만 실행하세요.

## 권한과 개인정보

일반 한글 입력에는 입력 모니터링 권한이 필요하지 않습니다. 이 권한은 다음 선택 기능에만 사용합니다.

- 오른쪽 Command·Option·Control 키를 입력 전환 키로 사용
- 실험적인 물리적 동시입력 묶기

권한은 설정 화면의 명시적인 버튼을 누른 경우에만 macOS에 요청합니다. Release 빌드는 입력 내용이나 조합 문자열을 수집하지 않습니다. Debug 빌드는 개발 로그가 남을 수 있으므로 민감한 문장을 입력하지 마세요.

## 업데이트

Baram은 구름의 업데이트 서버를 사용하지 않습니다. 정식 버전은 `https://baram.sionyuel.com/version.json`의 독립 피드에서 확인하며, 설정에서 알림을 끌 수 있습니다. 서명·공증 전 공개 프리릴리스에서는 업데이트 확인 자체를 비활성화합니다.

현재 공개 프리릴리스는 `1.0.0-rc.4`, 태그는 `Baram-1.0.0-rc.4`입니다. 정식 버전은 `1.0.0`, 태그는 `Baram-1.0.0` 형식을 사용합니다. 현재 준비 상태는 [릴리스 체크리스트](docs/release/Baram-1.0.0-rc-checklist.md)에서 확인할 수 있습니다.

## 개발

설치 상태를 바꾸지 않는 Universal Release Candidate 묶음은 깨끗한 작업 트리에서 다음과 같이 만듭니다.

```sh
tools/package_baram.sh --version 1.0.0-rc.1
```

산출물은 `dist/` 아래에 생성되며 Release 앱, 체크섬, build-info, 라이선스와 libhangul 대응 소스를 포함합니다. 공개 프리릴리스는 ad-hoc 서명이고 공증되지 않았음을 다운로드와 릴리스 노트에 명시하며, 자동 업데이트 피드에는 연결하지 않습니다.

전체 테스트:

```sh
xcodebuild -project Gureum.xcodeproj -scheme OSX -sdk macosx \
  -destination 'platform=macOS' test \
  -onlyUsePackageVersionsFromResolvedFile \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

빌드 구조와 서브모듈 정책은 [HACKING.md](HACKING.md), 변경 제안과 버그 보고 방법은 [CONTRIBUTING.md](CONTRIBUTING.md)를 참고하세요. 보안 문제는 공개 이슈 대신 [SECURITY.md](SECURITY.md)의 비공개 신고 절차를 이용해 주세요.

## 프로젝트 계보

Baram은 Gureum에서 출발한 독립 프로젝트입니다. 기존 저작권과 기여 이력을 존중하며, 과거에 존재했던 동명의 “한글입력기 바람”의 공식 후속판임을 주장하지 않습니다.

- 상위 프로젝트: [gureum/gureum](https://github.com/gureum/gureum)
- 한글 조합 엔진: [libhangul](https://github.com/libhangul/libhangul)
- 공개 저장소: [sionyuel/baram](https://github.com/sionyuel/baram)
- 공식 배포 도메인: [baram.sionyuel.com](https://baram.sionyuel.com)

## 라이선스

저장소의 코드와 포함된 의존성·아이콘 자산에는 서로 다른 라이선스가 적용될 수 있습니다. 프로젝트 코드의 기본 조건과 저작권 고지는 [COPYING](COPYING), 아이콘 관련 고지는 [OSX/Icons/COPYING](OSX/Icons/COPYING)을 확인하세요. `libhangul` 및 하위 구성요소의 라이선스는 각 서브모듈에 포함된 문서를 따릅니다.
