//
//  PreferenceViewController.swift
//  Preferences
//
//  Created by Jeong YunWon on 2017. 11. 29..
//  Copyright © 2017 youknowone.org. All rights reserved.
//

import Cocoa
import Foundation
import MASShortcut
import UniformTypeIdentifiers

@objc(SystemSettingsPopUpButtonCell)
final class SystemSettingsPopUpButtonCell: NSPopUpButtonCell {
  override func drawTitle(
    _ title: NSAttributedString, withFrame frame: NSRect, in controlView: NSView
  ) -> NSRect {
    var titleFrame = frame
    titleFrame.size.width = max(0, titleFrame.width - 24)
    return super.drawTitle(title, withFrame: titleFrame, in: controlView)
  }
}

@objc(SystemSettingsPopUpButton)
final class SystemSettingsPopUpButton: NSPopUpButton {
  private var usesSystemSettingsAccessory = false
  private static let accessoryDiameter: CGFloat = 20

  override init(frame buttonFrame: NSRect, pullsDown flag: Bool) {
    super.init(frame: buttonFrame, pullsDown: flag)
    let replacement = SystemSettingsPopUpButtonCell(textCell: "")
    replacement.pullsDown = flag
    replacement.menu = menu
    cell = replacement
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  override var intrinsicContentSize: NSSize {
    var size = super.intrinsicContentSize
    if usesSystemSettingsAccessory {
      size.width += 30
      size.height = max(size.height, Self.accessoryDiameter)
    }
    return size
  }

  func applySystemSettingsStyle() {
    usesSystemSettingsAccessory = true
    isBordered = false
    controlSize = .small
    alignment = .right
    (cell as? NSPopUpButtonCell)?.arrowPosition = .noArrow
    invalidateIntrinsicContentSize()
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    guard usesSystemSettingsAccessory else { return }

    let diameter = Self.accessoryDiameter
    let bounds = NSRect(
      x: self.bounds.maxX - diameter,
      y: self.bounds.midY - diameter / 2,
      width: diameter,
      height: diameter)
    NSColor.quaternaryLabelColor.setFill()
    NSBezierPath(ovalIn: bounds).fill()

    guard
      let symbol = NSImage(
        systemSymbolName: "chevron.up.chevron.down", accessibilityDescription: nil),
      let configured = symbol.withSymbolConfiguration(
        NSImage.SymbolConfiguration(pointSize: 8, weight: .semibold)
          .applying(NSImage.SymbolConfiguration(paletteColors: [.secondaryLabelColor])))
    else { return }
    configured.draw(
      in: NSRect(x: bounds.minX + 5, y: bounds.minY + 4, width: 10, height: 12),
      from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
  }

}

final class KeyboardPreviewView: NSView {
  private static let physicalKeys: [UInt16: String] = [
    0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
    8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r", 16: "y",
    17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=",
    25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "o", 32: "u",
    33: "[", 34: "i", 35: "p", 37: "l", 38: "j", 39: "'", 40: "k", 41: ";",
    42: "\\", 43: ",", 44: "/", 45: "n", 46: "m", 47: ".", 50: "`",
  ]
  private static let shiftedKeys = Dictionary(
    uniqueKeysWithValues: zip(
      Array("`1234567890-=qwertyuiop[]\\asdfghjkl;'zxcvbnm,./").map(String.init),
      Array("~!@#$%^&*()_+QWERTYUIOP{}|ASDFGHJKL:\"ZXCVBNM<>?").map(String.init)))
  private static let rows: [[String]] = [
    Array("`1234567890-=").map { String($0) },
    Array("qwertyuiop[]\\").map { String($0) },
    Array("asdfghjkl;'").map { String($0) },
    Array("zxcvbnm,./").map { String($0) },
  ]
  private static let rowInsets: [CGFloat] = [0, 14, 28, 48]
  private(set) var labels: [String: String] = [:]
  private(set) var layoutName: String
  private(set) var isAvailable = false
  private(set) var isShiftPressed = false
  private(set) var pressedKeys: Set<String> = []
  private var eventMonitor: Any?
  private var windowObservers: [NSObjectProtocol] = []
  private var releaseWorkItems: [String: DispatchWorkItem] = [:]

  init(layoutIdentifier: String, layoutName: String) {
    self.layoutName = layoutName
    super.init(frame: .zero)
    setAccessibilityElement(true)
    setAccessibilityRole(.group)
    reload(layoutIdentifier: layoutIdentifier, layoutName: layoutName)
  }

  required init?(coder: NSCoder) {
    return nil
  }

  deinit {
    stopObservingKeyboard()
  }

  override var isFlipped: Bool { true }
  override var intrinsicContentSize: NSSize { NSSize(width: 432, height: 120) }

  override func viewWillMove(toWindow newWindow: NSWindow?) {
    stopObservingKeyboard()
    super.viewWillMove(toWindow: newWindow)
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    guard let window else { return }
    eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) {
      [weak self] event in
      guard let self else { return event }
      guard self.window?.isKeyWindow == true,
        event.window == nil || event.window === self.window,
        !self.isHiddenOrHasHiddenAncestor
      else {
        self.resetInteraction()
        return event
      }
      return self.observeKeyboardEvent(event)
    }
    windowObservers = [
      NotificationCenter.default.addObserver(
        forName: NSWindow.didResignKeyNotification, object: window, queue: .main
      ) { [weak self] _ in self?.resetInteraction() },
      NotificationCenter.default.addObserver(
        forName: NSWindow.willCloseNotification, object: window, queue: .main
      ) { [weak self] _ in self?.stopObservingKeyboard() },
    ]
  }

  private func stopObservingKeyboard() {
    if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
    eventMonitor = nil
    windowObservers.forEach(NotificationCenter.default.removeObserver)
    windowObservers.removeAll()
    resetInteraction()
  }

  private func resetInteraction() {
    for workItem in releaseWorkItems.values { workItem.cancel() }
    releaseWorkItems.removeAll()
    pressedKeys.removeAll()
    isShiftPressed = false
    updateAccessibilityValue()
    needsDisplay = true
  }

  @discardableResult
  func observeKeyboardEvent(_ event: NSEvent) -> NSEvent {
    isShiftPressed = event.modifierFlags.contains(.shift)
    if let key = Self.physicalKeys[event.keyCode] {
      if event.type == .keyDown {
        releaseWorkItems.removeValue(forKey: key)?.cancel()
        pressedKeys.insert(key)
      } else if event.type == .keyUp {
        releaseWorkItems.removeValue(forKey: key)?.cancel()
        let release = DispatchWorkItem { [weak self] in
          self?.pressedKeys.remove(key)
          self?.releaseWorkItems.removeValue(forKey: key)
          self?.updateAccessibilityValue()
          self?.needsDisplay = true
        }
        releaseWorkItems[key] = release
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: release)
      }
    }
    updateAccessibilityValue()
    needsDisplay = true
    return event
  }

  func visibleLabel(for key: String) -> String {
    let mappedKey = isShiftPressed ? Self.shiftedKeys[key] ?? key : key
    return labels[mappedKey] ?? mappedKey
  }

  private func updateAccessibilityValue() {
    guard isAvailable else {
      setAccessibilityValue("\(layoutName) 미리보기를 불러올 수 없음")
      return
    }
    var value = "현재 한글 자판 \(layoutName)"
    if isShiftPressed { value += ", Shift 누름" }
    if !pressedKeys.isEmpty {
      value +=
        ", \(pressedKeys.sorted().map { visibleLabel(for: $0) }.joined(separator: ", ")) 키 누름"
    }
    setAccessibilityValue(value)
  }

