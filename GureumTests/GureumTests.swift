//
//  GureumTests.swift
//  OSX
//
//  Created by Jim Jeon on 16/09/2018.
//  Copyright © 2018 youknowone.org. All rights reserved.
//

import AppKit
import Hangul
import InputMethodKit
import MASShortcut
import QuartzCore
import XCTest

@testable import Gureum
@testable import GureumCore

private var lastNotification: NSUserNotification!

extension NSUserNotificationCenter {
  func deliver(_ notification: NSUserNotification) {
    lastNotification = notification
  }
}

class GureumTests: XCTestCase {
  static let domainName = "org.youknowone.Gureum.test"
  lazy var moderate: VirtualApp = ModerateApp()
  // lazy var xcode: VirtualApp = XcodeApp()
  lazy var terminal: VirtualApp! = nil
  // lazy var terminal: VirtualApp = TerminalApp()
  // lazy var greedy: VirtualApp = GreedyApp()
  lazy var apps: [VirtualApp] = [moderate]

  override class func setUp() {
    Configuration.shared = Configuration(suiteName: "org.youknowone.Gureum.test")!
    super.setUp()
  }

  override class func tearDown() {
    super.tearDown()
  }

  override func setUp() {
    super.setUp()
    // Put setup code here. This method is called before the invocation of each test method in the class.

    Configuration.shared.removePersistentDomain(forName: GureumTests.domainName)
  }

  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }

  func testPreferencePane() {
    let path = Bundle.main.path(forResource: "Preferences", ofType: "prefPane")
    let bundle = NSPrefPaneBundle(path: path)!
    let loaded = bundle.instantiatePrefPaneObject()
    XCTAssertTrue(loaded)
  }

  func testPreferencesHostAppliesMinimumWindowSizeAndRetainsChildController() throws {
    let storyboard = NSStoryboard(name: "Configuration", bundle: .main)
    let controller = try XCTUnwrap(storyboard.instantiateInitialController() as? NSWindowController)
    let window = try XCTUnwrap(controller.window)
    defer { window.close() }

    XCTAssertEqual(window.contentMinSize, NSSize(width: 500, height: 300))
    XCTAssertEqual(window.contentMaxSize, NSSize(width: 500, height: 680))
    XCTAssertTrue(window.autorecalculatesKeyViewLoop)
    let host = try XCTUnwrap(window.contentViewController)
    _ = host.view
    XCTAssertEqual(host.children.count, 1)
    let child = try XCTUnwrap(host.children.first)
    XCTAssertTrue(child.parent === host)
    XCTAssertTrue(child.view.superview === host.view)
  }

  func testReopeningTheInputMethodShowsPreferencesAgain() {
    preferencesWindow.close()
    let delegate = GureumAppDelegate()

    XCTAssertTrue(
      delegate.applicationShouldHandleReopen(NSApp, hasVisibleWindows: false))
    XCTAssertTrue(preferencesWindow.window?.isVisible == true)

    preferencesWindow.close()
  }

  func testOpeningTheRunningInputMethodShowsPreferencesAgain() {
    preferencesWindow.close()
    let delegate = GureumAppDelegate()

    XCTAssertTrue(delegate.applicationOpenUntitledFile(NSApp))
    XCTAssertTrue(preferencesWindow.window?.isVisible == true)

    preferencesWindow.close()
  }

  func testNotifyUpdate() {
    let data = """
      {
          "version": "1.10.0",
          "description": "Mojave 대응을 포함한 대형 업데이트",
          "url": "https://github.com/gureum/gureum/releases/tag/1.10.0"
      }
      """.data(using: .utf8)
    let update = try! JSONDecoder().decode(UpdateManager.UpdateInfo.self, from: data!)

    let versionInfo = UpdateManager.VersionInfo(update: update, experimental: true)
    UpdateManager.notifyUpdate(info: versionInfo)
    XCTAssertEqual(
      "최신 버전: 1.10.0 현재 버전: \(Bundle.main.version ?? "-")\nMojave 대응을 포함한 대형 업데이트",
      lastNotification.informativeText)
    XCTAssertEqual(
      ["url": "https://github.com/gureum/gureum/releases/tag/1.10.0"],
      lastNotification.userInfo as! [String: String])
  }

  func testUpdateVersionComparisonNeverOffersADowngrade() {
    XCTAssertTrue(
      UpdateManager.shouldOffer(
        updateVersion: "2.0.0", currentVersion: "1.13.2-73-g514508c-Debug"))
    XCTAssertTrue(
      UpdateManager.shouldOffer(updateVersion: "1.14.0", currentVersion: "1.13.2"))
    XCTAssertFalse(
      UpdateManager.shouldOffer(updateVersion: "1.13.2", currentVersion: "1.13.2-Debug"))
    XCTAssertFalse(
      UpdateManager.shouldOffer(updateVersion: "1.0.0", currentVersion: "1.13.2"))
    XCTAssertFalse(
      UpdateManager.shouldOffer(updateVersion: "invalid", currentVersion: "1.13.2"))
    XCTAssertTrue(UpdateManager.shouldOffer(updateVersion: "2.0.0", currentVersion: nil))
    XCTAssertTrue(
      UpdateManager.shouldOffer(updateVersion: "1.14.0-rc2", currentVersion: "1.14.0-rc1"))
    XCTAssertTrue(
      UpdateManager.shouldOffer(updateVersion: "1.14.0", currentVersion: "1.14.0-rc2"))
    XCTAssertFalse(
      UpdateManager.shouldOffer(updateVersion: "1.14.0-rc1", currentVersion: "1.14.0"))
  }

  func testLayoutChange() {
    Configuration.shared.inputModeExchangeKey = Configuration.Shortcut(.space, .shift)
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        "org.youknowone.inputmethod.Gureum.qwerty", forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputFlags(.capsLock)

      app.inputText(" ", key: .space, modifiers: .shift)
      app.inputText(" ", key: .space, modifiers: .shift)
      XCTAssertEqual("", app.client.string, "buffer: \(app.client.string), app: \(app)")
    }
  }

  func testLayoutChangeCommit() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        "org.youknowone.inputmethod.Gureum.han2", forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansiG)
      XCTAssertEqual("ㅎ", app.client.string, "buffer: \(app.client.string), app: \(app)")
      app.inputFlags(.capsLock)
      XCTAssertEqual("ㅎ", app.client.string, "buffer: \(app.client.string), app: \(app)")
    }
  }

  func testCapsLockLanguageSwitchCapableInfoPlist() {
    let infoDictionary = Bundle.main.infoDictionary ?? [:]
    XCTAssertEqual(infoDictionary["TICapsLockLanguageSwitchCapable"] as? Bool, true)

    let componentInputModeDict = infoDictionary["ComponentInputModeDict"] as? [String: Any]
    let inputModes = componentInputModeDict?["tsInputModeListKey"] as? [String: [String: Any]]
    let missingCapableInputModes = inputModes?
      .filter { $0.key.hasPrefix("org.youknowone.inputmethod.Gureum.") }
      .compactMap { inputMode, properties in
        (properties["TICapsLockLanguageSwitchCapable"] as? Bool) == true ? nil : inputMode
      }
      .sorted()

    XCTAssertEqual(missingCapableInputModes, [])
  }

  func testSearchEmoticonTable() {
    let bundle = Bundle(for: HGKeyboard.self)
    let path: String? = bundle.path(forResource: "emoji", ofType: "txt", inDirectory: "hanja")
    let table = HGHanjaTable(contentOfFile: path!)!
    // 현재 5글자 이상만 가능
    let list: HGHanjaList = table.hanjas(byPrefixSearching: "hushed") ?? HGHanjaList()
    XCTAssert(list.count > 0)
  }

  func testCommandkeyAndControlkey() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.qwerty.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansiA, modifiers: .command)
      app.inputKey(.ansiA, modifiers: .control)
      XCTAssertEqual("", app.client.string, "")
      XCTAssertEqual("", app.client.markedString(), "")
    }
  }

  func testCapslockRoman() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.qwerty.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansiM)
      app.inputKey(.ansiR)
      app.inputKey(.ansi2)
      XCTAssertEqual("mr2", app.client.string, "buffer: \(app.client.string), app: \(app)")
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.qwerty.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansiM, modifiers: .capsLock)
      app.inputKey(.ansiR, modifiers: .capsLock)
      app.inputKey(.ansi2, modifiers: .capsLock)
      XCTAssertEqual("MR2", app.client.string, "buffer: \(app.client.string), app: \(app)")
    }
  }

  func testHanjaSyllable() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansiM)
      app.inputKey(.ansiF)
      app.inputKey(.ansiS)
      XCTAssertEqual("한", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("한", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputText("\n", key: .return, modifiers: .option)
      XCTAssertEqual("한", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("한", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.controller.candidateSelectionChanged(NSAttributedString(string: "韓: 나라 이름 한"))
      XCTAssertEqual("한", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("한", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.controller.candidateSelected(NSAttributedString(string: "韓: 나라 이름 한"))
      XCTAssertEqual("韓", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
    }
  }

  func testHanjaWord() {
    for app in apps {
      if app == terminal {
        continue  // 터미널은 한자 모드 진입이 불가능
      }
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      // hanja search mode
      app.inputText("\n", key: .return, modifiers: .option)
      app.inputKey(.ansiI)
      app.inputKey(.ansiB)
      app.inputKey(.ansiW)
      XCTAssertEqual("물", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputText(" ", key: .space)
      XCTAssertEqual("물 ", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 ", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputKey(.ansiN)
      app.inputKey(.ansiB)
      XCTAssertEqual("물 수", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 수", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.controller.candidateSelectionChanged(NSAttributedString(string: "水: 물 수, 고를 수"))
      XCTAssertEqual("물 수", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 수", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.controller.candidateSelected(NSAttributedString(string: "水: 물 수, 고를 수"))
      XCTAssertEqual("水", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")

      // 연달아 다음 한자 입력에 들어간다
      app.inputText(" ", key: .space)
      XCTAssertEqual("水 ", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputKey(.ansiI)
      XCTAssertEqual("水 ㅁ", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("ㅁ", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputKey(.ansiB)
      app.inputKey(.ansiW)
      XCTAssertEqual("水 물", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputText(" ", key: .space)
      XCTAssertEqual("水 물 ", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 ", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputKey(.ansiN)
      app.inputKey(.ansiB)
      XCTAssertEqual("水 물 수", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 수", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.controller.candidateSelectionChanged(NSAttributedString(string: "水: 물 수, 고를 수"))
      XCTAssertEqual("水 물 수", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 수", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.controller.candidateSelected(NSAttributedString(string: "水: 물 수, 고를 수"))
      XCTAssertEqual("水 水", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
    }
  }

  func testHanjaBlank() {
    for app in apps {
      if app == terminal {
        continue  // 터미널은 한자 모드 진입이 불가능
      }
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han2.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      // hanja search mode
      app.inputText("\n", key: .return, modifiers: .option)
      app.inputText(" ", key: .space)
      app.inputKey(.ansiA)
      app.inputKey(.ansiN)
      app.inputKey(.ansiF)
      XCTAssertEqual(" 물", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputText(" ", key: .space)
      XCTAssertEqual(" 물 ", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 ", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputKey(.ansiT)
      app.inputKey(.ansiN)
      app.inputText(" ", key: .space)
      XCTAssertEqual(" 물 수 ", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 수 ", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.controller.candidateSelectionChanged(NSAttributedString(string: "水: 물 수, 고를 수"))
      XCTAssertEqual(" 물 수 ", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 수 ", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.controller.candidateSelected(NSAttributedString(string: "水: 물 수, 고를 수"))
      XCTAssertEqual(" 水", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
    }
  }

  func testHanjaSelection() {
    for app in apps {
      if app == terminal {
        continue  // 터미널은 한자 모드 진입이 불가능
      }
      app.client.string = "물 수"
      app.controller.setValue(
        GureumInputSource.han3Final.rawValue,
        forTag: kTextServiceInputModePropertyTag, client: app.client)
      app.client.setSelectedRange(NSMakeRange(0, 3))
      XCTAssertEqual("물 수", app.client.selectedString(), "")
      app.inputText("\n", key: .return, modifiers: .option)
      XCTAssertEqual("물 수", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.controller.candidateSelectionChanged(NSAttributedString(string: "水: 물 수, 고를 수"))
      XCTAssertEqual("물 수", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("물 수", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.controller.candidateSelected(NSAttributedString(string: "水: 물 수, 고를 수"))
      XCTAssertEqual("水", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testHanjaEscapeSyllable() {
    for app in apps {
      if app == terminal {
        continue  // 터미널은 한자 모드 진입이 불가능
      }
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han2.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansiG)
      app.inputKey(.ansiK)
      app.inputKey(.ansiS)
      XCTAssertEqual("한", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("한", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputText("\n", key: .return, modifiers: .option)
      XCTAssertEqual("한", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("한", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.controller.candidateSelectionChanged(NSAttributedString(string: "韓: 나라 이름 한"))
      XCTAssertEqual("한", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("한", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      // Escape from Hanja mode
      app.inputText("\n", key: .return, modifiers: .option)
      XCTAssertEqual("한", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testHanjaEscapeWord() {
    for app in apps {
      if app == terminal {
        continue  // 터미널은 한자 모드 진입이 불가능
      }
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han2.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      // hanja search mode
      app.inputText("\n", key: .return, modifiers: .option)
      app.inputKey(.ansiA)
      app.inputKey(.ansiN)
      app.inputKey(.ansiF)
      XCTAssertEqual("물", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputText(" ", key: .space)
      XCTAssertEqual("물 ", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 ", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputKey(.ansiT)
      app.inputKey(.ansiN)
      XCTAssertEqual("물 수", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 수", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.controller.candidateSelectionChanged(NSAttributedString(string: "水: 물 수, 고를 수"))
      XCTAssertEqual("물 수", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 수", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      // Escape from Hanja mode
      app.inputText("\n", key: .return, modifiers: .option)
      XCTAssertEqual("물 수", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
    }
  }

  func testHanjaEscapeSelection() {
    for app in apps {
      if app == terminal {
        continue  // 터미널은 한자 모드 진입이 불가능
      }
      app.client.string = "물 수"
      app.controller.setValue(
        GureumInputSource.han2.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.client.setSelectedRange(NSMakeRange(0, 3))
      XCTAssertEqual("물 수", app.client.selectedString(), "")
      app.inputText("\n", key: .return, modifiers: .option)
      XCTAssertEqual("물 수", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.controller.candidateSelectionChanged(NSAttributedString(string: "水: 물 수, 고를 수"))
      XCTAssertEqual("물 수", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("물 수", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      // Escape from Hanja mode
      app.inputText("\n", key: .return, modifiers: .option)
      XCTAssertEqual("물 수", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testBackQuoteHan2() {
    Configuration.shared.hangulWonCurrencySymbolForBackQuote = true
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han2.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiGrave)
      XCTAssertEqual("₩", app.client.string, "buffer: \(app.client.string) app: \(app)")

      app.inputKey(.ansiGrave, modifiers: .shift)
      XCTAssertEqual("₩~", app.client.string, "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testBackQuoteOnComposing() {
    Configuration.shared.hangulWonCurrencySymbolForBackQuote = true
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han2.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiR)
      app.inputKey(.ansiK)
      XCTAssertEqual("가", app.client.string, "buffer: \(app.client.string) app: \(app)")

      app.inputKey(.ansiGrave)
      XCTAssertEqual("가₩", app.client.string, "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testBackQuoteQwerty() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.qwerty.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiGrave)
      XCTAssertEqual("`", app.client.string, "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testBackQuoteHan3Final() {
    Configuration.shared.removeObject(forKey: ConfigurationName.hangulBackQuoteOutputCharacter)
    Configuration.shared.hangulWonCurrencySymbolForBackQuote = true
    Configuration.shared.hangulShiftBackQuoteOutputCharacter = ""
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputText("`", key: .ansiGrave)
      XCTAssertEqual("*", app.client.string, "buffer: \(app.client.string) app: \(app)")

      app.inputKey(.ansiGrave, modifiers: .shift)
      XCTAssertEqual("*※", app.client.string, "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testBackQuoteHan3Classic() {
    // 세벌식 옛글에서 역따옴표는 종성으로 매핑되어 있어 커밋 없이 조합만 진행된다.
    Configuration.shared.hangulBackQuoteOutputCharacter = ""
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han3Classic.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiGrave)
      XCTAssertEqual("\u{11F9}", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual(
        "\u{11F9}", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testCustomBackQuoteCharactersOverrideHan3Final() {
    Configuration.shared.hangulBackQuoteOutputCharacter = "·"
    Configuration.shared.hangulShiftBackQuoteOutputCharacter = "@"
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiGrave)
      app.inputKey(.ansiGrave, modifiers: .shift)
      XCTAssertEqual("·@", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("", app.client.markedString())
    }
  }

  func testCustomBackQuoteCommitsCompositionInDeferredMode() {
    Configuration.shared.hangulBackQuoteOutputCharacter = "…"
    Configuration.shared.hangulDeferredSymbolCommit = true
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han2.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiR)
      app.inputKey(.ansiK)
      app.inputKey(.ansiGrave)
      XCTAssertEqual("가…", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("", app.client.markedString())
    }
  }

  func testCustomBackQuoteAcceptsOneGraphemeAndPreservesLegacyFallback() {
    Configuration.shared.removeObject(forKey: ConfigurationName.hangulBackQuoteOutputCharacter)
    Configuration.shared.hangulWonCurrencySymbolForBackQuote = true
    XCTAssertEqual(Configuration.shared.hangulBackQuoteOutputCharacter, "₩")
    Configuration.shared.hangulWonCurrencySymbolForBackQuote = false
    XCTAssertEqual(Configuration.shared.hangulBackQuoteOutputCharacter, "")

    Configuration.shared.hangulBackQuoteOutputCharacter = "👨‍👩‍👧‍👦"
    XCTAssertEqual(Configuration.shared.hangulBackQuoteOutputCharacter, "👨‍👩‍👧‍👦")
    XCTAssertFalse(Configuration.isValidHangulSpecialCharacter("\u{200D}"))
    XCTAssertFalse(Configuration.isValidHangulSpecialCharacter("\u{0301}"))
    Configuration.shared.hangulBackQuoteOutputCharacter = "두글자"
    XCTAssertEqual(Configuration.shared.hangulBackQuoteOutputCharacter, "👨‍👩‍👧‍👦")
    Configuration.shared.hangulBackQuoteOutputCharacter = ""
    XCTAssertEqual(Configuration.shared.hangulBackQuoteOutputCharacter, "")
  }

  func testDvorak() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        "org.youknowone.inputmethod.Gureum.dvorak", forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiJ)
      app.inputKey(.ansiD)
      app.inputKey(.ansiP)
      app.inputKey(.ansiP)
      app.inputKey(.ansiS)
      XCTAssertEqual("hello", app.client.string, "buffer: \(app.client.string) app: \(app)")
    }
  }

  func test3Number() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        "org.youknowone.inputmethod.Gureum.han3final", forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansiK, modifiers: .shift)
      XCTAssertEqual("2", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testBlock() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        "org.youknowone.inputmethod.Gureum.qwerty", forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansiM)
      app.inputKey(.ansiF)
      app.inputKey(.ansiS)
      app.inputKey(.ansiK)
      app.inputKey(.ansiG)
      app.inputKey(.ansiW)
      XCTAssertEqual("mfskgw", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputText(" ", key: .space)

      app.inputText("", key: .leftArrow)
      app.inputText("", key: .leftArrow)
      app.inputText("", key: .leftArrow)
      app.inputText("", key: .leftArrow)
      app.inputText("", key: .leftArrow)
      app.inputText("", key: .leftArrow)
    }
  }

  func testSequentialAutoReorderIsDisabledByDefault() {
    XCTAssertFalse(Configuration.shared.hangulAutoReorder)
  }

  func testSequentialSebeolsikFinalKeepsVowelBeforeInitialSeparateWhenReorderIsDisabled() {
    let previousAutoReorder = Configuration.shared.hangulAutoReorder
    Configuration.shared.hangulAutoReorder = false
    defer { Configuration.shared.hangulAutoReorder = previousAutoReorder }

    for app in apps {
      app.controller.setValue(
        GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKeys("fk")

      XCTAssertEqual("ㅏㄱ", app.client.string)
      XCTAssertEqual("ㄱ", app.client.markedString())
    }
  }

  func testSequentialSebeolsikFinalCombinesInitialBeforeVowelWhenReorderIsDisabled() {
    let previousAutoReorder = Configuration.shared.hangulAutoReorder
    Configuration.shared.hangulAutoReorder = false
    defer { Configuration.shared.hangulAutoReorder = previousAutoReorder }

    for app in apps {
      app.controller.setValue(
        GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKeys("kf")

      XCTAssertEqual("가", app.client.string)
      XCTAssertEqual("가", app.client.markedString())
    }
  }

  func testSequentialSebeolsikFinalCombinesVowelBeforeInitialWhenReorderIsEnabled() {
    let previousAutoReorder = Configuration.shared.hangulAutoReorder
    Configuration.shared.hangulAutoReorder = true
    defer { Configuration.shared.hangulAutoReorder = previousAutoReorder }

    for app in apps {
      app.controller.setValue(
        GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKeys("fk")

      XCTAssertEqual("가", app.client.string)
      XCTAssertEqual("가", app.client.markedString())
    }
  }

  func testSequentialSebeolsikFinalCombinesInitialBeforeVowelWhenReorderIsEnabled() {
    let previousAutoReorder = Configuration.shared.hangulAutoReorder
    Configuration.shared.hangulAutoReorder = true
    defer { Configuration.shared.hangulAutoReorder = previousAutoReorder }

    for app in apps {
      app.controller.setValue(
        GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKeys("kf")

      XCTAssertEqual("가", app.client.string)
      XCTAssertEqual("가", app.client.markedString())
    }
  }

  func testSequentialSebeolsikFinalDoesNotInferAChordFromReversedCompoundVowels() {
    let previousAutoReorder = Configuration.shared.hangulAutoReorder
    Configuration.shared.hangulAutoReorder = true
    defer { Configuration.shared.hangulAutoReorder = previousAutoReorder }

    for app in apps {
      app.controller.setValue(
        GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKeys("kfv")

      XCTAssertEqual("가ㅗ", app.client.string)
      XCTAssertEqual("ㅗ", app.client.markedString())
    }
  }

  func test3final() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        "org.youknowone.inputmethod.Gureum.han3final", forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansiM)
      app.inputKey(.ansiF)
      app.inputKey(.ansiS)
      XCTAssertEqual("한", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("한", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiK)
      XCTAssertEqual("한ㄱ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("ㄱ", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiG)
      XCTAssertEqual("한그", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("그", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiW)
      XCTAssertEqual("한글", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("글", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputText(" ", key: .space)
      XCTAssertEqual("한글 ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiM)
      XCTAssertEqual("한글 ㅎ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("ㅎ", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiF)
      app.inputKey(.ansiS)
      XCTAssertEqual("한글 한", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("한", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiK)
      XCTAssertEqual("한글 한ㄱ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("ㄱ", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiG)
      app.inputKey(.ansiW)
      XCTAssertEqual("한글 한글", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("글", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputText("\n", key: .return)
      if app != terminal {
        XCTAssertEqual("한글 한글\n", app.client.string, "buffer: \(app.client.string) app: \(app)")
      }
    }
  }

  func testColemak() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.colemak.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiH)
      app.inputKey(.ansiK)
      app.inputKey(.ansiU)
      app.inputKey(.ansiU)
      app.inputKey(.ansiSemicolon)
      app.inputKey(.ansiSlash, modifiers: .shift)
      XCTAssertEqual("hello?", app.client.string, "buffer: \(app.client.string) app: \(app)")
    }
  }

  func test2() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han2.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiG)
      app.inputKey(.ansiK)
      app.inputKey(.ansiS)
      XCTAssertEqual("한", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("한", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiR)
      XCTAssertEqual("한ㄱ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("ㄱ", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiM)
      app.inputKey(.ansiF)
      XCTAssertEqual("한글", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("글", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputText(" ", key: .space)
      XCTAssertEqual("한글 ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")

      app.inputKey(.ansiG)
      XCTAssertEqual("한글 ㅎ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("ㅎ", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiK)
      app.inputKey(.ansiS)
      XCTAssertEqual("한글 한", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("한", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiR)
      XCTAssertEqual("한글 한ㄱ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("ㄱ", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiM)
      app.inputKey(.ansiF)
      XCTAssertEqual("한글 한글", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("글", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputText("\n", key: .return)
      if app != terminal {
        XCTAssertEqual("한글 한글\n", app.client.string, "buffer: \(app.client.string) app: \(app)")
      }
    }
  }

  func testCapslockHangul() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiM)
      app.inputKey(.ansiR)
      app.inputKey(.ansi2)
      XCTAssertEqual("했", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("했", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")

      app.inputText(" ", key: .space)

      app.client.string = ""
      app.inputKey(.ansiM, modifiers: .capsLock)
      app.inputKey(.ansiR, modifiers: .capsLock)
      app.inputKey(.ansi2, modifiers: .capsLock)
      XCTAssertEqual("했", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("했", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testRomanEmoticon() {
    for app in apps {
      if app == terminal {
        continue
      }
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.qwerty.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      let composer = app.controller.receiver.composer
      let emoticonComposer = composer.searchComposer
      emoticonComposer.delegate = composer.delegate
      composer.delegate = emoticonComposer

      app.inputKey(.ansiS)
      app.inputKey(.ansiL)
      app.inputKey(.ansiE)
      app.inputKey(.ansiE)
      app.inputKey(.ansiP)
      app.inputKey(.ansiY)
      XCTAssertEqual("sleepy", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual(
        "sleepy", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputText(" ", key: .space)
      XCTAssertEqual("sleepy ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual(
        "sleepy ", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiF)
      app.inputKey(.ansiA)
      app.inputKey(.ansiC)
      app.inputKey(.ansiE)
      XCTAssertEqual("sleepy face", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual(
        "sleepy face", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.controller.candidateSelectionChanged(NSAttributedString(string: "😪: sleepy face"))
      XCTAssertEqual("sleepy face", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual(
        "sleepy face", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.controller.candidateSelected(NSAttributedString(string: "😪: sleepy face"))
      XCTAssertEqual("😪", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")

      app.client.string = ""
      app.inputKey(.ansiH)
      app.inputKey(.ansiU)
      app.inputKey(.ansiS)
      app.inputKey(.ansiH)
      app.inputKey(.ansiE)
      app.inputKey(.ansiD)
      XCTAssertEqual("hushed", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual(
        "hushed", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputText(" ", key: .space)
      XCTAssertEqual("hushed ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual(
        "hushed ", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiF)
      app.inputKey(.ansiA)
      app.inputKey(.ansiC)
      app.inputKey(.ansiE)
      XCTAssertEqual("hushed face", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual(
        "hushed face", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.controller.candidateSelectionChanged(NSAttributedString(string: "😯: hushed face"))
      XCTAssertEqual("hushed face", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual(
        "hushed face", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.controller.candidateSelected(NSAttributedString(string: "😯:, hushed face"))
      XCTAssertEqual("😯", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testHan3UnicodeArea() {
    for app in apps {
      // 두벌식 ㅑㄴ
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han2.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansiI)
      app.inputKey(.ansiS)
      XCTAssertEqual("ㅑㄴ", app.client.string, "buffer: \(app.client.string) app: \(app)")

      let han2 = app.client.string
      app.inputText(" ", key: .space)

      // 세벌식 ㅑㄴ
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han3FinalNoShift.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansi6)
      app.inputKey(.ansiS)
      XCTAssertEqual(han2, app.client.string, "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testViModeEscape() {
    XCTAssertFalse(Configuration.shared.romanModeByEscapeKey)
    Configuration.shared.romanModeByEscapeKey = true
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han3FinalNoShift.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiM)
      XCTAssertEqual("ㅎ", app.client.string, "buffer: \(app.client.string) app: \(app)")

      let processed = app.inputKey(.escape)
      XCTAssertFalse(processed)
      XCTAssertEqual("ㅎ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertTrue(app.controller.receiver.composer.inputMode.hasSuffix("qwerty"))
    }
  }

  func testViModeEscapeCanBeScopedToTheCurrentApplication() throws {
    let identifier = try XCTUnwrap(Bundle.main.bundleIdentifier)
    Configuration.shared.romanModeByEscapeKey = false
    Configuration.shared.romanModeByEscapeKeyApplications = [identifier: "Tests"]

    for app in apps {
      app.controller.setValue(
        GureumInputSource.han3FinalNoShift.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      _ = app.inputKey(.escape)

      XCTAssertTrue(app.controller.receiver.composer.inputMode.hasSuffix("qwerty"))
    }
  }

  func testViModeEscapeIgnoresApplicationsOutsideTheRule() {
    Configuration.shared.romanModeByEscapeKey = false
    Configuration.shared.romanModeByEscapeKeyApplications = ["com.example.Editor": "Editor"]

    for app in apps {
      app.controller.setValue(
        GureumInputSource.han3FinalNoShift.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      _ = app.inputKey(.escape)

      XCTAssertTrue(app.controller.receiver.composer.inputMode.hasSuffix("han3finalnoshift"))
    }
  }

  func testViModeCtrlAndLeftBracket() {
    XCTAssertFalse(Configuration.shared.romanModeByEscapeKey)
    Configuration.shared.romanModeByEscapeKey = true
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han3FinalNoShift.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiM)
      XCTAssertEqual("ㅎ", app.client.string, "buffer: \(app.client.string) app: \(app)")

      let processed = app.inputKey(.ansiLeftBracket, modifiers: [.control])
      XCTAssertFalse(processed)
      XCTAssertEqual("ㅎ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertTrue(app.controller.receiver.composer.inputMode.hasSuffix("qwerty"))

      app.inputKey(.ansiLeftBracket, modifiers: [.control, .shift])
      XCTAssertEqual("ㅎ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertTrue(app.controller.receiver.composer.inputMode.hasSuffix("qwerty"))
    }
  }

  func testHanClassic() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han3Classic.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiM)
      XCTAssertEqual("ㅎ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiF)
      XCTAssertEqual("하", app.client.string, "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiF)
      XCTAssertEqual("ᄒᆞ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiS)
      XCTAssertEqual("ᄒᆞᆫ", app.client.string, "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testHanDelete() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han2.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansiD)
      XCTAssertEqual("ㅇ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("ㅇ", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputText("", key: .delete)
      XCTAssertEqual("", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testSearchPool() {
    for (pool, key, test) in [
      (SearchSourceConst.emojiKorean, "사과", "사과"),
      (SearchSourceConst.hanjaReversed, "물 수", "水"),
    ] {
      let workItem = DispatchWorkItem {}
      let candidates = pool.collect(key, workItem: workItem)
      let c = candidates[0]
      XCTAssertTrue(c.candidate.value == test || c.candidate.description.contains(test))
    }
  }

  func testSearchPoolWithoutDuplicate() {
    for (pool, key, test) in [
      (SearchSourceConst.koreanSingle, "구", "九")
    ] {
      let workItem = DispatchWorkItem {}
      let candidates = pool.collect(key, workItem: workItem)
      XCTAssertEqual(1, candidates.filter { $0.candidate.value == test }.count)
    }
  }

  //    func testSelection() {
  //        for app in apps {
  //            app.client.string = "한"
  //            app.controller.setValue(GureumInputSourceIdentifier.han2.rawValue, forTag: kTextServiceInputModePropertyTag, client: app.client)
  //            _ = app.inputKey(kVK_ANSI_D)
  //            XCTAssertEqual("한ㅇ", app.client.string, "buffer: \(app.client.string) app: \(app)")
  //            XCTAssertEqual("ㅇ", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
  //            app.client.setSelectedRange(NSRange(location: 0, length: 0))
  //            _ = app.inputKey(kVK_ANSI_R)
  //            XCTAssertEqual("ㄱ한ㅇ", app.client.string, "buffer: \(app.client.string) app: \(app)")
  //            XCTAssertEqual("ㄱ", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
  //        }
  //    }
}

private final class HUDInputClient: MockInputClient {
  override func selectedRange() -> NSRange { NSRange(location: NSNotFound, length: 0) }
}

private final class HUDTestPanel: NSPanel {
  var orderOutCount = 0

  override func orderOut(_ sender: Any?) {
    orderOutCount += 1
    super.orderOut(sender)
  }
}

private final class UnreadableRomanInputClient: MockInputClient {
  override func attributedSubstring(from range: NSRange) -> NSAttributedString! { nil }

  override func markedRange() -> NSRange {
    let marked = super.markedRange()
    return marked.location == NSNotFound
      ? NSRange(location: NSNotFound, length: NSNotFound) : marked
  }

  override func selectedRange() -> NSRange {
    if super.markedRange().location != NSNotFound, super.markedRange().length > 0 {
      return NSRange(location: 0, length: 0)
    }
    return super.selectedRange()
  }
}

/// Models Chromium hosting xterm.js (Paseo's terminal) as recorded with a probe page on
/// 2026-11-16. Clearing the marked text inside a key event only hides it: Chromium reports no
/// marked range and a caret after it, while the page keeps the composition until the next
/// commit. A commit without a
/// range replaces that composition (one compositionend). A commit with an explicit range is
/// applied at once and the composition is never ended, so xterm.js sends the word twice; the
/// terminal cannot take sent data back.
private final class DeferredCompositionInputClient: MockInputClient {
  private var hiddenComposition: NSRange?
  private var unmarking = false

  override func markedRange() -> NSRange {
    hiddenComposition == nil
      ? super.markedRange() : NSRange(location: NSNotFound, length: NSNotFound)
  }

  override func selectedRange() -> NSRange {
    guard let composition = hiddenComposition else { return super.selectedRange() }
    return NSRange(location: NSMaxRange(composition), length: 0)
  }

  override func setMarkedText(
    _ string: Any, selectedRange: NSRange, replacementRange: NSRange
  ) {
    let text = (string as? NSAttributedString)?.string ?? string as? String ?? ""
    if text.isEmpty, !unmarking, hiddenComposition == nil, hasMarkedText() {
      let composition = super.markedRange()
      unmarking = true
      unmarkText()
      unmarking = false
      hiddenComposition = composition
      return
    }
    super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
  }

  override func insertText(_ string: Any, replacementRange: NSRange) {
    guard let composition = hiddenComposition else {
      super.insertText(string, replacementRange: replacementRange)
      return
    }
    hiddenComposition = nil
    let text = (string as? NSAttributedString)?.string ?? string as? String ?? ""
    let target =
      replacementRange.location == NSNotFound
      ? composition : NSRange(location: length(), length: 0)
    textStorage?.replaceCharacters(in: target, with: text)
    setSelectedRange(NSRange(location: target.location + (text as NSString).length, length: 0))
  }
}

class HangulLayoutAutocorrectionTests: IsolatedChordConfigurationTests {
  private func app(
    romanSource: GureumInputSource = .system, hangulSource: GureumInputSource = .han3Final,
    enabled: Bool = true, secure: Bool = false, client: MockInputClient = MockInputClient()
  ) -> VirtualApp {
    let app = ModerateApp(client: client)
    app.controller.receiver.romanAutocorrectionAvailable = { true }
    app.controller.receiver.romanAutocorrectionSecureInput = { secure }
    app.controller.receiver.romanAutocorrectionKnownEnglishWord = { word in
      [
        "hello", "world", "swift", "apple", "paseo", "compact", "yes", "if", "or", "it",
        "he", "me", "github", "build", "foo", "key", "flag", "god", "then", "when", "dad", "ace",
        "dir", "sys", "sudo", "todo", "goto",
      ]
      .contains(word.lowercased())
    }
    if enabled, let identifier = app.client.bundleIdentifier() {
      Configuration.shared.hangulLayoutAutocorrectionApplications = [identifier: "Test app"]
    }
    app.controller.setValue(
      romanSource.rawValue, forTag: kTextServiceInputModePropertyTag, client: app.client)
    Configuration.shared.lastHangulInputMode = hangulSource.rawValue
    return app
  }

  private func twoSetApp(enabled: Bool = true) -> VirtualApp {
    let app = app(hangulSource: .han2, enabled: enabled)
    app.controller.receiver.selectsClientInputModeForLayoutChanges = { false }
    return app
  }

  private func isRoman(_ app: VirtualApp) -> Bool {
    app.controller.receiver.composer.delegate is RomanComposer
  }

  private func typeWord(_ app: VirtualApp, _ keys: String, boundary: String = " ") {
    app.inputKeys(keys)
    app.inputText(boundary, key: .space)
  }

  func testImmediateBackspaceRestoresAutomaticConversionAndPreviousMode() {
    for (boundary, key) in [(" ", KeyCode.space), ("\n", .return), ("\t", .tab)] {
      for startsInHangul in [false, true] {
        let app = app()
        let previousMode =
          startsInHangul
          ? GureumInputSource.han3Final.rawValue : app.controller.receiver.composer.inputMode
        app.controller.receiver.composer.inputMode = previousMode
        app.inputKeys(startsInHangul ? "apple" : "jfshea")
        let original = app.client.string
        app.inputText(boundary, key: key)
        XCTAssertNotEqual(app.client.string, original + boundary)

        XCTAssertTrue(app.inputDelete())
        XCTAssertEqual(app.client.string, original + boundary)
        XCTAssertEqual(app.controller.receiver.composer.inputMode, previousMode)
        app.inputDelete()
        XCTAssertEqual(app.client.string, original)
      }
    }
  }

  func testConversionUndoDoesNotReplaceTextAfterCursorMoveOrExternalCommit() {
    for externalCommit in [false, true] {
      let app = app()
      typeWord(app, "jfshea")
      if externalCommit {
        app.controller.commitComposition(app.client)
      } else {
        app.client.setSelectedRange(NSRange(location: 0, length: 0))
      }
      XCTAssertFalse(
        app.controller.receiver.input(
          text: "", key: .delete, modifiers: [], client: app.client
        ).processed)
      XCTAssertEqual(app.client.string, "안녕 ")
    }
  }

  func testConversionUndoUsesUTF16RangeWithoutReadingTheDocument() {
    let app = app(client: UnreadableRomanInputClient())
    app.client.string = "🙂 앞 "
    app.client.setSelectedRange(
      NSRange(location: (app.client.string as NSString).length, length: 0))
    typeWord(app, "jfshea")
    app.inputDelete()
    XCTAssertEqual(app.client.string, "🙂 앞 jfshea ")
    XCTAssertTrue(isRoman(app))
  }

  func testConversionUndoExpiresAfterAnotherKeyOrSecureInput() {
    for secure in [false, true] {
      let app = app()
      typeWord(app, "jfshea")
      var undoCount = 0
      app.controller.receiver.automaticLayoutChangeUndone = { undoCount += 1 }
      if secure {
        app.controller.receiver.romanAutocorrectionSecureInput = { true }
      } else {
        app.inputKeys("k")
      }
      app.inputDelete()
      XCTAssertFalse(isRoman(app))
      XCTAssertEqual(undoCount, 0)
      XCTAssertFalse(app.client.string.contains("jfshea"))
    }
  }

  func testConversionUndoRejectsAnotherClientAndMarkedSelection() {
    for anotherClient in [false, true] {
      let app = app()
      typeWord(app, "jfshea")
      let client = anotherClient ? MockInputClient() : app.client
      if anotherClient {
        client.string = "안녕 "
        client.setSelectedRange(NSRange(location: 3, length: 0))
      } else {
        client.setMarkedText(
          "안녕", selectionRange: NSRange(location: 2, length: 0),
          replacementRange: NSRange(location: 0, length: 2))
      }
      _ = app.controller.receiver.input(text: "", key: .delete, modifiers: [], client: client)
      XCTAssertFalse(client.string.contains("jfshea"))
      XCTAssertFalse(isRoman(app))
    }
  }

  func testConversionUndoRestoresItsExactModeAfterAnotherControllerChangesLastMode() {
    for startsInHangul in [false, true] {
      let app = app()
      if startsInHangul {
        app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
      }
      let previousMode = app.controller.receiver.composer.inputMode
      typeWord(app, startsInHangul ? "apple" : "jfshea")
      Configuration.shared.lastHangulInputMode = GureumInputSource.han2.rawValue
      Configuration.shared.lastRomanInputMode = GureumInputSource.dvorak.rawValue

      XCTAssertTrue(app.inputDelete())
      XCTAssertEqual(app.controller.receiver.composer.inputMode, previousMode)
    }
  }

  func testConversionUndoRollsBackModeWhenLayoutTransitionChangesTheCaret() {
    let app = app()
    typeWord(app, "jfshea")
    let convertedMode = app.controller.receiver.composer.inputMode
    app.controller.receiver.selectsClientInputModeForLayoutChanges = {
      app.client.setSelectedRange(NSRange(location: 0, length: 0))
      return false
    }

    XCTAssertFalse(
      app.controller.receiver.input(
        text: "", key: .delete, modifiers: [], client: app.client
      ).processed)
    XCTAssertEqual(app.client.string, "안녕 ")
    XCTAssertEqual(app.controller.receiver.composer.inputMode, convertedMode)
  }

  func testSuccessfulSebeolsikCompositionIsTheConversionCriterion() {
    XCTAssertEqual(RomanLayoutAutocorrector.convert("jfshea", keyboard: "3f"), "안녕")
    XCTAssertEqual(RomanLayoutAutocorrector.convert("jfs", keyboard: "3f"), "안")
    XCTAssertEqual(RomanLayoutAutocorrector.convert("j/r", keyboard: "3f"), "왜")
    XCTAssertEqual(RomanLayoutAutocorrector.convert("kgo4B", keyboard: "3f"), "그쵸?")
    XCTAssertEqual(RomanLayoutAutocorrector.convert("jvhgw", keyboard: "3f"), "오늘")
    for word in ["if", "or", "it", "he", "me"] {
      XCTAssertNil(RomanLayoutAutocorrector.convert(word, keyboard: "3f"))
    }
    XCTAssertEqual(
      RomanLayoutAutocorrector.convert("jfsheamfncj4", keyboard: "3f"), "안녕하세요")
    XCTAssertEqual(RomanLayoutAutocorrector.convert("jdktq;/f", keyboard: "3f"), "이것봐")
    XCTAssertEqual(RomanLayoutAutocorrector.convert("jfshea", keyboard: "39"), "안녕")
    for keys in ["hello", "world", "jfsheaz", "Jfshea", "jfshea1"] {
      XCTAssertNil(RomanLayoutAutocorrector.convert(keys, keyboard: "3f"), keys)
    }
    XCTAssertNil(RomanLayoutAutocorrector.convert("jfshea", keyboard: "2-full"))
    XCTAssertNil(RomanLayoutAutocorrector.convert("jfshea", keyboard: "missing"))
  }

  func testHangulMistypedEnglishConvertsAndSwitchesFollowingInputToRoman() {
    let app = app()
    app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
    app.inputKeys("apple")
    XCTAssertEqual(app.client.string, app.client.markedString())
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "apple ")
    XCTAssertTrue(app.controller.receiver.composer.delegate is RomanComposer)
    app.inputKeys("world")
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "apple world ")
  }

  func testReverseCorrectionPreservesNormalHangulAndShortEnglishCollisions() {
    for keys in ["jfshea", "if", "or", "it", "he", "me"] {
      let app = app()
      app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
      app.inputKeys(keys)
      let original = app.client.string
      app.inputText(" ", key: .space)
      XCTAssertEqual(app.client.string, original + " ", keys)
      XCTAssertTrue(app.controller.receiver.composer.delegate is HangulComposer)
    }
  }

  func testReverseCorrectionDoesNotDropLeadingPunctuationFromValidHangul() {
    let app = app()
    app.controller.receiver.romanAutocorrectionKnownEnglishWord = { $0 == "vies" }
    app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
    app.inputKeys(";vies")
    XCTAssertEqual(app.client.string, "보면")

    app.inputText(" ", key: .space)

    XCTAssertEqual(app.client.string, "보면 ")
    XCTAssertFalse(isRoman(app))
    for prefix in [";", ",", ".", "!", "?", ":", ")"] {
      XCTAssertFalse(
        RomanLayoutAutocorrector.isKnownEnglishExpression(prefix + "vies") { $0 == "vies" },
        prefix)
    }
  }

  func testReverseCorrectionStillRestoresEnglishWithIncompleteJamo() {
    for word in ["apple", "hello", "swift", "paseo", "compact", "world", "haezoom.com"] {
      let app = app()
      app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
      typeWord(app, word)
      XCTAssertEqual(app.client.string, word + " ", word)
      XCTAssertTrue(isRoman(app), word)
    }
  }

  func testReverseCorrectionRestoresGitHubWithoutSystemDictionarySupport() {
    Configuration.shared.hangulAutoReorder = true
    let app = app()
    app.controller.receiver.romanAutocorrectionKnownEnglishWord = { _ in false }
    app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
    app.inputKeys("github")
    XCTAssertEqual(app.client.string, "므너두")

    app.inputText(" ", key: .space)

    XCTAssertEqual(app.client.string, "github ")
    XCTAssertTrue(isRoman(app))
    XCTAssertTrue(RomanLayoutAutocorrector.isKnownEnglishExpression("github") { _ in false })
    XCTAssertTrue(RomanLayoutAutocorrector.isKnownEnglishExpression("GitHub") { _ in false })
  }

  func testReverseCorrectionPreservesLiteralThreeSetDigits() {
    let app = app()
    app.controller.receiver.romanAutocorrectionKnownEnglishWord = { $0 == "YYYY" }
    app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
    app.inputKeys("YYYY")
    XCTAssertEqual(app.client.string, "5555")

    app.inputText(" ", key: .space)

    XCTAssertEqual(app.client.string, "5555 ")
    XCTAssertFalse(isRoman(app))
  }

  func testReverseCorrectionPreservesRepeatedHangulJamoAtWhitespace() {
    for keys in ["mmmm", "0000", "mmmm.", "0000."] {
      let app = app()
      app.controller.receiver.romanAutocorrectionKnownEnglishWord = { _ in true }
      app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
      app.inputKeys(keys)
      let original = app.client.string
      XCTAssertTrue(RomanLayoutAutocorrector.isRepeatedHangulJamoExpression(original), keys)

      app.inputText(" ", key: .space)

      XCTAssertEqual(app.client.string, original + " ", keys)
      XCTAssertFalse(isRoman(app), keys)
    }
  }

  func testBuiltInTechnicalTermsSupplyCaseInsensitiveEnglishEvidence() {
    for word in ["github", "GitHub", "tailscale", "Tailscale", "TAILSCALE"] {
      XCTAssertTrue(RomanLayoutAutocorrector.isKnownEnglishExpression(word) { _ in false }, word)
    }
    for word in ["kube", "aws", "tailscalex"] {
      XCTAssertFalse(RomanLayoutAutocorrector.isKnownEnglishExpression(word) { _ in false }, word)
    }
  }

  func testReverseCorrectionRestoresTailscaleAndImmediateBackspaceRestoresHangul() {
    Configuration.shared.hangulAutoReorder = true
    let app = app()
    app.controller.receiver.romanAutocorrectionKnownEnglishWord = { _ in false }
    let previousMode = GureumInputSource.han3Final.rawValue
    app.controller.receiver.composer.inputMode = previousMode
    app.inputKeys("tailscale")
    let original = app.client.string
    XCTAssertNotEqual(original, "tailscale")

    app.inputText(" ", key: .space)

    XCTAssertEqual(app.client.string, "tailscale ")
    XCTAssertTrue(isRoman(app))
    XCTAssertTrue(app.inputDelete())
    XCTAssertEqual(app.client.string, original + " ")
    XCTAssertEqual(app.controller.receiver.composer.inputMode, previousMode)
  }

  func testTechnicalTermsPreserveTypedCasingInMixedTokens() {
    for prefix in ["GitHub", "Tailscale", "TAILSCALE"] {
      XCTAssertEqual(
        RomanLayoutAutocorrector.convertEnglishPrefixWithHangulSuffix(
          keys: prefix + "jcnt", roman: prefix + "jcnt", keyboard: "3f",
          isKnownWord: { _ in false }),
        prefix + "에서", prefix)
    }
  }

  func testTechnicalTermEvidenceRespectsApplicationAndSecureInputGates() {
    for (enabled, secure) in [(false, false), (true, true)] {
      let app = app(enabled: enabled, secure: secure)
      app.controller.receiver.romanAutocorrectionKnownEnglishWord = { _ in false }
      app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
      app.inputKeys("tailscale")
      let original = app.client.string

      app.inputText(" ", key: .space)

      XCTAssertEqual(app.client.string, original + " ")
      XCTAssertFalse(isRoman(app))
    }
  }

  func testEnglishExpressionAllowsOpeningQuotesAndTrailingPunctuation() {
    for expression in ["hello;", "hello,", "\"hello\"", "'hello'", "(hello)", "“hello”", "‘hello’"]
    {
      XCTAssertTrue(
        RomanLayoutAutocorrector.isKnownEnglishExpression(expression) { $0 == "hello" },
        expression)
    }
  }

  func testTwoSetKeepsNativeResyllabificationAndBackspaceBehavior() {
    let app = app()
    app.controller.receiver.composer.inputMode = GureumInputSource.han2.rawValue
    app.inputKeys("rksk")
    XCTAssertEqual(app.client.string, "가나")

    app.inputDelete()

    XCTAssertEqual(app.client.string, "가ㄴ")
    XCTAssertTrue(app.controller.receiver.composer.delegate is HangulComposer)
  }

  func testReverseCorrectionBackspaceReplaysWholeWord() {
    let app = app()
    app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
    app.inputKeys("applx")
    app.inputDelete()
    app.inputKeys("e")
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "apple ")
  }

  func testBufferedHangulBackspaceDeletesPreviouslyCompletedSyllablesAsCharacters() {
    let app = app()
    app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
    app.inputKeys("jfshe")
    XCTAssertEqual(app.client.string, "안녀")
    for expected in ["안ㄴ", "안", ""] {
      app.inputDelete()
      XCTAssertEqual(app.client.string, expected)
    }
  }

  func testBufferedHangulBackspaceStillDecomposesTheFirstActiveSyllable() {
    let app = app()
    app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
    app.inputKeys("jfs")
    for expected in ["아", "ㅇ", ""] {
      app.inputDelete()
      XCTAssertEqual(app.client.string, expected)
    }
  }

  func testBufferedHangulCanContinueAfterDeletingBackToACompletedBoundary() {
    let app = app()
    app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
    app.inputKeys("jfshe")
    app.inputDelete()
    app.inputDelete()
    app.inputKeys("jfs")
    XCTAssertEqual(app.client.string, "안안")
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "안안 ")
  }

  func testBufferedHangulBackspacePreservesMultipleCompletedBoundaries() {
    let app = app()
    app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
    app.inputKeys("jfsheajfs")
    XCTAssertEqual(app.client.string, "안녕안")
    for expected in ["안녕아", "안녕ㅇ", "안녕", "안", ""] {
      app.inputDelete()
      XCTAssertEqual(app.client.string, expected)
    }
    app.inputKeys("apple")
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "apple ")
  }

  func testBufferedHangulReplayDoesNotReopenACompletedSyllableAfterNewVowels() {
    let app = app()
    app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
    app.inputKeys("jfshe")
    app.inputDelete()
    app.inputDelete()
    app.inputKeys("ef")
    app.inputDelete()
    XCTAssertEqual(app.client.string, "안ㅕ")
  }

  func testReverseCorrectionReleasesBackspaceAfterDeletingTheWholeBuffer() {
    let app = app()
    app.client.string = "prefix"
    app.client.setSelectedRange(NSRange(location: 6, length: 0))
    app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
    app.inputKeys("a")
    XCTAssertFalse(app.client.markedString().isEmpty)

    app.inputDelete()
    XCTAssertEqual(app.client.string, "prefix")
    XCTAssertEqual(app.client.markedString(), "")

    app.inputDelete()
    XCTAssertEqual(app.client.string, "prefi")
  }

  func testReverseCorrectionPreservesBoundariesCasePunctuationAndRepeats() {
    for (boundary, key) in [(" ", KeyCode.space), ("\n", .return), ("\t", .tab)] {
      for word in ["Apple", "hello!", "compact.compact", "appleapple"] {
        let app = app()
        app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
        app.inputKeys(word)
        app.inputText(boundary, key: key)
        XCTAssertEqual(app.client.string, word + boundary)
        XCTAssertTrue(app.controller.receiver.composer.delegate is RomanComposer)
      }
    }
  }

  func testDomainPrefixConvertsAtPeriodAndContinuesInRoman() {
    for source in [GureumInputSource.han3Final, .han2] {
      let app = app(hangulSource: source)
      app.controller.receiver.selectsClientInputModeForLayoutChanges = { false }
      app.controller.receiver.composer.inputMode = source.rawValue
      app.inputKeys("haezoom.")
      XCTAssertEqual(app.client.string, "haezoom.")
      XCTAssertTrue(isRoman(app))
      app.inputKeys("com")
      XCTAssertEqual(app.client.string, "haezoom.com")
    }
  }

  func testDomainPrefixImmediateBackspaceRestoresHangulAndPeriod() {
    for source in [GureumInputSource.han3Final, .han2] {
      let app = app(hangulSource: source)
      app.controller.receiver.selectsClientInputModeForLayoutChanges = { false }
      app.controller.receiver.composer.inputMode = source.rawValue
      app.inputKeys("haezoom")
      let original = app.client.string
      app.inputKeys(".")
      XCTAssertTrue(app.inputDelete())
      XCTAssertEqual(app.client.string, original + ".")
      XCTAssertEqual(app.controller.receiver.composer.inputMode, source.rawValue)
      app.inputDelete()
      XCTAssertEqual(app.client.string, original)
    }
  }

  func testPeriodRequiresLongDomainLabelAndIncompleteJamo() {
    for source in [GureumInputSource.han3Final, .han2] {
      for keys in [
        "abc.", "-haezoom.", "haezoom-.", "foo/haezoom.", "foo_haezoom.",
        source == .han2 ? "dkssud." : "jfshea.",
      ] {
        let app = app(hangulSource: source)
        app.controller.receiver.composer.inputMode = source.rawValue
        let baseline = self.app(hangulSource: source, enabled: false)
        baseline.controller.receiver.romanAutocorrectionAvailable = { false }
        baseline.controller.receiver.composer.inputMode = source.rawValue
        app.inputKeys(keys)
        baseline.inputKeys(keys)
        XCTAssertEqual(app.client.string, baseline.client.string, keys)
        XCTAssertFalse(isRoman(app), keys)
      }
    }
  }

  func testPeriodRejectsLaughterNumericAndConsonantRuns() {
    for source in [GureumInputSource.han3Final, .han2] {
      for keys in ["0000.", "mmmm.", "1234.", "bcdf.", "aeiou."] {
        let app = app(hangulSource: source)
        app.controller.receiver.composer.inputMode = source.rawValue
        let baseline = self.app(hangulSource: source, enabled: false)
        baseline.controller.receiver.romanAutocorrectionAvailable = { false }
        baseline.controller.receiver.composer.inputMode = source.rawValue
        app.inputKeys(keys)
        baseline.inputKeys(keys)
        XCTAssertEqual(app.client.string, baseline.client.string, keys)
        XCTAssertFalse(isRoman(app), keys)
        if source == .han3Final, keys == "0000." {
          XCTAssertEqual(app.client.string, "ㅋㅋㅋㅋ.")
        } else if source == .han3Final, keys == "mmmm." {
          XCTAssertEqual(app.client.string, "ㅎㅎㅎㅎ.")
        }
      }
    }
  }

  func testDomainLikeBrandNamesConvertWithoutDictionaryEntries() {
    XCTAssertTrue(
      RomanLayoutAutocorrector.isKnownEnglishExpression("haezoom.com") { _ in false })
    for invalid in ["haezoom", ".com", "haezoom.", "-haezoom.com", "haezoom-.com"] {
      XCTAssertFalse(RomanLayoutAutocorrector.isDomainExpression(invalid), invalid)
    }

    let reverse = app()
    reverse.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
    reverse.inputKeys("haezoom.com")
    reverse.inputText(" ", key: .space)
    XCTAssertEqual(reverse.client.string, "haezoom.com ")
    XCTAssertTrue(reverse.controller.receiver.composer.delegate is RomanComposer)

    let forward = app()
    forward.inputKeys("haezoom.com")
    forward.inputText(" ", key: .space)
    XCTAssertEqual(forward.client.string, "haezoom.com ")
    XCTAssertTrue(forward.controller.receiver.composer.delegate is RomanComposer)
  }

  func testReverseCorrectionWorksWithoutDocumentReadsOrAbsoluteMarkedSelection() {
    let app = app(client: UnreadableRomanInputClient())
    app.client.string = "🙂 앞 문장 "
    app.client.setSelectedRange(
      NSRange(location: (app.client.string as NSString).length, length: 0))
    app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
    app.inputKeys("apple")
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "🙂 앞 문장 apple ")
  }

  func testReverseCorrectionExternalCommitAndSecureInputPreserveOriginalOnce() {
    for useSecureBoundary in [false, true] {
      let app = app()
      app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
      app.inputKeys("apple")
      let original = app.client.string
      if useSecureBoundary {
        app.controller.receiver.romanAutocorrectionSecureInput = { true }
        app.inputText(" ", key: .space)
        XCTAssertEqual(app.client.string, original + " ")
      } else {
        app.controller.commitComposition(app.client)
        app.controller.updateComposition()
        XCTAssertEqual(app.client.string, original)
      }
      XCTAssertTrue(app.controller.receiver.composer.delegate is HangulComposer)
    }
  }

  func testAutomaticLayoutChangeCallbackOnlyFollowsSuccessfulCommitOnce() {
    for (keys, startsInHangul, expected) in [
      ("jfshea", false, "hangul"), ("apple", true, "roman"),
      ("apple", false, ""), ("jfshea", true, ""),
    ] {
      let app = app()
      if startsInHangul {
        app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
      }
      var directions: [String] = []
      app.controller.receiver.automaticLayoutChangeCommitted = {
        directions.append($0 == .hangul ? "hangul" : "roman")
        XCTAssertFalse(app.client.string.isEmpty)
      }
      app.inputKeys(keys)
      XCTAssertTrue(directions.isEmpty)
      app.inputText(" ", key: .space)
      app.inputText(" ", key: .space)
      XCTAssertEqual(directions, expected.isEmpty ? [] : [expected])
    }
  }

  func testAutomaticLayoutChangeHUDUsesTheSionyuelToastTimingContract() {
    XCTAssertEqual(AutomaticLayoutChangeHUD.displayDuration(for: "짧은 알림"), 1.8)
    XCTAssertEqual(
      AutomaticLayoutChangeHUD.displayDuration(for: String(repeating: "a", count: 21)), 1.9,
      accuracy: 0.001)
    XCTAssertEqual(
      AutomaticLayoutChangeHUD.displayDuration(for: String(repeating: "a", count: 100)), 6)
    XCTAssertEqual(AutomaticLayoutChangeHUD.springProgress(at: 0), 0, accuracy: 0.001)
    XCTAssertEqual(AutomaticLayoutChangeHUD.springProgress(at: 0.131), 0.9, accuracy: 0.08)
    XCTAssertEqual(AutomaticLayoutChangeHUD.springProgress(at: 0.732), 1, accuracy: 0.01)
  }

  func testImmediateHUDDismissDoesNotLeaveAQueuedPresentationVisible() {
    let hud = AutomaticLayoutChangeHUD.shared
    let client = HUDInputClient()
    hud.show(.hangul, client: client)
    hud.dismiss()
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.4))
    XCTAssertFalse(hud.isVisible)
    hud.dismiss()
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))
  }

  func testHUDExitRetainsItsEndpointUntilThePanelOrdersOut() throws {
    for reduceMotion in [false, true] {
      let panel = HUDTestPanel()
      let hud = AutomaticLayoutChangeHUD(panel: panel, reduceMotion: { reduceMotion })
      let client = HUDInputClient()
      hud.show(.hangul, client: client)
      RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.08))
      let layer = try XCTUnwrap(hud.toastLayer)
      let presentation = try XCTUnwrap(layer.presentation())
      XCTAssertGreaterThan(presentation.opacity, 0)
      XCTAssertLessThan(presentation.opacity, 1)
      hud.dismiss()
      RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.03))

      let exit = try XCTUnwrap(
        layer.animation(forKey: "automaticLayoutChangeExit") as? CAAnimationGroup)
      XCTAssertFalse(exit.isRemovedOnCompletion)
      XCTAssertEqual(exit.fillMode, .forwards)
      XCTAssertEqual(exit.duration, reduceMotion ? 0.15 : 0.18)
      XCTAssertEqual(layer.opacity, 1)
      XCTAssertTrue(CATransform3DIsIdentity(layer.transform))
      let animations = try XCTUnwrap(exit.animations as? [CABasicAnimation])
      XCTAssertEqual(
        animations.map(\.keyPath),
        reduceMotion
          ? ["opacity"]
          : [
            "opacity", "transform.translation.y",
          ])
      XCTAssertEqual(
        try XCTUnwrap(animations[0].fromValue as? Float), presentation.opacity, accuracy: 0.1)
      XCTAssertEqual(animations[0].toValue as? Int, 0)
      if !reduceMotion {
        // AppKit's unflipped backing layer uses negative Y for a downward exit.
        XCTAssertLessThan(presentation.transform.m42, 0)
        XCTAssertEqual(
          try XCTUnwrap(animations[1].fromValue as? CGFloat), presentation.transform.m42,
          accuracy: 1)
        XCTAssertEqual(animations[1].toValue as? Int, -8)
        var controlPoint: [Float] = [0, 0]
        animations[0].timingFunction?.getControlPoint(at: 1, values: &controlPoint)
        XCTAssertEqual(controlPoint, [0.4, 0])
        animations[0].timingFunction?.getControlPoint(at: 2, values: &controlPoint)
        XCTAssertEqual(controlPoint, [1, 1])
      }
      XCTAssertTrue(hud.isVisible)
      XCTAssertEqual(panel.orderOutCount, 0)
      hud.dismiss()
      RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))
      XCTAssertFalse(hud.isVisible)
      XCTAssertEqual(panel.orderOutCount, 1)
      XCTAssertNil(layer.animation(forKey: "automaticLayoutChangeExit"))
      hud.dismiss()
      RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))
      XCTAssertEqual(panel.orderOutCount, 1)
    }
  }

  func testHUDReplacementDuringExitContinuesFromItsPresentationState() throws {
    let replacements: [(AutomaticLayoutChangeDirection, Bool)] = [
      (.hangul, false), (.roman, false), (.hangul, true), (.roman, true),
    ]
    for (direction, reduceMotion) in replacements {
      let panel = HUDTestPanel()
      let hud = AutomaticLayoutChangeHUD(panel: panel, reduceMotion: { reduceMotion })
      let client = HUDInputClient()
      hud.show(.hangul, client: client)
      RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.8))
      hud.dismiss()
      RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.09))
      let layer = try XCTUnwrap(hud.toastLayer)
      let presentation = try XCTUnwrap(layer.presentation())
      XCTAssertGreaterThan(presentation.opacity, 0)
      XCTAssertLessThan(presentation.opacity, 1)
      hud.show(direction, client: client)
      RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.02))
      let fade = try XCTUnwrap(
        layer.animation(forKey: "automaticLayoutChangeFadeIn") as? CABasicAnimation)
      XCTAssertEqual(try XCTUnwrap(fade.fromValue as? Float), presentation.opacity, accuracy: 0.15)
      if reduceMotion {
        XCTAssertEqual(fade.duration, 0.15)
        XCTAssertNil(layer.animation(forKey: "automaticLayoutChangeSpringIn"))
      } else {
        let spring = try XCTUnwrap(
          layer.animation(forKey: "automaticLayoutChangeSpringIn") as? CASpringAnimation)
        XCTAssertEqual(
          try XCTUnwrap(spring.fromValue as? CGFloat), presentation.transform.m42, accuracy: 1.5)
      }
      XCTAssertNil(layer.animation(forKey: "automaticLayoutChangeExit"))
      RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))
      XCTAssertTrue(hud.isVisible)
      XCTAssertEqual(panel.orderOutCount, 0)
      hud.dismiss()
      RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))
      XCTAssertEqual(panel.orderOutCount, 1)
    }
  }

  func testHUDKeepsItsEntrancePulseAndRestartedHold() throws {
    let panel = HUDTestPanel()
    let hud = AutomaticLayoutChangeHUD(panel: panel, reduceMotion: { false })
    let client = HUDInputClient()
    hud.show(.hangul, client: client)
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.03))
    let layer = try XCTUnwrap(hud.toastLayer)
    let fade = try XCTUnwrap(
      layer.animation(forKey: "automaticLayoutChangeFadeIn") as? CABasicAnimation)
    XCTAssertEqual(fade.duration, 0.2)
    XCTAssertEqual(fade.fromValue as? Float, 0)
    let spring = try XCTUnwrap(
      layer.animation(forKey: "automaticLayoutChangeSpringIn") as? CASpringAnimation)
    XCTAssertEqual(spring.fromValue as? CGFloat, -12)
    XCTAssertEqual(spring.duration, 0.732)
    XCTAssertEqual(spring.mass, 1)
    XCTAssertEqual(spring.stiffness, 449)
    XCTAssertEqual(spring.damping, 31.4)
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.6))
    hud.show(.hangul, client: client)
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.03))
    let pulse = try XCTUnwrap(
      hud.pillLayer?.animation(forKey: "automaticLayoutChangePulse")
        as? CAKeyframeAnimation)
    XCTAssertEqual(pulse.duration, 0.16)
    XCTAssertEqual(pulse.values?.compactMap { ($0 as? NSNumber)?.doubleValue }, [1, 1.04, 1])
    XCTAssertNil(layer.animation(forKey: "automaticLayoutChangeFadeIn"))
    XCTAssertNil(layer.animation(forKey: "automaticLayoutChangeSpringIn"))
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.4))
    XCTAssertTrue(hud.isVisible)
    XCTAssertEqual(panel.orderOutCount, 0)
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.7))
    XCTAssertFalse(hud.isVisible)
    XCTAssertEqual(panel.orderOutCount, 1)
  }

  func testBaramInternalLayoutToggleDoesNotLeaveTheBaramInputSource() {
    let app = app()
    app.controller.receiver.selectsClientInputModeForLayoutChanges = { false }
    app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue

    _ = app.controller.receiver.input(event: .changeLayout(.roman, true), client: app.client)
    XCTAssertTrue(app.controller.receiver.composer.delegate is RomanComposer)
    XCTAssertTrue(app.client.selectedInputModeRequests.isEmpty)

    _ = app.controller.receiver.input(event: .changeLayout(.hangul, true), client: app.client)
    XCTAssertTrue(app.controller.receiver.composer.delegate is HangulComposer)
    XCTAssertTrue(app.client.selectedInputModeRequests.isEmpty)
  }

  func testNonBaramLayoutToggleStillSelectsTheRequestedInputMode() {
    let app = app()
    app.controller.receiver.selectsClientInputModeForLayoutChanges = { true }
    app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue

    _ = app.controller.receiver.input(event: .changeLayout(.roman, true), client: app.client)

    XCTAssertEqual(
      app.client.selectedInputModeRequests,
      [app.controller.receiver.composer.inputMode])
  }

  func testReverseCorrectionUsesTheSelectedRomanKeyboardMapping() {
    for (source, type) in [
      (GureumInputSource.qwerty, RomanComposer.ComposerType.qwerty),
      (.dvorak, .dvorak), (.colemak, .colemak),
    ] {
      let app = app(romanSource: source)
      app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
      let physicalMap = Dictionary(
        zip(type.keyboardData, RomanComposer.ComposerType.qwerty.keyboardData),
        uniquingKeysWith: { first, _ in first })
      app.inputKeys(String("apple".map { physicalMap[$0]! }))
      app.inputText(" ", key: .space)
      XCTAssertEqual(app.client.string, "apple ")
      XCTAssertEqual(app.controller.receiver.composer.inputMode, source.rawValue)
    }
  }

  // MARK: - Two-set (2-full) automatic switching

  func testTwoSetRomanKeysConvertAtBoundaryAndSwitchTheInternalModeOnly() {
    for (keys, expected) in [("dkssud", "안녕 "), ("rksk", "가나 ")] {
      let app = twoSetApp()
      typeWord(app, keys)
      XCTAssertEqual(app.client.string, expected, keys)
      XCTAssertEqual(app.controller.receiver.composer.inputMode, GureumInputSource.han2.rawValue)
      XCTAssertFalse(isRoman(app))
      XCTAssertTrue(app.client.selectedInputModeRequests.isEmpty)
    }
  }

  func testTwoSetFollowingInputUsesTheRealModeAfterEachDecision() {
    let app = twoSetApp()
    typeWord(app, "dkssud")
    typeWord(app, "rksk")
    XCTAssertEqual(app.client.string, "안녕 가나 ")
    XCTAssertFalse(isRoman(app))
    typeWord(app, "apple")
    XCTAssertEqual(app.client.string, "안녕 가나 apple ")
    XCTAssertTrue(isRoman(app))
    typeWord(app, "dkssud")
    XCTAssertEqual(app.client.string, "안녕 가나 apple 안녕 ")
    XCTAssertFalse(isRoman(app))
  }

  func testTwoSetKnownEnglishAndDomainsStayRoman() {
    for word in ["hello", "swift", "paseo", "haezoom.com", "appleapple"] {
      let app = twoSetApp()
      typeWord(app, word)
      XCTAssertEqual(app.client.string, word + " ", word)
      XCTAssertTrue(isRoman(app), word)
    }
  }

  func testTwoSetConversionIsConservative() {
    for keys in ["dir", "sys", "xor", "qux", "TODO", "dks", "Dkssud", "dkssud1", "dkssud/", "rk"] {
      XCTAssertNil(RomanLayoutAutocorrector.convert(keys, keyboard: "2-full"), keys)
    }
    XCTAssertEqual(RomanLayoutAutocorrector.convert("dkssud", keyboard: "2-full"), "안녕")
    XCTAssertEqual(RomanLayoutAutocorrector.convert("rksk", keyboard: "2-full"), "가나")
    XCTAssertEqual(RomanLayoutAutocorrector.convert("Rksk", keyboard: "2-full"), "까나")
    XCTAssertEqual(RomanLayoutAutocorrector.convert("dkssud.", keyboard: "2-full"), "안녕.")
    XCTAssertNil(RomanLayoutAutocorrector.convert("dk.ssud", keyboard: "2-full"))
    // Words that happen to compose cleanly stay English because the checker knows them.
    for word in ["sudo", "todo", "goto", "dad", "then", "when"] {
      let app = twoSetApp()
      typeWord(app, word)
      XCTAssertEqual(app.client.string, word + " ", word)
      XCTAssertTrue(isRoman(app), word)
    }
  }

  func testCodeLikeTokensStayRomanInTwoSetAndThreeSet() {
    for token in ["v2", "build.sh", "foo/bar", "--flag", "key=value", "main.swift"] {
      for hangul in [GureumInputSource.han2, .han3Final] {
        let app = app(hangulSource: hangul)
        typeWord(app, token)
        XCTAssertEqual(app.client.string, token + " ", token)
        XCTAssertTrue(isRoman(app), token)
      }
    }
    XCTAssertTrue(RomanLayoutAutocorrector.isCodeLikeToken("build.sh"))
    XCTAssertTrue(RomanLayoutAutocorrector.isCodeLikeToken("--flag"))
    XCTAssertTrue(RomanLayoutAutocorrector.isCodeLikeToken("key=value"))
    XCTAssertFalse(RomanLayoutAutocorrector.isCodeLikeToken("jfshea"))
    XCTAssertFalse(RomanLayoutAutocorrector.isCodeLikeToken("jdktq;/f"))
  }

  func testTwoSetBackspaceInRomanBufferDropsOnlyTheLastKey() {
    let app = twoSetApp()
    app.inputKeys("dkssudx")
    app.inputDelete()
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "안녕 ")
  }

  func testTwoSetReverseCorrectionRestoresEnglishAndSwitchesToRoman() {
    for word in ["apple", "Apple", "hello!", "appleapple", "haezoom.com"] {
      let app = twoSetApp()
      app.controller.receiver.composer.inputMode = GureumInputSource.han2.rawValue
      app.inputKeys(word)
      if word == "haezoom.com" {
        XCTAssertEqual(app.client.string, word)
        XCTAssertEqual(app.client.markedString(), "com")
        XCTAssertTrue(isRoman(app))
      } else {
        XCTAssertEqual(app.client.string, app.client.markedString(), word)
      }
      app.inputText(" ", key: .space)
      XCTAssertEqual(app.client.string, word + " ", word)
      XCTAssertTrue(isRoman(app), word)
      XCTAssertTrue(app.client.selectedInputModeRequests.isEmpty)
      typeWord(app, "world")
      XCTAssertEqual(app.client.string, word + " world ")
    }
  }

  func testTwoSetReverseCorrectionKeepsValidHangulAndEnglishLookalikes() {
    // dkssud/rksk are Korean; then/when/dad/ace compose into complete or short Hangul.
    for keys in ["dkssud", "rksk", "then", "when", "dad", "ace", "if", "or", "it", "he", "me"] {
      let app = twoSetApp()
      app.controller.receiver.composer.inputMode = GureumInputSource.han2.rawValue
      app.inputKeys(keys)
      let original = app.client.string
      app.inputText(" ", key: .space)
      XCTAssertEqual(app.client.string, original + " ", keys)
      XCTAssertFalse(isRoman(app), keys)
    }
  }

  func testTwoSetReverseBackspaceReplacesTheLastKeyOfTheEnglishWord() {
    let app = twoSetApp()
    app.controller.receiver.composer.inputMode = GureumInputSource.han2.rawValue
    app.inputKeys("applx")
    app.inputDelete()
    app.inputKeys("e")
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "apple ")
    XCTAssertTrue(isRoman(app))
  }

  func testTwoSetBufferedBackspaceMatchesUnbufferedBackspaceAtEveryStep() {
    enum Step {
      case keys(String)
      case delete
    }
    let scripts: [[Step]] = [
      [.keys("rksk"), .delete, .delete, .delete, .delete],
      [.keys("dkssud"), .delete, .delete, .delete, .delete, .delete, .delete, .delete],
      [.keys("ekfrrhrl"), .delete, .delete, .delete, .delete, .delete],
      [.keys("dlTdj"), .delete, .delete, .keys("dj"), .delete, .delete, .delete],
      [.keys("rkrt"), .keys("k"), .delete, .delete, .delete],
      [.keys("rk."), .delete, .delete, .delete],
      [.keys("rksk"), .delete, .keys("k"), .delete, .delete],
    ]
    for script in scripts {
      let buffered = twoSetApp(enabled: true)
      let native = twoSetApp(enabled: false)
      for app in [buffered, native] {
        app.controller.receiver.composer.inputMode = GureumInputSource.han2.rawValue
      }
      var trace: [String] = []
      for step in script {
        for app in [buffered, native] {
          switch step {
          case .keys(let keys): app.inputKeys(keys)
          case .delete: app.inputDelete()
          }
        }
        trace.append(buffered.client.string)
        XCTAssertEqual(buffered.client.string, native.client.string, "\(script) \(trace)")
      }
      XCTAssertTrue(buffered.controller.receiver.composer.delegate is HangulComposer)
    }
  }

  func testTwoSetBackspaceAfterDeletingCompletedSyllablesDoesNotConvertTheWord() {
    let app = twoSetApp()
    app.controller.receiver.composer.inputMode = GureumInputSource.han2.rawValue
    app.inputKeys("appleapple")
    app.inputDelete()
    app.inputDelete()
    app.inputDelete()
    app.inputKeys("x")
    let original = app.client.string
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, original + " ")
  }

  // MARK: - English prefix with a Hangul suffix

  func testDocumentedGitHubMixedTokensDoNotDependOnSystemSpellingDictionary() {
    for (layout, keys) in [(GureumInputSource.han2, "githubdptj"), (.han3Final, "githubjcnt")] {
      let app = app(hangulSource: layout)
      app.controller.receiver.romanAutocorrectionKnownEnglishWord = { _ in false }
      typeWord(app, keys)
      XCTAssertEqual(app.client.string, "github에서 ", keys)
      XCTAssertFalse(isRoman(app), keys)
    }
  }

  func testGitHubMixedTokenUsesAUniqueBoundaryWithShorterKnownPrefixes() {
    XCTAssertEqual(
      RomanLayoutAutocorrector.convertEnglishPrefixWithHangulSuffix(
        keys: "githubjcnt", roman: "githubjcnt", keyboard: "3f",
        isKnownWord: { ["git", "Github"].contains($0) }),
      "github에서")
  }

  func testEnglishPrefixWithTwoSetSuffixSplitsAtTheBoundary() {
    let app = twoSetApp()
    typeWord(app, "githubdptj")
    XCTAssertEqual(app.client.string, "github에서 ")
    XCTAssertEqual(app.controller.receiver.composer.inputMode, GureumInputSource.han2.rawValue)
    XCTAssertFalse(isRoman(app))
    XCTAssertTrue(app.client.selectedInputModeRequests.isEmpty)
    typeWord(app, "dkssud")
    XCTAssertEqual(app.client.string, "github에서 안녕 ")
  }

  func testEnglishPrefixWithThreeSetSuffixSplitsAtTheBoundary() {
    let app = app()
    app.controller.receiver.selectsClientInputModeForLayoutChanges = { false }
    typeWord(app, "githubjcnt")
    XCTAssertEqual(app.client.string, "github에서 ")
    XCTAssertTrue(app.controller.receiver.composer.inputMode.hasSuffix("han3final"))
    XCTAssertFalse(isRoman(app))
    XCTAssertTrue(app.client.selectedInputModeRequests.isEmpty)
  }

  func testMixedTokenSplitCoversCaseAndNeverDuplicatesText() {
    let app = twoSetApp()
    app.inputKeys("Githubdptj")
    XCTAssertEqual(app.client.string, app.client.markedString())
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "Github에서 ")
    XCTAssertEqual(app.client.markedString(), "")
  }

  func testMixedTokenSplitLeavesAmbiguousAndEnglishTokensAlone() {
    for hangul in [GureumInputSource.han2, .han3Final] {
      // github alone, code tokens and a known-English "suffix" keep the original text.
      for token in ["github", "github.com", "githubthen", "build.sh", "foo/bar", "key=value"] {
        let app = app(hangulSource: hangul)
        typeWord(app, token)
        XCTAssertEqual(app.client.string, token + " ", "\(hangul) \(token)")
        XCTAssertTrue(isRoman(app), token)
      }
    }
    // Whole-token Hangul wins over a split: god + 복 would otherwise become "god복".
    let app = twoSetApp()
    typeWord(app, "godqhr")
    XCTAssertEqual(app.client.string, "행복 ")
    // A prefix that is not a known word, or a suffix that does not compose, is not split.
    for token in ["gitxubdptj", "githubdptjy", "githubdp"] {
      let app = twoSetApp()
      typeWord(app, token)
      XCTAssertEqual(app.client.string, token + " ", token)
      XCTAssertTrue(isRoman(app), token)
    }
  }

  func testMixedTokenSplitRespectsSecureInput() {
    let app = app(hangulSource: .han2, secure: true)
    typeWord(app, "githubdptj")
    XCTAssertEqual(app.client.string, "githubdptj ")
    XCTAssertTrue(isRoman(app))
  }

  func testReverseWordRemainsAvailableToHanjaSearch() {
    let app = app()
    app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
    app.inputKeys("jfshea")
    _ = app.controller.receiver.input(event: .changeLayout(.search, true), client: app.client)
    XCTAssertEqual(app.controller.receiver.composer.searchComposer.composedString, "안녕")
  }

  func testConversionWaitsForWhitespaceAndPreservesBoundary() {
    for (boundary, key) in [(" ", KeyCode.space), ("\n", .return), ("\t", .tab)] {
      let app = app()
      app.inputKeys("jfshea")
      XCTAssertEqual(app.client.string, "jfshea")

      app.inputText(boundary, key: key)

      XCTAssertEqual(app.client.string, "안녕" + boundary)
      XCTAssertTrue(app.controller.receiver.composer.inputMode.hasSuffix("han3final"))
    }
  }

  func testSingleCompleteSyllableConvertsAtTheBoundary() {
    let app = app()
    app.inputKeys("j/r")
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "왜 ")
    XCTAssertTrue(app.controller.receiver.composer.inputMode.hasSuffix("han3final"))
  }

  func testNumberRowKeysCanCompleteAThreeSetWord() {
    let app = app()
    app.inputKeys("jfsheamfncj4")
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "안녕하세요 ")
    XCTAssertTrue(app.controller.receiver.composer.inputMode.hasSuffix("han3final"))

    app.inputKeys("jfshea")
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "안녕하세요 안녕 ")
  }

  func testSuccessfulCorrectionSwitchesTheFollowingPhraseToHangul() {
    let app = app()
    app.inputKeys("jdkc")
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "이게 ")
    XCTAssertTrue(app.controller.receiver.composer.inputMode.hasSuffix("han3final"))

    app.inputKeys("i9twld")
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "이게 뭘지 ")
  }

  func testSuccessfulCorrectionKeepsALongerFollowingPhraseInHangul() {
    let app = app()
    app.inputKeys("jdkc")
    app.inputText(" ", key: .space)
    for keys in ["lfwu/dhgs", "keajbuv", "jd2hgsuc"] {
      app.inputKeys(keys)
      app.inputText(" ", key: .space)
    }
    XCTAssertEqual(app.client.string, "이게 잘되는 경우도 있는데 ")
  }

  func testThreeSetPunctuationKeysCanFormACompleteWord() {
    let app = app()
    app.inputKeys("jdktq;/f")
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "이것봐 ")
  }

  func testShiftFlagChangesDoNotDiscardThePendingThreeSetWord() {
    let app = app()
    func sendShiftFlags(_ flags: NSEvent.ModifierFlags) {
      let event = NSEvent.keyEvent(
        with: .flagsChanged, location: .zero, modifierFlags: flags, timestamp: 0,
        windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
        isARepeat: false, keyCode: UInt16(KeyCode.shift.rawValue))!
      _ = app.controller.handle(event, client: app.client)
    }
    app.inputKeys("jfs")
    sendShiftFlags(.shift)
    sendShiftFlags([])
    app.inputKeys("hea")
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "안녕 ")
  }

  func testShiftKeyDownCanFinishASentenceInsideTheMarkedWord() {
    let app = app()
    app.inputKeys("kgo4")
    for flags: NSEvent.ModifierFlags in [.shift, []] {
      let event = NSEvent.keyEvent(
        with: .flagsChanged, location: .zero, modifierFlags: flags, timestamp: 0,
        windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
        isARepeat: false, keyCode: UInt16(KeyCode.shift.rawValue))!
      _ = app.controller.handle(event, client: app.client)
      if flags == .shift { app.inputKey(.ansiB, modifiers: .shift) }
    }
    XCTAssertEqual(app.client.markedString(), "kgo4B")
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "그쵸? ")
  }

  func testOnlyTheTypedWordRangeIsReplacedAfterUnicodeText() {
    let app = app()
    app.client.string = "🙂 앞 문장 "
    app.client.setSelectedRange(
      NSRange(location: (app.client.string as NSString).length, length: 0))
    app.inputKeys("jfshea")
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "🙂 앞 문장 안녕 ")
  }

  func testOrdinaryEnglishAndIncompleteJamoRemainRoman() {
    let app = app()
    for word in ["hello", "world", "swift", "apple", "yes", "if", "or", "it", "he", "me"] {
      app.inputKeys(word)
      app.inputText(" ", key: .space)
    }
    XCTAssertEqual(app.client.string, "hello world swift apple yes if or it he me ")
  }

  func testSentencePunctuationDoesNotBypassTheEnglishWordProtection() {
    for word in ["yes.", "yes,", "\"yes\"", "hello!", "yes,yes", "yes.yes"] {
      let app = app()
      app.inputKeys(word)
      app.inputText(" ", key: .space)
      XCTAssertEqual(app.client.string, word + " ")
      XCTAssertTrue(app.controller.receiver.composer.inputMode.hasSuffix("system"))
    }
  }

  func testRepeatedKnownEnglishWordsRemainRoman() {
    for word in ["appleapple", "paseopaseo", "compactcompact"] {
      let app = app()
      app.inputKeys(word)
      app.inputText(" ", key: .space)
      XCTAssertEqual(app.client.string, word + " ")
      XCTAssertTrue(app.controller.receiver.composer.inputMode.hasSuffix("system"))
    }
  }

  func testKnownEnglishCommitsMarkedTextExactlyOnceWithCaretAtTheEnd() {
    let app = app()
    app.inputKeys("apple")
    let marked = app.client.markedRange()
    XCTAssertEqual(app.client.markedString(), "apple")
    app.client.setSelectedRange(NSRange(location: NSMaxRange(marked), length: 0))
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "apple ")
  }

  func testBufferedRomanReplacementRangeSurvivesVanishedMarkedRange() {
    XCTAssertEqual(
      InputReceiver.bufferedRomanReplacementRange(
        markedRange: NSRange(location: 7, length: 5),
        bufferedStartLocation: 2, selectionRange: NSRange(location: 12, length: 0),
        composedUTF16Length: 5),
      NSRange(location: 7, length: 5))
    XCTAssertEqual(
      InputReceiver.bufferedRomanReplacementRange(
        markedRange: NSRange(location: NSNotFound, length: NSNotFound),
        bufferedStartLocation: 7, selectionRange: NSRange(location: 0, length: 0),
        composedUTF16Length: 5),
      NSRange(location: 7, length: 5))
    XCTAssertEqual(
      InputReceiver.bufferedRomanReplacementRange(
        markedRange: NSRange(location: NSNotFound, length: NSNotFound),
        bufferedStartLocation: nil, selectionRange: NSRange(location: 12, length: 0),
        composedUTF16Length: 5),
      NSRange(location: 7, length: 5))
    XCTAssertNil(
      InputReceiver.bufferedRomanReplacementRange(
        markedRange: NSRange(location: NSNotFound, length: NSNotFound),
        bufferedStartLocation: nil, selectionRange: NSRange(location: 3, length: 0),
        composedUTF16Length: 5))
  }

  func testSlashCommandsBypassTheMarkedWordBuffer() {
    let app = app()
    app.inputKeys("/compact/compact")
    XCTAssertEqual(app.client.string, "/compact/compact")
    XCTAssertEqual(app.client.markedString(), "")
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "/compact/compact ")
  }

  func testFeatureIsOffWithoutAnAllowedApplication() {
    let app = app(enabled: false)
    XCTAssertTrue(Configuration.shared.hangulLayoutAutocorrectionApplications.isEmpty)
    XCTAssertFalse(Configuration.shared.hangulLayoutAutocorrectionAllApplications)
    app.inputKeys("jfshea")
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "jfshea ")
  }

  func testUnavailableProductAndSecureInputKeepTheOriginalWord() {
    let unavailable = app()
    unavailable.controller.receiver.romanAutocorrectionAvailable = { false }
    unavailable.inputKeys("jfshea")
    unavailable.inputText(" ", key: .space)
    XCTAssertEqual(unavailable.client.string, "jfshea ")

    let secure = app(secure: true)
    secure.inputKeys("jfshea")
    secure.inputText(" ", key: .space)
    XCTAssertEqual(secure.client.string, "jfshea ")
  }

  func testSecureInputActivatedAtTheBoundaryDiscardsThePendingWord() {
    let app = app()
    app.inputKeys("jfshea")
    app.controller.receiver.romanAutocorrectionSecureInput = { true }
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "jfshea ")
  }

  func testNoncomposingPrefixesAndPunctuationPreventSuffixConversion() {
    let app = app()
    for word in ["1jfshea", "Jjfshea", "/jfshea", "jfshea.com"] {
      app.inputKeys(word)
      app.inputText(" ", key: .space)
    }
    XCTAssertEqual(app.client.string, "1jfshea Jjfshea /jfshea jfshea.com ")
  }

  func testExternalEditsAndMouseBoundariesCommitTheOriginalMarkedWord() {
    let app = app()
    app.inputKeys("jfshea")
    app.controller.commitComposition(app.client)
    app.client.string = "abcdef"
    app.client.setSelectedRange(NSRange(location: 6, length: 0))
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "abcdef ")

    let moved = self.app()
    moved.inputKeys("jfshea")
    var tracking: ObjCBool = false
    _ = moved.controller.mouseDown(
      onCharacterIndex: 3, coordinate: .zero, withModifier: 0,
      continueTracking: &tracking, client: moved.client)
    moved.client.setSelectedRange(NSRange(location: 3, length: 0))
    moved.inputText(" ", key: .space)
    // Native mouse/external commit callbacks end marked composition before moving the caret.
    XCTAssertEqual(moved.client.string, "jfshea ")
  }

  func testSelectionAndMarkedTextAreNeverAutocorrected() {
    let app = app()
    app.client.string = "replace"
    app.client.setSelectedRange(NSRange(location: 0, length: 6))
    app.inputKeys("jfshea")
    app.inputText(" ", key: .space)
    XCTAssertFalse(app.client.string.contains("안녕"))

    let marked = self.app()
    marked.client.setMarkedText(
      "existing", selectedRange: NSRange(location: 8, length: 0),
      replacementRange: NSRange(location: 0, length: 0))
    marked.inputKeys("jfshea")
    marked.inputText(" ", key: .space)
    XCTAssertFalse(marked.client.string.contains("안녕"))
  }

  func testBackspaceEditsTheMarkedWordAndExternalCommitsKeepTheOriginal() {
    let app = app()
    app.inputKeys("jfsheax")
    app.inputDelete()
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "안녕 ")

    let committed = self.app()
    committed.inputKeys("jfshea")
    committed.controller.commitComposition(committed.client)
    committed.inputText(" ", key: .space)
    XCTAssertEqual(committed.client.string, "jfshea ")

    let switched = self.app()
    switched.inputKeys("jfshea")
    switched.controller.setValue(
      GureumInputSource.qwerty.rawValue, forTag: kTextServiceInputModePropertyTag,
      client: switched.client)
    switched.inputText(" ", key: .space)
    XCTAssertEqual(switched.client.string, "jfshea ")
  }

  func testLayoutShortcutTakesPrecedenceOverTheWordBoundary() {
    let app = app()
    Configuration.shared.inputModeExchangeKey = (.space, [])
    app.inputKeys("jfshea")

    app.inputText(" ", key: .space)

    XCTAssertEqual(app.client.string, "jfshea")
    XCTAssertTrue(app.controller.receiver.composer.inputMode.hasSuffix("han3final"))
  }

  func testSystemInputModeChangeFromHangulAllowsTheFirstRomanWordToConvert() {
    let app = app()
    app.controller.setValue(
      GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
      client: app.client)
    app.inputKeys("jfs")
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "안 ")

    app.controller.setValue(
      GureumInputSource.system.rawValue, forTag: kTextServiceInputModePropertyTag,
      client: app.client)
    app.inputKeys("jfshea")
    XCTAssertEqual(app.client.markedString(), "jfshea")
    app.inputText(" ", key: .space)

    XCTAssertEqual(app.client.string, "안 안녕 ")
    XCTAssertTrue(app.controller.receiver.composer.inputMode.hasSuffix("han3final"))
  }

  func testPhysicalKeysAreDistinctFromDvorakAndColemakOutput() {
    for source in [GureumInputSource.qwerty, .dvorak, .colemak] {
      let app = app(romanSource: source)
      app.inputKeys("jfshea")
      let original = app.client.string
      if source != .qwerty { XCTAssertNotEqual(original, "jfshea") }
      app.inputText(" ", key: .space)
      XCTAssertEqual(app.client.string, "안녕 ", "\(source) original=\(original)")
    }
  }

  func testTerminalAndCredentialAppsCannotBeAllowedAccidentally() {
    Configuration.shared.hangulLayoutAutocorrectionAllApplications = true
    for identifier in ["com.apple.Terminal", "com.googlecode.iterm2", "com.apple.keychainaccess"] {
      Configuration.shared.hangulLayoutAutocorrectionApplications = [identifier: "Excluded app"]
      XCTAssertFalse(Configuration.shared.usesHangulLayoutAutocorrection(for: identifier))
    }
    XCTAssertFalse(Configuration.shared.usesHangulLayoutAutocorrection(for: nil))
  }

  func testAllApplicationsAndMultipleSelectedApplicationsAreSupported() {
    Configuration.shared.hangulLayoutAutocorrectionApplications = [
      "com.example.One": "One", "com.example.Two": "Two",
    ]
    XCTAssertTrue(Configuration.shared.usesHangulLayoutAutocorrection(for: "com.example.One"))
    XCTAssertTrue(Configuration.shared.usesHangulLayoutAutocorrection(for: "com.example.Two"))
    XCTAssertFalse(Configuration.shared.usesHangulLayoutAutocorrection(for: "com.example.Three"))

    Configuration.shared.hangulLayoutAutocorrectionAllApplications = true
    XCTAssertTrue(Configuration.shared.usesHangulLayoutAutocorrection(for: "com.example.Three"))
    XCTAssertFalse(Configuration.shared.usesHangulLayoutAutocorrection(for: nil))
  }

  func testClientBundleIdentifierFallsBackToTheFrontmostApplicationSafely() {
    XCTAssertEqual(
      InputReceiver.autocorrectionBundleIdentifier(
        client: nil, frontmostApplication: "sh.paseo.desktop"),
      "sh.paseo.desktop")
    XCTAssertEqual(
      InputReceiver.autocorrectionBundleIdentifier(
        client: "com.1password.1password", frontmostApplication: "sh.paseo.desktop"),
      "com.1password.1password")
    XCTAssertNil(
      InputReceiver.autocorrectionBundleIdentifier(client: nil, frontmostApplication: nil))
  }

  func testBufferedRomanWordIsMarkedUntilTheBoundary() {
    let app = app()
    app.inputKeys("jfshea")
    XCTAssertEqual(app.client.markedString(), "jfshea")
    XCTAssertEqual(app.controller.receiver.composer.commitString, "")
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "안녕 ")
    XCTAssertEqual(app.client.markedString(), "")
  }

  func testMarkedWordSurvivesUnavailableDocumentReadsAndReportedRangeChurn() {
    let app = app(client: UnreadableRomanInputClient())
    app.inputKeys("jvhgw")
    XCTAssertEqual(app.client.markedString(), "jvhgw")
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "오늘 ")
  }

  func testMarkedWordsCommitOnceWhenTheClientDefersTheComposition() {
    let cases: [(startsInHangul: Bool, keys: String, expected: String)] = [
      (false, "apple", "apple "),
      (false, "jvhgw", "오늘 "),
      (true, "apple", "apple "),
    ]
    for (startsInHangul, keys, expected) in cases {
      let app = app(client: DeferredCompositionInputClient())
      if startsInHangul {
        app.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
      }
      typeWord(app, keys)
      XCTAssertEqual(app.client.string, expected, keys)
    }
    // Ordinary Hangul commits once in Chromium, so the model must agree.
    let plain = app(enabled: false, client: DeferredCompositionInputClient())
    plain.controller.receiver.composer.inputMode = GureumInputSource.han3Final.rawValue
    typeWord(plain, "jfs")
    XCTAssertEqual(plain.client.string, "안 ")
  }

  func testChangingClientsCommitsTheOriginalWordOnlyToItsOwner() {
    let app = app()
    app.inputKeys("jfshea")
    let otherClient = MockInputClient()
    let result = app.controller.receiver.input(
      text: "x", key: .ansiX, modifiers: [], client: otherClient)
    if !result.processed {
      otherClient.insertText("x", replacementRange: NSRange(location: NSNotFound, length: 0))
    }
    XCTAssertEqual(app.client.string, "jfshea")
    XCTAssertEqual(otherClient.string, "x")
    XCTAssertFalse(app.controller.receiver.composer.romanComposer.hasBufferedWord)
  }

  func testWordLengthLimitCommitsOriginalWithoutDroppingOrConvertingASuffix() {
    let app = app()
    let longWord = String(repeating: "x", count: 65) + "jfshea"
    app.inputKeys(longWord)
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, longWord + " ")
  }

  func testRealWorldKeySequencesCommitAsOneWord() {
    for (keys, expected) in [
      ("j/r", "왜"), ("jfs", "안"), ("jfsheamfncj4", "안녕하세요"),
      ("jdktq;/f", "이것봐"), ("kgo4B", "그쵸?"), ("jvhgw", "오늘"),
      ("jdlchgs", "이제는"),
    ] {
      let app = app()
      app.inputKeys(keys)
      XCTAssertEqual(app.client.markedString(), keys)
      XCTAssertEqual(app.controller.receiver.composer.commitString, "")
      app.inputText(" ", key: .space)
      XCTAssertEqual(app.client.string, expected + " ", keys)
      XCTAssertEqual(app.client.markedString(), "")
      XCTAssertTrue(app.controller.receiver.composer.inputMode.hasSuffix("han3final"))
    }
  }

  func testModifierKeyAndExplicitBoundaryResetDiscardThePendingWord() {
    for modifier in [NSEvent.ModifierFlags.command, .control, .option, .capsLock] {
      let app = app()
      app.inputKeys("jfshea")
      app.inputKey(.ansiX, modifiers: modifier)
      app.inputText(" ", key: .space)
      XCTAssertFalse(app.client.string.contains("안녕"), "\(modifier)")
    }

    let app = app()
    app.inputKeys("jfshea")
    app.controller.receiver.resetRomanAutocorrection()
    app.inputText(" ", key: .space)
    XCTAssertEqual(app.client.string, "jfshea ")
  }
}

class PreferencesFormTests: IsolatedChordConfigurationTests {
  private func form(identity: InputMethodIdentity? = nil) throws -> (
    NSWindow, PreferenceViewController
  ) {
    let controller: NSWindowController
    if let identity {
      let host = PreferencePaneViewController()
      host.productIdentity = identity
      let window = NSWindow(contentViewController: host)
      controller = ConfiguraionWindowController(window: window)
      controller.windowDidLoad()
    } else {
      let storyboard = NSStoryboard(name: "Configuration", bundle: .main)
      controller = try XCTUnwrap(storyboard.instantiateInitialController() as? NSWindowController)
    }
    let window = try XCTUnwrap(controller.window)
    let host = try XCTUnwrap(window.contentViewController)
    _ = host.view
    let child = try XCTUnwrap(host.children.first as? PreferenceViewController)
    host.view.layoutSubtreeIfNeeded()
    child.viewDidAppear()
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
    addTeardownBlock {
      window.close()
      _ = controller
    }
    return (window, child)
  }

  private func identity(_ product: InputMethodProductKind) throws -> InputMethodIdentity {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString).appendingPathExtension("bundle")
    let contents = directory.appendingPathComponent("Contents", isDirectory: true)
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    addTeardownBlock { try FileManager.default.removeItem(at: directory) }
    let data = try PropertyListSerialization.data(
      fromPropertyList: ["GureumProductKind": product.rawValue], format: .xml, options: 0)
    try data.write(to: contents.appendingPathComponent("Info.plist"))
    return InputMethodIdentity(bundle: try XCTUnwrap(Bundle(url: directory)))
  }

  private func descendants(_ view: NSView) -> [NSView] {
    [view] + view.subviews.flatMap { descendants($0) }
  }

  private func select(_ index: Int, in controller: PreferenceViewController) {
    controller.selectSettingsSection(at: index)
  }

  func testHostUsesCompactFixedWidthAndRetainsThePreferenceController() throws {
    let (window, child) = try form()

    XCTAssertEqual(window.contentLayoutRect.width, 500)
    XCTAssertEqual(
      window.contentLayoutRect.height, child.preferredContentHeight(for: 0), accuracy: 0.5)
    XCTAssertEqual(window.contentMinSize, NSSize(width: 500, height: 300))
    XCTAssertEqual(window.contentMaxSize, NSSize(width: 500, height: 680))
    XCTAssertTrue(window.autorecalculatesKeyViewLoop)
    XCTAssertNotNil(child.parent)
    let toolbar = try XCTUnwrap(window.toolbar)
    XCTAssertEqual(toolbar.displayMode, .iconAndLabel)
    XCTAssertEqual(toolbar.sizeMode, .regular)
    let navigation = try XCTUnwrap(toolbar.items.first as? NSToolbarItemGroup)
    XCTAssertEqual(navigation.subitems.map(\.label), child.settingsSectionTitles)
    XCTAssertEqual(navigation.selectedIndex, 0)
  }

  func testOpeningSettingsDoesNotFocusAnEditableField() throws {
    let (window, child) = try form()
    child.viewDidAppear()
    XCTAssertFalse(window.firstResponder is NSTextView)
  }

  func testAdvancedPageFitsWithoutReachingTheScrollHeightCap() throws {
    let (_, child) = try form()
    XCTAssertLessThan(child.preferredContentHeight(for: 2), 680)
    let pageHeights = (0..<3).map(child.preferredContentHeight(for:))
    XCTAssertEqual(child.preferredWindowContentHeight(), pageHeights.max())
  }

  func testBaramAutocorrectionOffersAllAppsAndMultipleAppSelection() throws {
    let (_, child) = try form(identity: identity(.baram))
    select(2, in: child)
    let views = descendants(child.view).filter { !$0.isHiddenOrHasHiddenAncestor }
    let menu = try XCTUnwrap(
      views.compactMap { $0 as? NSPopUpButton }.first {
        $0.accessibilityLabel() == "실험 · 자동 한영 전환"
      })
    XCTAssertEqual(menu.controlSize, .small)
    XCTAssertFalse(menu.isBordered)
    XCTAssertTrue(menu.itemArray.contains { ($0.representedObject as? String) == "all" })
    XCTAssertTrue(menu.itemArray.contains { ($0.representedObject as? String) == "choose" })
    XCTAssertTrue(
      views.compactMap { $0 as? NSTextField }.contains {
        $0.stringValue.contains("dkssud 또는 jfshea → 안녕")
          && $0.stringValue.contains("모든 앱 또는 선택한 앱")
      })
  }

  func testGroupsUsePrimaryBoxesAndMiniSwitches() throws {
    let (_, child) = try form()
    let views = descendants(child.view)
    let boxes = views.compactMap { $0 as? NSBox }.filter { $0.boxType != .separator }
    let switches = views.compactMap { $0 as? NSSwitch }

    XCTAssertFalse(boxes.isEmpty)
    XCTAssertFalse(switches.isEmpty)
    XCTAssertTrue(boxes.allSatisfy { $0.boxType == .primary })
    XCTAssertTrue(switches.allSatisfy { $0.controlSize == .mini })
  }

  func testRowsAreVerticallyCenteredWithMinimumHeightAndInsetSeparators() throws {
    let (_, child) = try form()
    let views = descendants(child.view)
    let rows = views.filter { view in
      view.constraints.contains {
        ($0.firstItem as? NSView) === view && $0.firstAttribute == .height
          && $0.relation == .greaterThanOrEqual && $0.constant == 34
      }
    }
    XCTAssertFalse(rows.isEmpty)
    for row in rows {
      XCTAssertEqual(row.constraints.filter { $0.firstAttribute == .centerY }.count, 2)
    }
    let separators = views.compactMap { $0 as? NSBox }.filter { $0.boxType == .separator }
    XCTAssertFalse(separators.isEmpty)
    for separator in separators {
      let inset = try XCTUnwrap(separator.superview)
      XCTAssertTrue(inset.constraints.contains { $0.firstAttribute == .height && $0.constant == 1 })
      XCTAssertTrue(
        inset.constraints.contains { $0.firstAttribute == .leading && $0.constant == 10 })
      XCTAssertTrue(
        inset.constraints.contains { $0.firstAttribute == .trailing && $0.constant == -10 })
    }
  }

  func testNavigationAndPopupsUseCompactNativeControlSizes() throws {
    for product in [InputMethodProductKind.upstream, .lab, .baram] {
      try assertNavigationAndPopups(identity: identity(product))
    }
  }

  private func assertNavigationAndPopups(identity: InputMethodIdentity) throws {
    let (window, child) = try form(identity: identity)
    let views = descendants(child.view)
    XCTAssertTrue(views.compactMap { $0 as? NSSegmentedControl }.isEmpty)
    let navigation = try XCTUnwrap(window.toolbar?.items.first as? NSToolbarItemGroup)
    XCTAssertEqual(navigation.subitems.count, 3)
    let popups = views.compactMap { $0 as? NSPopUpButton }
    XCTAssertEqual(popups.count, identity.isBaram ? 5 : 4)
    XCTAssertTrue(popups.allSatisfy { $0.controlSize == .small })
    XCTAssertTrue(popups.allSatisfy { $0 is SystemSettingsPopUpButton })
    let option = try XCTUnwrap(popups.first { $0.accessibilityLabel() == "Option 키 동작" })
    XCTAssertFalse(option.pullsDown)
    XCTAssertFalse(option.isBordered)
    for popup in popups {
      XCTAssertTrue(popup.cell is SystemSettingsPopUpButtonCell)
      XCTAssertEqual((popup.cell as? NSPopUpButtonCell)?.arrowPosition, .noArrow)
      XCTAssertGreaterThanOrEqual(popup.intrinsicContentSize.height, 20)
      XCTAssertGreaterThanOrEqual(popup.intrinsicContentSize.width, 44)
      let nativeTitleRect = try XCTUnwrap(
        popup.cell?.titleRect(
          forBounds: NSRect(
            origin: .zero, size: popup.intrinsicContentSize)))
      XCTAssertGreaterThanOrEqual(nativeTitleRect.width - 24, popup.attributedTitle.size().width)
      XCTAssertFalse(
        popup.constraints.contains {
          ($0.firstItem as? NSView) === popup
            && ObjectIdentifier(type(of: $0)) == ObjectIdentifier(NSLayoutConstraint.self)
            && $0.firstAttribute == .height && $0.relation == .equal
        }, "\(popup.constraints)")
      XCTAssertTrue(
        popup.constraints.contains {
          $0.firstAttribute == .width && $0.relation == .lessThanOrEqual && $0.constant == 220
        })
    }
    let characterFields = views.compactMap { $0 as? NSTextField }.filter(\.isEditable)
    XCTAssertEqual(
      Set(characterFields.compactMap { $0.accessibilityLabel() }),
      ["` 키 문자", "Shift+` 키 문자"])
    XCTAssertTrue(characterFields.allSatisfy { $0.controlSize == .small })
    XCTAssertTrue(characterFields.allSatisfy { $0.placeholderString == "기본" })
    XCTAssertTrue(
      characterFields.allSatisfy { field in
        field.constraints.contains {
          $0.firstAttribute == .width && $0.relation == .equal && $0.constant == 72
        }
      })
  }

  func testKeyboardPreviewUsesTheBundledThreeSetFinalMapping() {
    let preview = KeyboardPreviewView(layoutIdentifier: "3f", layoutName: "세벌식 최종")

    XCTAssertEqual(preview.labels["k"], "ㄱ")
    XCTAssertEqual(preview.labels["f"], "ㅏ")
    XCTAssertEqual(preview.labels["v"], "ㅗ")
    XCTAssertTrue(preview.isAvailable)
    XCTAssertEqual(preview.intrinsicContentSize, NSSize(width: 432, height: 120))
    XCTAssertEqual(preview.accessibilityLabel(), "세벌식 최종 키보드 미리보기")
  }

  func testKeyboardPreviewNormalizesVirtualJamoAndReportsUnavailableLayouts() {
    let strict = KeyboardPreviewView(layoutIdentifier: "3fs", layoutName: "세벌식 최종 정석")
    XCTAssertTrue(strict.isAvailable)
    XCTAssertEqual(strict.labels["/"], "ㅗ")
    XCTAssertEqual(strict.labels["9"], "ㅜ")

    let missing = KeyboardPreviewView(layoutIdentifier: "missing", layoutName: "알 수 없는 자판")
    XCTAssertFalse(missing.isAvailable)
    XCTAssertTrue(missing.labels.isEmpty)
    XCTAssertEqual(missing.accessibilityValue() as? String, "알 수 없는 자판 미리보기를 불러올 수 없음")
  }

  func testKeyboardPreviewCanReloadAfterTheInputSourceChanges() {
    let preview = KeyboardPreviewView(layoutIdentifier: "2-full", layoutName: "두벌식")
    XCTAssertEqual(preview.labels["r"], "ㄱ")

    preview.reload(layoutIdentifier: "3f", layoutName: "세벌식 최종")

    XCTAssertEqual(preview.layoutName, "세벌식 최종")
    XCTAssertEqual(preview.labels["k"], "ㄱ")
    XCTAssertEqual(preview.accessibilityLabel(), "세벌식 최종 키보드 미리보기")
  }

  private func previewEvent(
    _ type: NSEvent.EventType, keyCode: UInt16, modifiers: NSEvent.ModifierFlags = []
  ) -> NSEvent {
    NSEvent.keyEvent(
      with: type, location: .zero, modifierFlags: modifiers, timestamp: 0,
      windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
      isARepeat: false, keyCode: keyCode)!
  }

  func testKeyboardPreviewShiftUsesTheActualShiftedLayoutAndPreservesEvents() {
    let preview = KeyboardPreviewView(layoutIdentifier: "3f", layoutName: "세벌식 최종")
    XCTAssertEqual(preview.visibleLabel(for: "k"), "ㄱ")
    XCTAssertEqual(preview.visibleLabel(for: "1"), "ㅎ")
    let shift = previewEvent(.flagsChanged, keyCode: 56, modifiers: .shift)

    XCTAssertTrue(preview.observeKeyboardEvent(shift) === shift)

    XCTAssertTrue(preview.isShiftPressed)
    XCTAssertEqual(preview.visibleLabel(for: "k"), "2")
    XCTAssertEqual(preview.visibleLabel(for: "1"), "ㄲ")
    XCTAssertTrue((preview.accessibilityValue() as? String)?.contains("Shift 누름") == true)
    preview.observeKeyboardEvent(previewEvent(.flagsChanged, keyCode: 56))
    XCTAssertFalse(preview.isShiftPressed)
    XCTAssertEqual(preview.visibleLabel(for: "k"), "ㄱ")
    XCTAssertFalse(preview.acceptsFirstResponder)
  }

  func testKeyboardPreviewHighlightsPhysicalKeysAndReleasesAfterKeyUp() {
    let preview = KeyboardPreviewView(layoutIdentifier: "3f", layoutName: "세벌식 최종")
    let down = previewEvent(.keyDown, keyCode: 40)
    XCTAssertTrue(preview.observeKeyboardEvent(down) === down)
    XCTAssertEqual(preview.pressedKeys, ["k"])
    XCTAssertTrue((preview.accessibilityValue() as? String)?.contains("ㄱ 키 누름") == true)

    let up = previewEvent(.keyUp, keyCode: 40)
    XCTAssertTrue(preview.observeKeyboardEvent(up) === up)
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
    XCTAssertTrue(preview.pressedKeys.isEmpty)
  }

  func testKeyboardPreviewDetachingAndWindowResigningClearHeldKeys() {
    let preview = KeyboardPreviewView(layoutIdentifier: "3f", layoutName: "세벌식 최종")
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 500, height: 150),
      styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView?.addSubview(preview)
    preview.observeKeyboardEvent(previewEvent(.keyDown, keyCode: 40, modifiers: .shift))

    NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: window)
    XCTAssertTrue(preview.pressedKeys.isEmpty)
    XCTAssertFalse(preview.isShiftPressed)

    preview.observeKeyboardEvent(previewEvent(.keyDown, keyCode: 40))
    preview.removeFromSuperview()
    XCTAssertTrue(preview.pressedKeys.isEmpty)
    window.close()
  }

  func testKeyboardPreviewReceivesInputMethodEventsWhileAnotherAppHasFocus() {
    let preview = KeyboardPreviewView(layoutIdentifier: "3f", layoutName: "세벌식 최종")
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 500, height: 150),
      styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView?.addSubview(preview)
    window.orderFront(nil)
    defer { window.close() }
    let app = ModerateApp()

    _ = app.controller.handle(previewEvent(.keyDown, keyCode: 40), client: app.client)
    XCTAssertEqual(preview.pressedKeys, ["k"])
    _ = app.controller.handle(
      previewEvent(.flagsChanged, keyCode: 56, modifiers: .shift), client: app.client)
    XCTAssertTrue(preview.isShiftPressed)
    XCTAssertEqual(preview.visibleLabel(for: "k"), "2")
    XCTAssertFalse(app.controller.handle(previewEvent(.keyUp, keyCode: 40), client: app.client))
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
    XCTAssertTrue(preview.pressedKeys.isEmpty)

    preview.isHidden = true
    _ = app.controller.handle(previewEvent(.keyDown, keyCode: 40), client: app.client)
    XCTAssertTrue(preview.pressedKeys.isEmpty)
    XCTAssertFalse(preview.isShiftPressed)
    preview.isHidden = false
    window.orderOut(nil)
    _ = app.controller.handle(previewEvent(.keyDown, keyCode: 40), client: app.client)
    XCTAssertTrue(preview.pressedKeys.isEmpty)
  }

  func testKeyboardPreviewKeepsObservingWhenTheSameSettingsWindowReopens() {
    let preview = KeyboardPreviewView(layoutIdentifier: "3f", layoutName: "세벌식 최종")
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 500, height: 150),
      styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView?.addSubview(preview)
    defer { window.close() }
    let app = ModerateApp()

    for _ in 0..<3 {
      window.orderFront(nil)
      _ = app.controller.handle(
        previewEvent(.keyDown, keyCode: 40, modifiers: .shift), client: app.client)
      XCTAssertEqual(preview.pressedKeys, ["k"])
      XCTAssertTrue(preview.isShiftPressed)

      window.close()
      XCTAssertTrue(preview.pressedKeys.isEmpty)
      XCTAssertFalse(preview.isShiftPressed)
      XCTAssertTrue(preview.window === window)
    }
  }

  func testEveryPageKeyLoopContainsOnlyItsVisibleControlsInReadingOrder() throws {
    for product in [InputMethodProductKind.upstream, .lab, .baram] {
      try assertPageKeyLoops(identity: identity(product))
    }
  }

  private func assertPageKeyLoops(identity: InputMethodIdentity) throws {
    let (window, child) = try form(identity: identity)
    var advanced = ["두벌식 종성 결합", "조합 상태 유지", "Esc로 로마자 전환"]
    if identity.isBaram { advanced.append("실험 · 자동 한영 전환") }
    if identity.supportsPhysicalChording {
      advanced.append(contentsOf: ["동시에 누른 키 묶기", "키 감지 권한 허용"])
    }
    if identity.supportsUpdates { advanced.append("업데이트 알림") }
    if identity.supportsExperimentalUpdates { advanced.append("실험 버전 알림") }
    let labels = [
      [
        "모아치기", "세벌식 정석 조합", "` 키 문자", "Shift+` 키 문자", "키보드 레이아웃",
        "Option 키 동작",
      ],
      ["한글 ↔ 로마자", "한자 및 이모지", "로마자로 전환", "한글로 전환", "오른쪽 전환 키", "키 감지 권한 열기", "키보드 열기"],
      advanced,
    ]
    for index in 0..<3 {
      select(index, in: child)
      child.viewDidAppear()
      let first = try XCTUnwrap(window.initialFirstResponder)
      var visited = [first]
      var next = first.nextKeyView
      while let control = next, control !== first, visited.count < 32 {
        XCTAssertFalse(control.isHiddenOrHasHiddenAncestor)
        visited.append(control)
        next = control.nextKeyView
      }
      XCTAssertTrue(next === first)
      let readingOrder = visited.compactMap { control -> String? in
        if control is MASShortcutView {
          return control.superview?.subviews.compactMap { $0 as? NSTextField }.first?.stringValue
        }
        return control.accessibilityLabel()
      }
      XCTAssertEqual(readingOrder, labels[index])
      XCTAssertEqual(Set(visited.map(ObjectIdentifier.init)).count, visited.count)
    }
  }

  func testSpecialCharacterFieldsSaveOneGraphemeAndRejectLongValues() throws {
    let configuration = Configuration()
    let backQuoteKey = ConfigurationName.hangulBackQuoteOutputCharacter
    let shiftBackQuoteKey = ConfigurationName.hangulShiftBackQuoteOutputCharacter
    let originalBackQuote = configuration.object(forKey: backQuoteKey)
    let originalShiftBackQuote = configuration.object(forKey: shiftBackQuoteKey)
    addTeardownBlock {
      if let originalBackQuote {
        configuration.set(originalBackQuote, forKey: backQuoteKey)
      } else {
        configuration.removeObject(forKey: backQuoteKey)
      }
      if let originalShiftBackQuote {
        configuration.set(originalShiftBackQuote, forKey: shiftBackQuoteKey)
      } else {
        configuration.removeObject(forKey: shiftBackQuoteKey)
      }
    }
    configuration.removeObject(forKey: backQuoteKey)
    configuration.removeObject(forKey: shiftBackQuoteKey)
    let (_, child) = try form()
    let fields = descendants(child.view).compactMap { $0 as? NSTextField }.filter(\.isEditable)
    let backQuote = try XCTUnwrap(fields.first { $0.accessibilityLabel() == "` 키 문자" })
    let shift = try XCTUnwrap(fields.first { $0.accessibilityLabel() == "Shift+` 키 문자" })

    child.controlTextDidEndEditing(
      Notification(name: NSControl.textDidEndEditingNotification, object: backQuote))
    XCTAssertNil(configuration.object(forKey: backQuoteKey))

    shift.stringValue = "@"
    child.controlTextDidChange(
      Notification(name: NSControl.textDidChangeNotification, object: shift))
    XCTAssertEqual(configuration.hangulShiftBackQuoteOutputCharacter, "@")
    XCTAssertEqual(shift.textColor, .labelColor)

    shift.stringValue = "@@"
    child.controlTextDidChange(
      Notification(name: NSControl.textDidChangeNotification, object: shift))
    XCTAssertEqual(configuration.hangulShiftBackQuoteOutputCharacter, "@")
    XCTAssertEqual(shift.textColor, .systemRed)

    shift.stringValue = ""
    child.controlTextDidChange(
      Notification(name: NSControl.textDidChangeNotification, object: shift))
    XCTAssertEqual(configuration.hangulShiftBackQuoteOutputCharacter, "")
    XCTAssertEqual(shift.textColor, .labelColor)
  }

  func testPermissionAndSystemShortcutRowsAreVisibleWithoutDisclosures() throws {
    let (_, child) = try form()
    select(1, in: child)
    let views = descendants(child.view)
    let buttons = views.compactMap { $0 as? NSButton }
    XCTAssertFalse(buttons.contains { $0.bezelStyle == .disclosure })
    for label in ["키 감지 권한 열기", "키보드 열기"] {
      let button = try XCTUnwrap(buttons.first { $0.accessibilityLabel() == label })
      XCTAssertFalse(button.isHiddenOrHasHiddenAncestor)
      XCTAssertEqual(button.controlSize, .small)
      XCTAssertEqual(button.title, "열기…")
    }
    let labels = views.compactMap { $0 as? NSTextField }.filter { !$0.isHiddenOrHasHiddenAncestor }
      .map(\.stringValue)
    XCTAssertTrue(labels.contains("오른쪽 키 전환"))
    XCTAssertTrue(labels.contains("시스템 단축키"))
  }

  func testSequentialReorderingCopyDoesNotClaimPhysicalChordCapture() throws {
    let (_, child) = try form()
    let labels = descendants(child.view).compactMap { $0 as? NSTextField }.map(\.stringValue)

    XCTAssertTrue(
      labels.contains(
        "모아치기는 순서가 바뀐 낱자를 자동으로 조합합니다. 정석 조합은 세벌식 최종·390에서 이중모음과 겹받침을 해당 자판 규칙으로 제한합니다."))
    if !InputMethodIdentity.current.supportsPhysicalChording {
      XCTAssertFalse(labels.contains("실험 기능 · 물리적 동시입력"))
    }
  }

  func testInternalCrashVerificationIsNotShownInSettings() throws {
    let (_, child) = try form()
    select(2, in: child)
    let views = descendants(child.view).filter { !$0.isHiddenOrHasHiddenAncestor }
    XCTAssertFalse(
      views.compactMap { $0 as? NSTextField }.contains { $0.stringValue == "개발자" })
    XCTAssertFalse(views.compactMap { $0 as? NSButton }.contains { $0.title == "종료…" })
  }

  func testShortcutLocalizationIsLimitedToThePreferenceRecorderSubclass() throws {
    let (_, child) = try form()
    let recorder = try XCTUnwrap(
      descendants(child.view).compactMap { $0 as? MASShortcutView }.first)
    let localCell = try XCTUnwrap(type(of: recorder).shortcutCellClass() as? NSButtonCell.Type)
    XCTAssertNotEqual(
      ObjectIdentifier(localCell), ObjectIdentifier(MASShortcutView.shortcutCellClass()))
    XCTAssertEqual(localCell.init(textCell: "Record Shortcut").title, "단축키 입력")
    XCTAssertEqual(MASShortcutViewButtonCell(textCell: "Record Shortcut").title, "Record Shortcut")
  }
}

class GureumMenuTests: XCTestCase {
  private func capabilities(
    lab: Bool = false, productKind: String? = nil, displayName: String? = nil,
    bundleName: String? = "Fixture Input Method", baramUpdateFeedEnabled: Bool = false
  ) throws -> GureumMenuCapabilities {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString).appendingPathExtension("bundle")
    let contents = directory.appendingPathComponent("Contents", isDirectory: true)
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    addTeardownBlock { try FileManager.default.removeItem(at: directory) }
    var info: [String: Any] = ["GureumChordLab": lab]
    info["GureumProductKind"] = productKind
    info["CFBundleDisplayName"] = displayName
    info["CFBundleName"] = bundleName
    info["BaramUpdateFeedEnabled"] = baramUpdateFeedEnabled
    let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
    try data.write(to: contents.appendingPathComponent("Info.plist"))
    let bundle = try XCTUnwrap(Bundle(url: directory))
    return GureumMenuCapabilities.current(
      bundle: bundle, identity: InputMethodIdentity(bundle: bundle))
  }

  private func identifiers(_ menu: NSMenu) -> [String] {
    menu.items.map { $0.isSeparatorItem ? "separator" : ($0.identifier?.rawValue ?? "missing") }
  }

  private func item(_ menu: NSMenu, identifier: String) -> NSMenuItem? {
    menu.items.first { $0.identifier?.rawValue == identifier }
  }

  private func descendants(_ menu: NSMenu) -> [NSMenuItem] {
    menu.items.flatMap { item in
      [item] + (item.submenu.map { descendants($0) } ?? [])
    }
  }

  func testUpstreamCapabilitiesPreserveExistingDestinationsAndUpdates() throws {
    let capabilities = try capabilities()

    XCTAssertEqual(capabilities.websiteURL?.absoluteString, "http://gureum.io")
    XCTAssertEqual(capabilities.helpURL?.absoluteString, "http://dan.gureum.io")
    XCTAssertEqual(capabilities.issuesURL?.absoluteString, "http://meok.gureum.io")
    XCTAssertEqual(capabilities.sourceURL?.absoluteString, "http://ssi.gureum.io")
    XCTAssertEqual(capabilities.donationURL?.absoluteString, "http://donation.gureum.io")
    XCTAssertTrue(capabilities.supportsUpdates)
    XCTAssertTrue(capabilities.supportsExperimentalUpdates)
  }

  func testLabCapabilitiesExposeOnlyForkIssuesAndSource() throws {
    let capabilities = try capabilities(lab: true)

    XCTAssertNil(capabilities.websiteURL)
    XCTAssertNil(capabilities.helpURL)
    XCTAssertNil(capabilities.donationURL)
    XCTAssertEqual(
      capabilities.issuesURL?.absoluteString, "https://github.com/kathar0s/gureum/issues")
    XCTAssertEqual(capabilities.sourceURL?.absoluteString, "https://github.com/kathar0s/gureum")
    XCTAssertFalse(capabilities.supportsUpdates)
    XCTAssertFalse(capabilities.supportsExperimentalUpdates)
  }

  func testBaramCapabilitiesUseForkServicesAndBundleDisplayName() throws {
    let capabilities = try capabilities(
      productKind: "baram", displayName: "바람 입력기", bundleName: "Baram")

    XCTAssertEqual(capabilities.displayName, "바람 입력기")
    XCTAssertEqual(capabilities.websiteURL?.absoluteString, "https://baram.sionyuel.com")
    XCTAssertNil(capabilities.helpURL)
    XCTAssertNil(capabilities.donationURL)
    XCTAssertEqual(
      capabilities.issuesURL?.absoluteString, "https://github.com/sionyuel/baram/issues")
    XCTAssertEqual(capabilities.sourceURL?.absoluteString, "https://github.com/sionyuel/baram")
    XCTAssertFalse(capabilities.supportsUpdates)
    XCTAssertFalse(capabilities.supportsExperimentalUpdates)
  }

  func testBaramMenuOffersStableUpdatesWithoutDeveloperChannel() throws {
    let menu = GureumMenuBuilder(
      capabilities: try capabilities(
        productKind: "baram", displayName: "바람 입력기", bundleName: "Baram",
        baramUpdateFeedEnabled: true),
      includeDeveloperTools: true
    ).makeMenu()

    XCTAssertEqual(
      identifiers(menu), ["preferences", "update", "separator", "support", "separator", "about"])
    let allIDs = descendants(menu).compactMap { $0.identifier?.rawValue }
    XCTAssertFalse(allIDs.contains("developer"))
    XCTAssertFalse(allIDs.contains("experimental-update"))
  }

  func testUpstreamMenuHasCompactTopLevelOrderAndGroupedSupportItems() throws {
    let menu = GureumMenuBuilder(capabilities: try capabilities(), includeDeveloperTools: false)
      .makeMenu()

    XCTAssertEqual(
      identifiers(menu), ["preferences", "update", "separator", "support", "separator", "about"])
    let support = try XCTUnwrap(
      item(menu, identifier: "support")?.submenu)
    XCTAssertEqual(identifiers(support), ["website", "help", "issues", "source", "donation"])
  }

  func testLabMenuHidesUpstreamOnlyServicesAndUpdates() throws {
    let menu = GureumMenuBuilder(
      capabilities: try capabilities(lab: true), includeDeveloperTools: true
    )
    .makeMenu()

    XCTAssertEqual(
      identifiers(menu), ["preferences", "separator", "support", "separator", "about"])
    let support = try XCTUnwrap(
      item(menu, identifier: "support")?.submenu)
    XCTAssertEqual(identifiers(support), ["issues", "source"])
    let allIDs = descendants(menu).compactMap { $0.identifier?.rawValue }
    XCTAssertTrue(
      Set(allIDs).isDisjoint(with: [
        "website", "help", "donation", "update", "developer", "experimental-update",
      ]))
  }

  func testDeveloperAndExperimentalUpdateAppearOnlyWhenRequestedForUpstream() throws {
    let capabilities = try capabilities()
    let publicMenu = GureumMenuBuilder(capabilities: capabilities, includeDeveloperTools: false)
      .makeMenu()
    let developerMenu = GureumMenuBuilder(capabilities: capabilities, includeDeveloperTools: true)
      .makeMenu()

    XCTAssertFalse(descendants(publicMenu).contains { $0.identifier?.rawValue == "developer" })
    let support = try XCTUnwrap(
      item(developerMenu, identifier: "support")?.submenu)
    XCTAssertEqual(
      identifiers(support),
      ["website", "help", "issues", "source", "donation", "separator", "developer"])
    let developer = try XCTUnwrap(
      item(support, identifier: "developer")?.submenu)
    XCTAssertEqual(identifiers(developer), ["experimental-update"])
  }

  func testMenuActionsUseFirstResponderTargetsAndExpectedSelectors() throws {
    let menu = GureumMenuBuilder(capabilities: try capabilities(), includeDeveloperTools: true)
      .makeMenu()
    let expected: [String: String] = [
      "preferences": "showPreferencesWindow:", "update": "checkRecentVersion:",
      "website": "openWebsite:", "help": "openWebsiteHelp:", "issues": "openWebsiteIssues:",
      "source": "openWebsiteSource:", "donation": "openWebsiteDonation:",
      "experimental-update": "checkExperimentalVersion:", "about": "showStandardAboutPanel:",
    ]
    for item in descendants(menu) where !item.isSeparatorItem && item.submenu == nil {
      let identifier = try XCTUnwrap(item.identifier?.rawValue)
      XCTAssertNil(item.target, identifier)
      XCTAssertEqual(item.action.map(NSStringFromSelector), expected[identifier], identifier)
      if identifier == "preferences" {
        XCTAssertEqual(item.keyEquivalent, ",")
        XCTAssertEqual(item.keyEquivalentModifierMask, .command)
      } else {
        XCTAssertEqual(item.keyEquivalent, "")
        XCTAssertEqual(item.keyEquivalentModifierMask, [])
      }
    }
  }

  func testMenuTitlesAndIdentifiersAreNonemptyTrimmedAndUnique() throws {
    for lab in [false, true] {
      let menu = GureumMenuBuilder(
        capabilities: try capabilities(lab: lab), includeDeveloperTools: true
      )
      .makeMenu()
      var allIdentifiers: [String] = []
      for item in descendants(menu) where !item.isSeparatorItem {
        XCTAssertFalse(item.title.isEmpty)
        XCTAssertEqual(item.title, item.title.trimmingCharacters(in: .whitespacesAndNewlines))
        let identifier = try XCTUnwrap(item.identifier?.rawValue)
        XCTAssertFalse(identifier.isEmpty)
        allIdentifiers.append(identifier)
        if let submenu = item.submenu { XCTAssertEqual(submenu.title, item.title) }
      }
      XCTAssertEqual(Set(allIdentifiers).count, allIdentifiers.count)
    }
  }

  func testDisplayNameAndAboutTitlePreferBundleDisplayName() throws {
    let capabilities = try capabilities(displayName: "Custom Chord Lab", bundleName: "Fallback")
    let menu = GureumMenuBuilder(capabilities: capabilities, includeDeveloperTools: false)
      .makeMenu()

    XCTAssertEqual(capabilities.displayName, "Custom Chord Lab")
    XCTAssertEqual(menu.title, "Custom Chord Lab")
    XCTAssertEqual(item(menu, identifier: "about")?.title, "About")
  }

  func testBlankDisplayNameFallsBackToBundleName() throws {
    XCTAssertEqual(
      try capabilities(displayName: "  \n", bundleName: "Fallback").displayName, "Fallback")
  }

  func testMissingBundleNamesUseTheUpstreamDisplayNameFallback() throws {
    XCTAssertEqual(try capabilities(bundleName: nil).displayName, "구름 입력기")
  }
}

class InputMethodIdentityTests: XCTestCase {
  private let sourceSuffixes: [(GureumInputSource, String)] = [
    (.system, "system"), (.qwerty, "qwerty"), (.dvorak, "dvorak"), (.colemak, "colemak"),
    (.han2, "han2"), (.han2Classic, "han2classic"), (.han3Final, "han3final"),
    (.han390, "han390"), (.han3NoShift, "han3noshift"), (.han3Classic, "han3classic"),
    (.han3Layout2, "han3layout2"), (.hanAhnmatae, "hanahnmatae"), (.hanRoman, "hanroman"),
    (.han3FinalNoShift, "han3finalnoshift"), (.han32011, "han3-2011"), (.han32012, "han3-2012"),
  ]

  private func identity(infoDictionary: [String: Any] = [:]) throws -> InputMethodIdentity {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString).appendingPathExtension("bundle")
    let contents = directory.appendingPathComponent("Contents", isDirectory: true)
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    addTeardownBlock { try FileManager.default.removeItem(at: directory) }
    let data = try PropertyListSerialization.data(
      fromPropertyList: infoDictionary, format: .xml, options: 0)
    try data.write(to: contents.appendingPathComponent("Info.plist"))
    return InputMethodIdentity(bundle: try XCTUnwrap(Bundle(url: directory)))
  }

  private func labIdentity() throws -> InputMethodIdentity {
    try identity(infoDictionary: [
      "GureumInputSourcePrefix": "io.github.kathar0s.inputmethod.GureumChordLab",
      "GureumDefaultsSuiteName": "io.github.kathar0s.GureumChordLab",
      "GureumChordLab": true,
    ])
  }

  private func baramIdentity(
    defaultsSuite: String = "com.sionyuel.Baram",
    legacySuite: String = "io.github.kathar0s.GureumChordLab",
    updateFeedEnabled: Bool = false
  ) throws -> InputMethodIdentity {
    try identity(infoDictionary: [
      "GureumInputSourcePrefix": "com.sionyuel.inputmethod.Baram",
      "GureumDefaultsSuiteName": defaultsSuite,
      "GureumProductKind": "baram",
      "GureumLegacyInputSourcePrefix": "io.github.kathar0s.inputmethod.GureumChordLab",
      "GureumLegacyDefaultsSuiteName": legacySuite,
      "BaramUpdateFeedEnabled": updateFeedEnabled,
    ])
  }

  func testMissingBundleMetadataPreservesUpstreamIdentity() throws {
    let identity = try identity()

    XCTAssertEqual(identity.inputSourcePrefix, "org.youknowone.inputmethod.Gureum")
    XCTAssertEqual(identity.defaultsSuiteName, "org.youknowone.Gureum")
    XCTAssertEqual(identity.productKind, .upstream)
    XCTAssertFalse(identity.isChordLab)
  }

  func testLabBundleMetadataSelectsLabIdentity() throws {
    let identity = try labIdentity()

    XCTAssertEqual(identity.inputSourcePrefix, "io.github.kathar0s.inputmethod.GureumChordLab")
    XCTAssertEqual(identity.defaultsSuiteName, "io.github.kathar0s.GureumChordLab")
    XCTAssertEqual(identity.productKind, .lab)
    XCTAssertTrue(identity.isChordLab)
  }

  func testBaramBundleMetadataSelectsBaramIdentityAndCapabilities() throws {
    let identity = try baramIdentity()

    XCTAssertEqual(identity.inputSourcePrefix, "com.sionyuel.inputmethod.Baram")
    XCTAssertEqual(identity.defaultsSuiteName, "com.sionyuel.Baram")
    XCTAssertEqual(identity.productKind, .baram)
    XCTAssertTrue(identity.isBaram)
    XCTAssertTrue(identity.usesForkServices)
    XCTAssertTrue(identity.supportsPhysicalChording)
    XCTAssertFalse(identity.recordsChordDiagnostics)
    XCTAssertFalse(identity.supportsUpstreamUpdates)
    XCTAssertFalse(identity.supportsUpdates)
    XCTAssertFalse(identity.supportsExperimentalUpdates)
    XCTAssertNil(UpdateManager.feedURL(mode: .stable, identity: identity))
    XCTAssertNil(UpdateManager.feedURL(mode: .experimental, identity: identity))
  }

  func testBaramUpdateFeedRequiresAnExplicitReleaseFlag() throws {
    let identity = try baramIdentity(updateFeedEnabled: true)

    XCTAssertTrue(identity.supportsUpdates)
    XCTAssertEqual(
      UpdateManager.feedURL(mode: .stable, identity: identity)?.absoluteString,
      "https://baram.sionyuel.com/version.json")
    XCTAssertNil(UpdateManager.feedURL(mode: .experimental, identity: identity))
  }

  func testBaramInfoPlistUsesLayoutSpecificInputSourceIcons() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent()
    let plistURL = root.appendingPathComponent("OSX/Baram-Info.plist")
    let data = try Data(contentsOf: plistURL)
    let plist = try XCTUnwrap(
      PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    XCTAssertEqual(plist["CFBundleSignature"] as? String, "Barm")
    XCTAssertEqual(
      plist["NSHumanReadableCopyright"] as? String,
      "Copyright © 2026 Sionyuel.\nBased on Gureum © 2011-2022 Jeong YunWon and contributors.")
    XCTAssertEqual(
      plist["CFBundleGetInfoString"] as? String,
      "${VERSION}, Copyright © 2026 Sionyuel\nBased on Gureum © 2011-2022 Jeong YunWon and contributors"
    )
    let upstreamData = try Data(contentsOf: root.appendingPathComponent("OSX/Info.plist"))
    let upstreamPlist = try XCTUnwrap(
      PropertyListSerialization.propertyList(from: upstreamData, format: nil) as? [String: Any])
    XCTAssertEqual(
      upstreamPlist["NSHumanReadableCopyright"] as? String,
      "Copyright 2011-2022 Jeong YunWon")
    let component = try XCTUnwrap(plist["ComponentInputModeDict"] as? [String: Any])
    let modes = try XCTUnwrap(component["tsInputModeListKey"] as? [String: [String: Any]])
    XCTAssertEqual(modes.count, GureumInputSource.allCases.count)
    let internalRoman = try XCTUnwrap(modes["com.sionyuel.inputmethod.Baram.system"])
    XCTAssertEqual(internalRoman["tsInputModeIsVisibleKey"] as? Bool, false)
    let visibleModes = try XCTUnwrap(component["tsVisibleInputModeOrderedArrayKey"] as? [String])
    XCTAssertFalse(visibleModes.contains("com.sionyuel.inputmethod.Baram.system"))
    let menuIcons = [
      "colemak": "baramcm.png",
      "dvorak": "baramdv.png",
      "han2": "baram2.png",
      "han2classic": "baram2.png",
      "han3-2011": "baram3.png",
      "han3-2012": "baram3.png",
      "han390": "baram390.png",
      "han3classic": "baram3.png",
      "han3final": "baram3f.png",
      "han3finalnoshift": "baram3f.png",
      "han3layout2": "baram3.png",
      "han3noshift": "baram3.png",
      "hanahnmatae": "baram.png",
      "hanroman": "baramrom.png",
      "qwerty": "baramqw.png",
      "system": "barameng.png",
    ]
    XCTAssertEqual(Set(menuIcons.keys), Set(sourceSuffixes.map(\.1)))
    for (suffix, menuIcon) in menuIcons {
      let identifier = "com.sionyuel.inputmethod.Baram.\(suffix)"
      let mode = try XCTUnwrap(modes[identifier], identifier)
      XCTAssertEqual(mode["tsInputModeMenuIconFileKey"] as? String, menuIcon, identifier)
      let fallbackIcon =
        ["han390", "han3final", "han3finalnoshift"].contains(suffix)
        ? "baram3.png" : menuIcon
      XCTAssertEqual(
        mode["tsInputModeAlternateMenuIconFileKey"] as? String, fallbackIcon, identifier)
      XCTAssertEqual(mode["tsInputModePaletteIconFileKey"] as? String, fallbackIcon, identifier)
    }

    for assetName in Set(menuIcons.values).union(["baram3.png"]) {
      let stem = String(assetName.dropLast(4))
      let asset = root.appendingPathComponent("OSX/Assets.xcassets/\(stem).imageset")
      let contents = try Data(contentsOf: asset.appendingPathComponent("Contents.json"))
      XCTAssertNoThrow(try JSONSerialization.jsonObject(with: contents), stem)
      for (filename, width, height) in [(assetName, 22, 16), ("\(stem)@2x.png", 44, 32)] {
        let data = try Data(contentsOf: asset.appendingPathComponent(filename))
        let image = try XCTUnwrap(NSBitmapImageRep(data: data), filename)
        XCTAssertEqual(image.pixelsWide, width, filename)
        XCTAssertEqual(image.pixelsHigh, height, filename)
        let direct = root.appendingPathComponent("OSX/InputSourceIcons/\(filename)")
        XCTAssertEqual(try Data(contentsOf: direct), data, filename)
      }
    }

    let appIcon = root.appendingPathComponent("OSX/Assets.xcassets/BaramAppIcon.appiconset")
    let brandAssets = root.appendingPathComponent("docs/brand/baram/assets")
    XCTAssertEqual(
      try Data(contentsOf: appIcon.appendingPathComponent("icon_16x16.png")),
      try Data(contentsOf: brandAssets.appendingPathComponent("baram-app-icon-concept-16.png")))
    XCTAssertEqual(
      try Data(contentsOf: appIcon.appendingPathComponent("icon_512x512@2x.png")),
      try Data(contentsOf: brandAssets.appendingPathComponent("baram-app-icon-concept-1024.png")))
  }

  func testUpstreamInputSourceIdentifiersRetainTheirExistingValues() throws {
    let identity = try identity()
    XCTAssertEqual(sourceSuffixes.count, GureumInputSource.allCases.count)
    XCTAssertEqual(Set(sourceSuffixes.map(\.1)), InputMethodIdentity.knownInputSourceSuffixes)

    for (source, suffix) in sourceSuffixes {
      XCTAssertEqual(
        source.identifier(for: identity), "org.youknowone.inputmethod.Gureum.\(suffix)")
    }
  }

  func testAllInputSourcesRoundTripUnderEveryProductIdentity() throws {
    for identity in try [identity(), labIdentity(), baramIdentity()] {
      for source in GureumInputSource.allCases {
        let identifier = source.identifier(for: identity)

        XCTAssertEqual(GureumInputSource(rawValue: identifier, identity: identity), source)
      }
    }
  }

  func testInputSourceRawValuesUseTheCurrentBundleIdentity() {
    for (source, suffix) in sourceSuffixes {
      XCTAssertEqual(source.rawValue, InputMethodIdentity.current.identifier(for: suffix))
      XCTAssertEqual(GureumInputSource(rawValue: source.rawValue), source)
    }
  }

  func testInputSourcesRejectIdentifiersFromTheOtherProduct() throws {
    let upstream = try identity()
    let lab = try labIdentity()
    let baram = try baramIdentity()

    for source in GureumInputSource.allCases {
      for (candidate, other) in [(upstream, lab), (upstream, baram), (lab, baram)] {
        XCTAssertNil(
          GureumInputSource(rawValue: source.identifier(for: other), identity: candidate))
        XCTAssertNil(
          GureumInputSource(rawValue: source.identifier(for: candidate), identity: other))
      }
    }
  }

  func testInputSourcesRejectUnknownSuffixes() throws {
    for identity in try [identity(), labIdentity(), baramIdentity()] {
      XCTAssertNil(
        GureumInputSource(rawValue: identity.identifier(for: "unknown"), identity: identity))
    }
  }

  func testEveryProductUsesAnIndependentDefaultsSuite() throws {
    let upstreamIdentity = try identity()
    let labIdentity = try labIdentity()
    let baramIdentity = try baramIdentity()
    XCTAssertNotEqual(upstreamIdentity.defaultsSuiteName, labIdentity.defaultsSuiteName)
    XCTAssertNotEqual(upstreamIdentity.defaultsSuiteName, baramIdentity.defaultsSuiteName)
    XCTAssertNotEqual(labIdentity.defaultsSuiteName, baramIdentity.defaultsSuiteName)

    let testSuffix = ".test.\(UUID().uuidString)"
    let upstreamSuite = upstreamIdentity.defaultsSuiteName + testSuffix
    let labSuite = labIdentity.defaultsSuiteName + testSuffix
    let baramSuite = baramIdentity.defaultsSuiteName + testSuffix
    let upstream = try XCTUnwrap(Configuration(suiteName: upstreamSuite))
    let lab = try XCTUnwrap(Configuration(suiteName: labSuite))
    let baram = try XCTUnwrap(Configuration(suiteName: baramSuite))
    defer {
      upstream.removePersistentDomain(forName: upstreamSuite)
      lab.removePersistentDomain(forName: labSuite)
      baram.removePersistentDomain(forName: baramSuite)
    }

    upstream.hangulAutoReorder = false
    lab.hangulAutoReorder = true
    baram.hangulAutoReorder = false

    XCTAssertFalse(upstream.hangulAutoReorder)
    XCTAssertTrue(lab.hangulAutoReorder)
    XCTAssertFalse(baram.hangulAutoReorder)
  }

  func testBaramMigratesKnownLabSettingsOnceWithoutEnablingPhysicalChording() throws {
    let suffix = UUID().uuidString
    let legacySuite = "io.github.kathar0s.GureumChordLab.test.\(suffix)"
    let baramSuite = "com.sionyuel.Baram.test.\(suffix)"
    let identity = try baramIdentity(defaultsSuite: baramSuite, legacySuite: legacySuite)
    let legacy = try XCTUnwrap(UserDefaults(suiteName: legacySuite))
    let baram = try XCTUnwrap(UserDefaults(suiteName: baramSuite))
    defer {
      legacy.removePersistentDomain(forName: legacySuite)
      baram.removePersistentDomain(forName: baramSuite)
    }
    legacy.set(false, forKey: ConfigurationName.hangulAutoReorder)
    legacy.set(true, forKey: ConfigurationName.hangulForceStrictCombinationRule)
    legacy.set(true, forKey: ConfigurationName.physicalChordingEnabled)
    legacy.set(
      "io.github.kathar0s.inputmethod.GureumChordLab.han3final",
      forKey: ConfigurationName.lastHangulInputMode)
    legacy.set(
      "io.github.kathar0s.inputmethod.GureumChordLab.qwerty",
      forKey: ConfigurationName.lastRomanInputMode)

    Configuration.migrateLegacyDefaultsIfNeeded(identity: identity)
    let migratedDomain = try XCTUnwrap(baram.persistentDomain(forName: baramSuite))

    XCTAssertEqual(migratedDomain[ConfigurationName.hangulAutoReorder] as? Bool, false)
    XCTAssertEqual(
      migratedDomain[ConfigurationName.hangulForceStrictCombinationRule] as? Bool, true)
    XCTAssertNil(migratedDomain[ConfigurationName.physicalChordingEnabled])
    XCTAssertEqual(
      baram.string(forKey: ConfigurationName.lastHangulInputMode),
      "com.sionyuel.inputmethod.Baram.han3final")
    XCTAssertEqual(
      baram.string(forKey: ConfigurationName.lastRomanInputMode),
      "com.sionyuel.inputmethod.Baram.qwerty")
    XCTAssertEqual(
      baram.integer(forKey: Configuration.baramMigrationVersionKey),
      Configuration.baramMigrationVersion)
    XCTAssertEqual(
      legacy.string(forKey: ConfigurationName.lastHangulInputMode),
      "io.github.kathar0s.inputmethod.GureumChordLab.han3final")
    XCTAssertTrue(legacy.bool(forKey: ConfigurationName.physicalChordingEnabled))

    baram.set(true, forKey: ConfigurationName.hangulAutoReorder)
    legacy.set(false, forKey: ConfigurationName.hangulForceStrictCombinationRule)
    Configuration.migrateLegacyDefaultsIfNeeded(identity: identity)
    XCTAssertTrue(baram.bool(forKey: ConfigurationName.hangulAutoReorder))
    XCTAssertTrue(baram.bool(forKey: ConfigurationName.hangulForceStrictCombinationRule))
  }

  func testBaramMigrationPreservesExistingTarget() throws {
    let suffix = UUID().uuidString
    let legacySuite = "io.github.kathar0s.GureumChordLab.test.\(suffix)"
    let baramSuite = "com.sionyuel.Baram.test.\(suffix)"
    let identity = try baramIdentity(defaultsSuite: baramSuite, legacySuite: legacySuite)
    let legacy = try XCTUnwrap(UserDefaults(suiteName: legacySuite))
    let baram = try XCTUnwrap(UserDefaults(suiteName: baramSuite))
    defer {
      legacy.removePersistentDomain(forName: legacySuite)
      baram.removePersistentDomain(forName: baramSuite)
    }
    baram.set("com.apple.keylayout.Dvorak", forKey: ConfigurationName.overridingKeyboardName)

    Configuration.migrateLegacyDefaultsIfNeeded(identity: identity)
    let migratedDomain = try XCTUnwrap(baram.persistentDomain(forName: baramSuite))

    XCTAssertEqual(
      migratedDomain[ConfigurationName.overridingKeyboardName] as? String,
      "com.apple.keylayout.Dvorak")
    XCTAssertEqual(
      baram.integer(forKey: Configuration.baramMigrationVersionKey),
      Configuration.baramMigrationVersion)
  }

  func testBaramMigrationRejectsUnknownInputModesInAnEmptyTarget() throws {
    let suffix = UUID().uuidString
    let legacySuite = "io.github.kathar0s.GureumChordLab.test.\(suffix)"
    let baramSuite = "com.sionyuel.Baram.test.\(suffix)"
    let identity = try baramIdentity(defaultsSuite: baramSuite, legacySuite: legacySuite)
    let legacy = try XCTUnwrap(UserDefaults(suiteName: legacySuite))
    let baram = try XCTUnwrap(UserDefaults(suiteName: baramSuite))
    defer {
      legacy.removePersistentDomain(forName: legacySuite)
      baram.removePersistentDomain(forName: baramSuite)
    }
    legacy.set(
      "io.github.kathar0s.inputmethod.GureumChordLab.unknown",
      forKey: ConfigurationName.lastHangulInputMode)
    legacy.set(true, forKey: ConfigurationName.hangulForceStrictCombinationRule)

    Configuration.migrateLegacyDefaultsIfNeeded(identity: identity)
    let migratedDomain = try XCTUnwrap(baram.persistentDomain(forName: baramSuite))

    XCTAssertNil(migratedDomain[ConfigurationName.lastHangulInputMode])
    XCTAssertEqual(
      migratedDomain[ConfigurationName.hangulForceStrictCombinationRule] as? Bool, true)
    XCTAssertEqual(
      baram.integer(forKey: Configuration.baramMigrationVersionKey),
      Configuration.baramMigrationVersion)
  }

  func testUpstreamRecognizedEventsDoNotRequestKeyUp() throws {
    let app = ModerateApp()
    let mask = app.controller.receiver.recognizedEvents(app.client, identity: try identity())

    XCTAssertTrue(mask.contains(.keyDown))
    XCTAssertFalse(mask.contains(.keyUp))
  }

  func testLabRecognizedEventsRequestKeyUpOnlyInDebugBuilds() throws {
    let app = ModerateApp()
    let mask = app.controller.receiver.recognizedEvents(app.client, identity: try labIdentity())

    XCTAssertTrue(mask.contains(.keyDown))
    #if DEBUG
      XCTAssertTrue(mask.contains(.keyUp))
    #else
      XCTAssertFalse(mask.contains(.keyUp))
    #endif
  }

  func testLabRecognizedEventsOnlyDifferFromUpstreamInDebugBuilds() throws {
    let app = ModerateApp()
    let receiver = app.controller.receiver!
    let upstream = receiver.recognizedEvents(app.client, identity: try identity())
    let lab = receiver.recognizedEvents(app.client, identity: try labIdentity())

    #if DEBUG
      XCTAssertEqual(lab.subtracting(upstream), .keyUp)
    #else
      XCTAssertEqual(lab, upstream)
    #endif
    XCTAssertEqual(upstream.subtracting(lab), [])
  }

  func testBaramRequestsIMKKeyUpForTheLiveKeyboardPreview() throws {
    let app = ModerateApp()
    let mask = app.controller.receiver.recognizedEvents(app.client, identity: try baramIdentity())

    XCTAssertTrue(mask.contains(.keyDown))
    XCTAssertTrue(mask.contains(.keyUp))
  }
}

private final class FakePhysicalKeyEventSource: PhysicalKeyEventSourceProtocol {
  var status: PhysicalKeySourceStatus = .healthy
  var permissionGranted = true
  var secureInputEnabled = false
  var refreshAction: (() -> Void)?
  private(set) var startCallCount = 0
  private(set) var stopCallCount = 0
  private var leases: Set<UUID> = []
  var activeLeaseCount: Int { leases.count }
  private var observers: [UUID: (PhysicalKeySourceEvent) -> Void] = [:]

  func acquireLease(_ token: UUID) {
    if leases.isEmpty { startCallCount += 1 }
    leases.insert(token)
  }
  func releaseLease(_ token: UUID) {
    guard leases.remove(token) != nil else { return }
    if leases.isEmpty { stopCallCount += 1 }
  }
  func refresh() { refreshAction?() }
  func addObserver(_ observer: @escaping (PhysicalKeySourceEvent) -> Void) -> UUID {
    let token = UUID()
    observers[token] = observer
    return token
  }
  func removeObserver(_ token: UUID) { observers.removeValue(forKey: token) }
  func emit(_ event: PhysicalKeySourceEvent) {
    for observer in Array(observers.values) { observer(event) }
  }
}

private final class ChordCoordinatorFixture {
  final class State {
    var now: TimeInterval = 0
    var enabled = true
    var replayed: [ChordStroke] = []
    var disabled: [ChordFlushReason] = []
    var outcome = ChordTerminalOutcome.composerReplay
  }

  let source = FakePhysicalKeyEventSource()
  let state = State()
  let coordinator: ChordInputCoordinator

  init(
    enabled: Bool = true, watchdog: TimeInterval = 2, maxOrphans: Int = 32, maxStrokes: Int = 64,
    acceptsRelease: @escaping (Int) -> Bool = { _ in true },
    orderGroup: @escaping (StrokeGroup) -> [ChordStroke] = { $0.strokes }
  ) {
    let state = state
    state.enabled = enabled
    coordinator = ChordInputCoordinator(
      source: source, clock: { state.now }, isEnabled: { state.enabled },
      acceptsRelease: acceptsRelease, watchdog: watchdog,
      orphanLifetime: 0.25, maxOrphans: maxOrphans, maxStrokes: maxStrokes,
      orderGroup: orderGroup,
      onDisabled: { state.disabled.append($0) },
      replay: {
        state.replayed.append($0)
        return state.outcome
      })
    coordinator.activate()
  }

  @discardableResult func press(
    _ keyCode: Int, at timestamp: TimeInterval = 0, isRepeat: Bool = false
  ) -> Bool {
    coordinator.consume(
      keyCode: keyCode, text: "key\(keyCode)", modifiers: 0, timestamp: timestamp,
      isRepeat: isRepeat)
  }

  func release(_ keyCode: Int, at timestamp: TimeInterval = 0.1) {
    source.emit(.keyUp(keyCode: keyCode, timestamp: timestamp))
  }
}

class ChordInputCoordinatorTests: XCTestCase {
  func testValidPolicyPermutationChangesOnlyReleaseCompletedReplayOrder() {
    let fixture = ChordCoordinatorFixture(orderGroup: { Array($0.strokes.reversed()) })
    fixture.press(1)
    fixture.press(2, at: 0.01)
    fixture.release(1, at: 0.02)
    fixture.release(2, at: 0.03)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [2, 1])
    XCTAssertEqual(fixture.coordinator.terminalCount, 2)
  }

  func testInvalidPolicyIdsAndPayloadsFallBackToOriginalOrder() {
    let invalidPolicies: [(StrokeGroup) -> [ChordStroke]] = [
      { _ in [] },
      { [$0.strokes[0], $0.strokes[0]] },
      {
        let stroke = $0.strokes[0]
        return [
          ChordStroke(
            id: 999, keyCode: stroke.keyCode, text: stroke.text, modifiers: stroke.modifiers,
            timestamp: stroke.timestamp), $0.strokes[1],
        ]
      },
      {
        let stroke = $0.strokes[0]
        return [
          ChordStroke(
            id: stroke.id, keyCode: stroke.keyCode, text: "changed", modifiers: stroke.modifiers,
            timestamp: stroke.timestamp), $0.strokes[1],
        ]
      },
    ]
    for policy in invalidPolicies {
      let fixture = ChordCoordinatorFixture(orderGroup: policy)
      fixture.press(1)
      fixture.press(2, at: 0.01)
      fixture.release(1, at: 0.02)
      fixture.release(2, at: 0.03)
      XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1, 2])
      XCTAssertEqual(fixture.state.replayed.map(\.text), ["key1", "key2"])
      XCTAssertEqual(fixture.coordinator.terminalCount, fixture.coordinator.consumedStrokeCount)
    }
  }

  func testSafetyAndBoundaryFlushesNeverInvokeTheOrderingPolicy() {
    for safetyFault in [false, true] {
      var policyCalls = 0
      let fixture = ChordCoordinatorFixture(orderGroup: {
        policyCalls += 1
        return Array($0.strokes.reversed())
      })
      fixture.press(1)
      fixture.press(2, at: 0.01)
      if safetyFault {
        fixture.coordinator.checkTimeout(now: 2)
      } else {
        fixture.coordinator.flushBoundary(.command)
      }
      XCTAssertEqual(policyCalls, 0)
      XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1, 2])
    }
  }

  func testLeaseStopsOnLastDeactivationAndRestartsOnActivation() {
    let fixture = ChordCoordinatorFixture()
    XCTAssertEqual(fixture.source.activeLeaseCount, 1)
    XCTAssertEqual(fixture.source.startCallCount, 1)

    fixture.coordinator.deactivate()
    XCTAssertEqual(fixture.source.activeLeaseCount, 0)
    XCTAssertEqual(fixture.source.stopCallCount, 1)
    fixture.coordinator.activate()
    XCTAssertEqual(fixture.source.activeLeaseCount, 1)
    XCTAssertEqual(fixture.source.startCallCount, 2)
  }

  func testFatalWatchdogReleasesTheSourceLease() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.coordinator.checkTimeout(now: 2)

    XCTAssertEqual(fixture.source.activeLeaseCount, 0)
    XCTAssertEqual(fixture.source.stopCallCount, 1)
    XCTAssertEqual(fixture.coordinator.disabledReason, .watchdog)
  }

  func testTrailingUnconsumedShortcutReleaseIsIgnoredAfterBoundary() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.coordinator.flushBoundary(.shortcut, ignoringReleaseOf: 2, timestamp: 0.01)
    fixture.release(1, at: 0.02)
    fixture.release(2, at: 0.03)
    fixture.coordinator.checkTimeout(now: 0.4)

    XCTAssertNil(fixture.coordinator.disabledReason)
    XCTAssertEqual(fixture.source.activeLeaseCount, 1)
    XCTAssertTrue(fixture.press(3, at: 0.5))
    fixture.release(3, at: 0.6)
    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1, 3])
  }

  func testSourceEventsAfterDeactivationDoNotBufferOrReplay() {
    let fixture = ChordCoordinatorFixture()
    fixture.coordinator.deactivate()
    fixture.release(1)
    fixture.source.emit(.heartbeat(timestamp: 5))

    XCTAssertEqual(fixture.source.activeLeaseCount, 0)
    XCTAssertTrue(fixture.state.replayed.isEmpty)
    XCTAssertEqual(fixture.coordinator.bufferedStrokeCount, 0)
    XCTAssertEqual(fixture.coordinator.terminalCount, 0)
  }

  func testIneligibleReleaseNeverBecomesAnExpiringOrphan() {
    let fixture = ChordCoordinatorFixture(acceptsRelease: { $0 != KeyCode.space.rawValue })
    fixture.release(KeyCode.space.rawValue)

    fixture.coordinator.checkTimeout(now: 0.25)

    XCTAssertNil(fixture.coordinator.disabledReason)
    XCTAssertEqual(fixture.coordinator.consumedStrokeCount, 0)
    XCTAssertTrue(fixture.press(KeyCode.ansiK.rawValue, at: 0.3))
    fixture.release(KeyCode.ansiK.rawValue, at: 0.4)
    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [KeyCode.ansiK.rawValue])
  }

  func testReactivationFlushesThePreviousGroupBeforeAcceptingNewInput() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)

    fixture.coordinator.activate()

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertEqual(fixture.coordinator.recentTerminations.map(\.reason), [.clientChanged])
    XCTAssertEqual(fixture.coordinator.outstandingStrokeCount, 0)
    XCTAssertNil(fixture.coordinator.disabledReason)
    XCTAssertTrue(fixture.press(2, at: 0.2))
    fixture.release(2, at: 0.3)
    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1, 2])
    XCTAssertEqual(fixture.coordinator.terminalCount, fixture.coordinator.consumedStrokeCount)
  }

  func testDisabledModeNeverStartsThePhysicalEventSource() {
    let fixture = ChordCoordinatorFixture(enabled: false)

    XCTAssertEqual(fixture.source.startCallCount, 0)
    XCTAssertNil(fixture.coordinator.disabledReason)
    XCTAssertFalse(fixture.coordinator.isActive)
    XCTAssertFalse(fixture.press(1))
  }

  func testReactivationAfterOptOutDoesNotRestartThePhysicalEventSource() {
    let fixture = ChordCoordinatorFixture()
    XCTAssertEqual(fixture.source.startCallCount, 1)
    fixture.coordinator.deactivate()
    fixture.state.enabled = false

    fixture.coordinator.activate()

    XCTAssertEqual(fixture.source.startCallCount, 1)
    XCTAssertNil(fixture.coordinator.disabledReason)
    XCTAssertFalse(fixture.coordinator.isActive)
  }

  func testDisabledModePassesThroughWithoutConsuming() {
    let fixture = ChordCoordinatorFixture()
    fixture.state.enabled = false

    XCTAssertFalse(fixture.press(1))
    XCTAssertNil(fixture.coordinator.disabledReason)
    XCTAssertFalse(fixture.coordinator.isActive)
    XCTAssertEqual(fixture.coordinator.consumedStrokeCount, 0)
  }

  func testUnhealthySourcePassesThroughWithoutConsuming() {
    let fixture = ChordCoordinatorFixture()
    fixture.source.status = .unavailable

    XCTAssertFalse(fixture.press(1))
    XCTAssertEqual(fixture.coordinator.disabledReason, .tapDisabled)
    XCTAssertEqual(fixture.coordinator.consumedStrokeCount, 0)
  }

  func testDisablingModeFlushesBeforePassingThroughTheNextDown() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.state.enabled = false

    XCTAssertFalse(fixture.press(2, at: 0.01))

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertNil(fixture.coordinator.disabledReason)
    XCTAssertFalse(fixture.coordinator.isActive)
    XCTAssertEqual(fixture.coordinator.consumedStrokeCount, 1)
    XCTAssertEqual(fixture.coordinator.terminalCount, 1)
  }

  func testPermissionDeniedPassesThroughWithoutConsuming() {
    let fixture = ChordCoordinatorFixture()
    fixture.source.permissionGranted = false

    XCTAssertFalse(fixture.press(1))
    XCTAssertEqual(fixture.coordinator.disabledReason, .permissionLost)
    XCTAssertEqual(fixture.coordinator.consumedStrokeCount, 0)
  }

  func testPermissionRevocationFlushesBufferedStrokeExactlyOnce() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.source.permissionGranted = false
    fixture.source.emit(.statusChanged(.permissionDenied))
    fixture.release(1)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertEqual(fixture.coordinator.disabledReason, .permissionLost)
    XCTAssertEqual(fixture.coordinator.terminalCount, 1)
    XCTAssertEqual(fixture.coordinator.outstandingStrokeCount, 0)
  }

  func testPermissionLossDuringRefreshFlushesBeforeRejectingNextDown() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    let source = fixture.source
    source.refreshAction = { [weak source] in source?.permissionGranted = false }

    XCTAssertFalse(fixture.press(2, at: 0.01))

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertEqual(fixture.coordinator.disabledReason, .permissionLost)
    XCTAssertEqual(fixture.coordinator.consumedStrokeCount, 1)
    XCTAssertEqual(fixture.coordinator.terminalCount, 1)
  }

  func testSecureInputFlushesAndDisablesBuffering() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.source.secureInputEnabled = true
    fixture.coordinator.checkTimeout(now: 0.1)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertEqual(fixture.coordinator.disabledReason, .secureInput)
    XCTAssertFalse(fixture.press(2))
  }

  func testTapDisableFlushesAndDisablesBuffering() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.source.emit(.statusChanged(.tapDisabled))

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertEqual(fixture.coordinator.disabledReason, .tapDisabled)
    XCTAssertFalse(fixture.press(2))
  }

  func testSourceStopFlushesAndDisablesBuffering() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.source.emit(.statusChanged(.stopped))

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertNil(fixture.coordinator.disabledReason)
    XCTAssertFalse(fixture.coordinator.isActive)
  }

  func testKeyReleaseAfterDownCompletesOneStroke() {
    let fixture = ChordCoordinatorFixture()
    XCTAssertTrue(fixture.press(1))
    XCTAssertEqual(fixture.coordinator.bufferedStrokeCount, 1)
    XCTAssertTrue(fixture.state.replayed.isEmpty)

    fixture.release(1)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertEqual(fixture.coordinator.bufferedStrokeCount, 0)
    XCTAssertEqual(fixture.coordinator.terminalCount, 1)
  }

  func testKeyReleaseArrivingBeforeImkDownMatchesByTimestamp() {
    let fixture = ChordCoordinatorFixture()
    fixture.release(1, at: 0.1)

    XCTAssertTrue(fixture.press(1, at: 0.05))

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertEqual(fixture.coordinator.terminalCount, 1)
    XCTAssertNil(fixture.coordinator.disabledReason)
  }

  func testOverlappingKeysWaitForFinalReleaseAndPreservePressOrder() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(3)
    fixture.press(1, at: 0.01)
    fixture.release(3, at: 0.02)
    XCTAssertTrue(fixture.state.replayed.isEmpty)

    fixture.release(1, at: 0.03)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [3, 1])
    XCTAssertEqual(fixture.coordinator.terminalCount, 2)
  }

  func testReverseReleaseOrderPreservesOriginalPressOrder() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(3)
    fixture.press(1, at: 0.01)
    fixture.release(1, at: 0.02)
    fixture.release(3, at: 0.03)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [3, 1])
  }

  func testRollingOverlapStaysInOneGroupUntilHeldSetIsEmpty() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.press(2, at: 0.01)
    fixture.release(1, at: 0.02)
    fixture.press(3, at: 0.03)
    fixture.release(2, at: 0.04)
    XCTAssertTrue(fixture.state.replayed.isEmpty)

    fixture.release(3, at: 0.05)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1, 2, 3])
  }

  func testBrokenOverlapChainCompletesBeforeNextGroup() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.release(1, at: 0.01)
    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])

    fixture.press(2, at: 0.02)
    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    fixture.release(2, at: 0.03)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1, 2])
  }

  func testRepressAfterReleaseAddsDistinctStrokeWhileAnotherKeyIsHeld() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.press(2, at: 0.01)
    fixture.release(1, at: 0.02)
    fixture.press(1, at: 0.03)
    fixture.release(2, at: 0.04)
    fixture.release(1, at: 0.05)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1, 2, 1])
    XCTAssertEqual(fixture.state.replayed.map(\.id), [1, 2, 3])
  }

  func testAutoRepeatIsAccountedForWithoutDuplicatingReplay() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.press(1, at: 0.01, isRepeat: true)
    fixture.release(1, at: 0.02)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertEqual(fixture.coordinator.consumedStrokeCount, 2)
    XCTAssertEqual(fixture.coordinator.terminalCount, 2)
    XCTAssertEqual(
      fixture.coordinator.recentTerminations.map(\.outcome), [.repeatSuppression, .composerReplay])
  }

  func testRepeatWithoutHeldKeyPassesThroughWithoutConsumption() {
    let fixture = ChordCoordinatorFixture()

    XCTAssertFalse(fixture.press(1, isRepeat: true))
    XCTAssertEqual(fixture.coordinator.disabledReason, .unmatchedEvent)
    XCTAssertEqual(fixture.coordinator.consumedStrokeCount, 0)
  }

  func testDuplicateNonRepeatDownFlushesBothStrokesAndDisables() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.press(1, at: 0.01)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1, 1])
    XCTAssertEqual(fixture.coordinator.disabledReason, .unmatchedEvent)
    XCTAssertEqual(fixture.coordinator.terminalCount, 2)
  }

  func testGroupOverflowFlushesEveryConsumedStroke() {
    let fixture = ChordCoordinatorFixture(maxStrokes: 2)
    fixture.press(1)
    fixture.press(2, at: 0.01)
    fixture.press(3, at: 0.02)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1, 2, 3])
    XCTAssertEqual(fixture.coordinator.disabledReason, .groupOverflow)
    XCTAssertEqual(fixture.coordinator.terminalCount, fixture.coordinator.consumedStrokeCount)
    XCTAssertEqual(fixture.coordinator.outstandingStrokeCount, 0)
  }

  func testOrphanOverflowDisablesWithoutConsumingInput() {
    let fixture = ChordCoordinatorFixture(maxOrphans: 1)
    fixture.release(1)
    fixture.release(2)

    XCTAssertEqual(fixture.coordinator.disabledReason, .orphanOverflow)
    XCTAssertEqual(fixture.coordinator.consumedStrokeCount, 0)
    XCTAssertTrue(fixture.state.replayed.isEmpty)
  }

  func testExpiredOrphanIsDroppedAndTheNextChordStillWorks() {
    let fixture = ChordCoordinatorFixture()
    fixture.release(1)
    fixture.coordinator.checkTimeout(now: 0.249)
    XCTAssertNil(fixture.coordinator.disabledReason)

    fixture.coordinator.checkTimeout(now: 0.25)

    XCTAssertNil(fixture.coordinator.disabledReason)
    XCTAssertEqual(fixture.coordinator.expiredOrphanCount, 1)
    XCTAssertTrue(fixture.press(2, at: 0.3))
    fixture.release(2, at: 0.4)
    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [2])
  }

  func testMissingReleaseWatchdogFlushesAtInclusiveDeadline() {
    let fixture = ChordCoordinatorFixture(watchdog: 2)
    fixture.press(1)
    fixture.coordinator.checkTimeout(now: 1.999)
    XCTAssertTrue(fixture.state.replayed.isEmpty)

    fixture.source.emit(.heartbeat(timestamp: 2))

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertEqual(fixture.coordinator.disabledReason, .watchdog)
    XCTAssertEqual(fixture.coordinator.recentTerminations.map(\.outcome), [.safetyFlush])
  }

  func testDeactivationFlushesAndPreventsFurtherConsumption() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.coordinator.deactivate()

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertNil(fixture.coordinator.disabledReason)
    XCTAssertFalse(fixture.coordinator.isActive)
    XCTAssertFalse(fixture.press(2))
  }

  func testActivatingAnotherClientFlushesOnlyTheOriginalClient() {
    let original = ChordCoordinatorFixture()
    original.press(1)

    let next = ChordCoordinatorFixture()

    XCTAssertEqual(original.state.replayed.map(\.keyCode), [1])
    XCTAssertNil(original.coordinator.disabledReason)
    XCTAssertFalse(original.coordinator.isActive)
    XCTAssertTrue(next.state.replayed.isEmpty)
    XCTAssertTrue(next.press(2))
    next.release(2)
    XCTAssertEqual(next.state.replayed.map(\.keyCode), [2])
  }

  func testOrdinaryBoundariesFlushAndAllowTheNextChord() {
    for reason: ChordFlushReason in [
      .layoutChanged, .mouse, .command, .shortcut, .candidate, .nonMappable,
    ] {
      let fixture = ChordCoordinatorFixture()
      fixture.press(3)
      fixture.press(1, at: 0.01)
      fixture.coordinator.flushBoundary(reason)

      XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [3, 1], reason.rawValue)
      XCTAssertNil(fixture.coordinator.disabledReason)
      XCTAssertTrue(fixture.coordinator.isActive)
      XCTAssertEqual(fixture.coordinator.terminalCount, fixture.coordinator.consumedStrokeCount)
      XCTAssertEqual(fixture.coordinator.outstandingStrokeCount, 0)
      fixture.release(3, at: 0.02)
      fixture.release(1, at: 0.03)
      XCTAssertTrue(fixture.press(2, at: 0.04))
      fixture.release(2, at: 0.05)
      XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [3, 1, 2])
      XCTAssertNil(fixture.coordinator.disabledReason)
    }
  }

  func testComposerReplayRecordsComposerOutcome() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.release(1)

    XCTAssertEqual(fixture.coordinator.recentTerminations.map(\.outcome), [.composerReplay])
  }

  func testLiteralFallbackRecordsLiteralOutcomeExactlyOnce() {
    let fixture = ChordCoordinatorFixture()
    fixture.state.outcome = .literalFallback
    fixture.press(1)
    fixture.release(1)

    XCTAssertEqual(fixture.coordinator.recentTerminations.map(\.outcome), [.literalFallback])
    XCTAssertEqual(fixture.coordinator.terminalCount, 1)
    XCTAssertEqual(fixture.coordinator.outstandingStrokeCount, 0)
  }

  func testFinalReleaseBeforeWatchdogTerminatesStrokeOnlyOnce() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.release(1, at: 2)
    fixture.coordinator.checkTimeout(now: 2)

    XCTAssertEqual(fixture.state.replayed.count, 1)
    XCTAssertEqual(fixture.coordinator.terminalCount, 1)
    XCTAssertNil(fixture.coordinator.disabledReason)
  }

  func testWatchdogBeforeFinalReleaseTerminatesStrokeOnlyOnce() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.coordinator.checkTimeout(now: 2)
    fixture.release(1, at: 2)

    XCTAssertEqual(fixture.state.replayed.count, 1)
    XCTAssertEqual(fixture.coordinator.terminalCount, 1)
    XCTAssertEqual(fixture.coordinator.disabledReason, .watchdog)
  }

  func testReleaseTimestampBeforeDownTriggersSafetyFlush() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1, at: 0.2)
    fixture.release(1, at: 0.1)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertEqual(fixture.coordinator.disabledReason, .timestampMismatch)
    XCTAssertEqual(fixture.coordinator.terminalCount, 1)
  }

  func testDownTimestampBeforePreviousCompletionTriggersSafetyFlush() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.release(1, at: 0.1)
    fixture.press(2, at: 0.05)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1, 2])
    XCTAssertEqual(fixture.coordinator.disabledReason, .timestampMismatch)
    XCTAssertEqual(fixture.coordinator.terminalCount, 2)
  }

  func testStaleOrphanDoesNotReleaseANewerPressOfTheSameKey() {
    let fixture = ChordCoordinatorFixture()
    fixture.release(1, at: 0.1)
    fixture.press(1, at: 0.2)

    XCTAssertTrue(fixture.state.replayed.isEmpty)
    XCTAssertEqual(fixture.coordinator.bufferedStrokeCount, 1)

    fixture.coordinator.checkTimeout(now: 0.25)

    XCTAssertTrue(fixture.state.replayed.isEmpty)
    XCTAssertEqual(fixture.coordinator.bufferedStrokeCount, 1)
    XCTAssertNil(fixture.coordinator.disabledReason)
    fixture.release(1, at: 0.3)
    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertEqual(fixture.coordinator.terminalCount, 1)
  }

  func testInvalidEventDoesNotConsumeOrBufferInput() {
    let fixture = ChordCoordinatorFixture()

    XCTAssertFalse(
      fixture.coordinator.consume(
        keyCode: 1, text: "", modifiers: 0, timestamp: 0, isRepeat: false))
    XCTAssertFalse(fixture.press(1, at: .nan))
    XCTAssertFalse(fixture.press(1, at: -1))
    XCTAssertEqual(fixture.coordinator.consumedStrokeCount, 0)
    XCTAssertEqual(fixture.coordinator.bufferedStrokeCount, 0)
  }
}

