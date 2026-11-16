//
//  InputMethodServer.swift
//  OSX
//
//  Created by yuaming on 2018. 9. 20..
//  Copyright © 2018 youknowone.org. All rights reserved.
//

import AppKit
import Foundation
import InputMethodKit
import QuartzCore
import SwiftIOKit

let debugInputServer = false
let debugIOKitEvent = false

private final class AutomaticLayoutChangeHUDPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

final class AutomaticLayoutChangeHUD {
  static let shared = AutomaticLayoutChangeHUD()
  private static let springDuration: TimeInterval = 0.732
  private static let pillSize = NSSize(width: 220, height: 36)
  private static let canvasInset = NSSize(width: 8, height: 12)
  private static let hangulColor = NSColor(
    srgbRed: 0.0784, green: 0.4039, blue: 0.3725, alpha: 1)
  private static let romanColor = NSColor(
    srgbRed: 0.4824, green: 0.2902, blue: 0.1412, alpha: 1)

  private let panel: NSPanel
  private let toastContainer: NSView
  private let pillView: NSView
  private let label: NSTextField
  private let reduceMotion: () -> Bool
  private let presentationState: (CALayer) -> (opacity: Float, translation: CGFloat)?
  private var hideWorkItem: DispatchWorkItem?
  private var lastAnnouncement: (message: String, time: TimeInterval)?
  private var presentationGeneration = 0
  private var isExiting = false

  var isVisible: Bool { panel.isVisible }
  var toastLayer: CALayer? { toastContainer.layer }
  var pillLayer: CALayer? { pillView.layer }