  func reload(layoutIdentifier: String, layoutName: String) {
    let loadedLabels = Self.loadLabels(layoutIdentifier: layoutIdentifier)
    labels = loadedLabels ?? [:]
    isAvailable = loadedLabels != nil
    self.layoutName = layoutName
    setAccessibilityLabel("\(layoutName) 키보드 미리보기")
    resetInteraction()
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    guard isAvailable else {
      let message = "자판 미리보기를 불러올 수 없습니다."
      let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12),
        .foregroundColor: NSColor.secondaryLabelColor,
      ]
      let size = message.size(withAttributes: attributes)
      message.draw(
        at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2),
        withAttributes: attributes)
      return
    }
    let keySize = NSSize(width: 28, height: 24)
    let gap: CGFloat = 4
    let top: CGFloat = 8
    for (rowIndex, keys) in Self.rows.enumerated() {
      let rowWidth = CGFloat(keys.count) * keySize.width + CGFloat(keys.count - 1) * gap
      var x = max(10, (bounds.width - 412) / 2 + Self.rowInsets[rowIndex])
      if rowIndex == 0 { x = max(10, (bounds.width - rowWidth) / 2) }
      let y = top + CGFloat(rowIndex) * (keySize.height + gap)
      for key in keys {
        let frame = NSRect(origin: NSPoint(x: x, y: y), size: keySize)
        let isPressed = pressedKeys.contains(key)
        (isPressed ? NSColor.selectedControlColor : NSColor.controlColor).setFill()
        NSBezierPath(roundedRect: frame, xRadius: 4, yRadius: 4).fill()
        let label = visibleLabel(for: key)
        let attributes: [NSAttributedString.Key: Any] = [
          .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
          .foregroundColor: isPressed ? NSColor.selectedControlTextColor : NSColor.labelColor,
        ]
        let size = label.size(withAttributes: attributes)
        label.draw(
          at: NSPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2),
          withAttributes: attributes)
        x += keySize.width + gap
      }
    }
  }

  static func layout(for inputMode: String, strict: Bool) -> (identifier: String, name: String) {
    let suffix = inputMode.split(separator: ".").last.map(String.init) ?? "han2"
    let values: [String: (String, String)] = [
      "han2": ("2-full", "두벌식"), "han2classic": ("2y-full", "두벌식 옛글"),
      "han3final": (strict ? "3fs" : "3f", "세벌식 최종"),
      "han390": (strict ? "39s" : "39", "세벌식 390"),
      "han3noshift": ("3s", "세벌식 순아래"), "han3classic": ("3y", "세벌식 옛글"),
      "han3layout2": ("32", "세벌식 두벌식 배치"), "hanroman": ("ro", "세벌식 로마자"),
      "hanahnmatae": ("ahn", "안마태"), "han3finalnoshift": ("3gs", "세벌식 최종 순아래"),
      "han3-2011": ("3-2011", "세벌식 2011"), "han3-2012": ("3-2012", "세벌식 2012"),
    ]
    return values[suffix] ?? (suffix, "알 수 없는 자판")
  }

  private static func loadLabels(layoutIdentifier: String) -> [String: String]? {
    guard let frameworks = Bundle.main.privateFrameworksURL,
      let bundle = Bundle(url: frameworks.appendingPathComponent("Hangul.framework")),
      let url = bundle.url(
        forResource: "hangul-keyboard-\(layoutIdentifier)", withExtension: "xml",
        subdirectory: "keyboards"),
      let parser = XMLParser(contentsOf: url)
    else { return nil }
    let delegate = KeyboardPreviewXMLParser()
    parser.delegate = delegate
    parser.shouldResolveExternalEntities = false
    guard parser.parse() else { return nil }
    return delegate.values.reduce(into: [:]) { result, entry in
      guard let keyScalar = UnicodeScalar(entry.key), let output = displayLabel(for: entry.value)
      else { return }
      result[String(keyScalar)] = output
    }
  }

  private static func displayLabel(for scalar: UInt32) -> String? {
    let scalar = (0xE000...0xE0FF).contains(scalar) ? scalar - 0xE000 + 0x1100 : scalar
    let compatibility: [UInt32: String] = [
      0x1100: "ㄱ", 0x1101: "ㄲ", 0x1102: "ㄴ", 0x1103: "ㄷ", 0x1104: "ㄸ",
      0x1105: "ㄹ", 0x1106: "ㅁ", 0x1107: "ㅂ", 0x1108: "ㅃ", 0x1109: "ㅅ",
      0x110A: "ㅆ", 0x110B: "ㅇ", 0x110C: "ㅈ", 0x110D: "ㅉ", 0x110E: "ㅊ",
      0x110F: "ㅋ", 0x1110: "ㅌ", 0x1111: "ㅍ", 0x1112: "ㅎ",
      0x1161: "ㅏ", 0x1162: "ㅐ", 0x1163: "ㅑ", 0x1164: "ㅒ", 0x1165: "ㅓ",
      0x1166: "ㅔ", 0x1167: "ㅕ", 0x1168: "ㅖ", 0x1169: "ㅗ", 0x116A: "ㅘ",
      0x116B: "ㅙ", 0x116C: "ㅚ", 0x116D: "ㅛ", 0x116E: "ㅜ", 0x116F: "ㅝ",
      0x1170: "ㅞ", 0x1171: "ㅟ", 0x1172: "ㅠ", 0x1173: "ㅡ", 0x1174: "ㅢ",
      0x1175: "ㅣ",
      0x11A8: "ㄱ", 0x11A9: "ㄲ", 0x11AA: "ㄳ", 0x11AB: "ㄴ", 0x11AC: "ㄵ",
      0x11AD: "ㄶ", 0x11AE: "ㄷ", 0x11AF: "ㄹ", 0x11B0: "ㄺ", 0x11B1: "ㄻ",
      0x11B2: "ㄼ", 0x11B3: "ㄽ", 0x11B4: "ㄾ", 0x11B5: "ㄿ", 0x11B6: "ㅀ",
      0x11B7: "ㅁ", 0x11B8: "ㅂ", 0x11B9: "ㅄ", 0x11BA: "ㅅ", 0x11BB: "ㅆ",
      0x11BC: "ㅇ", 0x11BD: "ㅈ", 0x11BE: "ㅊ", 0x11BF: "ㅋ", 0x11C0: "ㅌ",
      0x11C1: "ㅍ", 0x11C2: "ㅎ",
    ]
    if let label = compatibility[scalar] { return label }
    guard let unicodeScalar = UnicodeScalar(scalar) else { return nil }
    return String(unicodeScalar)
  }
}

private final class KeyboardPreviewXMLParser: NSObject, XMLParserDelegate {
  var values: [UInt32: UInt32] = [:]
  private var inPrimaryMap = false

  func parser(
    _: XMLParser, didStartElement elementName: String, namespaceURI _: String?,
    qualifiedName _: String?, attributes: [String: String]
  ) {
    if elementName == "map" { inPrimaryMap = attributes["id"] == "0" }
    guard inPrimaryMap, elementName == "item",
      let key = Self.scalar(attributes["key"]), let value = Self.scalar(attributes["value"])
    else { return }
    values[key] = value
  }

  func parser(
    _: XMLParser, didEndElement elementName: String, namespaceURI _: String?,
    qualifiedName _: String?
  ) {
    if elementName == "map" { inPrimaryMap = false }
  }

  private static func scalar(_ value: String?) -> UInt32? {
    guard let value else { return nil }
    return value.lowercased().hasPrefix("0x")
      ? UInt32(value.dropFirst(2), radix: 16) : UInt32(value)
  }
}

private final class PreferencesDocumentView: NSView {
  override var isFlipped: Bool { true }
}

