# Baram 개발하기

Baram은 Swift/AppKit 입력기이며 InputMethodKit으로 앱과 통신합니다. 한글 조합은 `libhangul-objc/Hangul` 프레임워크를 통해 C 엔진 libhangul을 사용합니다. 프로젝트 파일과 기본 스킴 이름은 상위 프로젝트에서 이어진 `Gureum.xcodeproj`와 `OSX`입니다.

## 개발 환경

- 실행 대상: macOS 12 이상. 앱과 `libhangul-objc`에 같은 최소 버전을 적용합니다.
- 빌드: 전체 Xcode가 필요합니다. 로컬에서는 Xcode 27.1을 검증했습니다.
- CI: GitHub Actions `macos-15`와 Xcode 26.2를 사용합니다.
- `make init`: Homebrew로 ShellCheck를, RubyGems로 xcpretty를 준비하고 서브모듈을 초기화합니다. 도구가 이미 준비됐다면 서브모듈 초기화만 실행할 수 있습니다.

```sh
git clone --recurse-submodules https://github.com/sionyuel/baram.git
cd baram
make init
open Gureum.xcodeproj
```

Xcode 선택 상태는 `xcode-select -p`로 확인합니다. Command Line Tools만 선택되어 있으면 다음과 같이 전체 Xcode로 전환합니다.

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## 서브모듈과 라이선스

`libhangul-objc`는 Objective-C 프레임워크와 C 엔진을 앱에서 사용할 수 있도록 연결합니다. 프레임워크 분리가 의존성의 라이선스 의무를 없애지는 않습니다. 앱 코드의 [COPYING](COPYING), 서브모듈 안의 라이선스와 저작권 고지를 각각 유지해야 합니다.

부모 저장소는 `sionyuel/libhangul-objc`의 특정 커밋을 고정합니다. 하위 프로젝트를 바꿀 때는 해당 커밋을 먼저 공개한 뒤 부모의 서브모듈 포인터를 갱신합니다. 원본과 비교할 때는 `https://github.com/gureum/libhangul-objc.git`을 서브모듈의 `upstream` 원격으로 사용할 수 있습니다.

URL이나 초기화 상태가 어긋나면 로컬 변경을 먼저 확인하고 다음 명령으로 동기화합니다.

```sh
git submodule status --recursive
git submodule sync --recursive
git submodule update --init --recursive
```

오류가 계속되면 해당 서브모듈의 `git status`와 원격 URL을 확인하세요. `.git/modules`를 지우거나 강제 초기화하기 전에 하위 저장소의 미커밋 변경과 로컬 커밋을 보존해야 합니다.

Swift 패키지는 `Gureum.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`에 고정합니다. 의존성 갱신 때만 이 파일을 바꾸고, CI와 배포 빌드는 고정된 버전을 사용합니다.

## Baram 빌드와 설치

설치 없이 Universal Debug 앱만 만들려면 다음 명령을 사용합니다.

```sh
GUREUM_BARAM_ARCHS='arm64 x86_64' tools/install_baram.sh --build-only
```

결과는 `build/baram/Build/Products/Debug/Baram.app`입니다. 스크립트는 Baram 식별자와 아이콘 리소스를 확인하고 ad-hoc 서명·서명 검증을 수행합니다. Developer ID 서명이나 Apple 공증은 수행하지 않습니다.

실제 설치는 전용 스크립트로 진행합니다.

```sh
GUREUM_BARAM_ARCHS='arm64 x86_64' tools/install_baram.sh --install
tools/baram_input_source.sh list
tools/baram_input_source.sh select han3final
```

