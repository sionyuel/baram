//
//  Configuration.swift
//  Gureum
//
//  Created by Jeong YunWon on 2018. 4. 19..
//  Copyright © 2018 youknowone.org. All rights reserved.
//

import AppKit
import Foundation

/// 앱 번들이 선택한 입력 소스 및 설정 영역. 일반 구름은 기존 식별자를 유지한다.
public enum InputMethodProductKind: String {
  case upstream, lab, baram
}

public struct InputMethodIdentity {
  static let knownInputSourceSuffixes: Set<String> = [
    "system", "qwerty", "dvorak", "colemak", "han2", "han2classic", "han3final", "han390",
    "han3noshift", "han3classic", "han3layout2", "hanahnmatae", "hanroman",
    "han3finalnoshift", "han3-2011", "han3-2012",
  ]
  public let inputSourcePrefix: String
  public let defaultsSuiteName: String
  public let productKind: InputMethodProductKind
  public let legacyInputSourcePrefix: String?
  public let legacyDefaultsSuiteName: String?
  public let baramUpdateFeedEnabled: Bool

  public static let current = InputMethodIdentity()

  public init(bundle: Bundle = .main) {
    inputSourcePrefix =
      bundle.object(forInfoDictionaryKey: "GureumInputSourcePrefix") as? String
      ?? "org.youknowone.inputmethod.Gureum"
    defaultsSuiteName =
      bundle.object(forInfoDictionaryKey: "GureumDefaultsSuiteName") as? String
      ?? "org.youknowone.Gureum"
    if let value = bundle.object(forInfoDictionaryKey: "GureumProductKind") as? String,
      let kind = InputMethodProductKind(rawValue: value)
    {
      productKind = kind
    } else if bundle.object(forInfoDictionaryKey: "GureumChordLab") as? Bool ?? false {
      productKind = .lab
    } else {
      productKind = .upstream
    }
    legacyInputSourcePrefix =
      bundle.object(forInfoDictionaryKey: "GureumLegacyInputSourcePrefix") as? String
    legacyDefaultsSuiteName =
      bundle.object(forInfoDictionaryKey: "GureumLegacyDefaultsSuiteName") as? String
    baramUpdateFeedEnabled =
      bundle.object(forInfoDictionaryKey: "BaramUpdateFeedEnabled") as? Bool ?? false
  }

  public var isChordLab: Bool { productKind == .lab }
  public var isBaram: Bool { productKind == .baram }
  public var usesForkServices: Bool { productKind != .upstream }
  public var supportsPhysicalChording: Bool { productKind != .upstream }
  public var recordsChordDiagnostics: Bool { productKind == .lab }
  public var supportsUpstreamUpdates: Bool { productKind == .upstream }
  public var supportsUpdates: Bool {
    productKind == .upstream || (productKind == .baram && baramUpdateFeedEnabled)
  }
  public var supportsExperimentalUpdates: Bool { productKind == .upstream }

  public func identifier(for suffix: String) -> String {
    "\(inputSourcePrefix).\(suffix)"
  }

  public func suffix(for identifier: String) -> String? {
    let prefix = inputSourcePrefix + "."
    guard identifier.hasPrefix(prefix) else { return nil }
    return String(identifier.dropFirst(prefix.count))
  }
}

/// 환경 설정 이름을 정의한 열거형.
enum ConfigurationName {
  /// 마지막 한글 입력 모드.
  public static let lastHangulInputMode = "LastHangulInputMode"
  /// 마지막 로마자 입력 모드.
  public static let lastRomanInputMode = "LastRomanInputMode"

  /// 입력기 바꾸기 단축키.
  public static let inputModeExchangeKey = "InputModeExchangeKey"
  /// 한자 및 이모지 검색 단축키.
  public static let inputModeSearchKey = "InputModeHanjaKey"
  /// 로마자로 바꾸기 단축키.
  public static let inputModeEnglishKey = "InputModeEnglishKey"
  /// 한글로 바꾸기 단축키.
  public static let inputModeKoreanKey = "InputModeKoreanKey"
  /// 옵션 키 동작.
  public static let optionKeyBehavior = "OptionKeyBehavior"
  /// 기본 키보드 레이아웃.
  public static let overridingKeyboardName = "OverridingKeyboardName"