private final class KoreanShortcutCell: MASShortcutViewButtonCell {
  private static let koreanResources: Bundle? = {
    for owner in [
      Bundle.main, Bundle(for: MASShortcutView.self), Bundle(for: PreferenceViewController.self),
    ] {
      let resources =
        owner.url(forResource: "MASShortcut_MASShortcut", withExtension: "bundle")
        ?? owner.bundleURL.deletingLastPathComponent().appendingPathComponent(
          "MASShortcut_MASShortcut.bundle")
      if let bundle = Bundle(url: resources),
        let path = bundle.path(forResource: "ko", ofType: "lproj")
      {
        return Bundle(path: path)
      }
    }
    return nil
  }()

  override var title: String? {
    get { super.title }
    set {
      guard let value = newValue else {
        super.title = nil
        return
      }
      let fallback = value == "Record Shortcut" ? "단축키 입력" : value
      super.title =
        Self.koreanResources?.localizedString(forKey: value, value: fallback, table: nil)
        ?? fallback
    }
  }
}

@objc(GureumShortcutView)
private final class GureumShortcutView: MASShortcutView {
  override class func shortcutCellClass() -> AnyClass { KoreanShortcutCell.self }
}

#if !USE_PREFPANE
  import GureumCore
#endif

@objc(PreferenceViewController)
final class PreferenceViewController: NSViewController, NSTextFieldDelegate {
  private(set) var productIdentity = InputMethodIdentity.current
  @IBOutlet private var debugButton: NSButton!
  /// 옵션 키 동작.
  @IBOutlet private var optionKeyBehaviorButton: NSPopUpButton!

  /// 한글 입력기일 때 역따옴표(`)로 원화 기호(₩) 입력.
  @IBOutlet private var hangulWonCurrencySymbolForBackQuoteButton: NSButton!
  private var hangulBackQuoteOutputCharacterField: NSTextField!
  private var hangulShiftBackQuoteOutputCharacterField: NSTextField!
  private var hangulSpecialCharacterHelp: NSTextField!
  private var editedSpecialCharacterFields: Set<ObjectIdentifier> = []
  private var escapeKeyApplicationMenu: SystemSettingsPopUpButton!
  private var autocorrectionApplicationMenu: SystemSettingsPopUpButton!
  private var keyboardPreview: KeyboardPreviewView?
  /// 완성되지 않은 낱자 자동 교정 (모아치기).
  @IBOutlet private var hangulAutoReorderButton: NSButton!
  /// 두벌식 초성 조합 중에도 종성 결합 허용 (MS윈도 호환).
  @IBOutlet private var hangulNonChoseongCombinationButton: NSButton!
  /// 모든 글자를 조합중인 글자로 취급 (JDK 호환).
  @IBOutlet private var hangulDeferredSymbolCommitButton: NSButton!
  /// 세벌식 정석 강요.
  @IBOutlet private var hangulForceStrictCombinationRuleButton: NSButton!
  /// Esc 키로 로마자 자판으로 전환 (vi 모드).
  @IBOutlet private var romanModeByEscapeKeyButton: NSButton!
  /// 우측 키로 언어 전환
  @IBOutlet private var rightToggleKeyButton: NSPopUpButton!

  /// 입력기 바꾸기 단축키.
  @IBOutlet private var inputModeExchangeShortcutView: MASShortcutView!
  /// 한자 및 이모지 검색 단축키.
  @IBOutlet private var inputModeSearchShortcutView: MASShortcutView!
  /// 로마자로 바꾸기 단축키.
  @IBOutlet private var inputModeEnglishShortcutView: MASShortcutView!
  /// 한글로 바꾸기 단축키.
  @IBOutlet private var inputModeKoreanShortcutView: MASShortcutView!

  /// 업데이트 알림 받기
  @IBOutlet private var updateNotificationButton: NSButton!
  /// 실험버전 업데이트 알림 받기
  @IBOutlet private var updateNotificationExperimentalButton: NSButton!

  private let configuration = Configuration()
  private let pane: GureumPreferencePane! = nil
  private let shortcutValidator = GureumShortcutValidator()
  private let backgroundQueue = DispatchQueue.global(qos: .background)
  private var preferencePages: [NSView] = []
  private var switchBindings: [NSSwitch: NSButton] = [:]
  private var preferenceKeyViews: [[NSView]] = []
  private var buildingKeyViews: [NSView] = []
  private var sectionPicker: NSSegmentedControl!
  private let sectionTitles = ["입력", "단축키", "고급"]
  private static let hangulSpecialCharacterHelpText =
    "한글 입력 중 사용할 문자 한 개를 입력하세요. 비우면 현재 자판의 기본 문자를 사용합니다."
  private static let hangulSpecialCharacterErrorText = "한 글자만 입력하세요. 예: ₩ · @ …"
  #if !USE_PREFPANE
    private var physicalChordSwitch: NSSwitch?
    private var physicalChordStatus: NSTextField?
    private var physicalChordPermissionButton: NSButton?
  #endif

  private lazy var inputSources: [(identifier: String, localizedName: String)] = {
    let abcIdentifier = "com.apple.keylayout.ABC"

    guard
      let rawSources = TISInputSource.sources(
        withProperties: [
          kTISPropertyInputSourceType!: kTISTypeKeyboardLayout!,
          kTISPropertyInputSourceIsASCIICapable!: true,
        ], includeAllInstalled: true)
    else {
      return []
    }

    let unsortedSources = rawSources.map {
      (identifier: $0.identifier, localizedName: $0.localizedName, enabled: $0.enabled)
    }
    let sortedSources = unsortedSources.sorted {
      if $0.identifier == abcIdentifier {
        return true
      } else if $1.identifier == abcIdentifier {
        return false
      }
      if $0.enabled != $1.enabled {
        return $0.enabled
      }
      return $0.localizedName < $1.localizedName
    }
    let sources = sortedSources.map { (identifier: $0.identifier, localizedName: $0.localizedName) }
    return sources
  }()

  override func viewDidLoad() {
    hangulWonCurrencySymbolForBackQuoteButton.state = isOn(
      configuration.hangulWonCurrencySymbolForBackQuote)
    romanModeByEscapeKeyButton.state = isOn(configuration.romanModeByEscapeKey)
    hangulAutoReorderButton.state = isOn(configuration.hangulAutoReorder)
    hangulNonChoseongCombinationButton.state = isOn(configuration.hangulNonChoseongCombination)
    hangulDeferredSymbolCommitButton.state = isOn(configuration.hangulDeferredSymbolCommit)
    hangulForceStrictCombinationRuleButton.state = isOn(
      configuration.hangulForceStrictCombinationRule)
    switch configuration.rightToggleKey {
    case kHIDUsage_KeyboardRightGUI:
      rightToggleKeyButton.selectItem(at: 1)
    case kHIDUsage_KeyboardRightAlt:
      rightToggleKeyButton.selectItem(at: 2)
    case kHIDUsage_KeyboardRightControl:
      rightToggleKeyButton.selectItem(at: 3)
    default:
      rightToggleKeyButton.selectItem(at: 0)
    }
    if (0..<optionKeyBehaviorButton.numberOfItems).contains(configuration.optionKeyBehavior) {
      optionKeyBehaviorButton.selectItem(at: configuration.optionKeyBehavior)
    }

    inputModeExchangeShortcutView.shortcutValidator = shortcutValidator
    inputModeSearchShortcutView.shortcutValidator = shortcutValidator
    inputModeEnglishShortcutView.shortcutValidator = shortcutValidator
    inputModeKoreanShortcutView.shortcutValidator = shortcutValidator

    loadShortcutValues()
    setupShortcutViewValueChangeEvents()

    configureUpdateControls()

    debugButton.isHidden = true
    buildSettingsForm()
  }

  func configureProductIdentity(_ identity: InputMethodIdentity) {
    guard
      productIdentity.productKind != identity.productKind
        || productIdentity.supportsUpdates != identity.supportsUpdates
    else { return }
    productIdentity = identity
    if isViewLoaded {
      configureUpdateControls()
      buildSettingsForm()
    }
  }