private final class ChordHandleTestController: InputController {
  var testClient: MockInputClient
  private var handlingEvent = false

  init(client: MockInputClient) {
    testClient = client
    super.init()
    receiver = InputReceiver(
      server: InputMethodServer.shared.server, delegate: client, client: client, controller: self)
  }

  override func client() -> (IMKTextInput & NSObjectProtocol)! {
    if handlingEvent { return testClient }
    return super.client() ?? testClient
  }

  override func handle(_ event: NSEvent, client sender: Any) -> Bool {
    handlingEvent = true
    defer { handlingEvent = false }
    return super.handle(event, client: sender)
  }

  override func selectionRange() -> NSRange { client().selectedRange() }

  override func updateComposition() {
    let target = client() as! MockInputClient
    let composed = receiver.composedString(target)
    target.setMarkedText(
      composed, selectedRange: NSRange(location: 0, length: composed.count),
      replacementRange: target.markedRange())
  }

  override func cancelComposition() {
    receiver.cancelCompositionEvent()
    let target = client() as! MockInputClient
    target.setMarkedText(
      "", selectedRange: NSRange(location: 0, length: 0), replacementRange: target.markedRange())
  }
}

private final class ChordHandleFixture {
  let source = FakePhysicalKeyEventSource()
  let state = ChordCoordinatorFixture.State()
  let client = MockInputClient()
  let controller: ChordHandleTestController

