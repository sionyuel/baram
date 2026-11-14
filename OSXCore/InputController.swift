//
//  InputController.swift
//  Gureum
//
//  Created by KMLee on 2018. 9. 12..
//  Copyright © 2018 youknowone.org. All rights reserved.
//

import Foundation
import InputMethodKit

#if DEBUG
  import os

  private let chordLabEventLogger = Logger(
    subsystem: "io.github.kathar0s.inputmethod.GureumChordLab", category: "KeyEvents")
#endif

let debugLogging = false
let debugInputController = false
let debugSpying = true

//! @enum
//! @brief  최종적으로 InputController가 처리할 결과

public enum InputAction: Equatable {
  case none
  case commit
  case cancel
  case layout(String)
  case candidatesEvent(KeyCode)  // keyCode
}

struct InputResult: Equatable {
  let processed: Bool
  let action: InputAction

  static let processed = InputResult(processed: true, action: .none)
  static let notProcessed = InputResult(processed: false, action: .none)
}

enum ChangeLayout {
  case toggle
  case toggleByCapsLock
  case toggleByRightKey
  case hangul
  case roman
  case search
}

enum InputEvent {
  case changeLayout(ChangeLayout, Bool)
}

struct ChordControllerEnvironment {
  let isLab: () -> Bool
  let isEnabled: () -> Bool
  let sourceFactory: () -> PhysicalKeyEventSourceProtocol
  let clock: () -> TimeInterval
  let candidatesVisible: () -> Bool
  let reportSessionWarning: (String?) -> Void

  init(
    isLab: @escaping () -> Bool, isEnabled: @escaping () -> Bool,
    sourceFactory: @escaping () -> PhysicalKeyEventSourceProtocol,
    clock: @escaping () -> TimeInterval,
    candidatesVisible: @escaping () -> Bool = { false },
    reportSessionWarning: @escaping (String?) -> Void = { _ in }
  ) {
    self.isLab = isLab
    self.isEnabled = isEnabled
    self.sourceFactory = sourceFactory
    self.clock = clock
    self.candidatesVisible = candidatesVisible
    self.reportSessionWarning = reportSessionWarning
  }

  static var production: Self {
    Self(
      isLab: { InputMethodIdentity.current.supportsPhysicalChording },
      isEnabled: { Configuration.shared.physicalChordingEnabled },
      sourceFactory: { PhysicalKeyEventSource.shared },
      clock: { ProcessInfo.processInfo.systemUptime },
      candidatesVisible: { InputMethodServer.shared.candidates.isVisible() },
      reportSessionWarning: { PhysicalKeyEventSource.shared.reportSessionWarning($0) })
  }
}

@objc(GureumInputController)
public class InputController: IMKInputController {
  var receiver: InputReceiver!
  var lastFlags = NSEvent.ModifierFlags(rawValue: 0)
  var updating = false
  private(set) var chordCoordinator: ChordInputCoordinator?
  var chordEnvironment = ChordControllerEnvironment.production {
    willSet {
      deactivatePhysicalInput(reason: .clientChanged)
      chordCoordinator = nil
      chordOwnerClient = nil
    }
  }
  private var chordOwnerClient: (IMKTextInput & IMKUnicodeTextInput)?
  private var chordReplayClient: (IMKTextInput & IMKUnicodeTextInput)?
  private var physicalClientIsActive = false
  #if DEBUG
    private lazy var chordLabControllerToken = UUID().uuidString
  #endif

