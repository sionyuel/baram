//
//  InputReceiver.swift
//  OSX
//
//  Created by Jeong YunWon on 21/10/2018.
//  Copyright © 2018 youknowone.org. All rights reserved.
//

import AppKit
import Foundation
import Hangul
import InputMethodKit

let debugInputReceiver = false

/// Observed technical terms that system spelling dictionaries may omit. This supplies only
/// word evidence; callers retain automatic-conversion eligibility and ownership checks.
enum BuiltInTechnicalTermLexicon {
  private static let terms: Set<String> = ["github", "tailscale"]

  static func contains(_ word: String) -> Bool {
    terms.contains(word.lowercased())
  }
}

/// Converts an input-method-owned physical key sequence without inspecting document text.
enum RomanLayoutAutocorrector {
  private static let sentencePunctuation = CharacterSet(charactersIn: ".,!?;:'\"()~…“”‘’")
  private static let supportedHangulKeyboards: Set<String> = [
    "2-full", "3f", "39", "3fs", "39s", "3s", "32", "3gs", "3-2011", "3-2012", "ahn",
  ]
  /// Two-set Shift only changes these keys (ㅃㅉㄸㄲㅆㅒㅖ). Any other capital letter is an
  /// English-looking token, not Hangul that was deliberately shifted.
  private static let twoSetShiftedKeys = Set("QWERTOP")
  private static let codeFileExtensions: Set<String> = [
    "c", "cpp", "css", "go", "h", "html", "js", "json", "lock", "log", "md", "plist", "py",
    "rb", "rs", "sh", "swift", "toml", "ts", "txt", "xml", "yaml", "yml",
  ]
  private static let commonTopLevelDomains: Set<String> = [
    "ai", "app", "biz", "cloud", "co", "com", "dev", "info", "io", "kr", "me", "net",
    "org", "tech", "xyz",
  ]

  static func englishWordCandidates(_ output: String) -> [String] {
    output.components(separatedBy: sentencePunctuation).filter { !$0.isEmpty }
  }

  static func supportsHangulKeyboard(_ identifier: String) -> Bool {
    supportedHangulKeyboards.contains(identifier)
  }

  private static func isKnownEnglishWord(
    _ word: String, isKnownWord: (String) -> Bool
  ) -> Bool {
    BuiltInTechnicalTermLexicon.contains(word) || Configuration.shared.isLearnedRomanTerm(word)
      || isKnownWord(word)
  }

  static func isKnownEnglishExpression(
    _ output: String, isKnownWord: (String) -> Bool
  ) -> Bool {
    if isDomainExpression(output) { return true }
    // A word may start with an opening quote or parenthesis, but dropping arbitrary
    // leading punctuation can turn valid three-set Hangul (`;vies` -> 보면) into English.
    let openingPunctuation = CharacterSet(charactersIn: "(\"'“‘")
    guard let first = output.unicodeScalars.drop(while: openingPunctuation.contains).first,
      (65...90).contains(first.value) || (97...122).contains(first.value)
    else { return false }
    let candidates = englishWordCandidates(output)
    guard !candidates.isEmpty else { return false }
    return candidates.allSatisfy { candidate in
      if isKnownEnglishWord(candidate, isKnownWord: isKnownWord) { return true }
      guard candidate.count.isMultiple(of: 2) else { return false }
      let midpoint = candidate.index(candidate.startIndex, offsetBy: candidate.count / 2)
      let first = String(candidate[..<midpoint])
      let second = String(candidate[midpoint...])
      return first == second && isKnownEnglishWord(first, isKnownWord: isKnownWord)
    }
  }

  static func isTrustedTechnicalExpression(_ output: String) -> Bool {
    let candidates = englishWordCandidates(output)
    return !candidates.isEmpty
      && candidates.allSatisfy {
        BuiltInTechnicalTermLexicon.contains($0) || Configuration.shared.isLearnedRomanTerm($0)
      }
  }

  static func isDomainExpression(_ output: String) -> Bool {
    let labels = output.lowercased().split(separator: ".", omittingEmptySubsequences: false)
    guard labels.count >= 2, let topLevelDomain = labels.last,
      commonTopLevelDomains.contains(String(topLevelDomain))
    else { return false }
    return labels.allSatisfy { label in
      guard (1...63).contains(label.count), label.first != "-", label.last != "-" else {
        return false
      }
      return label.unicodeScalars.allSatisfy {
        (48...57).contains($0.value) || (97...122).contains($0.value) || $0.value == 45
      }
    }
  }

  static func isTwoSet(_ keyboard: String) -> Bool { keyboard == "2-full" }

  /// Repeated standalone jamo are common Korean chat expressions (`ㅎㅎㅎㅎ`, `ㅋㅋㅋㅋ`, `ㅠㅠ`).
  /// Dictionary evidence for their physical keys must not turn them into Roman text.
  static func isRepeatedHangulJamoExpression(_ output: String) -> Bool {
    var scalars = Array(output.unicodeScalars)
    while let last = scalars.last, sentencePunctuation.contains(last) { scalars.removeLast() }
    guard scalars.count >= 2, let first = scalars.first,
      (0x1100...0x11FF).contains(first.value) || (0x3130...0x318F).contains(first.value)
    else { return false }
    return scalars.dropFirst().allSatisfy { $0 == first }
  }

  /// Tokens that read as code, paths or flags. They stay English in both directions of the
  /// shared rules; the keyboard-specific composition rules reject the rest (digits, `/`, `.sh`).
  /// Only characters that no supported three-set layout needs for ordinary Hangul are listed.
  static func isCodeLikeToken(_ output: String) -> Bool {
    if output.hasPrefix("-") || output.contains("=") { return true }
    let parts = output.lowercased().split(separator: ".", omittingEmptySubsequences: false)
    if parts.count == 2, !parts[0].isEmpty, let ext = parts.last,
      codeFileExtensions.contains(String(ext)),
      parts[0].unicodeScalars.allSatisfy({
        (48...57).contains($0.value) || (97...122).contains($0.value) || $0.value == 45
          || $0.value == 95
      })
    {
      return true
    }
    return false
  }

  private static func isHangulSyllable(_ scalar: Unicode.Scalar) -> Bool {
    (0xAC00...0xD7A3).contains(scalar.value)
  }