  private func configureUpdateControls() {
    updateNotificationButton.state = isOn(configuration.updateNotification)
    updateNotificationButton.isEnabled = true
    updateNotificationExperimentalButton.isEnabled = true
    let identity = productIdentity
    if !identity.supportsUpdates {
      updateNotificationButton.state = .off
      updateNotificationButton.isEnabled = false
      updateNotificationExperimentalButton.state = .off
      updateNotificationExperimentalButton.isEnabled = false
    } else if !identity.supportsExperimentalUpdates {
      updateNotificationButton.isEnabled = true
      updateNotificationExperimentalButton.state = .off
      updateNotificationExperimentalButton.isEnabled = false
    } else if Bundle.main.isExperimental {
      updateNotificationExperimentalButton.state = .on
      updateNotificationExperimentalButton.isEnabled = false
    } else {
      updateNotificationExperimentalButton.state = isOn(
        configuration.updateNotificationExperimental)
    }
  }

  override func viewDidAppear() {
    super.viewDidAppear()
    updateKeyViewLoop()
    view.window?.makeFirstResponder(nil)
  }

  /// The nib owns the existing setting controls and actions; this form gives them a
  /// consistent native presentation without changing the stored preferences.
  private func buildSettingsForm() {
    for subview in view.subviews { subview.removeFromSuperview() }
    NSLayoutConstraint.deactivate(view.constraints)
    view.setFrameSize(NSSize(width: 500, height: 440))
    preferenceKeyViews.removeAll()
    buildingKeyViews.removeAll()
    switchBindings.removeAll()

    sectionPicker = NSSegmentedControl(
      labels: sectionTitles, trackingMode: .selectOne,
      target: self, action: #selector(selectSettingsSection(_:)))
    sectionPicker.segmentStyle = .automatic
    sectionPicker.controlSize = .regular
    sectionPicker.selectedSegment = 0
    sectionPicker.setAccessibilityLabel("설정 카테고리")
    sectionPicker.translatesAutoresizingMaskIntoConstraints = false
    #if USE_PREFPANE
      view.addSubview(sectionPicker)
    #else
      sectionPicker.isHidden = true
    #endif

    let layoutMenu = SystemSettingsPopUpButton(frame: .zero, pullsDown: false)
    layoutMenu.addItems(withTitles: inputSources.map(\.localizedName))
    if let index = inputSources.firstIndex(where: {
      $0.identifier == configuration.overridingKeyboardName
    }) {
      layoutMenu.selectItem(at: index)
    }
    layoutMenu.target = self
    layoutMenu.action = #selector(layoutMenuChanged(_:))
    styleMenu(layoutMenu, label: "키보드 레이아웃")
    styleMenu(rightToggleKeyButton, label: "오른쪽 전환 키")
    styleMenu(optionKeyBehaviorButton, label: "Option 키 동작")
    hangulBackQuoteOutputCharacterField = specialCharacterField(
      value: configuration.hangulBackQuoteOutputCharacter, label: "` 키 문자")
    hangulShiftBackQuoteOutputCharacterField = specialCharacterField(
      value: configuration.hangulShiftBackQuoteOutputCharacter, label: "Shift+` 키 문자")
    hangulSpecialCharacterHelp = helperText(Self.hangulSpecialCharacterHelpText)
    escapeKeyApplicationMenu = SystemSettingsPopUpButton(frame: .zero, pullsDown: false)
    escapeKeyApplicationMenu.target = self
    escapeKeyApplicationMenu.action = #selector(escapeKeyApplicationMenuChanged(_:))
    styleMenu(escapeKeyApplicationMenu, label: "Esc로 로마자 전환")
    refreshEscapeKeyApplicationMenu()
    autocorrectionApplicationMenu = SystemSettingsPopUpButton(frame: .zero, pullsDown: false)
    autocorrectionApplicationMenu.target = self
    autocorrectionApplicationMenu.action = #selector(autocorrectionApplicationMenuChanged(_:))
    styleMenu(autocorrectionApplicationMenu, label: "실험 · 자동 한영 전환")
    refreshAutocorrectionApplicationMenu()

    var inputSections: [NSView] = [
      section(
        "한글 조합",
        rows: [
          settingRow(
            "모아치기",
            control: settingSwitch(hangulAutoReorderButton, label: "모아치기")),
          settingRow(
            "세벌식 정석 조합",
            control: settingSwitch(hangulForceStrictCombinationRuleButton, label: "세벌식 정석 조합")),
        ],
        explanation: helperText(
          "모아치기는 순서가 바뀐 낱자를 자동으로 조합합니다. 정석 조합은 세벌식 최종·390에서 이중모음과 겹받침을 해당 자판 규칙으로 제한합니다.")),
      section(
        "특수문자 키",
        rows: [
          settingRow("` 키 문자", control: hangulBackQuoteOutputCharacterField),
          settingRow("Shift+` 키 문자", control: hangulShiftBackQuoteOutputCharacterField),
        ], explanation: hangulSpecialCharacterHelp),
      section(
        "로마자 입력",
        rows: [
          settingRow("키보드 레이아웃", control: layoutMenu),
          settingRow("Option 키 동작", control: optionKeyBehaviorButton),
        ], explanation: helperText("선택한 레이아웃은 로마자 입력과 한글 입력 중 로마자 단축키에 함께 적용됩니다.")),
    ]
    #if !USE_PREFPANE
      let previewLayout = KeyboardPreviewView.layout(
        for: configuration.lastHangulInputMode,
        strict: configuration.hangulForceStrictCombinationRule)
      let preview = KeyboardPreviewView(
        layoutIdentifier: previewLayout.identifier, layoutName: previewLayout.name)
      keyboardPreview = preview
      preview.translatesAutoresizingMaskIntoConstraints = false
      preview.heightAnchor.constraint(equalToConstant: 120).isActive = true
      inputSections.append(
        section(
          "현재 한글 자판", rows: [preview],
          explanation: helperText("현재 한글 자판입니다. 키를 누르면 해당 위치가 반응하고 Shift를 누르면 윗글자를 표시합니다.")))
    #endif
    let inputPage = page(inputSections)

    let shortcutsPage = page([
      section(
        "입력 전환",
        rows: [
          settingRow(
            "한글 ↔ 로마자",
            control: shortcutControl(inputModeExchangeShortcutView, label: "한글 ↔ 로마자")),
          settingRow(
            "한자 및 이모지",
            control: shortcutControl(inputModeSearchShortcutView, label: "한자 및 이모지")),
          settingRow(
            "로마자로 전환", control: shortcutControl(inputModeEnglishShortcutView, label: "로마자로 전환")),
          settingRow(
            "한글로 전환", control: shortcutControl(inputModeKoreanShortcutView, label: "한글로 전환")),
        ]),
      section(
        "오른쪽 키 전환",
        rows: [
          settingRow("오른쪽 전환 키", control: rightToggleKeyButton),
          settingRow(
            "키 감지 권한",
            control: settingsButton(
              for: "키 감지 권한", action: #selector(openInputMonitoringPreference(sender:)))),
        ], explanation: helperText("오른쪽 키 전환과 실험 동시입력에만 필요합니다. 일반 입력에는 필요하지 않습니다.")),
      section(
        "시스템 단축키",
        rows: [
          settingRow(
            "키보드",
            control: settingsButton(
              for: "키보드", action: #selector(openKeyboardShortcutsPreference(sender:))))
        ], explanation: helperText("Caps Lock 전환은 키보드 설정에서 켭니다. Shift 조합을 등록할 때는 Fn 키도 함께 누르세요.")),
    ])

    var advancedSections = [
      section(
        "앱 호환성",
        rows: [
          settingRow(
            "두벌식 종성 결합",
            control: settingSwitch(hangulNonChoseongCombinationButton, label: "두벌식 종성 결합")),
          settingRow(
            "조합 상태 유지",
            control: settingSwitch(hangulDeferredSymbolCommitButton, label: "조합 상태 유지")),
        ], explanation: helperText("특정 앱에서 조합이 어긋날 때만 켜세요. 종성 결합은 Windows 방식, 조합 상태 유지는 JDK 앱용입니다.")
      )
    ]
    var applicationRows = [settingRow("Esc로 로마자 전환", control: escapeKeyApplicationMenu)]
    if productIdentity.isBaram {
      applicationRows.append(
        settingRow("실험 · 자동 한영 전환", control: autocorrectionApplicationMenu))
    }
    let applicationHelp =
      productIdentity.isBaram
      ? "모든 앱 또는 선택한 앱에 적용합니다. Esc는 로마자로 전환합니다. 자동 한영 전환은 공백·Return·Tab에서 완전히 조합된 현대 두벌식·세벌식 단어나 사전에 있는 영단어만 바꾸고 실제 입력 모드도 전환합니다. 예: dkssud 또는 jfshea → 안녕, 한글 모드에서 잘못 친 apple → apple. 일부 터미널 앱과 보안 입력은 제외됩니다."
      : "선택한 Vim·터미널·코드 편집기에서만 Esc 또는 Control+[로 한글 조합을 끝내고 로마자로 전환합니다."
    advancedSections.append(
      section("앱별 동작", rows: applicationRows, explanation: helperText(applicationHelp)))
    #if !USE_PREFPANE
      if productIdentity.supportsPhysicalChording {
        let toggle = NSSwitch()
        toggle.controlSize = .mini
        toggle.target = self
        toggle.action = #selector(physicalChordModeChanged(_:))
        toggle.setAccessibilityLabel("동시에 누른 키 묶기")
        toggle.setAccessibilityHelp(
          "지원 세벌식의 모아 누른 키를 배열 기준 초성, 중성, 종성으로 정렬합니다. 경계 및 안전 복구에서는 입력 순서를 유지합니다.")
        physicalChordSwitch = toggle
        let permission = NSButton(
          title: "입력 모니터링 허용…", target: self, action: #selector(requestPhysicalChordPermission(_:)))
        permission.controlSize = .small
        permission.setAccessibilityLabel("키 감지 권한 허용")
        physicalChordPermissionButton = permission
        let status = helperText("")
        physicalChordStatus = status
        advancedSections.append(
          section(
            "실험 기능 · 물리적 동시입력",
            rows: [
              settingRow("동시에 누른 키 묶기", control: toggle),
              settingRow("키 감지 권한", control: permission),
            ], explanation: status))
        NotificationCenter.default.removeObserver(
          self, name: PhysicalKeyEventSource.statusDidChange, object: nil)
        NotificationCenter.default.addObserver(
          self, selector: #selector(physicalChordSourceChanged(_:)),
          name: PhysicalKeyEventSource.statusDidChange, object: nil)
        refreshPhysicalChordControls()
      }
    #endif
    let identity = productIdentity
    if identity.supportsUpdates {
      var updateRows = [
        settingRow(
          "업데이트 알림", control: settingSwitch(updateNotificationButton, label: "업데이트 알림"))
      ]
      if identity.supportsExperimentalUpdates {
        updateRows.append(
          settingRow(
            "실험 버전 알림",
            control: settingSwitch(updateNotificationExperimentalButton, label: "실험 버전 알림")))
      }
      let updateExplanation =
        identity.isBaram
        ? helperText("baram.sionyuel.com에서 바람 입력기의 새 정식 버전을 확인합니다.") : nil
      advancedSections.append(
        section("업데이트", rows: updateRows, explanation: updateExplanation))
    }
    let advancedPage = page(advancedSections)
    preferencePages = [inputPage, shortcutsPage, advancedPage]
    let pageContainer = NSView()
    pageContainer.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(pageContainer)
    for (index, page) in preferencePages.enumerated() {
      page.translatesAutoresizingMaskIntoConstraints = false
      page.isHidden = index != 0
      pageContainer.addSubview(page)
      NSLayoutConstraint.activate([
        page.leadingAnchor.constraint(equalTo: pageContainer.leadingAnchor),
        page.trailingAnchor.constraint(equalTo: pageContainer.trailingAnchor),
        page.topAnchor.constraint(equalTo: pageContainer.topAnchor),
        page.bottomAnchor.constraint(equalTo: pageContainer.bottomAnchor),
      ])
    }
    var layoutConstraints = [
      pageContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      pageContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      pageContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
    ]
    #if USE_PREFPANE
      layoutConstraints.append(contentsOf: [
        sectionPicker.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
        sectionPicker.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        pageContainer.topAnchor.constraint(equalTo: sectionPicker.bottomAnchor, constant: 16),
      ])
    #else
      layoutConstraints.append(
        pageContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: 16))
    #endif
    NSLayoutConstraint.activate(layoutConstraints)
  }

  #if !USE_PREFPANE
    override func viewWillAppear() {
      super.viewWillAppear()
      let previewLayout = KeyboardPreviewView.layout(
        for: configuration.lastHangulInputMode,
        strict: configuration.hangulForceStrictCombinationRule)
      keyboardPreview?.reload(
        layoutIdentifier: previewLayout.identifier, layoutName: previewLayout.name)
      if productIdentity.supportsPhysicalChording { refreshPhysicalChordControls() }
    }

    @objc private func physicalChordModeChanged(_ sender: NSSwitch) {
      configuration.physicalChordingEnabled = sender.state == .on
      PhysicalKeyEventSource.shared.setEnabled(sender.state == .on)
      refreshPhysicalChordControls()
    }

    @objc private func requestPhysicalChordPermission(_: NSButton) {
      let source = PhysicalKeyEventSource.shared
      if source.requestPermissionFromUserAction(), configuration.physicalChordingEnabled {
        source.setEnabled(true)
      }
      refreshPhysicalChordControls()
    }

    @objc private func physicalChordSourceChanged(_: Notification) {
      refreshPhysicalChordControls()
    }

    private func refreshPhysicalChordControls() {
      let source = PhysicalKeyEventSource.shared
      source.refresh()
      physicalChordSwitch?.state = isOn(configuration.physicalChordingEnabled)
      physicalChordPermissionButton?.isEnabled = !source.permissionGranted
      let state = configuration.physicalChordingEnabled ? source.statusText : "물리적 묶기 꺼짐"
      physicalChordPermissionButton?.title = source.permissionGranted ? "허용됨" : "허용…"
      physicalChordStatus?.stringValue = "실험 · 지원 배열의 초성→중성→종성 정렬. 안전 복구는 입력 순서.\n\(state)"
    }
  #endif

  private func page(_ sections: [NSView]) -> NSScrollView {
    preferenceKeyViews.append(buildingKeyViews)
    buildingKeyViews.removeAll()
    let scroll = NSScrollView()
    scroll.borderType = .noBorder
    scroll.drawsBackground = false
    scroll.hasVerticalScroller = true
    scroll.autohidesScrollers = true
    let document = PreferencesDocumentView()
    document.translatesAutoresizingMaskIntoConstraints = false
    scroll.documentView = document
    let stack = verticalStack(sections, spacing: 20)
    stack.translatesAutoresizingMaskIntoConstraints = false
    document.addSubview(stack)
    NSLayoutConstraint.activate([
      document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
      stack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
      stack.topAnchor.constraint(equalTo: document.topAnchor),
      stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -12),
    ])
    return scroll
  }

  private func section(_ title: String, rows: [NSView], explanation: NSTextField? = nil) -> NSView {
    let label = NSTextField(labelWithString: title)
    label.font = .boldSystemFont(ofSize: 13)
    label.textColor = .labelColor
    let box = NSBox()
    box.boxType = .primary
    box.titlePosition = .noTitle
    box.contentViewMargins = .zero
    var arranged: [NSView] = []
    for (index, row) in rows.enumerated() {
      if index > 0 {
        let separator = NSBox()
        separator.boxType = .separator
        let inset = NSView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        inset.addSubview(separator)
        NSLayoutConstraint.activate([
          inset.heightAnchor.constraint(equalToConstant: 1),
          separator.leadingAnchor.constraint(equalTo: inset.leadingAnchor, constant: 10),
          separator.trailingAnchor.constraint(equalTo: inset.trailingAnchor, constant: -10),
          separator.topAnchor.constraint(equalTo: inset.topAnchor),
          separator.bottomAnchor.constraint(equalTo: inset.bottomAnchor),
        ])
        arranged.append(inset)
      }
      arranged.append(row)
    }
    let rowsStack = verticalStack(arranged, spacing: 0)
    rowsStack.translatesAutoresizingMaskIntoConstraints = false
    box.contentView!.addSubview(rowsStack)
    NSLayoutConstraint.activate([
      rowsStack.leadingAnchor.constraint(equalTo: box.contentView!.leadingAnchor),
      rowsStack.trailingAnchor.constraint(equalTo: box.contentView!.trailingAnchor),
      rowsStack.topAnchor.constraint(equalTo: box.contentView!.topAnchor),
      rowsStack.bottomAnchor.constraint(equalTo: box.contentView!.bottomAnchor),
    ])
    let labelInset = NSView()
    label.translatesAutoresizingMaskIntoConstraints = false
    labelInset.addSubview(label)
    var sectionViews = [labelInset, box]
    if let explanation = explanation {
      let explanationInset = NSView()
      explanation.translatesAutoresizingMaskIntoConstraints = false
      explanationInset.addSubview(explanation)
      NSLayoutConstraint.activate([
        explanation.leadingAnchor.constraint(equalTo: explanationInset.leadingAnchor, constant: 10),
        explanation.trailingAnchor.constraint(
          equalTo: explanationInset.trailingAnchor, constant: -10),
        explanation.topAnchor.constraint(equalTo: explanationInset.topAnchor),
        explanation.bottomAnchor.constraint(equalTo: explanationInset.bottomAnchor),
      ])
      sectionViews.append(explanationInset)
    }
    let group = verticalStack(sectionViews, spacing: 6)
    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: labelInset.leadingAnchor, constant: 10),
      label.trailingAnchor.constraint(equalTo: labelInset.trailingAnchor, constant: -10),
      label.topAnchor.constraint(equalTo: labelInset.topAnchor),
      label.bottomAnchor.constraint(equalTo: labelInset.bottomAnchor),
    ])
    group.setCustomSpacing(8, after: labelInset)
    return group
  }

  private func settingRow(_ title: String, control: NSView) -> NSView {
    let row = NSView()
    let label = NSTextField(wrappingLabelWithString: title)
    label.font = .systemFont(ofSize: 13)
    label.setContentCompressionResistancePriority(.required, for: .horizontal)
    label.translatesAutoresizingMaskIntoConstraints = false
    control.removeFromSuperview()
    NSLayoutConstraint.deactivate(
      control.constraints.filter {
        $0.firstAttribute == .width || $0.firstAttribute == .height
      })
    control.translatesAutoresizingMaskIntoConstraints = false
    control.isHidden = false
    row.addSubview(label)
    row.addSubview(control)
    NSLayoutConstraint.activate([
      row.heightAnchor.constraint(greaterThanOrEqualToConstant: 34),
      label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10),
      label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
      label.topAnchor.constraint(greaterThanOrEqualTo: row.topAnchor, constant: 6),
      label.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor, constant: -6),
      label.trailingAnchor.constraint(lessThanOrEqualTo: control.leadingAnchor, constant: -12),
      control.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -10),
      control.centerYAnchor.constraint(equalTo: row.centerYAnchor),
      control.topAnchor.constraint(greaterThanOrEqualTo: row.topAnchor, constant: 6),
      control.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor, constant: -6),
    ])
    if control is NSPopUpButton {
      control.widthAnchor.constraint(lessThanOrEqualToConstant: 220).isActive = true
    } else if let textField = control as? NSTextField, textField.isEditable {
      textField.widthAnchor.constraint(equalToConstant: 72).isActive = true
    } else if control is MASShortcutView {
      control.widthAnchor.constraint(equalToConstant: 120).isActive = true
      control.heightAnchor.constraint(
        equalToConstant: control.intrinsicContentSize.height
      ).isActive = true
    }
    buildingKeyViews.append(control)
    return row
  }

  private func settingSwitch(_ backing: NSButton, label: String) -> NSSwitch {
    let control = NSSwitch()
    control.controlSize = .mini
    control.state = backing.state
    control.isEnabled = backing.isEnabled
    control.target = self
    control.action = #selector(settingSwitchChanged(_:))
    control.setAccessibilityLabel(label)
    switchBindings[control] = backing
    return control
  }

  private func styleMenu(_ menu: NSPopUpButton, label: String) {
    if let systemMenu = menu as? SystemSettingsPopUpButton {
      systemMenu.applySystemSettingsStyle()
    } else {
      menu.isBordered = false
      menu.controlSize = .small
      menu.alignment = .right
    }
    menu.cell?.lineBreakMode = .byTruncatingMiddle
    menu.setAccessibilityLabel(label)
  }

  private func refreshEscapeKeyApplicationMenu() {
    let applications = configuration.romanModeByEscapeKeyApplications
    refreshApplicationMenu(
      escapeKeyApplicationMenu, applications: applications,
      summaryOverride: configuration.romanModeByEscapeKey ? "모든 앱 · 이전 설정" : nil)
  }

  private func refreshApplicationMenu(
    _ menu: NSPopUpButton, applications: [String: String], summaryOverride: String? = nil,
    offersAllApplications: Bool = false, allApplicationsEnabled: Bool = false
  ) {
    let summary: String
    if let summaryOverride {
      summary = summaryOverride
    } else if applications.isEmpty {
      summary = "사용 안 함"
    } else if applications.count == 1 {
      summary = applications.values.first ?? "1개 앱"
    } else {
      summary = "\(applications.count)개 앱"
    }

    menu.removeAllItems()
    menu.addItem(withTitle: summary)
    menu.lastItem?.isEnabled = false
    if !applications.isEmpty {
      menu.menu?.addItem(.separator())
      for name in applications.values.sorted() {
        let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
        item.state = .on
        item.isEnabled = false
        menu.menu?.addItem(item)
      }
    }
    menu.menu?.addItem(.separator())
    if offersAllApplications {
      let all = NSMenuItem(title: "모든 앱에서 사용", action: nil, keyEquivalent: "")
      all.representedObject = "all"
      all.state = allApplicationsEnabled ? .on : .off
      menu.menu?.addItem(all)
    }
    let choose = NSMenuItem(title: "앱 선택…", action: nil, keyEquivalent: "")
    choose.representedObject = "choose"
    menu.menu?.addItem(choose)
    if summaryOverride != nil || !applications.isEmpty || allApplicationsEnabled {
      let clear = NSMenuItem(title: "설정 지우기", action: nil, keyEquivalent: "")
      clear.representedObject = "clear"
      menu.menu?.addItem(clear)
    }
    menu.selectItem(at: 0)
  }

  private func refreshAutocorrectionApplicationMenu() {
    let allApplications = configuration.hangulLayoutAutocorrectionAllApplications
    refreshApplicationMenu(
      autocorrectionApplicationMenu,
      applications: configuration.hangulLayoutAutocorrectionApplications,
      summaryOverride: allApplications ? "모든 앱" : nil,
      offersAllApplications: true, allApplicationsEnabled: allApplications)
  }

  @objc private func autocorrectionApplicationMenuChanged(_ sender: NSPopUpButton) {
    defer { refreshAutocorrectionApplicationMenu() }
    switch sender.selectedItem?.representedObject as? String {
    case "all":
      configuration.hangulLayoutAutocorrectionAllApplications = true
      configuration.hangulLayoutAutocorrectionApplications = [:]
    case "choose":
      guard
        let applications = chooseApplications(
          title: "자동 한영 전환을 사용할 앱 선택",
          message:
            "잘못 선택한 입력 모드에서 완전히 조합된 현대 두벌식·세벌식 단어나 사전에 있는 영단어를 바꾸고 실제 한영 모드도 전환합니다. 예: dkssud 또는 jfshea → 안녕, 한글 모드에서 잘못 친 apple → apple. 일부 터미널 앱과 보안 입력은 제외됩니다."
        )
      else { return }
      configuration.hangulLayoutAutocorrectionAllApplications = false
      configuration.hangulLayoutAutocorrectionApplications = applications
    case "clear":
      configuration.hangulLayoutAutocorrectionAllApplications = false
      configuration.hangulLayoutAutocorrectionApplications = [:]
    default:
      break
    }
  }

  @objc private func escapeKeyApplicationMenuChanged(_ sender: NSPopUpButton) {
    defer { refreshEscapeKeyApplicationMenu() }
    switch sender.selectedItem?.representedObject as? String {
    case "choose":
      chooseEscapeKeyApplications()
    case "clear":
      configuration.romanModeByEscapeKey = false
      configuration.romanModeByEscapeKeyApplications = [:]
    default:
      break
    }
  }

  private func chooseEscapeKeyApplications() {
    guard
      let applications = chooseApplications(
        title: "Esc로 로마자 전환할 앱 선택",
        message: "Vim, 터미널, 코드 편집기처럼 Esc 뒤에 로마자 입력이 필요한 앱을 선택하세요.")
    else { return }
    configuration.romanModeByEscapeKey = false
    configuration.romanModeByEscapeKeyApplications = applications
  }

  private func chooseApplications(title: String, message: String) -> [String: String]? {
    let panel = NSOpenPanel()
    panel.title = title
    panel.message = message
    panel.prompt = "선택"
    panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
    panel.allowedContentTypes = [.applicationBundle]
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = true

    guard panel.runModal() == .OK else { return nil }
    let applications = panel.urls.reduce(into: [String: String]()) { result, url in
      guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else { return }
      let name =
        ["CFBundleDisplayName", "CFBundleName"]
        .compactMap { bundle.object(forInfoDictionaryKey: $0) as? String }
        .first { !$0.isEmpty }
        ?? url.deletingPathExtension().lastPathComponent
      result[identifier] = name
    }
    return applications.isEmpty ? nil : applications
  }

  private func specialCharacterField(value: String, label: String) -> NSTextField {
    let field = NSTextField(string: value)
    field.controlSize = .small
    field.font = .systemFont(ofSize: 13, weight: .medium)
    field.alignment = .center
    field.placeholderString = "기본"
    field.delegate = self
    field.setAccessibilityLabel(label)
    field.setAccessibilityHelp(Self.hangulSpecialCharacterHelpText)
    return field
  }

  private func shortcutControl(_ control: MASShortcutView, label: String) -> NSView {
    // MASShortcut's default cell leaves the clear glyph optically too far right on modern macOS.
    // Its textured native style applies the library's Big Sur-and-later alignment correction.
    control.style = .texturedRect
    control.setAccessibilityLabel(label)
    control.setAcceptsFirstResponder(true)
    return control
  }

  private func helperText(_ value: String) -> NSTextField {
    let label = NSTextField(wrappingLabelWithString: value)
    label.font = .systemFont(ofSize: 11)
    label.textColor = .secondaryLabelColor
    return label
  }

  private func verticalStack(_ views: [NSView], spacing: CGFloat) -> NSStackView {
    let stack = NSStackView(views: views)
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.distribution = .fill
    stack.detachesHiddenViews = true
    stack.spacing = spacing
    for view in views {
      view.translatesAutoresizingMaskIntoConstraints = false
      view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }
    return stack
  }

  private func settingsButton(for title: String, action: Selector) -> NSButton {
    let button = NSButton(title: "열기…", target: self, action: action)
    button.controlSize = .small
    button.setAccessibilityLabel("\(title) 열기")
    return button
  }

  private func updateKeyViewLoop() {
    guard let window = view.window,
      preferenceKeyViews.indices.contains(sectionPicker.selectedSegment)
    else { return }
    window.autorecalculatesKeyViewLoop = true
    window.recalculateKeyViewLoop()
    let pageControls = preferenceKeyViews[sectionPicker.selectedSegment]
    let controls = sectionPicker.isHidden ? pageControls : [sectionPicker!] + pageControls
    guard !controls.isEmpty else { return }
    for (index, control) in controls.enumerated() {
      control.nextKeyView = controls[(index + 1) % controls.count]
    }
    window.initialFirstResponder = controls[0]
  }

  @objc private func selectSettingsSection(_ sender: NSSegmentedControl) {
    selectSettingsSection(at: sender.selectedSegment)
  }

  func selectSettingsSection(at index: Int) {
    guard preferencePages.indices.contains(index) else { return }
    sectionPicker.selectedSegment = index
    for (index, page) in preferencePages.enumerated() {
      page.isHidden = index != sectionPicker.selectedSegment
    }
    updateKeyViewLoop()
  }

  var settingsSectionTitles: [String] { sectionTitles }

  func preferredContentHeight(for index: Int) -> CGFloat {
    guard preferencePages.indices.contains(index),
      let scroll = preferencePages[index] as? NSScrollView,
      let document = scroll.documentView
    else { return 340 }
    view.layoutSubtreeIfNeeded()
    document.layoutSubtreeIfNeeded()
    return min(max(300, document.fittingSize.height + 32), 680)
  }

  func preferredWindowContentHeight() -> CGFloat {
    sectionTitles.indices.map(preferredContentHeight(for:)).max() ?? 340
  }

  @objc private func settingSwitchChanged(_ sender: NSSwitch) {
    guard let backing = switchBindings[sender], let action = backing.action else { return }
    backing.state = sender.state
    NSApp.sendAction(action, to: backing.target, from: backing)
    for (control, button) in switchBindings { control.isEnabled = button.isEnabled }
  }

  @objc private func layoutMenuChanged(_ sender: NSPopUpButton) {
    guard inputSources.indices.contains(sender.indexOfSelectedItem) else { return }
    configuration.overridingKeyboardName = inputSources[sender.indexOfSelectedItem].identifier
  }

  func controlTextDidChange(_ notification: Notification) {
    guard let field = notification.object as? NSTextField else { return }
    guard
      field === hangulBackQuoteOutputCharacterField
        || field === hangulShiftBackQuoteOutputCharacterField
    else { return }
    editedSpecialCharacterFields.insert(ObjectIdentifier(field))
    if let editor = field.currentEditor() as? NSTextView, editor.hasMarkedText() { return }
    updateSpecialCharacterSetting(for: field)
  }

  func controlTextDidEndEditing(_ notification: Notification) {
    guard let field = notification.object as? NSTextField else { return }
    guard editedSpecialCharacterFields.remove(ObjectIdentifier(field)) != nil else { return }
    updateSpecialCharacterSetting(for: field)
  }

  private func updateSpecialCharacterSetting(for field: NSTextField) {
    if field === hangulBackQuoteOutputCharacterField {
      updateSpecialCharacterField(
        field, save: { configuration.hangulBackQuoteOutputCharacter = $0 })
    } else if field === hangulShiftBackQuoteOutputCharacterField {
      updateSpecialCharacterField(
        field, save: { configuration.hangulShiftBackQuoteOutputCharacter = $0 })
    } else {
      return
    }
    let hasError =
      hangulBackQuoteOutputCharacterField.textColor == .systemRed
      || hangulShiftBackQuoteOutputCharacterField.textColor == .systemRed
    hangulSpecialCharacterHelp.stringValue =
      hasError
      ? Self.hangulSpecialCharacterErrorText : Self.hangulSpecialCharacterHelpText
    hangulSpecialCharacterHelp.textColor = hasError ? .systemRed : .secondaryLabelColor
  }

  private func updateSpecialCharacterField(
    _ field: NSTextField, save: (String) -> Void
  ) {
    let value = field.stringValue
    let isValid = Configuration.isValidHangulSpecialCharacter(value)
    field.textColor = isValid ? .labelColor : .systemRed
    field.toolTip = isValid ? nil : Self.hangulSpecialCharacterErrorText
    if isValid { save(value) }
  }

  private func runAppleScript(_ script: String) {
    var error: NSDictionary?
    if let scriptObject = NSAppleScript(source: script) {
      let output: NSAppleEventDescriptor = scriptObject.executeAndReturnError(
        &error
      )
      print("pref event descriptor: \(output.stringValue ?? "nil")")
    }
  }

  // MARK: IBAction

  @IBAction private func debug(sender _: NSControl) {
    print("killing myself")
    let x = [0]
    _ = x[1]
  }

  @IBAction private func openKeyboardShortcutsPreference(sender _: NSControl) {
    if #available(OSX 13, *) {
      runAppleScript(
        """
            do shell script "open -b com.apple.systempreferences /System/Library/PreferencePanes/Keyboard.prefPane"
        """)
    } else {
      runAppleScript(
        """
            tell application "System Preferences"
                activate
                reveal anchor "ShortcutsTab" of pane id "com.apple.preference.keyboard"
            end tell
        """)
    }
  }

  @IBAction private func openKeyboardInputSourcesPreference(sender _: NSControl) {
    if #available(OSX 13, *) {
      runAppleScript(
        """
            do shell script "open -b com.apple.systempreferences /System/Library/PreferencePanes/Keyboard.prefPane"
        """)
    } else {
      runAppleScript(
        """
            tell application "System Preferences"
                activate
                reveal anchor "InputSources" of pane id "com.apple.preference.keyboard"
            end tell
        """)
    }
  }

  @IBAction private func openInputMonitoringPreference(sender _: NSControl) {
    if #available(OSX 13, *) {
      runAppleScript(
        """
            do shell script "open x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        """)
    } else {
      runAppleScript(
        """
            tell application "System Preferences"
                activate
                reveal anchor "Privacy" of pane id "com.apple.preference.security"
            end tell
        """)
    }
  }

  @IBAction private func updateCheck(sender _: NSControl) {
    updateCheck()
  }

  @IBAction private func optionKeyBehaviorValueChanged(_ sender: NSPopUpButton) {
    configuration.optionKeyBehavior = sender.indexOfSelectedItem
  }

  @IBAction private func romanModeByEscapeKeyValueChanged(_ sender: NSButton) {
    configuration.romanModeByEscapeKey = sender.state == .on
  }

  @IBAction private func hangulWonCurrencySymbolForBackQuoteValueChanged(_ sender: NSButton) {
    configuration.hangulWonCurrencySymbolForBackQuote = sender.state == .on
  }

  @IBAction private func hangulAutoReorderValueChanged(_ sender: NSButton) {
    configuration.hangulAutoReorder = sender.state == .on
  }

  @IBAction private func hangulNonChoseongCombinationValueChanged(_ sender: NSButton) {
    configuration.hangulNonChoseongCombination = sender.state == .on
  }

  @IBAction private func hangulDeferredSymbolCommitValueChanged(_ sender: NSButton) {
    configuration.hangulDeferredSymbolCommit = sender.state == .on
  }

  @IBAction private func hangulForceStrictCombinationRuleValueChanged(_ sender: NSButton) {
    configuration.hangulForceStrictCombinationRule = sender.state == .on
  }

  @IBAction private func rightToggleKeyValueChanged(_ sender: NSPopUpButton) {
    configuration.rightToggleKey = {
      switch sender.indexOfSelectedItem {
      case 1:
        return kHIDUsage_KeyboardRightGUI
      case 2:
        return kHIDUsage_KeyboardRightAlt
      case 3:
        return kHIDUsage_KeyboardRightControl
      default:
        return 0
      }
    }()
  }

  @IBAction private func updateNotificationValueChanged(_ sender: NSButton) {
    configuration.updateNotification = sender.state == .on
    if productIdentity.supportsExperimentalUpdates, !Bundle.main.isExperimental {
      updateNotificationExperimentalButton.isEnabled = sender.state == .on
    }
    backgroundQueue.async {
      self.updateCheck()
    }
  }

  @IBAction private func updateNotificationExperimentalValueChanged(_ sender: NSButton) {
    configuration.updateNotificationExperimental = sender.state == .on
    backgroundQueue.async {
      self.updateCheck()
    }
  }
}