  override init!(server: IMKServer, delegate: Any!, client inputClient: Any) {
    super.init(server: server, delegate: delegate, client: inputClient)
    guard let inputClient = inputClient as? (IMKTextInput & IMKUnicodeTextInput) else {
      return nil
    }
    dlog(
      debugInputController,
      "**** NEW INPUT CONTROLLER INIT **** WITH SERVER: \(server) / DELEGATE: \(String(describing: delegate)) / CLIENT: \(inputClient) \(inputClient.bundleIdentifier() ?? "nil")"
    )
    assert(InputMethodServer.shared.server === server)
    receiver = InputReceiver(
      server: server, delegate: delegate, client: inputClient, controller: self)
    if InputMethodIdentity.current.isBaram,
      ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    {
      receiver.automaticLayoutChangeCommitted = { [weak receiver] direction in
        guard let client = receiver?.inputClient else { return }
        let message = direction == .hangul ? "한글로 자동 전환됨" : "영문으로 자동 전환됨"
        AutomaticLayoutChangeHUD.shared.show(message, client: client)
      }
    }
  }

  override init() {
    super.init()
  }

  override public func inputControllerWillClose() {
    deactivatePhysicalInput()
    super.inputControllerWillClose()
  }

  deinit {
    if let coordinator = chordCoordinator {
      if Thread.isMainThread {
        coordinator.deactivate()
      } else {
        DispatchQueue.main.async { coordinator.deactivate() }
      }
    }
  }

  public override func client() -> (IMKTextInput & NSObjectProtocol)! {
    if let client = chordReplayClient { return client as? (IMKTextInput & NSObjectProtocol) }
    return super.client()
  }

  public override func selectionRange() -> NSRange {
    chordReplayClient?.selectedRange() ?? super.selectionRange()
  }

  func asClient(_ sender: Any!) -> IMKTextInput & IMKUnicodeTextInput {
    #if DEBUG
      return sender as! (IMKTextInput & IMKUnicodeTextInput)
    #else
      guard let sender = sender as? (IMKTextInput & IMKUnicodeTextInput) else {
        return client() as! (IMKTextInput & IMKUnicodeTextInput)
      }
      return sender
    #endif
  }

  #if DEBUG
    override public func responds(to aSelector: Selector) -> Bool {
      let r = super.responds(to: aSelector)
      dlog(debugSpying, "controller responds to: \(aSelector) \(r)")
      return r
    }

    override public func modes(_ sender: Any!) -> [AnyHashable: Any]! {
      let modes = super.modes(sender)
      dlog(debugSpying, "modes: \(String(describing: modes))")
      return modes
    }

    override public func value(forTag tag: Int, client _: Any!) -> Any! {
      let v = super.value(forTag: tag, client: client)
      dlog(debugSpying, "value: \(String(describing: v)) for tag: \(tag)")
      return v
    }
  #endif
}

extension InputController {
  private func withChordClient(_ client: IMKTextInput & IMKUnicodeTextInput, _ body: () -> Void) {
    let previous = chordReplayClient
    chordReplayClient = client
    defer { chordReplayClient = previous }
    body()
  }

  private var hasPhysicalChordLayout: Bool {
    receiver?.composer.delegate is HangulComposer && hasSebeolsikInputSource
  }

  private var hasSebeolsikInputSource: Bool {
    guard let receiver = receiver else { return false }
    guard let layout = GureumInputSource(rawValue: receiver.composer.inputMode)
    else { return false }
    switch layout {
    case .han3Final, .han390, .han3NoShift, .han3Classic, .han3Layout2,
      .han3FinalNoShift, .han32011, .han32012:
      return true
    default: return false
    }
  }

  private func flushChangedPhysicalClient(_ client: IMKTextInput & IMKUnicodeTextInput) {
    guard let owner = chordOwnerClient, (owner as AnyObject) !== (client as AnyObject) else {
      return
    }
    chordCoordinator?.endSession(.clientChanged)
    withChordClient(owner) {
      receiver.cancelCompositionEvent()
      receiver.inputting = true
      receiver.commitCompositionEvent(owner)
      receiver.inputting = false
    }
    receiver.inputClient = client
    chordCoordinator = nil
    chordOwnerClient = nil
  }