  /// Esc 키로 로마자 자판으로 전환 (vi 모드).
  public static let romanModeByEscapeKey = "ExchangeToRomanModeByEscapeKey"
  /// Esc로 로마자 전환을 사용할 앱의 번들 식별자와 표시 이름.
  public static let romanModeByEscapeKeyApplications = "ExchangeToRomanModeByEscapeKeyApplications"
  /// 완성형 세벌식 조합을 자동 한글 변환할 앱. 빈 목록이면 꺼짐.
  public static let hangulLayoutAutocorrectionApplications =
    "HangulLayoutAutocorrectionApplications"
  /// 완성형 세벌식 자동변환을 제외 앱 이외의 모든 앱에서 사용.
  public static let hangulLayoutAutocorrectionAllApplications =
    "HangulLayoutAutocorrectionAllApplications"
  /// 자동 전환을 되돌린 뒤 원래 글자를 그대로 둔 단어(원문 → 전환 결과). 사용자 승인 전 후보.
  public static let hangulLayoutAutocorrectionExceptionCandidates =
    "HangulLayoutAutocorrectionExceptionCandidates"
  /// 사용자가 승인해 다시는 자동 전환하지 않는 단어(원문 → 전환 결과).
  public static let hangulLayoutAutocorrectionExceptions = "HangulLayoutAutocorrectionExceptions"
  /// 한글 입력기일 때 역따옴표(`)로 원화 기호(₩) 입력.
  public static let hangulWonCurrencySymbolForBackQuote = "HangulWonCurrencySymbolForBackQuote"
  /// 한글 입력기에서 물리적 역따옴표(`) 키로 입력할 사용자 지정 문자.
  public static let hangulBackQuoteOutputCharacter = "HangulBackQuoteOutputCharacter"
  /// 한글 입력기에서 Shift+역따옴표(`) 키로 입력할 사용자 지정 문자.
  public static let hangulShiftBackQuoteOutputCharacter = "HangulShiftBackQuoteOutputCharacter"
  /// 완성되지 않은 낱자 자동 교정 (모아치기).
  public static let hangulAutoReorder = "HangulAutoReorder"
  /// Lab 전용 물리적 키 묶기. 사용자 동의 전에는 꺼져 있다.
  public static let physicalChordingEnabled = "PhysicalChordingEnabled"
  /// 두벌식 초성 조합 중에도 종성 결합 허용 (MS윈도 호환).
  public static let hangulNonChoseongCombination = "HangulNonChoseongCombination"
  /// 모든 글자를 조합 중인 글자로 취급 (JDK 호환).
  public static let hangulDeferredSymbolCommit = "HangulDeferredSymbolCommit"
  /// 세벌식 정석 강요.
  public static let hangulForceStrictCombinationRule = "HangulForceStrictCombinationRule"
  /// 우측 키로 언어 전환
  public static let rightToggleKey = "RightToggleKey"

  /// 업데이트 알림 받기
  public static let updateNotification = "UpdateNotification"
  /// 실험버전 업데이트 알림 받기
  public static let updateNotificationExperimental = "UpdateNotificationExperimental"

  static let migratable = [
    lastHangulInputMode, lastRomanInputMode, inputModeExchangeKey, inputModeSearchKey,
    inputModeEnglishKey, inputModeKoreanKey, optionKeyBehavior, overridingKeyboardName,
    romanModeByEscapeKey, romanModeByEscapeKeyApplications,
    hangulLayoutAutocorrectionApplications, hangulLayoutAutocorrectionAllApplications,
    hangulWonCurrencySymbolForBackQuote, hangulBackQuoteOutputCharacter,
    hangulShiftBackQuoteOutputCharacter, hangulAutoReorder,
    hangulNonChoseongCombination, hangulDeferredSymbolCommit,
    hangulForceStrictCombinationRule, rightToggleKey, updateNotification,
    updateNotificationExperimental,
  ]
}

// MARK: - Configuration 클래스

public enum UpdateMode: Equatable {
  case stable
  case experimental
}

/// 입력기의 환경 설정을 담당하는 오브젝트.
public class Configuration: UserDefaults {
  public static let sharedSuiteName = InputMethodIdentity.current.defaultsSuiteName
  public static var shared = Configuration()
  static let baramMigrationVersionKey = "BaramMigrationVersion"
  static let baramMigrationVersion = 1

  var enableCapslockToToggleInputMode: Bool = false