// MARK: - 비공개 메소드

extension PreferenceViewController {
  fileprivate func isOn(_ value: Bool) -> NSButton.StateValue {
    return value ? .on : .off
  }

  fileprivate func loadShortcutValues() {
    if let key = configuration.inputModeExchangeKey {
      inputModeExchangeShortcutView.shortcutValue = MASShortcut(
        keyCode: key.0.rawValue, modifierFlags: key.1)
    } else {
      inputModeExchangeShortcutView.shortcutValue = nil
    }

    if let key = configuration.inputModeSearchKey {
      inputModeSearchShortcutView.shortcutValue = MASShortcut(
        keyCode: key.0.rawValue, modifierFlags: key.1)
    } else {
      inputModeSearchShortcutView.shortcutValue = nil
    }

    if let key = configuration.inputModeEnglishKey {
      inputModeEnglishShortcutView.shortcutValue = MASShortcut(
        keyCode: key.0.rawValue, modifierFlags: key.1)
    } else {
      inputModeEnglishShortcutView.shortcutValue = nil
    }

    if let key = configuration.inputModeKoreanKey {
      inputModeKoreanShortcutView.shortcutValue = MASShortcut(
        keyCode: key.0.rawValue, modifierFlags: key.1)
    } else {
      inputModeKoreanShortcutView.shortcutValue = nil
    }
  }