  init(enabled: Bool = true, layout: GureumInputSource = .han3Final) {
    controller = ChordHandleTestController(client: client)
    state.enabled = enabled
    let source = source
    let state = state
    controller.chordEnvironment = ChordControllerEnvironment(
      isLab: { true }, isEnabled: { state.enabled }, sourceFactory: { source }, clock: { state.now }
    )
    controller.setValue(layout.rawValue, forTag: kTextServiceInputModePropertyTag, client: client)
  }

  func activate() { controller.activatePhysicalInput(client: client) }

  @discardableResult func down(
    _ key: KeyCode, text: String, at timestamp: TimeInterval = 0,
    modifiers: NSEvent.ModifierFlags = []
  ) -> Bool {
    let event = NSEvent.keyEvent(
      with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: timestamp,
      windowNumber: 0, context: nil, characters: text, charactersIgnoringModifiers: text,
      isARepeat: false, keyCode: UInt16(key.rawValue))!
    return controller.handle(event, client: controller.testClient)
  }

  func release(_ key: KeyCode, at timestamp: TimeInterval = 0.1) {
    source.emit(.keyUp(keyCode: key.rawValue, timestamp: timestamp))
  }
}

class IsolatedChordConfigurationTests: XCTestCase {
  private let configurationSuite = "org.youknowone.Gureum.test.chord.\(UUID().uuidString)"
  private var previousConfiguration: Configuration!