  private func prepareChordCoordinator(
    client: IMKTextInput & IMKUnicodeTextInput, newActivation: Bool = false
  ) {
    let environment = chordEnvironment
    guard physicalClientIsActive, environment.isLab(), environment.isEnabled(),
      hasPhysicalChordLayout
    else { return }
    if let coordinator = chordCoordinator {
      if newActivation
        || (!coordinator.isActive && coordinator.disabledReason == nil
          && coordinator.endedReason == .modeDisabled)
      {
        coordinator.activate()
        environment.reportSessionWarning(nil)
      }
      return
    }
    let owner = client
    chordOwnerClient = owner
    let source = environment.sourceFactory()
    chordCoordinator = ChordInputCoordinator(
      source: source, clock: environment.clock,
      isEnabled: { environment.isLab() && environment.isEnabled() },
      acceptsRelease: { rawCode in
        guard let key = KeyCode(rawValue: rawCode) else { return false }
        return key.isKeyMappable && ![.delete, .return, .tab, .space].contains(key)
      },
      orderGroup: { [weak self] group in
        guard let self = self else { return group.strokes }
        return ChordEmissionPolicy().order(
          group: group, keyboardIdentifier: self.receiver.composer.hangulComposer.keyboardIdentifier
        )
      },
      onDisabled: { _ in
        environment.reportSessionWarning("현재 앱에서 안전 중지 · 입력기를 다시 선택하세요.")
      },
      replay: { [weak self, owner] stroke in
        guard let self = self else {
          owner.insertText(stroke.text, replacementRange: NSRange(location: NSNotFound, length: 0))
          return .literalFallback
        }
        return self.replayPhysicalStroke(stroke, client: owner)
      })
    chordCoordinator?.activate()
    environment.reportSessionWarning(nil)
  }

  func activatePhysicalInput(client: IMKTextInput & IMKUnicodeTextInput) {
    physicalClientIsActive = true
    flushChangedPhysicalClient(client)
    prepareChordCoordinator(client: client, newActivation: true)
  }

  func deactivatePhysicalInput(reason: ChordFlushReason = .deactivated) {
    physicalClientIsActive = false
    chordCoordinator?.endSession(reason)
  }

  func flushPhysicalBoundary(_ reason: ChordFlushReason) {
    chordCoordinator?.flushBoundary(reason)
  }

  func endPhysicalLayoutSession() {
    chordCoordinator?.endSession(.layoutChanged)
    chordCoordinator = nil
    chordOwnerClient = nil
  }

  func resumePhysicalLayoutSession(client: IMKTextInput & IMKUnicodeTextInput) {
    if physicalClientIsActive { prepareChordCoordinator(client: client) }
  }

  private func consumePhysicalKeyDown(
    _ event: NSEvent, key: KeyCode, client: IMKTextInput & IMKUnicodeTextInput
  ) -> Bool {
    guard physicalClientIsActive, chordEnvironment.isLab(), chordEnvironment.isEnabled()
    else {
      chordCoordinator?.endSession(.modeDisabled)
      return false
    }
    guard event.modifierFlags.intersection([.command, .control, .option, .function]).isEmpty else {
      chordCoordinator?.flushBoundary(
        .command, ignoringReleaseOf: key.rawValue, timestamp: event.timestamp)
      return false
    }
    guard key.isKeyMappable, ![.delete, .return, .tab, .space].contains(key),
      let text = event.characters, !text.isEmpty
    else {
      chordCoordinator?.flushBoundary(
        .nonMappable, ignoringReleaseOf: key.rawValue, timestamp: event.timestamp)
      return false
    }
    guard hasPhysicalChordLayout else {
      if hasSebeolsikInputSource {
        chordCoordinator?.flushBoundary(
          .candidate, ignoringReleaseOf: key.rawValue, timestamp: event.timestamp)
      } else {
        chordCoordinator?.endSession(.layoutChanged)
      }
      return false
    }
    guard !chordEnvironment.candidatesVisible() else {
      chordCoordinator?.flushBoundary(
        .candidate, ignoringReleaseOf: key.rawValue, timestamp: event.timestamp)
      return false
    }
    guard
      receiver.composer.filterCommand(keyCode: key, modifiers: event.modifierFlags, client: client)
        == nil
    else {
      chordCoordinator?.flushBoundary(
        .shortcut, ignoringReleaseOf: key.rawValue, timestamp: event.timestamp)
      return false
    }

    prepareChordCoordinator(client: client)
    return chordCoordinator?.consume(
      keyCode: key.rawValue, text: text, modifiers: event.modifierFlags.rawValue,
      timestamp: event.timestamp, isRepeat: event.isARepeat) ?? false
  }