  /// `minimumSyllables` is 1 for three-set (existing behavior) and 2 for two-set: a single
  /// CVC English-looking token such as `wit` or `dir` can compose into one valid syllable by
  /// accident, while two clean syllables rarely do.
  static func convert(
    _ keys: String, keyboard: String, minimumKeys: Int = 3, minimumSyllables: Int? = nil
  ) -> String? {
    let twoSet = isTwoSet(keyboard)
    guard supportsHangulKeyboard(keyboard), (minimumKeys...64).contains(keys.count),
      keys.unicodeScalars.allSatisfy({ (33...126).contains($0.value) }),
      !twoSet
        || keys.unicodeScalars.allSatisfy({
          !(65...90).contains($0.value) || twoSetShiftedKeys.contains(Character($0))
        }),
      let context = HGInputContext(keyboardIdentifier: keyboard)
    else { return nil }
    context.setOption(HANGUL_IC_OPTION_AUTO_REORDER, value: false)
    var result = ""
    for scalar in keys.unicodeScalars {
      guard context.process(scalar.value) else { return nil }
      result += representableString(ucsString: context.commitUCSString)
    }
    result += representableString(ucsString: context.flushUCSString())
    guard result.unicodeScalars.contains(where: { (0xAC00...0xD7A3).contains($0.value) }),
      result.unicodeScalars.allSatisfy({
        (0xAC00...0xD7A3).contains($0.value) || sentencePunctuation.contains($0)
      })
    else { return nil }
    let syllables = result.unicodeScalars.filter(isHangulSyllable).count
    guard syllables >= (minimumSyllables ?? (twoSet ? 2 : 1)) else { return nil }
    if twoSet {
      // Two-set punctuation keys are literal; only a trailing run is a sentence ending.
      var sawPunctuation = false
      for scalar in result.unicodeScalars {
        if isHangulSyllable(scalar) {
          if sawPunctuation { return nil }
        } else {
          sawPunctuation = true
        }
      }
    }
    return result
  }

  /// English prefix + Hangul suffix inside one token (`githubdptj` -> `github에서`).
  /// Whole-token English or Hangul always wins; a split is used only when exactly one split
  /// point has a known English prefix and a suffix that composes into complete syllables.
  static func convertEnglishPrefixWithHangulSuffix(
    keys: String, roman: String, keyboard: String, isKnownWord: (String) -> Bool
  ) -> String? {
    let minimumPrefix = 3
    let minimumSuffix = 3
    guard supportsHangulKeyboard(keyboard), keys.count == roman.count,
      keys.count >= minimumPrefix + minimumSuffix, keys.count <= 64,
      !isCodeLikeToken(roman),
      !isKnownEnglishExpression(roman, isKnownWord: isKnownWord),
      convert(keys, keyboard: keyboard) == nil
    else { return nil }
    func isLetters(_ word: String) -> Bool {
      !word.isEmpty
        && word.unicodeScalars.allSatisfy {
          (65...90).contains($0.value) || (97...122).contains($0.value)
        }
    }
    // Built-in terms and system dictionaries supply prefix evidence; the suffix must
    // still compose at a unique boundary.
    func isKnownPrefix(_ word: String) -> Bool {
      isKnownEnglishWord(word, isKnownWord: isKnownWord)
        || (word == word.lowercased() && isKnownWord(word.capitalized))
    }
    if isLetters(roman), isKnownPrefix(roman) { return nil }
    var matches: [String] = []
    for split in minimumPrefix...(keys.count - minimumSuffix) {
      let keyIndex = keys.index(keys.startIndex, offsetBy: split)
      let romanIndex = roman.index(roman.startIndex, offsetBy: split)
      let prefix = String(roman[..<romanIndex])
      let romanSuffix = String(roman[romanIndex...])
      guard isLetters(prefix), isKnownPrefix(prefix),
        !(isLetters(romanSuffix) && isKnownPrefix(romanSuffix)),
        let suffix = convert(String(keys[keyIndex...]), keyboard: keyboard),
        let first = suffix.unicodeScalars.first, isHangulSyllable(first)
      else { continue }
      matches.append(prefix + suffix)
    }
    return matches.count == 1 ? matches[0] : nil
  }

  struct TeachingCandidate: Equatable {
    let term: String
    let replacement: String
    let isWholeWord: Bool
  }

  static func teachingCandidate(keys: String, roman: String, keyboard: String) -> TeachingCandidate?
  {
    guard supportsHangulKeyboard(keyboard), keys.count == roman.count, keys.count >= 3,
      roman.unicodeScalars.allSatisfy({
        (65...90).contains($0.value) || (97...122).contains($0.value)
      })
    else { return nil }
    let learnableSuffixes: Set<String> = [
      "가", "과", "는", "도", "를", "만", "에", "에서", "에서는", "에게", "와", "으로", "은", "의", "이",
    ]
    var mixed: [(prefixLength: Int, value: TeachingCandidate)] = []
    if keys.count >= 5 {
      for split in 3...(keys.count - 2) {
        let keyIndex = keys.index(keys.startIndex, offsetBy: split)
        let romanIndex = roman.index(roman.startIndex, offsetBy: split)
        let term = String(roman[..<romanIndex])
        guard
          let suffix = convert(
            String(keys[keyIndex...]), keyboard: keyboard, minimumKeys: 2, minimumSyllables: 1),
          suffix.unicodeScalars.allSatisfy({ (0xAC00...0xD7A3).contains($0.value) }),
          learnableSuffixes.contains(suffix)
        else { continue }
        mixed.append(
          (split, TeachingCandidate(term: term, replacement: term + suffix, isWholeWord: false)))
      }
    }
    let known = mixed.filter {
      BuiltInTechnicalTermLexicon.contains($0.value.term)
        || Configuration.shared.isLearnedRomanTerm($0.value.term)
    }
    if known.count == 1 { return known[0].value }
    if mixed.count == 1 { return mixed[0].value }
    if mixed.count > 1 { return nil }
    return TeachingCandidate(term: roman, replacement: roman, isWholeWord: true)
  }
}

enum AutomaticLayoutChangeDirection {
  case hangul, roman
}