  fileprivate func setupShortcutViewValueChangeEvents() {
    func masShortcutToShortcut(_ mas: MASShortcut?) -> Configuration.Shortcut? {
      guard let mas = mas, let keyCode = KeyCode(rawValue: mas.keyCode) else { return nil }
      return (keyCode, mas.modifierFlags)
    }
    inputModeExchangeShortcutView.shortcutValueChange = { sender in
      self.configuration.inputModeExchangeKey = masShortcutToShortcut(sender.shortcutValue)
    }

    inputModeSearchShortcutView.shortcutValueChange = { sender in
      self.configuration.inputModeSearchKey = masShortcutToShortcut(sender.shortcutValue)
    }

    inputModeEnglishShortcutView.shortcutValueChange = { sender in
      self.configuration.inputModeEnglishKey = masShortcutToShortcut(sender.shortcutValue)
    }

    inputModeKoreanShortcutView.shortcutValueChange = { sender in
      self.configuration.inputModeKoreanKey = masShortcutToShortcut(sender.shortcutValue)
    }
  }

  fileprivate func updateCheck() {
    #if !USE_PREFPANE
      UpdateManager.shared.requestAutoUpdateVersionInfo { info in
        guard let info = info else {
          return
        }
        UpdateManager.notifyUpdate(info: info)
      }
    #endif
  }
}