  public typealias Shortcut = (KeyCode, NSEvent.ModifierFlags)

  class func convertShortcutToConfiguration(_ shortcut: Shortcut?) -> [String: Any] {
    guard let shortcut = shortcut else {
      return [:]
    }
    return ["modifier": shortcut.1.rawValue, "keyCode": shortcut.0.rawValue]
  }

  class func convertConfigurationToShortcut(_ configuration: [String: Any]) -> Shortcut? {
    guard let modifier = configuration["modifier"] as? UInt,
      let keyCodeRawValue = configuration["keyCode"] as? Int,
      let keyCode = KeyCode(rawValue: keyCodeRawValue)
    else {
      return nil
    }
    return (keyCode, NSEvent.ModifierFlags(rawValue: modifier))
  }

  override init?(suiteName: String?) {
    if suiteName == InputMethodIdentity.current.defaultsSuiteName {
      Self.migrateLegacyDefaultsIfNeeded(identity: .current)
    }
    super.init(suiteName: suiteName)

    register(defaults: [
      ConfigurationName.lastHangulInputMode: InputMethodIdentity.current.identifier(for: "han2"),
      ConfigurationName.lastRomanInputMode: InputMethodIdentity.current.identifier(for: "qwerty"),

      ConfigurationName.inputModeSearchKey: Configuration.convertShortcutToConfiguration(
        (.return, .option)),
      ConfigurationName.optionKeyBehavior: 1,
      ConfigurationName.overridingKeyboardName: "com.apple.keylayout.ABC",

      ConfigurationName.romanModeByEscapeKey: false,
      ConfigurationName.hangulLayoutAutocorrectionAllApplications: false,
      ConfigurationName.hangulWonCurrencySymbolForBackQuote: true,
      ConfigurationName.hangulAutoReorder: InputMethodIdentity.current.usesForkServices,
      ConfigurationName.physicalChordingEnabled: false,
      ConfigurationName.hangulNonChoseongCombination: false,
      ConfigurationName.hangulDeferredSymbolCommit: false,
      ConfigurationName.hangulForceStrictCombinationRule: false,
      ConfigurationName.rightToggleKey: kHIDUsage_KeyboardRightAlt,

      ConfigurationName.updateNotification: true,
      ConfigurationName.updateNotificationExperimental: false,
    ])
  }

  convenience init() {
    self.init(suiteName: Configuration.sharedSuiteName)!
  }

  public func persistentDomain() -> [String: Any] {
    return persistentDomain(forName: Configuration.sharedSuiteName) ?? [:]
  }

  static func migrateLegacyDefaultsIfNeeded(identity: InputMethodIdentity) {
    guard identity.isBaram, let legacySuite = identity.legacyDefaultsSuiteName,
      let legacyPrefix = identity.legacyInputSourcePrefix,
      let target = UserDefaults(suiteName: identity.defaultsSuiteName)
    else { return }
    let targetDomain = target.persistentDomain(forName: identity.defaultsSuiteName) ?? [:]
    guard targetDomain[baramMigrationVersionKey] == nil else { return }

    if targetDomain.isEmpty,
      let source = UserDefaults(suiteName: legacySuite),
      let sourceDomain = source.persistentDomain(forName: legacySuite), !sourceDomain.isEmpty
    {
      var migrated: [String: Any] = [:]
      for key in ConfigurationName.migratable {
        guard let value = sourceDomain[key] else { continue }
        if key == ConfigurationName.lastHangulInputMode
          || key == ConfigurationName.lastRomanInputMode
        {
          guard let value = value as? String,
            let migratedValue = migratedInputMode(
              value, legacyPrefix: legacyPrefix, identity: identity)
          else { continue }
          migrated[key] = migratedValue
        } else {
          migrated[key] = value
        }
      }
      target.setPersistentDomain(migrated, forName: identity.defaultsSuiteName)
    }
    target.set(baramMigrationVersion, forKey: baramMigrationVersionKey)
  }

  private static func migratedInputMode(
    _ value: String, legacyPrefix: String, identity: InputMethodIdentity
  ) -> String? {
    let prefix = legacyPrefix + "."
    guard value.hasPrefix(prefix) else { return nil }
    let suffix = String(value.dropFirst(prefix.count))
    guard InputMethodIdentity.knownInputSourceSuffixes.contains(suffix) else { return nil }
    return identity.identifier(for: suffix)
  }