  init(
    panel suppliedPanel: NSPanel? = nil,
    reduceMotion: @escaping () -> Bool = {
      NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    },
    presentationState: @escaping (CALayer) -> (opacity: Float, translation: CGFloat)? = {
      guard let layer = $0.presentation() else { return nil }
      return (layer.opacity, layer.transform.m42)
    }
  ) {
    self.reduceMotion = reduceMotion
    self.presentationState = presentationState
    let panelSize = NSSize(
      width: Self.pillSize.width + Self.canvasInset.width * 2,
      height: Self.pillSize.height + Self.canvasInset.height * 2)
    panel =
      suppliedPanel
      ?? AutomaticLayoutChangeHUDPanel(
        contentRect: NSRect(origin: .zero, size: panelSize),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    panel.animationBehavior = .none
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = false
    panel.ignoresMouseEvents = true

    let root = NSView(frame: NSRect(origin: .zero, size: panelSize))
    root.wantsLayer = true
    root.layer?.backgroundColor = NSColor.clear.cgColor
    panel.contentView = root

    toastContainer = NSView(
      frame: NSRect(
        x: Self.canvasInset.width, y: Self.canvasInset.height,
        width: Self.pillSize.width, height: Self.pillSize.height))
    toastContainer.wantsLayer = true
    toastContainer.layer?.shadowColor = NSColor.black.cgColor
    toastContainer.layer?.shadowOpacity = 0.18
    toastContainer.layer?.shadowRadius = 14
    toastContainer.layer?.shadowOffset = NSSize(width: 0, height: -8)
    toastContainer.layer?.shadowPath = CGPath(
      roundedRect: toastContainer.bounds, cornerWidth: 18, cornerHeight: 18,
      transform: nil)
    root.addSubview(toastContainer)

    pillView = NSView(frame: toastContainer.bounds)
    pillView.autoresizingMask = [.width, .height]
    pillView.wantsLayer = true
    pillView.layer?.cornerRadius = 18
    pillView.layer?.masksToBounds = true

    label = NSTextField(labelWithString: "")
    label.alignment = .center
    label.font = .systemFont(ofSize: 13, weight: .semibold)
    label.textColor = .white
    label.translatesAutoresizingMaskIntoConstraints = false
    pillView.addSubview(label)
    toastContainer.addSubview(pillView)
    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: pillView.leadingAnchor, constant: 16),
      label.trailingAnchor.constraint(equalTo: pillView.trailingAnchor, constant: -16),
      label.centerYAnchor.constraint(equalTo: pillView.centerYAnchor),
    ])
  }

  static func displayDuration(for message: String) -> TimeInterval {
    min(6, 1.8 + Double(max(0, message.count - 20)) * 0.1)
  }

  static func springProgress(at time: TimeInterval) -> CGFloat {
    let mass = 1.0
    let stiffness = 449.0
    let damping = 31.4
    let omega0 = sqrt(stiffness / mass)
    let zeta = damping / (2 * sqrt(stiffness * mass))
    let omegaD = omega0 * sqrt(1 - zeta * zeta)
    let envelope = exp(-zeta * omega0 * time)
    let response =
      1
      - envelope
      * (cos(omegaD * time) + (zeta * omega0 / omegaD) * sin(omegaD * time))
    return CGFloat(response)
  }

  func show(
    _ direction: AutomaticLayoutChangeDirection,
    client: IMKTextInput & IMKUnicodeTextInput
  ) {
    DispatchQueue.main.async { [weak self, weak client = client as AnyObject] in
      guard let self,
        let client = client as? (IMKTextInput & IMKUnicodeTextInput)
      else { return }
      self.present(direction, client: client)
    }
  }

  func dismiss() {
    // Match show()'s queue so an immediate undo cannot be overtaken by its queued presentation.
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.hideWorkItem?.cancel()
      self.hide(generation: self.presentationGeneration)
    }
  }

  private func present(
    _ direction: AutomaticLayoutChangeDirection,
    client: IMKTextInput & IMKUnicodeTextInput
  ) {
    let message: String
    switch direction {
    case .hangul:
      message = "한글로 전환 · ⌫ 되돌리기"
      pillView.layer?.backgroundColor = Self.hangulColor.cgColor
    case .roman:
      message = "영문으로 전환 · ⌫ 되돌리기"
      pillView.layer?.backgroundColor = Self.romanColor.cgColor
    }
    hideWorkItem?.cancel()
    presentationGeneration += 1
    let generation = presentationGeneration
    let wasExiting = isExiting
    let interruptedState =
      wasExiting ? toastContainer.layer.flatMap(presentationState) : nil
    isExiting = false
    let repeatsVisibleMessage = !wasExiting && panel.isVisible && label.stringValue == message
    label.stringValue = message
    let finalOrigin = origin(on: targetScreen(for: client))
    let reduceMotion = reduceMotion()
    panel.setFrameOrigin(finalOrigin)

    if repeatsVisibleMessage {
      if !reduceMotion { pulse() }
    } else {
      resetToastLayer()
      panel.orderFrontRegardless()
      animateEntrance(
        reduceMotion: reduceMotion, fromOpacity: interruptedState?.opacity ?? 0,
        fromTranslation: interruptedState?.translation ?? -12)
    }

    let now = ProcessInfo.processInfo.systemUptime
    if lastAnnouncement?.message != message || now - (lastAnnouncement?.time ?? 0) >= 1 {
      NSAccessibility.post(
        element: label, notification: .announcementRequested,
        userInfo: [
          .announcement: message,
          .priority: NSAccessibilityPriorityLevel.medium.rawValue,
        ])
      lastAnnouncement = (message, now)
    }

    let workItem = DispatchWorkItem { [weak self] in self?.hide(generation: generation) }
    hideWorkItem = workItem
    DispatchQueue.main.asyncAfter(
      deadline: .now() + Self.displayDuration(for: message), execute: workItem)
  }

  private func animateEntrance(
    reduceMotion: Bool, fromOpacity: Float, fromTranslation: CGFloat
  ) {
    guard let layer = toastContainer.layer else { return }
    let fade = CABasicAnimation(keyPath: "opacity")
    fade.fromValue = fromOpacity
    fade.toValue = 1
    fade.duration = reduceMotion ? 0.15 : 0.2
    fade.timingFunction =
      reduceMotion
      ? CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1)
      : CAMediaTimingFunction(controlPoints: 0.333, 0, 0.667, 1)
    layer.add(fade, forKey: "automaticLayoutChangeFadeIn")

    guard !reduceMotion else { return }
    let spring = CASpringAnimation(keyPath: "transform.translation.y")
    spring.mass = 1
    spring.stiffness = 449
    spring.damping = 31.4
    spring.initialVelocity = 0
    spring.fromValue = fromTranslation
    spring.toValue = 0
    spring.duration = Self.springDuration
    layer.add(spring, forKey: "automaticLayoutChangeSpringIn")
  }

  private func resetToastLayer() {
    guard let layer = toastContainer.layer else { return }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.removeAllAnimations()
    layer.opacity = 1
    layer.transform = CATransform3DIdentity
    CATransaction.commit()
  }

  private func pulse() {
    guard let layer = pillView.layer else { return }
    layer.removeAnimation(forKey: "automaticLayoutChangePulse")
    let animation = CAKeyframeAnimation(keyPath: "transform.scale")
    animation.values = [1, 1.04, 1]
    animation.keyTimes = [0, 0.5, 1]
    animation.duration = 0.16
    let ease = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1)
    animation.timingFunctions = [
      ease, ease,
    ]
    layer.add(animation, forKey: "automaticLayoutChangePulse")
  }

  private func hide(generation: Int) {
    guard generation == presentationGeneration, panel.isVisible, !isExiting else { return }
    hideWorkItem = nil
    isExiting = true
    let reduceMotion = reduceMotion()
    guard let layer = toastContainer.layer else {
      panel.orderOut(nil)
      isExiting = false
      return
    }
    let presentation = presentationState(layer)
    let fromOpacity = presentation?.opacity ?? 1
    let fromTranslation = presentation?.translation ?? 0
    layer.removeAllAnimations()
    let duration = reduceMotion ? 0.15 : 0.18
    let easing =
      reduceMotion
      ? CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1)
      : CAMediaTimingFunction(controlPoints: 0.4, 0, 1, 1)
    let fade = CABasicAnimation(keyPath: "opacity")
    fade.fromValue = fromOpacity
    fade.toValue = 0
    fade.duration = duration
    fade.timingFunction = easing

    var animations: [CAAnimation] = [fade]
    if !reduceMotion {
      let drop = CABasicAnimation(keyPath: "transform.translation.y")
      drop.fromValue = fromTranslation
      drop.toValue = -8
      drop.duration = duration
      drop.timingFunction = easing
      animations.append(drop)
    }
    let group = CAAnimationGroup()
    group.animations = animations
    group.duration = duration
    // Hold the transparent endpoint until orderOut; removing it first reveals the visible model.
    group.fillMode = .forwards
    group.isRemovedOnCompletion = false

    CATransaction.begin()
    CATransaction.setCompletionBlock { [weak self] in
      guard let self, generation == self.presentationGeneration else { return }
      self.panel.orderOut(nil)
      self.isExiting = false
      self.resetToastLayer()
    }
    layer.add(group, forKey: "automaticLayoutChangeExit")
    CATransaction.commit()
  }

  private func targetScreen(for client: IMKTextInput & IMKUnicodeTextInput) -> NSScreen? {
    let selection = client.selectedRange()
    guard selection.location != NSNotFound else { return NSScreen.main ?? NSScreen.screens.first }
    var lineRect = NSRect.zero
    _ = client.attributes(forCharacterIndex: selection.location, lineHeightRectangle: &lineRect)
    return NSScreen.screens.first(where: { $0.frame.intersects(lineRect) })
      ?? NSScreen.main ?? NSScreen.screens.first
  }

  private func origin(on screen: NSScreen?) -> NSPoint {
    guard let screen else { return .zero }
    let visibleFrame = screen.visibleFrame
    return NSPoint(
      x: visibleFrame.midX - panel.frame.width / 2,
      y: visibleFrame.minY + 56 - Self.canvasInset.height)
  }
}

