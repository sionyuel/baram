//
//  RomanComposer.swift
//  Gureum
//
//  Created by Jeong YunWon on 2017. 7. 12..
//  Copyright © 2017년 youknowone.org. All rights reserved.
//

import Cocoa
import Foundation
import InputMethodKit

// MARK: - Character 구조체 확장

extension Character {
  /// 문자가 소문자인지 나타낸다.
  var isLowercaseCharacter: Bool {
    return self >= "a" && self <= "z"
  }
}

// MARK: - RomanComposer 클래스

/// 로마자 합성기 오브젝트.
final class RomanComposer: Composer {
  /// 로마자 합성기의 종류를 정의한 열거형.
  ///
  /// 각 케이스의 원시 값은 그에 대응하는 키보드 식별자를 나타낸다.
  enum ComposerType: String {
    /// 시스템 자판.
    case system
    /// 쿼티 자판.
    case qwerty
    /// 드보락 자판.
    case dvorak
    /// 콜맥 자판.
    case colemak

    init?(inputMode: String) {
      guard let keyboardIdentifier = GureumInputSource(rawValue: inputMode)?.keyboardIdentifier
      else {
        return nil
      }
      self.init(rawValue: keyboardIdentifier)
    }
  }

  private var _commitString: String?
  private(set) var bufferedPhysicalKeys = ""
  private var bufferedRomanOutput = ""
  var hasBufferedWord: Bool { !bufferedRomanOutput.isEmpty }
  private var _composerType: RomanComposer.ComposerType

  private let keyMap: [Character: Character]

  init(type: RomanComposer.ComposerType) {
    _composerType = type
    keyMap = zip(RomanComposer.ComposerType.qwerty.keyboardData, type.keyboardData)
      .reduce(into: [:]) { $0[$1.0] = $1.1 }
  }

  // MARK: Composer 프로토콜 구현

  var composedString: String {
    return bufferedRomanOutput
  }

  /// Only the word still being composed. IMKInputController inserts this when a composition is
  /// cancelled, so text already queued for commit must not appear here or it is typed twice.
  var originalString: String {
    return bufferedRomanOutput
  }

  var commitString: String {
    return _commitString ?? ""
  }

  var hasCandidates: Bool {
    return false
  }

  var candidates: [NSAttributedString]? {
    return nil
  }

  func dequeueCommitString() -> String {
    let dequeued = _commitString
    _commitString = nil
    return dequeued ?? ""
  }

  func cancelComposition() {
    finishBufferedWord()
  }

  func appendBufferedKey(_ physical: String, output: String) {
    bufferedPhysicalKeys += physical
    bufferedRomanOutput += output
  }

  func deleteBufferedKey() {
    if !bufferedPhysicalKeys.isEmpty { bufferedPhysicalKeys.removeLast() }
    if !bufferedRomanOutput.isEmpty { bufferedRomanOutput.removeLast() }
  }

  func finishBufferedWord(replacingWith replacement: String? = nil) {
    guard hasBufferedWord else { return }
    _commitString = (_commitString ?? "") + (replacement ?? bufferedRomanOutput)
    bufferedPhysicalKeys = ""
    bufferedRomanOutput = ""
  }

  func clearCompositionContext() {
    _commitString = nil
    bufferedPhysicalKeys = ""
    bufferedRomanOutput = ""
  }

  func clear() {
    clearCompositionContext()
  }

  func map(text: String?, key: KeyCode, modifiers: NSEvent.ModifierFlags) -> Character? {
    guard let text = text else {
      return nil
    }
    guard !text.isEmpty, key.isKeyMappable, _composerType != .system else {
      return nil
    }

    let character: Character?
    if modifiers.contains(.shift) {
      character = keyMapUpper[key.rawValue]?.first ?? text.first!
    } else {
      character = keyMapLower[key.rawValue]?.first ?? text.first!
    }
    guard let character = character else {
      return nil
    }
    let newCharacter: Character = {
      if modifiers.contains(.capsLock), character.isLowercaseCharacter {
        return Character(UnicodeScalar(String(character).unicodeScalars.first!.value - 0x20)!)
      } else {
        return character
      }
    }()
    guard let mappedCharacter = keyMap[newCharacter] else {
      return nil
    }
    return mappedCharacter
  }

  func input(
    text: String?,
    key: KeyCode,
    modifiers: NSEvent.ModifierFlags,
    client _: IMKTextInput & IMKUnicodeTextInput
  ) -> InputResult {
    guard let text = text else {
      assertionFailure()
      return .notProcessed
    }

    guard !modifiers.contains(.option) else {
      _commitString = nil
      return .notProcessed
    }

    guard let character = map(text: text, key: key, modifiers: modifiers) else {
      _commitString = nil
      return .notProcessed
    }

    _commitString = "\(character)"
    return .processed
  }

  func candidateSelected(_: NSAttributedString) {}

  func candidateSelectionChanged(_: NSAttributedString) {}
}

extension RomanComposer: CustomStringConvertible {
  var description: String {
    "RomanComposer(.\(String(describing: _composerType)))"
  }
}

// MARK: - RomanComposerType 열거형 확장

extension RomanComposer.ComposerType {
  /// 자판 배열 데이터.
  var keyboardData: String {
    switch self {
    case .system:
      return ""
    case .qwerty:
      return [
        "`1234567890-=\\",
        "qwertyuiop[]",
        "asdfghjkl;'",
        "zxcvbnm,./",
        "~!@#$%^&*()_+|",
        "QWERTYUIOP{}",
        "ASDFGHJKL:\"",
        "ZXCVBNM<>?",
      ].reduce("", +)
    case .dvorak:
      return [
        "`1234567890[]\\",
        "',.pyfgcrl/=",
        "aoeuidhtns-",
        ";qjkxbmwvz",
        "~!@#$%^&*(){}|",
        "\"<>PYFGCRL?+",
        "AOEUIDHTNS_",
        ":QJKXBMWVZ",
      ].reduce("", +)
    case .colemak:
      return [
        "`1234567890-=\\",
        "qwfpgjluy;[]",
        "arstdhneio'",
        "zxcvbkm,./",
        "~!@#$%^&*()_+|",
        "QWFPGJLUY:{}",
        "ARSTDHNEIO\"",
        "ZXCVBKM<>?",
      ].reduce("", +)
    }
  }
}