  // TODO: code generation

  /// 마지막 한글 입력 모드.
  public var lastHangulInputMode: String {
    get {
      string(forKey: ConfigurationName.lastHangulInputMode)!
    }
    set {
      set(newValue, forKey: ConfigurationName.lastHangulInputMode)
    }
  }

  /// 마지막 로마자 입력 모드.
  public var lastRomanInputMode: String {
    get {
      string(forKey: ConfigurationName.lastRomanInputMode)!
    }
    set {
      set(newValue, forKey: ConfigurationName.lastRomanInputMode)
    }
  }

  /// 옵션 키 동작.
  public var optionKeyBehavior: Int {
    get {
      integer(forKey: ConfigurationName.optionKeyBehavior)
    }
    set {
      set(newValue, forKey: ConfigurationName.optionKeyBehavior)
    }
  }

  /// 기본 키보드 레이아웃.
  public var overridingKeyboardName: String {
    get {
      string(forKey: ConfigurationName.overridingKeyboardName)!
    }
    set {
      set(newValue, forKey: ConfigurationName.overridingKeyboardName)
    }
  }

  /// 입력기 바꾸기 단축키.
  public var inputModeExchangeKey: Shortcut? {
    get {
      shortcut(forKey: ConfigurationName.inputModeExchangeKey)
    }
    set {
      setShortcut(newValue, forKey: ConfigurationName.inputModeExchangeKey)
    }
  }

  /// 한자 및 이모지 검색 단축키.
  public var inputModeSearchKey: Shortcut? {
    get {
      shortcut(forKey: ConfigurationName.inputModeSearchKey)
    }
    set {
      setShortcut(newValue, forKey: ConfigurationName.inputModeSearchKey)
    }
  }

  /// 로마자로 바꾸기 단축키.
  public var inputModeEnglishKey: Shortcut? {
    get {
      shortcut(forKey: ConfigurationName.inputModeEnglishKey)
    }
    set {
      setShortcut(newValue, forKey: ConfigurationName.inputModeEnglishKey)
    }
  }

  /// 한글로 바꾸기 단축키.
  public var inputModeKoreanKey: Shortcut? {
    get {
      shortcut(forKey: ConfigurationName.inputModeKoreanKey)
    }
    set {
      setShortcut(newValue, forKey: ConfigurationName.inputModeKoreanKey)
    }
  }

  /// Esc 키로 로마자 자판으로 전환 (vi 모드).
  public var romanModeByEscapeKey: Bool {
    get {
      bool(forKey: ConfigurationName.romanModeByEscapeKey)
    }
    set {
      set(newValue, forKey: ConfigurationName.romanModeByEscapeKey)
    }
  }

  public var romanModeByEscapeKeyApplications: [String: String] {
    get {
      guard let values = dictionary(forKey: ConfigurationName.romanModeByEscapeKeyApplications)
      else { return [:] }
      return values.reduce(into: [:]) { result, entry in
        guard !entry.key.isEmpty, let name = entry.value as? String, !name.isEmpty else { return }
        result[entry.key] = name
      }
    }
    set {
      let values = newValue.filter { !$0.key.isEmpty && !$0.value.isEmpty }
      set(values, forKey: ConfigurationName.romanModeByEscapeKeyApplications)
    }
  }

  public func usesRomanModeByEscapeKey(for bundleIdentifier: String?) -> Bool {
    if romanModeByEscapeKey { return true }
    guard let bundleIdentifier, !bundleIdentifier.isEmpty else { return false }
    return romanModeByEscapeKeyApplications[bundleIdentifier] != nil
  }

  public var hangulLayoutAutocorrectionApplications: [String: String] {
    get {
      guard
        let values = dictionary(forKey: ConfigurationName.hangulLayoutAutocorrectionApplications)
      else { return [:] }
      return values.reduce(into: [:]) { result, entry in
        guard !entry.key.isEmpty, let name = entry.value as? String, !name.isEmpty else { return }
        result[entry.key] = name
      }
    }
    set {
      set(
        newValue.filter { !$0.key.isEmpty && !$0.value.isEmpty },
        forKey: ConfigurationName.hangulLayoutAutocorrectionApplications)
    }
  }