설치 위치는 `~/Library/Input Methods/Baram.app`입니다. bundle/input-source prefix는 `com.sionyuel.inputmethod.Baram`, defaults suite는 `com.sionyuel.Baram`, IMK connection은 `Baram_Connection`입니다. 설치기는 이전 Baram 앱을 `~/Library/Application Support/Baram/Backups/`에 보존합니다. 구름과 Lab 앱·설정은 변경하지 않습니다. 백업 복원과 제거는 [README의 복구 안내](README.md#이전-baram-버전으로-복구)를 따릅니다.

처음 실행할 때 Baram 설정 영역이 비어 있으면 알려진 Lab 설정만 한 번 복사합니다. 마지막 한글·로마자 입력 소스 ID는 Baram prefix로 바꾸고, 새 앱에서 권한이 필요한 `PhysicalChordingEnabled`는 복사하지 않습니다.

새 입력 소스가 선택되지 않아 `OSStatus -50`이 나오면 시스템 설정 → 키보드 → 텍스트 입력에서 `Baram ·` 자판을 추가합니다. 필요한 경우 작업을 저장한 뒤 로그아웃·로그인합니다. `select`는 이전 입력 소스를 저장하며 `tools/baram_input_source.sh restore`로 그 선택으로 돌아갈 수 있습니다. 이 명령은 앱 버전 복원과는 별개입니다.

Baram 내부 Roman은 별도 추가 항목으로 노출하지 않습니다. 한영 전환은 Baram 내부 상태를 바꾸며 macOS 입력 소스를 Apple ABC로 바꾸지 않습니다. 메뉴의 3F 표시는 내부 Roman 상태에서도 유지됩니다.

## 입력 동작과 검증 범위

실험 자동 한영 전환은 지원 세벌식 자판에서만 양방향으로 동작합니다. 로마자에서 한글로 바꿀 때는 마지막으로 사용한 한글 자판 하나를 적용합니다. 영문 방향은 시스템 사전과 지원 TLD의 도메인 구조를 확인합니다. 두벌식은 일반 조합·삭제와 수동 한영 전환을 유지합니다.

단어 전체를 marked text로 보관하는 동안에도 현재 음절은 자모 단위로, 과거 완료 음절은 한 글자 단위로 삭제합니다. 예: `안녀 → 안ㄴ → 안 → 빈 문자열`. 자동완성 앱의 외부 커밋, 마우스·단축키·보안 입력 경계에서는 원문을 확정합니다.

물리적 동시입력은 별도 실험 기능이며 기본값은 꺼짐입니다. 설정 → 고급 → 실험 기능 · 물리적 동시입력에서 켤 수 있습니다. 키 감지 권한의 명시적 버튼으로만 macOS 입력 모니터링을 요청합니다. 공개 CG session event tap은 `listenOnly`로 키 해제를 관찰하고, IMK가 키 누름과 문자열 입력을 담당합니다. 관찰 탭은 키를 억제·수정·재전송하지 않습니다.

지원 XML의 낱자 역할을 초성→중성→종성으로 정렬하며 같은 역할 안의 순서는 유지합니다. 미지원 매핑·불완전 그룹은 원래 순서로 처리합니다. 권한 회수·Secure Event Input·탭 장애·누락 release 워치독은 대기 입력을 원래 순서로 비우고 해당 세션을 중지합니다. 실제 겹치는 입력·권한·앱 호환성 매트릭스는 아직 출시 검증 대상입니다. 자동 테스트 통과를 실기 검증 완료로 해석하지 않습니다.

## 테스트와 형식 검사

서명 인증서 없이 전체 테스트를 실행할 수 있습니다.

```sh
xcodebuild -project Gureum.xcodeproj -scheme OSX -sdk macosx \
  -destination 'platform=macOS' test \
  -onlyUsePackageVersionsFromResolvedFile \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
swift format lint --strict --recursive OSXCore OSX GureumTests Preferences OSXTestApp
git diff --check
```

형식을 자동 수정하려면 `make format`을 사용합니다. 테스트 타겟 이름은 소스 폴더 이름과 다른 `OSXTests`입니다. 예를 들어 자동 전환 테스트만 실행할 때는 위 xcodebuild 명령에 `-only-testing:OSXTests/HangulLayoutAutocorrectionTests`를 추가합니다. 설정 화면은 `OSXTestApp` 타겟으로 별도 확인할 수 있습니다.

빌드가 생성하는 `OSX/Version.xcconfig`는 커밋하지 않습니다. 작업 후에는 저장소의 `// Do not commit this file` 상태로 되돌립니다.

입력 동작을 바꾸면 TextEdit, 시스템 설정 검색창, 브라우저 입력란, Electron 앱, Terminal에서 실제 입력도 확인합니다. 자동 전환은 일부 터미널·민감 앱과 보안 입력에서 제외됩니다. 완성 전후 Backspace, Shift+Space 왕복, 공백·Return·Tab, 자동완성, 한자·이모지, 앱 이동과 입력 소스 복귀를 포함하세요.

## Debug와 Release

시험 설치 스크립트는 Debug 앱을 만듭니다. Debug는 시작 알림과 설정 창을 표시하며 개발 로그가 남을 수 있으므로 민감한 문장을 입력하지 않습니다. Baram은 상위 프로젝트의 Firebase 초기화·분석 서비스를 사용하지 않습니다. Release에서는 개발용 `dlog`가 비활성화됩니다. 공개 배포 전에 패키지와 로그·권한·업데이트 동작을 별도로 검증해야 합니다.

필요하면 설치된 프로세스에 Xcode의 Attach to Process로 디버거를 연결할 수 있습니다. 입력기에서 멈춘 동안 디버거 조작용 입력도 막힐 수 있으므로 먼저 로그와 결정적 테스트로 재현하고, 디버깅 전에 ABC 같은 복구용 입력 소스를 준비하세요.

Baram 정식 버전은 `2.0.0`부터 시작하며 릴리스 태그는 `Baram-2.0.0` 형식을 사용합니다. 서명·공증 전 시험 배포는 `Baram-2.0.0-rc.N` 프리릴리스로 공개하고, ad-hoc·미공증 상태를 명시합니다. 서명·공증된 파일, SHA-256, 릴리스 노트, 대응 소스와 라이선스 고지를 함께 준비한 뒤에만 업데이트 피드를 활성화합니다. 검증 항목은 [릴리스 체크리스트](docs/release/Baram-2.0.0-rc-checklist.md)에서 관리합니다.

설치본을 바꾸지 않는 Universal Release Candidate는 깨끗한 작업 트리에서 명시적인 시험 버전으로 만듭니다.

```sh
tools/package_baram.sh --version 2.0.0-rc.1
```

패키저는 Release Baram identity, 숨긴 내부 Roman, 비활성 업데이트 피드, arm64/x86_64, 직접 아이콘을 검증한 뒤 ad-hoc 서명 앱, 체크섬, build-info, 라이선스와 대응 소스를 `dist/`에 묶습니다. `--allow-dirty`는 로컬 패키저 검증에만 사용하며 그 산출물은 공개할 수 없습니다.

## 이전 제품 개발 참고

`tools/install_chord_lab.sh`, `tools/package_chord_lab.sh`, `tools/chord_lab_input_source.sh`와 `tools/capture_chord_lab_events.sh`는 독립 Lab 실험용으로 남아 있습니다. 현재 Baram 설치·배포 절차와 혼용하지 마세요. Lab 배포 형식은 [Lab 안내](tools/chord_lab_distribution/README.ko.md)를 참고합니다. `tools/install_debug.sh`와 구름 개발자 [Discord](https://discord.gg/wMbNU7EC8y)는 상위 Gureum 개발 자료입니다.