  func replayPhysicalStroke(
    _ stroke: ChordStroke, client: IMKTextInput & IMKUnicodeTextInput
  ) -> ChordTerminalOutcome {
    var outcome = ChordTerminalOutcome.literalFallback
    withChordClient(client) {
      guard let key = KeyCode(rawValue: stroke.keyCode) else {
        client.insertText(stroke.text, replacementRange: NSRange(location: NSNotFound, length: 0))
        return
      }
      // Eligibility and shortcut classification already happened at the authoritative IMK key-down.
      // The receiver still performs its normal commit/cancel action before literal fallback.
      let result = receiver.replayPhysicalStroke(
        text: stroke.text, key: key, modifiers: NSEvent.ModifierFlags(rawValue: stroke.modifiers),
        client: client)
      receiver.inputting = false
      if result.processed {
        outcome = .composerReplay
      } else {
        client.insertText(stroke.text, replacementRange: NSRange(location: NSNotFound, length: 0))
      }
    }
    return outcome
  }
}

// IMKServerInputTextData, IMKServerInputHandleEvent, IMKServerInputKeyBinding 중 하나를 구현하여 입력 구현
extension InputController {  // IMKServerInputHandleEvent
  // Receiving Events Directly from the Text Services Manager

  public override func handle(_ event: NSEvent, client sender: Any) -> Bool {
    // dlog(debugInputController, "event: \(event)")
    // sender is (IMKTextInput & IMKUnicodeTextInput & IMTSMSupport)
    let client = asClient(sender)
    flushChangedPhysicalClient(client)

    #if DEBUG
      if InputMethodIdentity.current.recordsChordDiagnostics,
        event.type == .keyDown || event.type == .keyUp
      {
        let eventType = event.type == .keyDown ? "keyDown" : "keyUp"
        let clientBundleIdentifier = client.bundleIdentifier() ?? "unknown"
        chordLabEventLogger.notice(
          "CHORDLAB_EVENT type=\(eventType, privacy: .public) timestamp=\(event.timestamp, privacy: .public) keyCode=\(event.keyCode, privacy: .public) repeat=\(event.isARepeat, privacy: .public) modifiers=\(event.modifierFlags.rawValue, privacy: .public) client=\(clientBundleIdentifier, privacy: .public) controller=\(self.chordLabControllerToken, privacy: .public)"
        )
        if event.type == .keyUp {
          return false
        }
      }
    #endif

    switch event.type {
    case .keyDown:
      guard let keyCode = KeyCode(rawValue: Int(event.keyCode)) else {
        chordCoordinator?.flushBoundary(.nonMappable)
        return false
      }

      dlog(
        debugInputController,
        "** InputController KEYDOWN -handleEvent:client: with event: %@ / key: %d / modifier: %lu / chars: %@ / chars ignoreMod: %@ / client: %@",
        event, event.keyCode, event.modifierFlags.rawValue, event.characters ?? "(empty)",
        event.charactersIgnoringModifiers ?? "(empty)",
        client.bundleIdentifier() ?? "(no client bundle)")

      let imkCandidates = InputMethodServer.shared.candidates
      let candidatesVisible = chordEnvironment.candidatesVisible()
      if candidatesVisible {
        chordCoordinator?.flushBoundary(
          .candidate, ignoringReleaseOf: keyCode.rawValue, timestamp: event.timestamp)
      }
      if candidatesVisible {
        let selectionKeys = imkCandidates.selectionKeys() as? [NSNumber] ?? []
        let arrowModifier = NSEvent.ModifierFlags.numericPad.union(.function)
        let emptyModifier = NSEvent.ModifierFlags(rawValue: 0)

        let inputModifier = event.modifierFlags
          .intersection(.deviceIndependentFlagsMask)
          .subtracting(.capsLock)

        if inputModifier == arrowModifier && KeyCode.arrows.contains(keyCode)
          || inputModifier == emptyModifier
            && (keyCode == .return || selectionKeys.contains(NSNumber(value: event.keyCode)))
        {
          // https://github.com/pkamb/NumberInput_IMKit_Sample/issues/1#issuecomment-633264470
          imkCandidates.perform(Selector(("handleKeyboardEvent:")), with: event)
          return true
        }
      }

      if consumePhysicalKeyDown(event, key: keyCode, client: client) { return true }

      let result = receiver.input(
        text: event.characters, key: keyCode, modifiers: event.modifierFlags, client: client)
      dlog(debugLogging, "LOGGING::PROCESSED::\(result)")
      return result.processed
    case .flagsChanged:
      dlog(
        debugInputController,
        "** InputController FLAGCHANGED -handleEvent:client: with event: %@ / key: %d / modifier: %lu / client: %@",
        event, -1, event.modifierFlags.rawValue, client.bundleIdentifier() ?? "(no client bundle)")
      let changed = lastFlags.symmetricDifference(event.modifierFlags)
      if !changed.intersection([.command, .control, .option, .function, .capsLock]).isEmpty {
        receiver.resetRomanAutocorrection()
        chordCoordinator?.flushBoundary(.command)
      }
      lastFlags = event.modifierFlags

      if changed.contains(.capsLock), Configuration.shared.enableCapslockToToggleInputMode {
        if InputMethodServer.shared.io.capsLockTriggered {
          dlog(debugIOKitEvent, "controller detected capslock to change layout")
          let toggle = { [weak self] in
            _ = self?.receiver.input(event: .changeLayout(.toggleByCapsLock, true), client: client)
          }
          toggle()
          InputMethodServer.shared.io.rollback = toggle
        } else {
          dlog(debugIOKitEvent, "controller detected capslock")
          (sender as! IMKTextInput).selectMode(receiver.composer.inputMode)
        }
      }

      if InputMethodServer.shared.io.resolveRightKeyPressed() {
        let result = receiver.input(event: .changeLayout(.toggleByRightKey, true), client: client)
        dlog(debugIOKitEvent, "controller detected right key")
        return result.processed
      }

      dlog(debugLogging, "LOGGING::UNHANDLED::%@/%@", event, sender as! NSObject)
      dlog(
        debugInputController,
        "** InputController -handleEvent:client: with event: %@ / sender: %@", event,
        sender as! NSObject)
      return false
    case .leftMouseDown, .leftMouseUp, .leftMouseDragged, .rightMouseDown, .rightMouseUp,
      .rightMouseDragged:
      chordCoordinator?.flushBoundary(.mouse)
      commitComposition(sender)
    default:
      dlog(debugSpying, "unhandled event: \(event)")
    }
    return false
  }
}

