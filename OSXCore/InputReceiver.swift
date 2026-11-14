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

/// Converts an input-method-owned physical key sequence without inspecting document text.
enum RomanLayoutAutocorrector {
  private static let sentencePunctuation = CharacterSet(charactersIn: ".,!?;:'\"()~…“”‘’")
  private static let commonTopLevelDomains: Set<String> = [
    "ai", "app", "biz", "cloud", "co", "com", "dev", "info", "io", "kr", "me", "net",
    "org", "tech", "xyz",
  ]

  static func englishWordCandidates(_ output: String) -> [String] {
    output.components(separatedBy: sentencePunctuation).filter { !$0.isEmpty }
  }

  static func isKnownEnglishExpression(
    _ output: String, isKnownWord: (String) -> Bool
  ) -> Bool {
    if isDomainExpression(output) { return true }
    let candidates = englishWordCandidates(output)
    guard !candidates.isEmpty else { return false }
    return candidates.allSatisfy { candidate in
      if isKnownWord(candidate) { return true }
      guard candidate.count.isMultiple(of: 2) else { return false }
      let midpoint = candidate.index(candidate.startIndex, offsetBy: candidate.count / 2)
      let first = String(candidate[..<midpoint])
      let second = String(candidate[midpoint...])
      return first == second && isKnownWord(first)
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

  static func convert(_ keys: String, keyboard: String) -> String? {
    let supported = ["3f", "39", "3fs", "39s", "3s", "32", "3gs", "3-2011", "3-2012", "ahn"]
    guard supported.contains(keyboard), (3...64).contains(keys.count),
      keys.unicodeScalars.allSatisfy({ (33...126).contains($0.value) }),
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
    return result
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
  var automaticLayoutChangeCommitted: (AutomaticLayoutChangeDirection) -> Void = { _ in }
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
      let candidates = RomanLayoutAutocorrector.englishWordCandidates(bufferedHangulRomanOutput)
      let hasJamo = original.unicodeScalars.contains {
        (0x1100...0x11FF).contains($0.value) || (0x3130...0x318F).contains($0.value)
      }
      let isDomain = RomanLayoutAutocorrector.isDomainExpression(bufferedHangulRomanOutput)
      let eligible =
        isDomain
        || (!candidates.isEmpty
          && candidates.allSatisfy {
            $0.count >= 4 || ($0.count == 3 && hasJamo)
          })
      let converted =
        eligible
          && RomanLayoutAutocorrector.isKnownEnglishExpression(
            bufferedHangulRomanOutput, isKnownWord: romanAutocorrectionKnownEnglishWord)
        ? bufferedHangulRomanOutput : nil
      pendingRomanCommitReplacementRange = Self.bufferedRomanReplacementRange(
        markedRange: client.markedRange(), bufferedStartLocation: bufferedHangulStartLocation,
        selectionRange: client.selectedRange(), composedUTF16Length: (original as NSString).length)
      hangul.finishBufferedWord(replacingWith: converted)
      bufferedHangulClient = nil
      bufferedHangulStartLocation = nil
      bufferedHangulRomanOutput = ""
      if converted != nil {
        pendingAutomaticLayoutChange = .roman
        _ = input(event: .changeLayout(.roman, false), client: client)
      }
      return InputResult(processed: false, action: .commit)
    }
    if key == .delete, hangul.isBufferingWord {
      hangul.deleteBufferedKey(client: client)
      if !bufferedHangulRomanOutput.isEmpty { bufferedHangulRomanOutput.removeLast() }
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
    bufferedHangulRomanOutput += output
    let result = hangul.appendBufferedKey(
      text: text, key: key, modifiers: modifiers, client: client)
    if result.action != .none || !result.processed {
      resetHangulAutocorrection()
      return .notProcessed
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
      let converted =
        isKnownEnglish
        ? nil : RomanLayoutAutocorrector.convert(roman.bufferedPhysicalKeys, keyboard: keyboard)
      pendingRomanCommitReplacementRange = Self.bufferedRomanReplacementRange(
        markedRange: client.markedRange(), bufferedStartLocation: bufferedRomanStartLocation,
        selectionRange: client.selectedRange(),
        composedUTF16Length: (roman.composedString as NSString).length)
      roman.finishBufferedWord(replacingWith: converted)
      bufferedRomanClient = nil
      bufferedRomanStartLocation = nil
      if converted != nil {
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

  func input(event: InputEvent, client sender: IMKTextInput & IMKUnicodeTextInput) -> InputResult {
    if case .changeLayout(.search, _) = event {
      composer.hangulComposer.prepareBufferedWordForSearch()
      bufferedHangulClient = nil
      bufferedHangulStartLocation = nil
      bufferedHangulRomanOutput = ""
    }
    resetRomanAutocorrection()
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