  override func setUp() {
    super.setUp()
    previousConfiguration = Configuration.shared
    Configuration.shared = Configuration(suiteName: configurationSuite)!
  }

  override func tearDown() {
    Configuration.shared.removePersistentDomain(forName: configurationSuite)
    Configuration.shared = previousConfiguration
    previousConfiguration = nil
    super.tearDown()
  }
}

class ChordInputControllerTests: IsolatedChordConfigurationTests {
  func testReleasedPhysicalChordUsesLayoutOrderingBeforeTheRealComposer() {
    let fixture = ChordHandleFixture()
    fixture.activate()
    XCTAssertFalse(Configuration.shared.hangulAutoReorder)
    XCTAssertTrue(fixture.down(.ansiS, text: "s"))
    XCTAssertTrue(fixture.down(.ansiF, text: "f", at: 0.01))
    XCTAssertTrue(fixture.down(.ansiJ, text: "j", at: 0.02))
    XCTAssertEqual(fixture.client.string, "")
    fixture.release(.ansiJ, at: 0.03)
    fixture.release(.ansiS, at: 0.04)
    XCTAssertEqual(fixture.client.string, "")

    fixture.release(.ansiF, at: 0.05)

    XCTAssertEqual(fixture.client.string, "안")
    XCTAssertEqual(fixture.controller.chordCoordinator?.terminalCount, 3)
    XCTAssertEqual(fixture.controller.chordCoordinator?.outstandingStrokeCount, 0)
  }