extension InputController {  // IMKStateSetting
  //! @brief  마우스 이벤트를 잡을 수 있게 한다.
  public override func recognizedEvents(_ sender: Any!) -> Int {
    let client = asClient(sender)
    return Int(receiver.recognizedEvents(client).rawValue)
  }

  //! @brief 자판 전환을 감지한다.
  public override func setValue(_ value: Any, forTag tag: Int, client sender: Any) {
    let client = asClient(sender)
    flushChangedPhysicalClient(client)
    if tag == kTextServiceInputModePropertyTag,
      (value as? String) != receiver.composer.inputMode
    {
      endPhysicalLayoutSession()
    }
    receiver.setValue(value, forTag: tag, client: client)
    if physicalClientIsActive { prepareChordCoordinator(client: client) }
  }

  public override func activateServer(_ sender: Any!) {
    dlog(true, "server activated")
    super.activateServer(sender)
    if let client = sender as? (IMKTextInput & IMKUnicodeTextInput) {
      activatePhysicalInput(client: client)
    }
  }

  public override func deactivateServer(_ sender: Any!) {
    deactivatePhysicalInput()
    dlog(true, "server deactivating")
    if responds(to: #selector(commitComposition(_:))) {
      self.commitComposition(sender)
    }
    super.deactivateServer(sender)
  }
}