extension IMKServer {
  convenience init?(bundle: Bundle) {
    guard let connectionName = bundle.infoDictionary!["InputMethodConnectionName"] as? String else {
      return nil
    }
    self.init(name: connectionName, bundleIdentifier: bundle.bundleIdentifier)
  }
}

class IOKitty {
  let service: SIOService
  let connect: SIOConnect
  let manager: IOHIDManager
  private var defaultCapsLockState: Bool = false
  var capsLockDate: Date?
  var rollback: (() -> Void)?
  var rightKeyPressed = false

  init?() {
    guard let _service = SIOService(name: kIOHIDSystemClass) else {
      return nil
    }
    service = _service
    guard
      let _connect = try? service.open(owningTask: mach_task_self_, type: kIOHIDParamConnectType)
        .get()
    else {
      return nil
    }
    connect = _connect

    defaultCapsLockState = (try? connect.getModifierLock(selector: .capsLock).get()) ?? false

    manager = IOHIDManager.create()
    manager.setDeviceMatching(page: kHIDPage_GenericDesktop, usage: kHIDUsage_GD_Keyboard)
    manager.setInputValueMatching(min: kHIDUsage_KeyboardCapsLock, max: kHIDUsage_KeyboardRightGUI)

    let _self = Unmanaged.passUnretained(self)
    // Set input value callback
    manager.registerInputValueCallback(
      {
        inContext, _, _, value in
        let usage = Int(value.element.usage)
        guard
          usage == kHIDUsage_KeyboardCapsLock
            || (usage >= kHIDUsage_KeyboardRightControl && usage <= kHIDUsage_KeyboardRightGUI)
        else {
          return
        }
        guard
          Configuration.shared.enableCapslockToToggleInputMode
            || Configuration.shared.rightToggleKey > 0
        else {
          return
        }
        guard let inContext = inContext else {
          dlog(true, "IOKit callback inContext is nil - impossible")
          return
        }

        let pressed = value.integerValue > 0
        switch usage {
        case kHIDUsage_KeyboardCapsLock:
          guard Configuration.shared.enableCapslockToToggleInputMode else {
            return
          }
          dlog(debugIOKitEvent, "caps lock pressed: \(pressed)")
          let _self = Unmanaged<IOKitty>.fromOpaque(inContext).takeUnretainedValue()
          if pressed {
            _self.capsLockDate = Date()
            dlog(debugIOKitEvent, "caps lock pressed set in context")
          } else {
            if _self.defaultCapsLockState || (_self.capsLockDate != nil && !_self.capsLockTriggered)
            {
              // long pressed
              _self.defaultCapsLockState = !_self.defaultCapsLockState
              _self.rollback?()
              _self.rollback = nil
            } else {
              // short pressed
              _ = _self.connect.setModifierLock(
                selector: .capsLock, state: _self.defaultCapsLockState)
              _self.capsLockDate = nil
            }
          }
        case Configuration.shared.rightToggleKey:
          dlog(debugIOKitEvent, "right toggle key pressed: \(pressed)")
          let _self = Unmanaged<IOKitty>.fromOpaque(inContext).takeUnretainedValue()
          if pressed {
            _self.rightKeyPressed = true
            dlog(debugIOKitEvent, "right toggle key pressed set in context")
          }
        default:
          break
        }
        // NSEvent.otherEvent(with: .applicationDefined, location: .zero, modifierFlags: .capsLock, timestamp: 0, windowNumber: 0, context: nil, subtype: 0, data1: 0, data2: 0)!
      }, context: _self.toOpaque())

    manager.schedule(runloop: .current, mode: .default)
    let r = manager.open()
    if r != kIOReturnSuccess {
      dlog(debugIOKitEvent, "IOHIDManagerOpen failed")
    }
  }