public class InputReceiver: InputTextDelegate {
  var inputClient: IMKTextInput & IMKUnicodeTextInput
  var composer = GureumComposer()
  weak var controller: InputController!
  var inputting: Bool = false
  var hasSelectionRange: Bool = false
  private weak var bufferedRomanClient: AnyObject?
  private var bufferedRomanStartLocation: Int?
  private var romanAutocorrectionSuppressed = false
  private var pendingRomanCommitReplacementRange: NSRange?
  private weak var bufferedHangulClient: AnyObject?
  private var bufferedHangulStartLocation: Int?
  private var bufferedHangulRomanOutput = ""
  private var hangulAutocorrectionSuppressed = false
  private var pendingAutomaticLayoutChange: AutomaticLayoutChangeDirection?
  private struct AutomaticConversionUndo {
    weak var client: AnyObject?
    let original: String
    let replacementRange: NSRange
    let previousMode: String
    let convertedMode: String
    let romanOutput: String
    let hangulKeyboard: String
  }
  private struct PendingAutomaticConversionUndo {
    let original: String
    let converted: String
    let previousMode: String
    let boundaryKey: KeyCode
    let romanOutput: String
    let hangulKeyboard: String
  }
  private var automaticConversionUndo: AutomaticConversionUndo?
  private var pendingAutomaticConversionUndo: PendingAutomaticConversionUndo?
  var automaticLayoutChangeCommitted: (AutomaticLayoutChangeDirection) -> Void = { _ in }
  var automaticLayoutChangeUndone: () -> Void = {}
  var selectsClientInputModeForLayoutChanges: () -> Bool = {
    !InputMethodIdentity.current.isBaram
  }
  var romanAutocorrectionAvailable: () -> Bool = { InputMethodIdentity.current.isBaram }
  var romanAutocorrectionSecureInput: () -> Bool = {
    PhysicalKeyEventSource.shared.secureInputEnabled
  }
  var romanAutocorrectionKnownEnglishWord: (String) -> Bool = { word in
    guard !word.isEmpty,
      word.unicodeScalars.allSatisfy({
        (65...90).contains($0.value) || (97...122).contains($0.value)
      })
    else { return false }
    let range = NSSpellChecker.shared.checkSpelling(
      of: word, startingAt: 0, language: "en_US", wrap: false,
      inSpellDocumentWithTag: 0, wordCount: nil)
    return range.location == NSNotFound
  }

  func resetRomanAutocorrection() {
    automaticConversionUndo = nil
    pendingAutomaticConversionUndo = nil
    resetHangulAutocorrection()
    guard composer.romanComposer.hasBufferedWord else {
      bufferedRomanStartLocation = nil
      return
    }
    romanAutocorrectionSuppressed = true
    composer.romanComposer.finishBufferedWord()
    let owner = bufferedRomanClient as? (IMKTextInput & IMKUnicodeTextInput) ?? inputClient
    let original = composer.romanComposer.dequeueCommitString()
    if !original.isEmpty {
      owner.insertText(original, replacementRange: NSRange(location: NSNotFound, length: 0))
    }
    bufferedRomanClient = nil
    bufferedRomanStartLocation = nil
  }

  private func resetHangulAutocorrection() {
    let hangul = composer.hangulComposer
    guard hangul.isBufferingWord else { return }
    let owner = bufferedHangulClient as? (IMKTextInput & IMKUnicodeTextInput) ?? inputClient
    let range = Self.bufferedRomanReplacementRange(
      markedRange: owner.markedRange(), bufferedStartLocation: bufferedHangulStartLocation,
      selectionRange: owner.selectedRange(),
      composedUTF16Length: (hangul.composedString as NSString).length)
    hangul.finishBufferedWord()
    let original = hangul.dequeueCommitString()
    bufferedHangulClient = nil
    bufferedHangulStartLocation = nil
    bufferedHangulRomanOutput = ""
    hangulAutocorrectionSuppressed = true
    if !original.isEmpty {
      owner.insertText(
        original, replacementRange: range ?? NSRange(location: NSNotFound, length: 0))
    }
  }