extension InputController {  // IMKMouseHandling
  //! @brief  마우스 입력 발생을 커서 옮기기로 간주하고 조합 중지. 만일 마우스 입력 발생을 감지하는 대신 커서 옮기기를 직접 알아낼 수 있으면 이 부분은 제거한다.
  public override func mouseDown(
    onCharacterIndex _: Int, coordinate _: NSPoint, withModifier _: Int,
    continueTracking _: UnsafeMutablePointer<ObjCBool>!, client sender: Any
  ) -> Bool {
    chordCoordinator?.flushBoundary(.mouse)
    dlog(debugLogging, "LOGGING::EVENT::MOUSEDOWN")
    commitComposition(sender)
    return false
  }
}

extension InputController {  // IMKCustomCommands
  public override func menu() -> NSMenu! {
    return (NSApplication.shared.delegate! as! GureumApplicationDelegate).menu
  }
}

extension InputController {  // IMKServerInput
  // Committing a Composition
  // 조합을 중단하고 현재까지 조합된 글자를 커밋한다.
  @objc public override func commitComposition(_ sender: Any!) {
    if chordReplayClient == nil { chordCoordinator?.flushBoundary(.nonMappable) }
    let client = asClient(sender)
    dlog(debugLogging, "LOGGING::EVENT::COMMIT-RAW?")
    _ = receiver.commitCompositionEvent(client)
    // super.commitComposition(sender)
  }

  @objc public override func updateComposition() {
    dlog(debugLogging, "LOGGING::EVENT::UPDATE-RAW?")
    dlog(debugInputController, "** InputController -updateComposition")
    receiver.updateCompositionEvent()
    super.updateComposition()
    dlog(debugInputController, "** InputController -updateComposition ended")
  }

  @objc public override func cancelComposition() {
    dlog(debugLogging, "LOGGING::EVENT::CANCEL-RAW?")
    receiver.cancelCompositionEvent()
    super.cancelComposition()
  }

  // Getting Input Strings and Candidates
  // 현재 입력 중인 글자를 반환한다. -updateComposition: 이 사용
  @objc public override func composedString(_ sender: Any!) -> Any {
    let client = asClient(sender)
    return receiver.composedString(client)
  }

  @objc public override func originalString(_ sender: Any!) -> NSAttributedString {
    let client = asClient(sender)
    return receiver.originalString(client)
  }

  @objc public override func candidates(_ sender: Any!) -> [Any]! {
    let client = asClient(sender)
    return receiver.candidates(client)
  }

  @objc public override func candidateSelected(_ candidateString: NSAttributedString!) {
    receiver.candidateSelected(candidateString)
  }

  @objc public override func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
    receiver.candidateSelectionChanged(candidateString)
  }
}