  func testEligibleHandleDefersComposerAndClientUntilRelease() {
    let fixture = ChordHandleFixture()
    fixture.activate()

    XCTAssertTrue(fixture.down(.ansiK, text: "k"))
    XCTAssertEqual(fixture.client.string, "")
    XCTAssertEqual(fixture.controller.receiver.composer.composedString, "")

    fixture.release(.ansiK)

    XCTAssertEqual(fixture.client.string, "ㄱ")
    XCTAssertEqual(fixture.controller.chordCoordinator?.terminalCount, 1)
    XCTAssertEqual(fixture.controller.chordCoordinator?.outstandingStrokeCount, 0)
  }

  func testActivationCapturesReleaseArrivingBeforeFirstImkDown() {
    let fixture = ChordHandleFixture()
    fixture.activate()
    XCTAssertEqual(fixture.source.activeLeaseCount, 1)
    fixture.release(.ansiK, at: 0.1)

    XCTAssertTrue(fixture.down(.ansiK, text: "k", at: 0.05))

    XCTAssertEqual(fixture.client.string, "ㄱ")
    XCTAssertEqual(fixture.controller.chordCoordinator?.terminalCount, 1)
    XCTAssertNil(fixture.controller.chordCoordinator?.disabledReason)
  }

  func testModeOffHandlesSequentialInputImmediatelyWithoutSourceLease() {
    let fixture = ChordHandleFixture(enabled: false)
    fixture.activate()

    XCTAssertTrue(fixture.down(.ansiK, text: "k"))

    XCTAssertEqual(fixture.client.string, "ㄱ")
    XCTAssertEqual(fixture.source.startCallCount, 0)
    XCTAssertNil(fixture.controller.chordCoordinator)
  }

