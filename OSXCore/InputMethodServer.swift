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

  private let panel: NSPanel
  private let label: NSTextField
  private var hideWorkItem: DispatchWorkItem?
  private var lastAnnouncement: (message: String, time: TimeInterval)?
  private var presentationGeneration = 0

  private init() {
    panel = AutomaticLayoutChangeHUDPanel(
      contentRect: NSRect(x: 0, y: 0, width: 220, height: 36),
      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    panel.animationBehavior = .none
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = true
    panel.ignoresMouseEvents = true

    let effect = NSVisualEffectView(frame: panel.contentView?.bounds ?? .zero)
    effect.material = .hudWindow
    effect.blendingMode = .behindWindow
    effect.state = .active
    effect.wantsLayer = true
    effect.layer?.cornerRadius = 18
    effect.layer?.masksToBounds = true
    effect.translatesAutoresizingMaskIntoConstraints = false

    label = NSTextField(labelWithString: "")
    label.alignment = .center
    label.font = .systemFont(ofSize: 13, weight: .semibold)
    label.textColor = .labelColor
    label.translatesAutoresizingMaskIntoConstraints = false
    effect.addSubview(label)
    panel.contentView = effect
    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 16),
      label.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -16),
      label.centerYAnchor.constraint(equalTo: effect.centerYAnchor),
    ])
  }

  func show(_ message: String, client: IMKTextInput & IMKUnicodeTextInput) {
    DispatchQueue.main.async { [weak self, weak client = client as AnyObject] in
      guard let self,
        let client = client as? (IMKTextInput & IMKUnicodeTextInput)
      else { return }
      self.present(message, client: client)
    }
  }

  private func present(_ message: String, client: IMKTextInput & IMKUnicodeTextInput) {
    hideWorkItem?.cancel()
    presentationGeneration += 1
    let generation = presentationGeneration
    label.stringValue = message
    let finalOrigin = origin(on: targetScreen(for: client))

    if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
      panel.setFrameOrigin(finalOrigin)
      panel.alphaValue = 0
      panel.orderFrontRegardless()
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.12
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        panel.animator().alphaValue = 1
      }
    } else {
      panel.setFrameOrigin(NSPoint(x: finalOrigin.x, y: finalOrigin.y - 8))
      panel.alphaValue = 0
      panel.orderFrontRegardless()
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.24
        context.timingFunction = CAMediaTimingFunction(
          controlPoints: 0.25, 0.1, 0.25, 1)
        panel.animator().alphaValue = 1
        panel.animator().setFrameOrigin(finalOrigin)
      }
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
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
  }

  private func hide(generation: Int) {
    guard generation == presentationGeneration else { return }
    hideWorkItem = nil
    if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
      panel.orderOut(nil)
      return
    }
    NSAnimationContext.runAnimationGroup(
      { context in
        context.duration = 0.12
        panel.animator().alphaValue = 0
      },
      completionHandler: { [weak self] in
        guard let self, generation == self.presentationGeneration else { return }
        self.panel.orderOut(nil)
      })
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
      y: visibleFrame.minY + 56)
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