#if DEBUG
  @objcMembers public class MockInputController: InputController {
    override public init(server: IMKServer, delegate: Any!, client: Any) {
      super.init()
      receiver = InputReceiver(
        server: server, delegate: delegate, client: client as! (IMKTextInput & IMKUnicodeTextInput),
        controller: self)
    }

    func repoduceTextLog(_ text: String) throws {
      for row in text.components(separatedBy: "\n") {
        guard let regex = try? NSRegularExpression(pattern: "LOGGING::([A-Z]+)::(.*)", options: [])
        else {
          throw NSException(
            name: NSExceptionName("MockInputControllerLogParserError"),
            reason: "Log is not readable format", userInfo: nil) as! Error
        }
        let matches = regex.matches(in: row, options: [], range: NSRangeFromString(row))
        let type = matches[1]
        let data = matches[2]
        print("test: \(type) \(data)")
      }
    }

    override public func client() -> (IMKTextInput & NSObjectProtocol)! {
      return receiver.inputClient as? (IMKTextInput & NSObjectProtocol)
    }

    override public func selectionRange() -> NSRange {
      return client().selectedRange()
    }
  }

  extension MockInputController {  // IMKServerInputTextData
    public func inputFlags(_: Int, client sender: Any) -> Bool {
      let client = asClient(sender)
      let result = receiver.input(event: .changeLayout(.toggle, true), client: client)
      if !result.processed {
        // [self cancelComposition]
      }
      return result.processed
    }

    public override func inputText(
      _ string: String!, key keyCode: Int, modifiers flags: Int, client sender: Any
    ) -> Bool {
      let client = asClient(sender)
      print(
        "** InputController -inputText:key:modifiers:client  with string: \(string ?? "(nil)") / keyCode: \(keyCode) / modifier flags: \(flags) / client: \(String(describing: client))"
      )
      guard let key = KeyCode(rawValue: keyCode) else { return false }
      let result = receiver.input(
        text: string, key: key, modifiers: NSEvent.ModifierFlags(rawValue: UInt(flags)),
        client: client)
      if !result.processed {
        // [self cancelComposition]
      }
      return result.processed
    }

    // Committing a Composition
    // 조합을 중단하고 현재까지 조합된 글자를 커밋한다.
    @objc public override func commitComposition(_ sender: Any) {
      let client = asClient(sender)
      receiver.commitCompositionEvent(client)
      // COMMIT triggered
    }

    public override func updateComposition() {
      receiver.updateCompositionEvent()

      let client = receiver.inputClient
      let composed = composedString(client) as! String
      let markedRange = client.markedRange()
      let view = receiver.inputClient as! NSTextView
      view.setMarkedText(
        composed, selectedRange: NSRange(location: 0, length: composed.count),
        replacementRange: markedRange)
    }

    public override func cancelComposition() {
      receiver.cancelCompositionEvent()

      let client = receiver.inputClient
      let view = receiver.inputClient as! NSTextView
      let markedRange = client.markedRange()
      view.setMarkedText(
        "", selectedRange: NSRange(location: markedRange.location, length: 0),
        replacementRange: markedRange)
    }

    // Getting Input Strings and Candidates
    // 현재 입력 중인 글자를 반환한다. -updateComposition: 이 사용
    public override func composedString(_ sender: Any) -> Any {
      let client = asClient(sender)
      return receiver.composedString(client)
    }

    public override func originalString(_ sender: Any) -> NSAttributedString {
      let client = asClient(sender)
      return receiver.originalString(client)
    }

    public override func candidates(_ sender: Any) -> [Any]? {
      let client = asClient(sender)
      return receiver.candidates(client)
    }

    public override func candidateSelected(_ candidateString: NSAttributedString!) {
      receiver.candidateSelected(candidateString)
    }

    public override func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
      receiver.candidateSelectionChanged(candidateString)
    }
  }

  extension MockInputController {  // IMKStateSetting
    //! @brief  마우스 이벤트를 잡을 수 있게 한다.
    public override func recognizedEvents(_ sender: Any) -> Int {
      let client = asClient(sender)
      return Int(receiver.recognizedEvents(client).rawValue)
    }

    //! @brief 자판 전환을 감지한다.
    public override func setValue(_ value: Any, forTag tag: Int, client sender: Any) {
      let client = asClient(sender)
      receiver.setValue(value, forTag: tag, client: client)
    }
  }
#endif