  func testIneligibleLayoutDoesNotAcquireSourceLease() {
    let fixture = ChordHandleFixture(layout: .han2)
    fixture.activate()

    XCTAssertTrue(fixture.down(.ansiR, text: "r"))

    XCTAssertEqual(fixture.client.string, "ㄱ")
    XCTAssertEqual(fixture.source.startCallCount, 0)
    XCTAssertNil(fixture.controller.chordCoordinator)
  }

  func testPermissionDeniedUsesBaselineCompositionImmediately() {
    let fixture = ChordHandleFixture()
    fixture.source.permissionGranted = false
    fixture.activate()

    XCTAssertTrue(fixture.down(.ansiK, text: "k"))

    XCTAssertEqual(fixture.client.string, "ㄱ")
    XCTAssertEqual(fixture.source.activeLeaseCount, 0)
    XCTAssertEqual(fixture.controller.chordCoordinator?.disabledReason, .permissionLost)
    XCTAssertEqual(fixture.controller.chordCoordinator?.consumedStrokeCount, 0)
  }

  func testCommandBoundaryFlushesAndTheNextChordStillDefers() {
    let fixture = ChordHandleFixture()
    fixture.activate()
    fixture.down(.ansiK, text: "k")

    XCTAssertFalse(fixture.down(.ansiA, text: "a", at: 0.01, modifiers: .command))
    fixture.release(.ansiK, at: 0.02)
    fixture.release(.ansiA, at: 0.03)
    XCTAssertEqual(fixture.client.string, "ㄱ")
    XCTAssertNil(fixture.controller.chordCoordinator?.disabledReason)

    XCTAssertTrue(fixture.down(.ansiF, text: "f", at: 0.04))
    XCTAssertEqual(fixture.client.string, "ㄱ")
    fixture.release(.ansiF, at: 0.05)
    XCTAssertEqual(fixture.client.string, "ㄱㅏ")
  }