  private func bufferedHangulInput(
    text: String?, key: KeyCode, modifiers: NSEvent.ModifierFlags,
    client: IMKTextInput & IMKUnicodeTextInput
  ) -> InputResult? {
    let configuration = Configuration.shared
    let hangul = composer.hangulComposer
    guard composer.delegate is HangulComposer else {
      resetHangulAutocorrection()
      return nil
    }
    guard RomanLayoutAutocorrector.supportsHangulKeyboard(hangul.keyboardIdentifier) else {
      resetHangulAutocorrection()
      return nil
    }
    let bundle = Self.autocorrectionBundleIdentifier(
      client: client.bundleIdentifier(),
      frontmostApplication: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    if let owner = bufferedHangulClient, owner !== (client as AnyObject) {
      resetHangulAutocorrection()
    }
    guard romanAutocorrectionAvailable(),
      configuration.usesHangulLayoutAutocorrection(for: bundle),
      !romanAutocorrectionSecureInput(),
      modifiers.intersection([.capsLock, .command, .control, .option, .function]).isEmpty
    else {
      resetHangulAutocorrection()
      return nil
    }
    if [.space, .return, .tab].contains(key) {
      defer { hangulAutocorrectionSuppressed = false }
      guard hangul.isBufferingWord else { return nil }
      let original = hangul.composedString
      let previousMode = composer.inputMode
      let candidates = RomanLayoutAutocorrector.englishWordCandidates(bufferedHangulRomanOutput)
      let hasJamo = original.unicodeScalars.contains {
        (0x1100...0x11FF).contains($0.value) || (0x3130...0x318F).contains($0.value)
      }
      let hasHangul =
        hasJamo || original.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) }
      let isRepeatedHangulJamo =
        RomanLayoutAutocorrector.isRepeatedHangulJamoExpression(original)
      let isDomain = RomanLayoutAutocorrector.isDomainExpression(bufferedHangulRomanOutput)
      // Two-set composes far more English words into plausible Hangul than three-set, so it
      // needs visible incomplete jamo as evidence (domains included) and 4+ letter words.
      let twoSet = RomanLayoutAutocorrector.isTwoSet(hangul.keyboardIdentifier)
      let eligible =
        twoSet
        ? hasJamo
          && (isDomain
            || (!candidates.isEmpty && candidates.allSatisfy { $0.count >= 4 }))
        : isDomain
          || (!candidates.isEmpty
            && candidates.allSatisfy {
              $0.count >= 4 || ($0.count == 3 && hasJamo)
            })
      let shouldKeepHangul = configuration.shouldKeepHangul(
        keyboard: hangul.keyboardIdentifier, romanKeys: bufferedHangulRomanOutput)
      let strongRomanEvidence =
        isDomain
        || RomanLayoutAutocorrector.isTrustedTechnicalExpression(bufferedHangulRomanOutput)
      let romanConverted =
        hasHangul && !isRepeatedHangulJamo && !shouldKeepHangul && eligible
          && (hasJamo || strongRomanEvidence)
          && RomanLayoutAutocorrector.isKnownEnglishExpression(
            bufferedHangulRomanOutput, isKnownWord: romanAutocorrectionKnownEnglishWord)
        ? bufferedHangulRomanOutput : nil
      let mixedConverted =
        hasHangul && !isRepeatedHangulJamo && !shouldKeepHangul && romanConverted == nil
        ? RomanLayoutAutocorrector.convertEnglishPrefixWithHangulSuffix(
          keys: hangul.bufferedPhysicalKeys, roman: bufferedHangulRomanOutput,
          keyboard: hangul.keyboardIdentifier,
          isKnownWord: { configuration.isLearnedRomanTerm($0) }) : nil
      let converted = romanConverted ?? mixedConverted
      let romanOutput = bufferedHangulRomanOutput
      let hangulKeyboard = hangul.keyboardIdentifier
      pendingRomanCommitReplacementRange = Self.bufferedRomanReplacementRange(
        markedRange: client.markedRange(), bufferedStartLocation: bufferedHangulStartLocation,
        selectionRange: client.selectedRange(), composedUTF16Length: (original as NSString).length)
      hangul.finishBufferedWord(replacingWith: converted)
      bufferedHangulClient = nil
      bufferedHangulStartLocation = nil
      bufferedHangulRomanOutput = ""
      if let converted {
        pendingAutomaticConversionUndo = PendingAutomaticConversionUndo(
          original: original, converted: converted, previousMode: previousMode,
          boundaryKey: key, romanOutput: romanOutput, hangulKeyboard: hangulKeyboard)
        if romanConverted != nil {
          pendingAutomaticLayoutChange = .roman
          _ = input(event: .changeLayout(.roman, false), client: client)
        }
      }
      return InputResult(processed: false, action: .commit)
    }
    if key == .delete, hangul.isBufferingWord, hangul.usesNativeBufferedBackspace {
      // Two-set carries final consonants into the next syllable, so replaying keys cannot
      // reproduce libhangul's own Backspace (`rksk` -> 가ㄴ, not 간). Use the live context while
      // it still has jamo; once only whole syllables remain, stop buffering and let the normal
      // Backspace delete them, exactly as without autocorrection.
      if let removedKeys = hangul.deleteBufferedKeyNatively(client: client) {
        bufferedHangulRomanOutput.removeLast(min(removedKeys, bufferedHangulRomanOutput.count))
        if !hangul.isBufferingWord {
          bufferedHangulClient = nil
          bufferedHangulStartLocation = nil
        }
        return .processed
      }
      resetHangulAutocorrection()
      return nil
    }
    if key == .delete, hangul.isBufferingWord {
      let removedKeys = hangul.deleteBufferedKey(client: client)
      bufferedHangulRomanOutput.removeLast(min(removedKeys, bufferedHangulRomanOutput.count))
      if !hangul.isBufferingWord {
        bufferedHangulClient = nil
        bufferedHangulStartLocation = nil
      }
      return .processed
    }
    guard !hangulAutocorrectionSuppressed else { return nil }
    let physicalMap = modifiers.contains(.shift) ? keyMapUpper : keyMapLower
    guard key.isKeyMappable, physicalMap.indices.contains(key.rawValue),
      let physical = physicalMap[key.rawValue], physical.unicodeScalars.count == 1,
      physical.unicodeScalars.allSatisfy({ (33...126).contains($0.value) }),
      bufferedHangulRomanOutput.count < 64, key != .ansiGrave
    else {
      resetHangulAutocorrection()
      return nil
    }
    if !hangul.isBufferingWord {
      let selection = client.selectedRange()
      let marked = client.markedRange()
      guard selection.location != NSNotFound, selection.length == 0,
        marked.location == NSNotFound || marked.length == 0,
        hangul.composedString.isEmpty, hangul.commitString.isEmpty
      else {
        hangulAutocorrectionSuppressed = true
        return nil
      }
      bufferedHangulClient = client as AnyObject
      bufferedHangulStartLocation = selection.location
      hangul.beginBufferedWord()
    }
    let output =
      composer.romanComposer.map(text: text ?? physical, key: key, modifiers: modifiers)
      .map(String.init) ?? text ?? physical
    let original = hangul.composedString
    // A trailing dot is enough only for a substantial domain label whose Hangul
    // composition is visibly incomplete. Vowel and consonant evidence excludes numeric
    // and laughter runs; completed Korean sentence endings stay Korean.
    if key == .ansiPeriod, output == ".",
      (4...63).contains(bufferedHangulRomanOutput.count),
      bufferedHangulRomanOutput.first != "-", bufferedHangulRomanOutput.last != "-",
      bufferedHangulRomanOutput.unicodeScalars.allSatisfy({
        (48...57).contains($0.value) || (65...90).contains($0.value)
          || (97...122).contains($0.value) || $0.value == 45
      }),
      bufferedHangulRomanOutput.lowercased().contains(where: { "aeiou".contains($0) }),
      bufferedHangulRomanOutput.lowercased().contains(where: {
        "bcdfghjklmnpqrstvwxyz".contains($0)
      }),
      original.unicodeScalars.contains(where: {
        (0x1100...0x11FF).contains($0.value) || (0x3130...0x318F).contains($0.value)
      }),
      !configuration.shouldKeepHangul(
        keyboard: hangul.keyboardIdentifier, romanKeys: bufferedHangulRomanOutput + "."),
      let range = Self.bufferedRomanReplacementRange(
        markedRange: client.markedRange(), bufferedStartLocation: bufferedHangulStartLocation,
        selectionRange: client.selectedRange(), composedUTF16Length: (original as NSString).length)
    {
      let converted = bufferedHangulRomanOutput + "."
      let previousMode = composer.inputMode
      pendingRomanCommitReplacementRange = range
      hangul.finishBufferedWord(replacingWith: converted)
      bufferedHangulClient = nil
      bufferedHangulStartLocation = nil
      bufferedHangulRomanOutput = ""
      pendingAutomaticConversionUndo = PendingAutomaticConversionUndo(
        original: original + ".", converted: converted, previousMode: previousMode,
        boundaryKey: key, romanOutput: converted, hangulKeyboard: hangul.keyboardIdentifier)
      pendingAutomaticLayoutChange = .roman
      _ = input(event: .changeLayout(.roman, false), client: client)
      return .processed
    }
    bufferedHangulRomanOutput += output
    let result = hangul.appendBufferedKey(
      text: text, key: key, modifiers: modifiers, client: client)
    if result.action != .none || !result.processed {
      resetHangulAutocorrection()
      return .notProcessed
    }
    // Phone, authentication, and numeric fields often reformat committed ASCII themselves.
    // Do not retain a marked-text word when the Hangul layout produced no Hangul at all;
    // commit the first literal immediately and let the app own the rest of this token.
    let composed = hangul.composedString
    let containsHangul = composed.unicodeScalars.contains {
      (0x1100...0x11FF).contains($0.value) || (0x3130...0x318F).contains($0.value)
        || (0xAC00...0xD7A3).contains($0.value)
    }
    if !composed.isEmpty, !containsHangul {
      resetHangulAutocorrection()
      return .processed
    }
    return .processed
  }

  static func autocorrectionBundleIdentifier(
    client: String?, frontmostApplication: String?
  ) -> String? {
    if let client, !client.isEmpty { return client }
    if let frontmostApplication, !frontmostApplication.isEmpty { return frontmostApplication }
    return nil
  }

  static func bufferedRomanReplacementRange(
    markedRange: NSRange, bufferedStartLocation: Int?, selectionRange: NSRange,
    composedUTF16Length: Int
  ) -> NSRange? {
    guard composedUTF16Length > 0 else { return nil }
    if markedRange.location != NSNotFound, markedRange.length > 0 {
      return markedRange
    }
    if let bufferedStartLocation, bufferedStartLocation != NSNotFound {
      return NSRange(location: bufferedStartLocation, length: composedUTF16Length)
    }
    guard selectionRange.location != NSNotFound, selectionRange.length == 0,
      selectionRange.location >= composedUTF16Length
    else { return nil }
    return NSRange(
      location: selectionRange.location - composedUTF16Length,
      length: composedUTF16Length)
  }

  private func bufferedRomanInput(
    text: String?, key: KeyCode, modifiers: NSEvent.ModifierFlags,
    client: IMKTextInput & IMKUnicodeTextInput
  ) -> InputResult? {
    let configuration = Configuration.shared
    guard composer.delegate is RomanComposer,
      let source = GureumInputSource(rawValue: configuration.lastHangulInputMode)
    else {
      resetRomanAutocorrection()
      romanAutocorrectionSuppressed = true
      return nil
    }
    let output =
      composer.romanComposer.map(text: text, key: key, modifiers: modifiers)
      .map(String.init) ?? text
    let keyboard = effectiveHangulKeyboardIdentifier(
      source.keyboardIdentifier,
      strictCombinationRule: configuration.hangulForceStrictCombinationRule)
    let bundleIdentifier = Self.autocorrectionBundleIdentifier(
      client: client.bundleIdentifier(),
      frontmostApplication: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    let roman = composer.romanComposer
    if let owner = bufferedRomanClient, owner !== (client as AnyObject) {
      resetRomanAutocorrection()
    }
    guard romanAutocorrectionAvailable(),
      configuration.usesHangulLayoutAutocorrection(for: bundleIdentifier),
      !romanAutocorrectionSecureInput(),
      modifiers.intersection([.capsLock, .command, .control, .option, .function]).isEmpty
    else {
      resetRomanAutocorrection()
      return nil
    }
    if key == .space || key == .return || key == .tab {
      defer { romanAutocorrectionSuppressed = false }
      guard roman.hasBufferedWord else { return nil }
      let isKnownEnglish = RomanLayoutAutocorrector.isKnownEnglishExpression(
        roman.composedString, isKnownWord: romanAutocorrectionKnownEnglishWord)
      let original = roman.composedString
      let previousMode = composer.inputMode
      let converted: String? =
        isKnownEnglish || RomanLayoutAutocorrector.isCodeLikeToken(roman.composedString)
        ? nil
        : RomanLayoutAutocorrector.convert(roman.bufferedPhysicalKeys, keyboard: keyboard)
          ?? RomanLayoutAutocorrector.convertEnglishPrefixWithHangulSuffix(
            keys: roman.bufferedPhysicalKeys, roman: roman.composedString, keyboard: keyboard,
            isKnownWord: romanAutocorrectionKnownEnglishWord)
      pendingRomanCommitReplacementRange = Self.bufferedRomanReplacementRange(
        markedRange: client.markedRange(), bufferedStartLocation: bufferedRomanStartLocation,
        selectionRange: client.selectedRange(),
        composedUTF16Length: (roman.composedString as NSString).length)
      roman.finishBufferedWord(replacingWith: converted)
      bufferedRomanClient = nil
      bufferedRomanStartLocation = nil
      if let converted {
        pendingAutomaticConversionUndo = PendingAutomaticConversionUndo(
          original: original, converted: converted, previousMode: previousMode,
          boundaryKey: key, romanOutput: original, hangulKeyboard: keyboard)
        pendingAutomaticLayoutChange = .hangul
        _ = input(event: .changeLayout(.hangul, false), client: client)
      }
      return InputResult(processed: false, action: .commit)
    }
    if key == .delete, roman.hasBufferedWord {
      roman.deleteBufferedKey()
      if !roman.hasBufferedWord {
        bufferedRomanClient = nil
        bufferedRomanStartLocation = nil
      }
      return .processed
    }
    guard !romanAutocorrectionSuppressed else { return nil }
    let physicalMap = modifiers.contains(.shift) ? keyMapUpper : keyMapLower
    guard physicalMap.indices.contains(key.rawValue),
      let physical = physicalMap[key.rawValue],
      physical.unicodeScalars.count == 1,
      physical.unicodeScalars.allSatisfy({ (33...126).contains($0.value) }),
      let output, output.unicodeScalars.count == 1,
      output.unicodeScalars.allSatisfy({ (33...126).contains($0.value) }),
      roman.bufferedPhysicalKeys.count < 64
    else {
      resetRomanAutocorrection()
      return nil
    }
    if output == "/", !roman.hasBufferedWord {
      romanAutocorrectionSuppressed = true
      return nil
    }
    if !roman.hasBufferedWord {
      let selection = client.selectedRange()
      let marked = client.markedRange()
      guard selection.location != NSNotFound, selection.length == 0,
        marked.location == NSNotFound || marked.length == 0
      else {
        romanAutocorrectionSuppressed = true
        return nil
      }
      bufferedRomanClient = client as AnyObject
      bufferedRomanStartLocation = selection.location
    }
    roman.appendBufferedKey(physical, output: output)
    return .processed
  }

  init(
    server: IMKServer, delegate: Any!, client: IMKTextInput & IMKUnicodeTextInput,
    controller: InputController
  ) {
    dlog(
      debugInputReceiver,
      "**** NEW INPUT CONTROLLER INIT **** WITH SERVER: %@ / DELEGATE: %@ / CLIENT: %@", server,
      (delegate as? NSObject) ?? "(nil)", (client as? NSObject) ?? "(nil)")
    inputClient = client
    self.controller = controller
  }

  // MARK: - IMKServerInputTextData

  func input2(
    text string: String?, keyCode: KeyCode, modifiers flags: NSEvent.ModifierFlags,
    client sender: IMKTextInput & IMKUnicodeTextInput
  ) -> InputResult {
    // 특정 애플리케이션에서 커맨드/옵션/컨트롤 키 입력을 선점하지 못하는 문제를 회피한다
    if flags.contains(.command) || flags.contains(.control) {
      dlog(
        debugInputReceiver, "-- InputReceiver -inputText: Command/Control key input / returned NO"
      )
      return InputResult(processed: false, action: .commit)
    }

    if string == nil, !flags.contains(.option) {
      return InputResult(processed: false, action: .commit)
    }

    let result = composer.input(text: string, key: keyCode, modifiers: flags, client: sender)

    return result
  }

  // MARK: InputTextDelegate 프로토콜 구현

  // IMKServerInput 프로토콜에 대한 공용 핸들러
  func input(
    text string: String?,
    key keyCode: KeyCode,
    modifiers flags: NSEvent.ModifierFlags,
    client sender: IMKTextInput & IMKUnicodeTextInput
  ) -> InputResult {
    processInput(text: string, key: keyCode, modifiers: flags, client: sender, allowsCommands: true)
  }

  func replayPhysicalStroke(
    text: String, key: KeyCode, modifiers: NSEvent.ModifierFlags,
    client: IMKTextInput & IMKUnicodeTextInput
  ) -> InputResult {
    processInput(text: text, key: key, modifiers: modifiers, client: client, allowsCommands: false)
  }

  private func processInput(
    text string: String?, key keyCode: KeyCode, modifiers flags: NSEvent.ModifierFlags,
    client sender: IMKTextInput & IMKUnicodeTextInput, allowsCommands: Bool
  ) -> InputResult {
    if undoAutomaticConversion(key: keyCode, modifiers: flags, client: sender) {
      return .processed
    }
    let selected = sender.selectedRange()
    let marked = sender.markedRange()
    if selected.location != marked.location {
      //            dlog(debugLogging, "MISMATCHING: \(selected) \(marked)")
      //            cancelComposition()
      //            sender.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: selected.location, length: 0))
      //
      //            // commitComposition(sender)
      //            marked = selected
    }

    // 입력기용 특수 커맨드 처리
    if allowsCommands,
      let command = composer.filterCommand(keyCode: keyCode, modifiers: flags, client: sender)
    {
      let result = input(event: command, client: sender)
      if result.processed {
        return result
      }
    }

    dlog(
      debugLogging, "LOGGING::KEY::(%@)(%ld)(%lu)",
      string?.replacingOccurrences(of: "\n", with: "\\n") ?? "(nil)", keyCode.rawValue,
      flags.rawValue)

    let hadComposedString = !_internalComposedString.isEmpty
    let result =
      bufferedHangulInput(text: string, key: keyCode, modifiers: flags, client: sender)
      ?? bufferedRomanInput(text: string, key: keyCode, modifiers: flags, client: sender)
      ?? input2(text: string, keyCode: keyCode, modifiers: flags, client: sender)

    // 합성 후보가 있다면 보여준다
    InputMethodServer.shared.showOrHideCandidates(controller: controller)

    inputting = true
    defer { inputting = false }

    if result.action != .none {
      cancelComposition()
    }

    let commited = commitCompositionEvent(sender)  // 조합 된 문자 반영
    if result.action == .commit {
      return result
    }
    let hasComposedString = !_internalComposedString.isEmpty
    let selectionRange = controller.selectionRange()
    hasSelectionRange = selectionRange.location != NSNotFound && selectionRange.length > 0
    if commited || controller.selectionRange().length > 0 || hadComposedString || hasComposedString
    {
      updateComposition()  // 조합 중인 문자 반영
    }

    inputting = false

    dlog(debugInputReceiver, "*** End of Input handling ***")
    return result
  }

  private func rememberAutomaticConversion(
    original: String, converted: String, start: Int?, previousMode: String,
    boundaryKey: KeyCode, romanOutput: String, hangulKeyboard: String,
    client: IMKTextInput & IMKUnicodeTextInput
  ) {
    guard let start, start != NSNotFound,
      client.selectedRange() == NSRange(location: start + (converted as NSString).length, length: 0)
    else { return }
    let boundary: String
    switch boundaryKey {
    case .space: boundary = " "
    case .return: boundary = "\n"
    case .tab: boundary = "\t"
    case .ansiPeriod: boundary = ""
    default: return
    }
    automaticConversionUndo = AutomaticConversionUndo(
      client: client as AnyObject, original: original + boundary,
      replacementRange: NSRange(
        location: start, length: (converted as NSString).length + (boundary as NSString).length),
      previousMode: previousMode, convertedMode: composer.inputMode,
      romanOutput: romanOutput, hangulKeyboard: hangulKeyboard)
  }

  private func undoAutomaticConversion(
    key: KeyCode, modifiers: NSEvent.ModifierFlags, client: IMKTextInput & IMKUnicodeTextInput
  ) -> Bool {
    guard let undo = automaticConversionUndo else { return false }
    automaticConversionUndo = nil
    let marked = client.markedRange()
    guard key == .delete,
      modifiers.intersection([.shift, .capsLock, .command, .control, .option, .function]).isEmpty,
      undo.client === (client as AnyObject), !romanAutocorrectionSecureInput(),
      composer.inputMode == undo.convertedMode,
      client.selectedRange() == NSRange(location: NSMaxRange(undo.replacementRange), length: 0),
      marked.location == NSNotFound || marked.length == 0,
      composer.composedString.isEmpty
    else { return false }
    let configuration = Configuration.shared
    let lastRomanMode = configuration.lastRomanInputMode
    let lastHangulMode = configuration.lastHangulInputMode
    restoreAutomaticConversionMode(undo.previousMode, client: client)
    guard composer.inputMode == undo.previousMode,
      client.selectedRange() == NSRange(location: NSMaxRange(undo.replacementRange), length: 0)
    else {
      restoreAutomaticConversionMode(undo.convertedMode, client: client)
      configuration.lastRomanInputMode = lastRomanMode
      configuration.lastHangulInputMode = lastHangulMode
      return false
    }
    client.insertText(undo.original, replacementRange: undo.replacementRange)
    if RomanComposer.ComposerType(inputMode: undo.previousMode) == nil {
      configuration.learnKeepHangul(
        keyboard: undo.hangulKeyboard, romanKeys: undo.romanOutput)
    } else {
      configuration.learnRomanTerm(undo.romanOutput)
    }
    romanAutocorrectionSuppressed = false
    hangulAutocorrectionSuppressed = false
    automaticLayoutChangeUndone()
    return true
  }

  private func restoreAutomaticConversionMode(
    _ mode: String, client: IMKTextInput & IMKUnicodeTextInput
  ) {
    let layout: ChangeLayout
    if RomanComposer.ComposerType(inputMode: mode) != nil {
      Configuration.shared.lastRomanInputMode = mode
      layout = .roman
    } else {
      Configuration.shared.lastHangulInputMode = mode
      layout = .hangul
    }
    _ = input(event: .changeLayout(layout, false), client: client)
  }

  private func learnCurrentRomanWord(
    client: IMKTextInput & IMKUnicodeTextInput
  ) -> InputResult {
    let configuration = Configuration.shared
    let hangul = composer.hangulComposer
    let marked = client.markedRange()
    let selection = client.selectedRange()
    let composedLength = (hangul.composedString as NSString).length
    let bundle = Self.autocorrectionBundleIdentifier(
      client: client.bundleIdentifier(),
      frontmostApplication: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    let ownsMarkedSelection =
      selection == marked
      || (selection.length == 0 && selection.location == NSMaxRange(marked))
    guard composer.delegate is HangulComposer, hangul.isBufferingWord,
      bufferedHangulClient === (client as AnyObject),
      configuration.usesHangulLayoutAutocorrection(for: bundle),
      !romanAutocorrectionSecureInput(),
      let ownedStart = bufferedHangulStartLocation, marked.location == ownedStart,
      marked.length == composedLength, ownsMarkedSelection,
      let candidate = RomanLayoutAutocorrector.teachingCandidate(
        keys: hangul.bufferedPhysicalKeys, roman: bufferedHangulRomanOutput,
        keyboard: hangul.keyboardIdentifier),
      let range = Self.bufferedRomanReplacementRange(
        markedRange: marked, bufferedStartLocation: ownedStart,
        selectionRange: selection, composedUTF16Length: composedLength)
    else { return .notProcessed }

    configuration.learnRomanTerm(candidate.term)
    configuration.forgetKeepHangul(
      keyboard: hangul.keyboardIdentifier, romanKeys: bufferedHangulRomanOutput)
    pendingRomanCommitReplacementRange = range
    hangul.finishBufferedWord(replacingWith: candidate.replacement)
    bufferedHangulClient = nil
    bufferedHangulStartLocation = nil
    bufferedHangulRomanOutput = ""
    if candidate.isWholeWord {
      pendingAutomaticLayoutChange = .roman
      _ = input(event: .changeLayout(.roman, false), client: client)
    } else {
      inputting = true
      _ = commitCompositionEvent(client)
      inputting = false
    }
    return .processed
  }

  func input(event: InputEvent, client sender: IMKTextInput & IMKUnicodeTextInput) -> InputResult {
    if case .learnRomanWord = event { return learnCurrentRomanWord(client: sender) }
    if case .changeLayout(.search, _) = event {
      composer.hangulComposer.prepareBufferedWordForSearch()
      bufferedHangulClient = nil
      bufferedHangulStartLocation = nil
      bufferedHangulRomanOutput = ""
    }
    let pendingUndo = pendingAutomaticConversionUndo
    resetRomanAutocorrection()
    pendingAutomaticConversionUndo = pendingUndo
    switch event {
    case .changeLayout(let layout, let processed):
      let previousMode = composer.inputMode
      controller.flushPhysicalBoundary(layout == .search ? .candidate : .shortcut)
      let innerLayout =
        layout == .toggleByCapsLock || layout == .toggleByRightKey ? .toggle : layout
      let result = composer.changeLayout(innerLayout, client: sender)
      let changedMode = previousMode != composer.inputMode
      if changedMode {
        romanAutocorrectionSuppressed = false
        hangulAutocorrectionSuppressed = false
      }
      if changedMode { controller.endPhysicalLayoutSession() }
      // 합성 후보가 있다면 보여준다
      InputMethodServer.shared.showOrHideCandidates(controller: controller)

      inputting = true

      if result.action != .none {
        cancelComposition()
        if result.action != .cancel {
          commitCompositionEvent(sender)
          if case .layout(let mode) = result.action, layout != .toggleByCapsLock,
            selectsClientInputModeForLayoutChanges()
          {
            (sender as IMKTextInput).selectMode(mode)
          }
        } else {
          updateComposition()  // 조합 중인 문자 반영
        }
      }

      inputting = false

      if changedMode { controller.resumePhysicalLayoutSession(client: sender) }

      return processed ? .processed : .notProcessed
    case .learnRomanWord:
      return .notProcessed
    }
  }
}

extension InputReceiver {  // IMKServerInput
  // Committing a Composition
  // 조합을 중단하고 현재까지 조합된 글자를 커밋한다.
  func commitComposition(_ sender: IMKTextInput & IMKUnicodeTextInput) {
    resetRomanAutocorrection()
    dlog(debugLogging, "LOGGING::EVENT::COMMIT-INTERNAL")
    commitCompositionEvent(sender)
  }

  func updateComposition() {
    dlog(debugLogging, "LOGGING::EVENT::UPDATE-INTERNAL")
    controller.updateComposition()
  }

  func cancelComposition() {
    dlog(debugLogging, "LOGGING::EVENT::CANCEL-INTERNAL")
    controller.cancelComposition()
  }

  // Committing a Composition
  // 조합을 중단하고 현재까지 조합된 글자를 커밋한다.
  @discardableResult
  func commitCompositionEvent(_ sender: IMKTextInput & IMKUnicodeTextInput) -> Bool {
    dlog(debugLogging, "LOGGING::EVENT::COMMIT")
    if !inputting {
      resetRomanAutocorrection()
      // 입력기 외부에서 들어오는 커밋 요청에 대해서는 편집 중인 글자도 커밋한다.
      dlog(
        debugInputController, "-- CANCEL composition because of external commit request from %@",
        sender as! NSObject)
      dlog(debugLogging, "LOGGING::EVENT::CANCEL-INTERNAL")
      cancelCompositionEvent()
    }
    // 왠지는 모르겠지만 프로그램마다 동작이 달라서 조합을 반드시 마쳐주어야 한다
    // 터미널과 같이 조합중에 리턴키 먹는 프로그램은 조합 중인 문자가 없고 보통은 있다
    let pendingReplacementRange = pendingRomanCommitReplacementRange
    pendingRomanCommitReplacementRange = nil
    let commitString = composer.dequeueCommitString()

    // 커밋할 문자가 없으면 중단
    if commitString.isEmpty {
      pendingAutomaticLayoutChange = nil
      pendingAutomaticConversionUndo = nil
      return false
    }

    dlog(
      debugInputReceiver, "** InputController -commitComposition: with sender: %@ / strings: %@",
      sender as! NSObject, commitString)
    let markedRange = sender.markedRange()
    var range =
      pendingReplacementRange
      ?? (markedRange.location != NSNotFound && markedRange.length > 0
        ? markedRange : controller.selectionRange())
    dlog(debugLogging, "LOGGING::COMMIT::%lu:%lu:%@", range.location, range.length, commitString)
    // NSLog("range1 \(range)")글
    if range.length == 0 {
      range = NSRange(location: NSNotFound, length: 0)
    }
    // NSLog("commit \(commitString) to \(range)")
    controller.client().insertText(commitString, replacementRange: range)

    if let pending = pendingAutomaticConversionUndo {
      pendingAutomaticConversionUndo = nil
      rememberAutomaticConversion(
        original: pending.original, converted: pending.converted,
        start: range.location == NSNotFound ? nil : range.location,
        previousMode: pending.previousMode, boundaryKey: pending.boundaryKey,
        romanOutput: pending.romanOutput, hangulKeyboard: pending.hangulKeyboard, client: sender)
    }

    if let direction = pendingAutomaticLayoutChange {
      pendingAutomaticLayoutChange = nil
      automaticLayoutChangeCommitted(direction)
    }

    InputMethodServer.shared.showOrHideCandidates(controller: controller)

    return true
  }

  func updateCompositionEvent() {
    dlog(debugLogging, "LOGGING::EVENT::UPDATE")
    dlog(debugInputController, "** InputController -updateComposition")
  }

  func cancelCompositionEvent() {
    if !inputting { automaticConversionUndo = nil }
    dlog(debugLogging, "LOGGING::EVENT::CANCEL")
    composer.cancelComposition()
  }

  var _internalComposedString: String {
    return composer.composedString
  }

  // Getting Input Strings and Candidates
  // 현재 입력 중인 글자를 반환한다. -updateComposition: 이 사용
  func composedString(_: IMKTextInput & IMKUnicodeTextInput) -> String {
    let string = _internalComposedString
    dlog(debugLogging, "LOGGING::CHECK::COMPOSEDSTRING::(%@)", string)
    dlog(debugInputController, "** InputController -composedString: with return: '%@'", string)
    return string
  }

  func originalString(_: IMKTextInput & IMKUnicodeTextInput) -> NSAttributedString {
    dlog(debugInputController, "** InputController -originalString:")
    let s = NSAttributedString(string: composer.originalString)
    dlog(debugLogging, "LOGGING::CHECK::ORIGINALSTRING::%@", s.string)
    return s
  }

  func candidates(_: IMKTextInput & IMKUnicodeTextInput) -> [Any]! {
    dlog(debugLogging, "LOGGING::CHECK::CANDIDATES")
    return composer.candidates
  }

  func candidateSelected(_ candidateString: NSAttributedString) {
    dlog(debugLogging, "LOGGING::CHECK::CANDIDATESELECTED::%@", candidateString)
    inputting = true
    composer.candidateSelected(candidateString)
    commitCompositionEvent(inputClient)
    inputting = false
  }

  func candidateSelectionChanged(_ candidateString: NSAttributedString) {
    dlog(debugLogging, "LOGGING::CHECK::CANDIDATESELECTIONCHANGED::%@", candidateString)
    composer.candidateSelectionChanged(candidateString)
    updateComposition()
  }
}

extension InputReceiver {  // IMKStateSetting
  //! @brief  마우스 이벤트를 잡을 수 있게 한다.
  func recognizedEvents(
    _: IMKTextInput & IMKUnicodeTextInput, identity: InputMethodIdentity = .current
  ) -> NSEvent.EventTypeMask {
    dlog(debugLogging, "LOGGING::CHECK::RECOGNIZEDEVENTS")
    // NSFlagsChangeMask는 -handleEvent: 에서만 동작
    let events = NSEvent.EventTypeMask(
      arrayLiteral: .keyDown, .flagsChanged, .leftMouseUp, .rightMouseUp, .leftMouseDown,
      .rightMouseDown, .leftMouseDragged, .rightMouseDragged, .appKitDefined, .applicationDefined,
      .systemDefined)
    if identity.isBaram {
      // Settings previews observe releases without consuming them in InputController.handle.
      return events.union(.keyUp)
    }
    #if DEBUG
      if identity.recordsChordDiagnostics {
        return events.union(.keyUp)
      }
    #endif
    return events
  }

  //! @brief 자판 전환을 감지한다.
  func setValue(_ value: Any, forTag tag: Int, client sender: IMKTextInput & IMKUnicodeTextInput) {
    resetRomanAutocorrection()
    InputMethodServer.shared.io.capsLockDate = nil
    dlog(debugLogging, "LOGGING::EVENT::CHANGE-%lu-%@", tag, value as? String ?? "(nonstring)")
    dlog(
      debugInputController,
      "** InputController -setValue:forTag:client: with value: %@ / tag: %lx / client: %@",
      value as? String ?? "(nonstring)", tag, String(describing: controller.client as AnyObject))
    sender.overrideKeyboard(withKeyboardNamed: Configuration.shared.overridingKeyboardName)
    switch tag {
    case kTextServiceInputModePropertyTag:
      guard let value = value as? String else {
        NSLog("Failed to change keyboard layout")
        assertionFailure()
        break
      }
      if value != composer.inputMode {
        let previousMode = composer.inputMode
        commitComposition(sender)
        composer.inputMode = value
        if composer.inputMode != previousMode { romanAutocorrectionSuppressed = false }
      }
    default:
      dlog(true, "**** UNKNOWN TAG %ld !!! ****", tag)
    }
  }
}