  deinit {
    manager.unschedule(runloop: .current, mode: .default)
    manager.unregisterInputValueCallback()
    let r = manager.close()
    assert(r == 0)
  }

  var capsLockTriggered: Bool {
    dlog(debugIOKitEvent, "  triggered: date \(String(describing: capsLockDate))")
    guard let capsLockDate = capsLockDate else {
      return false
    }
    let interval = Date().timeIntervalSince(capsLockDate)
    dlog(debugIOKitEvent, "  triggered: interval \(interval)")
    return interval < 0.5
  }

  func resolveRightKeyPressed() -> Bool {
    if !rightKeyPressed {
      return false
    }
    rightKeyPressed = false
    return true
  }
}

//! @brief  공통적인 OSX의 입력기 구조를 다룬다.
//!
//! InputManager는 @ref InputController 또는 테스트코드에 해당하는 외부에서 입력을 받아 입력기에서 처리 후 결과 값을 보관한다. 처리 후 그 결과를 확인하는 것은 사용자의 몫이다.
//!
//! IMKServer나 클라이언트와 무관하게 입력 값에 대해 출력 값을 생성해 내는 입력기. 입력 뿐만 아니라 여러 키보드 간 전환이나 입력기에 관한 단축키 등 입력기에 관한 모든 기능을 다룬다.
//!
//! @coclass    IMKServer DelegatedComposer
// TODO: InputTextDelegate를 제거하고 서버만 관리하도록 한다
public class InputMethodServer {
  public static let shared = InputMethodServer()
  //! @brief  현재 입력중인 서버
  let server: IMKServer
  //! @property
  let candidates: IMKCandidates
  //! @brief  입력기가 inputText: 문맥에 있는지 여부를 저장
  let io: IOKitty

  convenience init() {
    let bundle = Bundle.main
    var name = bundle.infoDictionary!["InputMethodConnectionName"] as! String
    #if DEBUG
      if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
        name += "_Test" + String(describing: Int.random(in: 0..<0x10000))
      } else if !InputMethodIdentity.current.usesForkServices {
        name += "_Debug"
      }
    #endif

    self.init(name: name)
  }

  init(name: String) {
    dlog(debugInputServer, "** InputMethodServer Init")

    server = IMKServer(name: name, bundleIdentifier: Bundle.main.bundleIdentifier)
    candidates = IMKCandidates(server: server, panelType: kIMKSingleColumnScrollingCandidatePanel)
    // candidates.setSelectionKeysKeylayout(TISInputSource.currentKeyboardLayout())

    io = IOKitty()!
    dlog(debugInputServer, "\t%@", description)
  }

  var description: String {
    return """
      <InputMethodServer server: "\(String(describing: server))" candidates: "\(String(describing: candidates))">
      """
  }

  func showOrHideCandidates(controller: InputController) {
    showOrHideCandidates(composer: controller.receiver.composer)
  }

  func showOrHideCandidates(composer: Composer) {
    if composer.hasCandidates {
      candidates.update()
      candidates.show(kIMKLocateCandidatesLeftHint)
    } else if candidates.isVisible() {
      candidates.hide()
    }
  }
}