  func testClientRebindingCommitsOnlyToTheOriginalClient() {
    let fixture = ChordHandleFixture()
    fixture.activate()
    fixture.down(.ansiK, text: "k")
    let nextClient = MockInputClient()
    fixture.controller.testClient = nextClient

    fixture.controller.setValue(
      GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
      client: nextClient)

    XCTAssertEqual(fixture.client.string, "ㄱ")
    XCTAssertEqual(fixture.client.markedString(), "")
    XCTAssertEqual(nextClient.string, "")
    XCTAssertTrue(fixture.down(.ansiF, text: "f", at: 0.2))
    XCTAssertEqual(nextClient.string, "")
    fixture.release(.ansiF, at: 0.3)
    XCTAssertEqual(nextClient.string, "ㅏ")
    XCTAssertEqual(fixture.client.string, "ㄱ")
  }

  func testDeactivationReleasesLeaseAndReactivationRestartsIt() {
    let fixture = ChordHandleFixture()
    fixture.activate()
    XCTAssertEqual(fixture.source.activeLeaseCount, 1)

    fixture.controller.deactivatePhysicalInput()
    XCTAssertEqual(fixture.source.activeLeaseCount, 0)
    fixture.activate()
    XCTAssertEqual(fixture.source.activeLeaseCount, 1)
    XCTAssertEqual(fixture.source.startCallCount, 2)
  }
}

private final class StubChordMappingProvider: ChordLayoutMappingProviding {
  var mappings: [String: ChordLayoutMapping]
  private(set) var requested: [String] = []

  init(_ mappings: [String: ChordLayoutMapping] = [:]) { self.mappings = mappings }
  func mapping(for identifier: String) -> ChordLayoutMapping? {
    requested.append(identifier)
    return mappings[identifier]
  }
}

class ChordEmissionPolicyTests: IsolatedChordConfigurationTests {
  private func group(_ characters: String, reason: ChordFlushReason = .allReleased) -> StrokeGroup {
    let strokes = characters.enumerated().map { index, character -> ChordStroke in
      let (key, modifiers) = keyMapReversed[String(character)]!
      return ChordStroke(
        id: UInt64(index + 1), keyCode: key.rawValue, text: String(character),
        modifiers: modifiers.rawValue, timestamp: Double(index) * 0.01)
    }
    return StrokeGroup(strokes: strokes, reason: reason, completedAt: 0.1)
  }