  public var hangulLayoutAutocorrectionAllApplications: Bool {
    get { bool(forKey: ConfigurationName.hangulLayoutAutocorrectionAllApplications) }
    set { set(newValue, forKey: ConfigurationName.hangulLayoutAutocorrectionAllApplications) }
  }

  public var hangulLayoutAutocorrectionExceptionCandidates: [String: String] {
    get { stringPairs(forKey: ConfigurationName.hangulLayoutAutocorrectionExceptionCandidates) }
    set {
      setStringPairs(
        newValue, forKey: ConfigurationName.hangulLayoutAutocorrectionExceptionCandidates)
    }
  }

  public var hangulLayoutAutocorrectionExceptions: [String: String] {
    get { stringPairs(forKey: ConfigurationName.hangulLayoutAutocorrectionExceptions) }
    set { setStringPairs(newValue, forKey: ConfigurationName.hangulLayoutAutocorrectionExceptions) }
  }

  /// A word the user has kept twice over: once by undoing its conversion, once by approving it.
  public func isHangulLayoutAutocorrectionException(_ original: String) -> Bool {
    hangulLayoutAutocorrectionExceptions[original] != nil
  }

  /// Remembers an undone conversion for the user to approve; approved words are not offered.
  public func addHangulLayoutAutocorrectionExceptionCandidate(original: String, converted: String) {
    guard !original.isEmpty, !converted.isEmpty,
      !isHangulLayoutAutocorrectionException(original)
    else { return }
    hangulLayoutAutocorrectionExceptionCandidates[original] = converted
  }

  public func approveHangulLayoutAutocorrectionExceptionCandidate(_ original: String) {
    var candidates = hangulLayoutAutocorrectionExceptionCandidates
    guard let converted = candidates.removeValue(forKey: original) else { return }
    hangulLayoutAutocorrectionExceptionCandidates = candidates
    hangulLayoutAutocorrectionExceptions[original] = converted
  }

  private func stringPairs(forKey key: String) -> [String: String] {
    guard let values = dictionary(forKey: key) else { return [:] }
    return values.reduce(into: [:]) { result, entry in
      guard !entry.key.isEmpty, let value = entry.value as? String, !value.isEmpty else { return }
      result[entry.key] = value
    }
  }

  private func setStringPairs(_ pairs: [String: String], forKey key: String) {
    set(pairs.filter { !$0.key.isEmpty && !$0.value.isEmpty }, forKey: key)
  }

  public func usesHangulLayoutAutocorrection(for bundleIdentifier: String?) -> Bool {
    guard let bundleIdentifier, !bundleIdentifier.isEmpty else { return false }
    // Terminals and credential managers remain excluded even if selected accidentally.
    let excluded = [
      "com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable",
      "com.apple.keychainaccess", "com.1password.1password", "com.agilebits.onepassword7",
    ]
    guard !excluded.contains(bundleIdentifier) else { return false }
    return hangulLayoutAutocorrectionAllApplications
      || hangulLayoutAutocorrectionApplications[bundleIdentifier] != nil
  }

  /// 한글 입력기일 때 역따옴표(`)로 원화 기호(₩) 입력.
  public var hangulWonCurrencySymbolForBackQuote: Bool {
    get {
      bool(forKey: ConfigurationName.hangulWonCurrencySymbolForBackQuote)
    }
    set {
      set(newValue, forKey: ConfigurationName.hangulWonCurrencySymbolForBackQuote)
    }
  }

  public static func isValidHangulSpecialCharacter(_ value: String) -> Bool {
    guard !value.isEmpty else { return true }
    guard value.count == 1 else { return false }
    let scalars = value.unicodeScalars
    guard !scalars.contains(where: { $0.properties.generalCategory == .control }) else {
      return false
    }
    return scalars.contains { scalar in
      if CharacterSet.whitespacesAndNewlines.contains(scalar) { return false }
      switch scalar.properties.generalCategory {
      case .control, .format, .nonspacingMark, .spacingMark, .enclosingMark:
        return false
      default:
        return true
      }
    }
  }

  public var hasExplicitHangulBackQuoteOutputCharacter: Bool {
    object(forKey: ConfigurationName.hangulBackQuoteOutputCharacter) != nil
  }