  private func directory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    addTeardownBlock { try FileManager.default.removeItem(at: url) }
    return url
  }

  private func write(_ xml: String, id: String = "fixture", directory: URL) throws {
    try Data(xml.utf8).write(
      to: directory.appendingPathComponent("hangul-keyboard-\(id).xml"))
  }

  private func xml(_ items: String, id: String = "fixture", type: String = "jaso") -> String {
    "<hangul-keyboard id=\"\(id)\" type=\"\(type)\"><map id=\"0\">\(items)</map></hangul-keyboard>"
  }

  private func stubPolicy(
    id: String = "fixture", type: String = "jaso", values: [UInt32: UInt32]
  ) -> ChordEmissionPolicy {
    ChordEmissionPolicy(
      mappingProvider: StubChordMappingProvider([
        id: ChordLayoutMapping(identifier: id, keyboardType: type, asciiToScalar: values)
      ]))
  }

  func testBundledXmlContainsAllSupportedSebeolsikMappings() throws {
    let repository = ChordLayoutMappingRepository()
    for id in ["3f", "39", "3fs", "39s", "3-2011", "3-2012", "3s", "3y", "3gs", "3gc"] {
      let mapping = try XCTUnwrap(repository.mapping(for: id), id)
      XCTAssertEqual(mapping.identifier, id)
      XCTAssertEqual(mapping.asciiToScalar[0x66], 0x1161, id)
      XCTAssertEqual(mapping.asciiToScalar[0x6A], 0x110B, id)
      XCTAssertEqual(mapping.asciiToScalar[0x73], 0x11AB, id)
    }
  }

  func testEveryFjsPermutationAcrossSupportedLayoutsComposesAnWithReorderOff() {
    Configuration.shared.hangulAutoReorder = false
    let policy = ChordEmissionPolicy()
    for id in ["3f", "39", "3fs", "39s", "3-2011", "3-2012", "3s", "3y"] {
      for permutation in ["fjs", "fsj", "jfs", "jsf", "sfj", "sjf"] {
        let ordered = policy.order(group: group(permutation), keyboardIdentifier: id)
        XCTAssertEqual(ordered.map(\.text).joined(), "jfs", "\(id): \(permutation)")
        let app = ModerateApp()
        app.controller.setValue(
          GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
          client: app.client)
        app.controller.receiver.composer.hangulComposer.setKeyboard(identifier: id)
        for stroke in ordered {
          app.inputKey(
            KeyCode(rawValue: stroke.keyCode)!,
            modifiers: NSEvent.ModifierFlags(rawValue: stroke.modifiers))
        }
        XCTAssertEqual(app.client.string, "안", "\(id): \(permutation)")
      }
    }
  }

  func testOrderingPreservesOriginalOrderWithinEveryHangulRole() {
    let policy = stubPolicy(
      values: [
        0x6A: 0x110B, 0x6B: 0x1100, 0x66: 0x1161, 0x64: 0x1175, 0x73: 0x11AB, 0x78: 0x11A8,
      ])
    XCTAssertEqual(
      policy.order(group: group("sfdjkx"), keyboardIdentifier: "fixture").map(\.text).joined(),
      "jkfdsx")
  }

  func testPhysicalChordCanonicalizesAReversedCompoundVowelPair() {
    let policy = stubPolicy(
      id: "3f",
      values: [
        0x6B: 0x1100,  // k = ㄱ
        0x66: 0x1161,  // f = ㅏ
        0x76: 0x1169,  // v = ㅗ
      ])

    XCTAssertEqual(
      policy.order(group: group("kfv"), keyboardIdentifier: "3f").map(\.text).joined(),
      "kvf")
    XCTAssertEqual(
      policy.order(group: group("vfk"), keyboardIdentifier: "3f").map(\.text).joined(),
      "kvf")
  }

  func testPhysicalChordPreservesReversedMedialsForOldHangulLayouts() {
    let policy = stubPolicy(
      id: "3y", type: "jaso-yet",
      values: [
        0x6B: 0x1100,  // k = ㄱ
        0x66: 0x1161,  // f = ㅏ
        0x76: 0x1169,  // v = ㅗ
      ])

    XCTAssertEqual(
      policy.order(group: group("fvk"), keyboardIdentifier: "3y").map(\.text).joined(),
      "kfv")
  }

  func testPhysicalChordPreservesNormalReversedMedialsForStrictFinal() {
    let ordered = ChordEmissionPolicy().order(group: group("kfv"), keyboardIdentifier: "3fs")
    XCTAssertEqual(ordered.map(\.text).joined(), "kfv")
  }

  func testPhysicalChordStrictFinalUsesItsVirtualCompoundVowelKey() {
    Configuration.shared.hangulAutoReorder = false
    let ordered = ChordEmissionPolicy().order(group: group("kf/"), keyboardIdentifier: "3fs")
    XCTAssertEqual(ordered.map(\.text).joined(), "kf/")

    let app = ModerateApp()
    app.controller.setValue(
      GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
      client: app.client)
    app.controller.receiver.composer.hangulComposer.setKeyboard(identifier: "3fs")
    for stroke in ordered {
      app.inputKey(
        KeyCode(rawValue: stroke.keyCode)!,
        modifiers: NSEvent.ModifierFlags(rawValue: stroke.modifiers))
    }
    XCTAssertEqual(app.client.string, "과")
  }

  func testPhysicalChordReversedCompoundVowelComposesWithoutSequentialAutoReorder() {
    Configuration.shared.hangulAutoReorder = false
    let ordered = ChordEmissionPolicy().order(group: group("kfv"), keyboardIdentifier: "3f")
    XCTAssertEqual(ordered.map(\.text).joined(), "kvf")

    let app = ModerateApp()
    app.controller.setValue(
      GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
      client: app.client)
    for stroke in ordered {
      app.inputKey(
        KeyCode(rawValue: stroke.keyCode)!,
        modifiers: NSEvent.ModifierFlags(rawValue: stroke.modifiers))
    }
    XCTAssertEqual(app.client.string, "과")
  }

  func testStrictSelectionUsesTheSharedEffectiveIdentifierRule() {
    XCTAssertEqual(effectiveHangulKeyboardIdentifier("3f", strictCombinationRule: true), "3fs")
    XCTAssertEqual(effectiveHangulKeyboardIdentifier("39", strictCombinationRule: true), "39s")
    XCTAssertEqual(effectiveHangulKeyboardIdentifier("3f", strictCombinationRule: false), "3f")
    XCTAssertEqual(effectiveHangulKeyboardIdentifier("3gs", strictCombinationRule: true), "3gs")
    let provider = StubChordMappingProvider()
    let policy = ChordEmissionPolicy(mappingProvider: provider, strictCombinationRule: true)
    _ = policy.order(group: group("fjs"), keyboardIdentifier: "3f")
    _ = policy.order(group: group("fjs"), keyboardIdentifier: "39")
    XCTAssertEqual(provider.requested, ["3fs", "39s"])
  }

  func testComposerTracksTheActualStrictKeyboardIdentifier() {
    Configuration.shared.hangulForceStrictCombinationRule = true
    let composer = HangulComposer(type: .han3Final)
    XCTAssertEqual(composer.keyboardIdentifier, "3fs")
    composer.setKeyboard(identifier: "39")
    XCTAssertEqual(composer.keyboardIdentifier, "39s")
    Configuration.shared.hangulForceStrictCombinationRule = false
    composer.setKeyboard(identifier: "39")
    XCTAssertEqual(composer.keyboardIdentifier, "39")
  }

  func testShiftUsesTheUppercaseMapWhileCapsLockUsesTheLowercaseMap() {
    let policy = stubPolicy(values: [0x66: 0x1161, 0x4A: 0x110B, 0x6A: 0x1100, 0x73: 0x11AB])
    XCTAssertEqual(
      policy.order(group: group("fJs"), keyboardIdentifier: "fixture").map(\.text).joined(), "Jfs")
    let original = group("fjs")
    let caps = StrokeGroup(
      strokes: original.strokes.map {
        ChordStroke(
          id: $0.id, keyCode: $0.keyCode, text: $0.text,
          modifiers: NSEvent.ModifierFlags.capsLock.rawValue, timestamp: $0.timestamp)
      }, reason: original.reason, completedAt: original.completedAt)
    XCTAssertEqual(
      policy.order(group: caps, keyboardIdentifier: "fixture").map(\.text).joined(), "jfs")
  }

  func testVirtualJamoCodesAreClassifiedThroughLibhangulNormalization() {
    let policy = stubPolicy(values: [0x66: 0xE061, 0x6A: 0xE00B, 0x73: 0xE0AB])
    XCTAssertEqual(
      policy.order(group: group("sfj"), keyboardIdentifier: "fixture").map(\.text).joined(), "jfs")
  }

  func testSpecializedAndUnsupportedKeyboardTypesPreservePressOrder() {
    for (id, type) in [("3gs", "gureum"), ("3gc", "jaso"), ("fixture", "jamo")] {
      let policy = stubPolicy(
        id: id, type: type, values: [0x66: 0x1161, 0x6A: 0x110B, 0x73: 0x11AB])
      let original = group("sfj")
      XCTAssertEqual(policy.order(group: original, keyboardIdentifier: id), original.strokes)
    }
  }

  func testSymbolsUnknownKeysAndMissingMappingsPreservePressOrder() {
    let policy = ChordEmissionPolicy()
    for original in [group("fjs,"), group("fjs?")] {
      XCTAssertEqual(policy.order(group: original, keyboardIdentifier: "3f"), original.strokes)
    }
    let original = group("sfj")
    XCTAssertEqual(policy.order(group: original, keyboardIdentifier: "missing"), original.strokes)
    let unknown = StrokeGroup(
      strokes: [ChordStroke(id: 1, keyCode: -1, text: "x", modifiers: 0, timestamp: 0)],
      reason: .allReleased, completedAt: 0.1)
    XCTAssertEqual(policy.order(group: unknown, keyboardIdentifier: "3f"), unknown.strokes)
  }

  func testGroupsWithoutInitialAndMedialBothPresentPreserveOrder() {
    let policy = ChordEmissionPolicy()
    for original in [group("sf"), group("sj")] {
      XCTAssertEqual(policy.order(group: original, keyboardIdentifier: "3f"), original.strokes)
    }
  }

  func testRepositoryParsesOnlyMapZeroAndPreservesTheKeyboardType() throws {
    let directory = try directory()
    try write(
      "<hangul-keyboard id=\"fixture\" type=\"jaso-yet\"><map id=\"1\"><item key=\"0x66\" value=\"0x1100\"/></map><map id=\"0\"><item key=\"0x66\" value=\"0x1161\"/></map></hangul-keyboard>",
      directory: directory)
    let mapping = try XCTUnwrap(
      ChordLayoutMappingRepository(keyboardDirectoryURL: directory).mapping(for: "fixture"))
    XCTAssertEqual(mapping.keyboardType, "jaso-yet")
    XCTAssertEqual(mapping.asciiToScalar, [0x66: 0x1161])
  }

  func testRepositoryCachesLoadedMappingsAcrossFileChanges() throws {
    let directory = try directory()
    let repository = ChordLayoutMappingRepository(keyboardDirectoryURL: directory)
    try write(xml("<item key=\"0x66\" value=\"0x1161\"/>"), directory: directory)
    let first = try XCTUnwrap(repository.mapping(for: "fixture"))
    try write(xml("<item key=\"0x66\" value=\"0x1100\"/>"), directory: directory)
    XCTAssertEqual(repository.mapping(for: "fixture"), first)
    XCTAssertEqual(
      ChordLayoutMappingRepository(keyboardDirectoryURL: directory).mapping(for: "fixture")?
        .asciiToScalar[0x66],
      0x1100)
  }

  func testRepositoryCachesMissingMappings() throws {
    let directory = try directory()
    let repository = ChordLayoutMappingRepository(keyboardDirectoryURL: directory)
    XCTAssertNil(repository.mapping(for: "fixture"))
    try write(xml("<item key=\"0x66\" value=\"0x1161\"/>"), directory: directory)
    XCTAssertNil(repository.mapping(for: "fixture"))
    XCTAssertNotNil(
      ChordLayoutMappingRepository(keyboardDirectoryURL: directory).mapping(for: "fixture"))
  }

  func testMalformedOrAmbiguousXmlFallsBackToOriginalOrder() throws {
    let directory = try directory()
    let invalid = [
      "<invalid/>", "<hangul-keyboard>", xml("", id: "different"),
      xml("<item key=\"0x66\" value=\"0xD800\"/>"),
      xml("<item key=\"0x80\" value=\"0x1161\"/>"),
      xml("<item key=\"0x66\" value=\"0x1161\"/><item key=\"0x66\" value=\"0x1100\"/>"),
      "<hangul-keyboard id=\"fixture\" type=\"jaso\"><map id=\"1\"/></hangul-keyboard>",
      "<hangul-keyboard id=\"fixture\" type=\"jaso\"><map id=\"0\"/><map id=\"0\"/></hangul-keyboard>",
    ]
    for xml in invalid {
      try write(xml, directory: directory)
      let repository = ChordLayoutMappingRepository(keyboardDirectoryURL: directory)
      XCTAssertNil(repository.mapping(for: "fixture"), xml)
      let original = group("sfj")
      XCTAssertEqual(
        ChordEmissionPolicy(mappingProvider: repository).order(
          group: original, keyboardIdentifier: "fixture"),
        original.strokes)
    }
  }

  func testRepositoryRejectsPathTraversalIdentifiers() throws {
    let repository = ChordLayoutMappingRepository(keyboardDirectoryURL: try directory())
    for identifier in ["", "../3f", "/3f", "3f.xml", "3f/other"] {
      XCTAssertNil(repository.mapping(for: identifier))
    }
  }

  func testRepositoryLoadsKeyboardResourcesFromAnInjectedBundle() throws {
    let root = try directory()
    let bundleURL = root.appendingPathComponent("Fixture.bundle")
    let keyboards = bundleURL.appendingPathComponent("Contents/Resources/keyboards")
    try FileManager.default.createDirectory(at: keyboards, withIntermediateDirectories: true)
    try write(xml("<item key=\"0x66\" value=\"0x1161\"/>"), directory: keyboards)
    let info = try PropertyListSerialization.data(
      fromPropertyList: ["CFBundleIdentifier": "test.chord.fixture"], format: .xml, options: 0)
    try info.write(to: bundleURL.appendingPathComponent("Contents/Info.plist"))
    let repository = ChordLayoutMappingRepository(bundle: try XCTUnwrap(Bundle(url: bundleURL)))
    XCTAssertEqual(repository.mapping(for: "fixture")?.asciiToScalar[0x66], 0x1161)
  }

  func testRepositorySupportsConcurrentCachedLookups() throws {
    let repository = ChordLayoutMappingRepository()
    let expected = try XCTUnwrap(repository.mapping(for: "3f"))
    let lock = NSLock()
    var mismatches = 0
    DispatchQueue.concurrentPerform(iterations: 64) { _ in
      if repository.mapping(for: "3f") != expected {
        lock.lock()
        mismatches += 1
        lock.unlock()
      }
    }
    XCTAssertEqual(mismatches, 0)
  }

  func testPolicyTimingReportsMeasuredOverheadWithoutAFlakyThreshold() {
    let policy = ChordEmissionPolicy()
    let input = group("sfj")
    var timings: [TimeInterval] = []
    for _ in 0..<1000 {
      let start = ProcessInfo.processInfo.systemUptime
      let result = policy.order(group: input, keyboardIdentifier: "3f")
      timings.append(ProcessInfo.processInfo.systemUptime - start)
      XCTAssertEqual(result.map(\.text).joined(), "jfs")
    }
    timings.sort()
    print("Chord policy seconds p50=\(timings[500]) p95=\(timings[950]) p99=\(timings[990])")
  }
}

class PhysicalStrokeReplayTests: IsolatedChordConfigurationTests {
  private func finalApp() -> ModerateApp {
    let app = ModerateApp()
    app.controller.setValue(
      GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
      client: app.client)
    return app
  }

  func testPhysicalChordingIsDisabledByDefault() throws {
    let suite = "org.youknowone.Gureum.test.physical.\(UUID().uuidString)"
    let configuration = try XCTUnwrap(Configuration(suiteName: suite))
    defer { configuration.removePersistentDomain(forName: suite) }

    XCTAssertFalse(configuration.physicalChordingEnabled)
  }

  func testAcceptedReplayUsesTheExistingHangulComposer() {
    let app = finalApp()
    app.inputKeys("k")
    let stroke = ChordStroke(
      id: 1, keyCode: KeyCode.ansiF.rawValue, text: "f", modifiers: 0, timestamp: 0)

    let outcome = app.controller.replayPhysicalStroke(stroke, client: app.client)

    XCTAssertEqual(outcome, .composerReplay)
    XCTAssertEqual(app.client.string, "가")
    XCTAssertEqual(app.client.markedString(), "가")
    XCTAssertFalse(app.controller.receiver.inputting)
  }

  func testDeclinedReplayCommitsCompositionBeforeInsertingLiteralExactlyOnce() {
    let app = finalApp()
    app.inputKeys("kf")
    let stroke = ChordStroke(
      id: 1, keyCode: KeyCode.return.rawValue, text: "\n", modifiers: 0, timestamp: 0)

    let outcome = app.controller.replayPhysicalStroke(stroke, client: app.client)

    XCTAssertEqual(outcome, .literalFallback)
    XCTAssertEqual(app.client.string, "가\n")
    XCTAssertEqual(app.client.markedString(), "")
    XCTAssertFalse(app.controller.receiver.inputting)
  }

  func testUnknownKeyReplayInsertsLiteralIntoTheSuppliedClient() {
    let app = finalApp()
    let owner = MockInputClient()
    let stroke = ChordStroke(id: 1, keyCode: -1, text: "?", modifiers: 0, timestamp: 0)

    let outcome = app.controller.replayPhysicalStroke(stroke, client: owner)

    XCTAssertEqual(outcome, .literalFallback)
    XCTAssertEqual(owner.string, "?")
    XCTAssertEqual(app.client.string, "")
  }
}

class Han3FinalNoShiftTests: XCTestCase {
  let app = ModerateApp()

  override class func setUp() {
    Configuration.shared = Configuration(suiteName: "org.youknowone.Gureum.test")!
    super.setUp()
  }

  override class func tearDown() {
    super.tearDown()
  }

  override func setUp() {
    super.setUp()
    // Put setup code here. This method is called before the invocation of each test method in the class.

    Configuration.shared.removePersistentDomain(forName: GureumTests.domainName)

    app.client.string = ""
    app.controller.setValue(
      GureumInputSource.han3FinalNoShift.rawValue, forTag: kTextServiceInputModePropertyTag,
      client: app.client)
  }

  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    app.inputKey(.space)
    app.client.string = ""
    super.tearDown()
  }

  func testSymbol() {
    app.inputKey(.ansiQuote, modifiers: .shift)
    XCTAssertEqual("\"", app.client.string, "buffer: \(app.client.string) app: \(app)")
    app.client.string = ""
  }

  func testModeKeyAsSymbol() {
    app.inputKey(.ansiLeftBracket)
    XCTAssertEqual("[", app.client.string, "buffer: \(app.client.string) app: \(app)")
    XCTAssertEqual("[", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
    app.inputKey(.ansiLeftBracket)
    XCTAssertEqual("[[", app.client.string, "buffer: \(app.client.string) app: \(app)")
    XCTAssertEqual("[", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
  }

  func testBufferedJung() {
    app.test(input: "fd", expecteds: ["ㅏ", "ㅏㅣ"], markeds: ["ㅏ", "ㅏㅣ"])
    app.test(input: "fds", expecteds: ["ㅏ", "ㅏㅣ", "ㅏㅣㄴ"], markeds: ["ㅏ", "ㅏㅣ", "ㅣㄴ"])
    app.test(input: "fde", expecteds: ["ㅏ", "ㅏㅣ", "ㅏㅣㅕ"], markeds: ["ㅏ", "ㅏㅣ", "ㅣㅕ"])
    app.test(input: "fdk", expecteds: ["ㅏ", "ㅏㅣ", "ㅏ기"], markeds: ["ㅏ", "ㅏㅣ", "기"])
    app.test(input: "fdk", expecteds: ["ㅏ", "ㅏㅣ", "ㅏ기"], markeds: ["ㅏ", "ㅏㅣ", "기"])
    app.test(input: "fdsk", expecteds: ["ㅏ", "ㅏㅣ", "ㅏㅣㄴ", "ㅏ긴"], markeds: ["ㅏ", "ㅏㅣ", "ㅣㄴ", "긴"])
    app.test(
      input: "fsdk", expecteds: ["ㅏ", "ㅏㄴ", "ㅏㄴㅣ", "ㅏㄴ기"], markeds: ["ㅏ", "ㅏㄴ", "ㅣ", "기"],
      removeds: ["ㅏㄴㅣ", "ㅏㄴ"])
  }

  func test까() {
    app.test(input: "jkf", expecteds: [nil, nil, "까"])
    app.test(input: "kjf", expecteds: [nil, nil, "까"])
    app.test(input: "fkj", expecteds: [nil, nil, "까"])
    app.test(input: "fjk", expecteds: [nil, nil, "까"])
    app.test(input: "fkji", expecteds: [nil, nil, "까", "까ㅁ"], removeds: ["까", ""])
    app.test(input: "fjki", expecteds: [nil, nil, "까", "까ㅁ"], removeds: ["까", ""])
    app.test(input: "jfk", expecteds: [nil, nil, "아ㄱ"], removeds: ["아"])
    app.test(input: "kfj", expecteds: [nil, nil, "가ㅇ"], removeds: ["가"])
    app.test(input: "sjkf", expecteds: [nil, nil, nil, "깐"])
    app.test(input: "skjf", expecteds: [nil, nil, nil, "깐"])
    app.test(input: "sfkj", expecteds: [nil, nil, nil, "깐"])
    app.test(input: "sfjk", expecteds: [nil, nil, nil, "깐"])
    app.test(input: "jksf", expecteds: [nil, nil, nil, "깐"])
    app.test(input: "kjsf", expecteds: [nil, nil, nil, "깐"])
    app.test(input: "fskj", expecteds: [nil, nil, nil, "깐"])
    app.test(input: "fsjk", expecteds: [nil, nil, nil, "깐"])
  }

  func testㄺ() {
    app.test(input: "2[", expecteds: ["ㅆ", "ㄺ"], markeds: ["ㅆ", "ㄺ"])
    app.test(input: "[2", expecteds: ["[", "ㄺ"], markeds: ["[", "ㄺ"])
  }

  func test괜() {
    app.test(input: "k/r", expecteds: [nil, nil, "괘"])
    app.test(input: "k/rs", expecteds: [nil, nil, nil, "괜"])
    app.test(input: "kr/s", expecteds: [nil, nil, nil, "괜"])
    app.test(input: "krs/", expecteds: [nil, nil, nil, "괜"])
    app.test(input: "k/sr", expecteds: [nil, nil, nil, "괜"])
    app.test(input: "ks/r", expecteds: [nil, nil, nil, "괜"])
    app.test(input: "ksr/", expecteds: [nil, nil, nil, "괜"])
  }

  func test뚫() {
    app.test(input: "iub[r", expecteds: [nil, nil, nil, "뚜[", "뚫"])
    app.test(input: "iu[br", expecteds: [nil, nil, nil, "뚜[", "뚫"])
    app.test(input: "iubr[", expecteds: [nil, nil, nil, "뚜ㅐ", "뚫"])
    app.test(input: "iubr[[", expecteds: [nil, nil, nil, "뚜ㅐ", "뚫", "뚫["], removeds: ["뚫", ""])
    app.test(input: "bb[r", expecteds: [nil, nil, "ㅜㅜ[", "ㅜㅜㅀ"], markeds: [nil, nil, "ㅜ[", "ㅜㅀ"])
  }

  func test많() {
    app.test(
      input: "if[s[", expecteds: [nil, nil, "맒", "많", "많["], markeds: [nil, nil, nil, nil, "["],
      removeds: ["많", ""])
    app.test(input: "ifs[", expecteds: [nil, nil, nil, "많"])
    app.test(input: "i[fs", expecteds: [nil, nil, nil, "많"])
    app.test(input: "i[sf", expecteds: [nil, nil, nil, "많"])
    app.test(input: "isf[", expecteds: [nil, nil, nil, "많"])
    app.test(input: "is[f", expecteds: [nil, nil, nil, "많"])
    app.test(
      input: "isf[f", expecteds: [nil, nil, nil, "많", "많ㅏ"], markeds: [nil, nil, nil, nil, "ㅏ"],
      removeds: ["많", ""])
    app.test(
      input: "is[ff", expecteds: [nil, nil, nil, "많", "많ㅏ"], markeds: [nil, nil, nil, nil, "ㅏ"],
      removeds: ["많", ""])
    app.test(
      input: "isff", expecteds: [nil, nil, "만", "만ㅏ"], markeds: [nil, nil, nil, "ㅏ"],
      removeds: ["만", ""])
    app.test(
      input: "isf[s", expecteds: [nil, nil, nil, "많", "많ㄴ"], markeds: [nil, nil, nil, nil, "ㄴ"],
      removeds: ["많", ""])
    app.test(
      input: "is[fs", expecteds: [nil, nil, nil, "많", "많ㄴ"], markeds: [nil, nil, nil, nil, "ㄴ"],
      removeds: ["많", ""])
    app.test(
      input: "ifss", expecteds: [nil, nil, "만", "만ㄴ"], markeds: [nil, nil, nil, "ㄴ"],
      removeds: ["만", ""])
  }

  func test삶() {
    app.test(input: "nf[f", expecteds: [nil, nil, "삶", "삶"])
    app.test(input: "n[ff", expecteds: [nil, nil, "삶", "삶"])
    app.test(input: "nff[", expecteds: [nil, "사", "사ㅏ", "삶"])
    app.test(input: "f[n", expecteds: [nil, "ㅏㄻ", "삶"])
    app.test(input: "[fn", expecteds: [nil, "ㅏㄻ", "삶"])
    app.test(input: "[nf", expecteds: [nil, "ㅅ[", "삶"])
    app.test(input: "n[[f", expecteds: [nil, "ㅅ[", "ㅅ[[", "ㅅ[ㅏㄻ"])
    app.test(
      input: "f[[nf", expecteds: [nil, "ㅏㄻ", "ㅏㄻ[", "ㅏㄻㅅ[", "ㅏㄻ삶"],
      markeds: [nil, nil, "ㅏㄻ[", "ㅅ[", "삶"])
  }

  func test얹() {
    app.test(input: "jt[e", expecteds: [nil, nil, "엀", "얹"])
    app.test(input: "te[j", expecteds: [nil, "ㅓㅕ", "ㅓㄵ", "얹"])
  }
}

extension VirtualApp {
  func test(
    input: String, expecteds: [String?], markeds: [String?]? = nil, removeds: [String?]? = nil
  ) {
    var results: [(Character, String)] = []

    func strokes() -> String {
      String(Array(results.map { $0.0 }))
    }

    XCTAssertEqual(client.string, "", "app.client.string is not cleared")
    for (i, keyChar) in input.enumerated() {
      let key = "\(keyChar)"
      results.append((keyChar, client.string))
      inputKeys(key)
      if let expected = expecteds[i] {
        XCTAssertEqual(
          expected, client.string,
          "strokes: \(strokes()) buffer: \(client.string) marked: \(client.markedString()) app: \(self)"
        )
      }
      if let markeds = markeds {
        if let marked = markeds[i] {
          XCTAssertEqual(
            marked, client.markedString(),
            "buffer: \(client.string) marked: \(client.markedString()) app: \(self)")
        }
      }
    }
    if var removeds = removeds {
      while let removed = removeds.first {
        removeds.remove(at: 0)
        inputDelete()
        XCTAssertEqual(
          removed, client.string,
          "buffer: \(client.string) marked: \(client.markedString()) app: \(self)")
      }
    } else {
      while let (keyChar, result) = results.popLast() {
        inputDelete()
        XCTAssertEqual(
          result, client.string,
          "strokes: \(strokes())<BS(\(keyChar))> buffer: \(client.string) marked: \(client.markedString()) app: \(self)"
        )
      }
    }

    inputKey(.space)
    client.string = ""

    inputKeys(input)
    let result = client.string
    inputKey(.ansiK)
    inputDelete()
    XCTAssertEqual(
      result, client.string,
      "input: \(input) 'k' and delete fails buffer: \(client.string) marked: \(client.markedString()) app: \(self)"
    )

    inputKey(.ansiF)
    inputDelete()
    XCTAssertEqual(
      result, client.string,
      "input: \(input) 'f' and delete fails buffer: \(client.string) marked: \(client.markedString()) app: \(self)"
    )

    inputKey(.ansiS)
    inputDelete()
    XCTAssertEqual(
      result, client.string,
      "input: \(input) 's' and delete fails buffer: \(client.string) marked: \(client.markedString()) app: \(self)"
    )

    inputKey(.space)
    client.string = ""
  }
}