  /// 한글 입력기에서 물리적 역따옴표(`) 키로 입력할 문자.
  /// 명시값이 없으면 기존 원화 기호 설정을 호환 기본값으로 사용한다.
  public var hangulBackQuoteOutputCharacter: String {
    get {
      if let value = object(forKey: ConfigurationName.hangulBackQuoteOutputCharacter) as? String {
        return Self.isValidHangulSpecialCharacter(value) ? value : ""
      }
      return hangulWonCurrencySymbolForBackQuote ? "₩" : ""
    }
    set {
      guard Self.isValidHangulSpecialCharacter(newValue) else { return }
      set(newValue, forKey: ConfigurationName.hangulBackQuoteOutputCharacter)
    }
  }

  /// 한글 입력기에서 Shift+역따옴표(`) 키로 입력할 문자.
  /// 빈 값이면 현재 자판의 기본 문자를 사용한다.
  public var hangulShiftBackQuoteOutputCharacter: String {
    get {
      guard
        let value = object(forKey: ConfigurationName.hangulShiftBackQuoteOutputCharacter) as? String
      else { return "" }
      return Self.isValidHangulSpecialCharacter(value) ? value : ""
    }
    set {
      guard Self.isValidHangulSpecialCharacter(newValue) else { return }
      set(newValue, forKey: ConfigurationName.hangulShiftBackQuoteOutputCharacter)
    }
  }

  /// 완성되지 않은 낱자 자동 교정 (모아치기).
  public var hangulAutoReorder: Bool {
    get {
      bool(forKey: ConfigurationName.hangulAutoReorder)
    }
    set {
      set(newValue, forKey: ConfigurationName.hangulAutoReorder)
    }
  }

  public var physicalChordingEnabled: Bool {
    get { bool(forKey: ConfigurationName.physicalChordingEnabled) }
    set { set(newValue, forKey: ConfigurationName.physicalChordingEnabled) }
  }

  /// 두벌식 초성 조합 중에도 종성 결합 허용 (MS윈도 호환).
  public var hangulNonChoseongCombination: Bool {
    get {
      bool(forKey: ConfigurationName.hangulNonChoseongCombination)
    }
    set {
      set(newValue, forKey: ConfigurationName.hangulNonChoseongCombination)
    }
  }

  /// 모든 글자를 조합중인 글자로 취급 (JDK 호환).
  public var hangulDeferredSymbolCommit: Bool {
    get {
      bool(forKey: ConfigurationName.hangulDeferredSymbolCommit)
    }
    set {
      set(newValue, forKey: ConfigurationName.hangulDeferredSymbolCommit)
    }
  }

  /// 세벌식 정석 강요.
  public var hangulForceStrictCombinationRule: Bool {
    get {
      bool(forKey: ConfigurationName.hangulForceStrictCombinationRule)
    }
    set {
      set(newValue, forKey: ConfigurationName.hangulForceStrictCombinationRule)
    }
  }

  /// 우측 키로 언어 전환
  public var rightToggleKey: Int {
    get {
      integer(forKey: ConfigurationName.rightToggleKey)
    }
    set {
      set(newValue, forKey: ConfigurationName.rightToggleKey)
    }
  }

  /// 업데이트 알림 받기
  public var updateNotification: Bool {
    get {
      bool(forKey: ConfigurationName.updateNotification)
    }
    set {
      set(newValue, forKey: ConfigurationName.updateNotification)
    }
  }

  /// 실험버전 업데이트 알림 받기
  public var updateNotificationExperimental: Bool {
    get {
      if Bundle.main.isExperimental {
        return true
      } else {
        return bool(forKey: ConfigurationName.updateNotificationExperimental)
      }
    }
    set {
      assert(!Bundle.main.isExperimental)
      set(newValue, forKey: ConfigurationName.updateNotificationExperimental)
    }
  }

  public var updateMode: UpdateMode? {
    switch (updateNotification, updateNotificationExperimental) {
    case (false, _):
      return nil
    case (true, false):
      return .stable
    case (true, true):
      return .experimental
    }
  }
}

extension Configuration {
  fileprivate func shortcut(forKey key: String) -> Shortcut? {
    guard let value = dictionary(forKey: key) else { return nil }
    return Configuration.convertConfigurationToShortcut(value)
  }

  fileprivate func setShortcut(_ newValue: Shortcut?, forKey key: String) {
    set(Configuration.convertShortcutToConfiguration(newValue), forKey: key)
  }
}
