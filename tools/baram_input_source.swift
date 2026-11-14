import Carbon
import Foundation

private let baramPrefix = "com.sionyuel.inputmethod.Baram."

private struct SavedSelection: Codable {
  let identifier: String
}

private enum ToolError: Error {
  case message(String)
}

private func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
  guard let value = TISGetInputSourceProperty(source, key) else { return nil }
  return Unmanaged<CFString>.fromOpaque(value).takeUnretainedValue() as String
}

private func boolProperty(_ source: TISInputSource, _ key: CFString) -> Bool {
  guard let value = TISGetInputSourceProperty(source, key) else { return false }
  return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(value).takeUnretainedValue())
}

private func allSources() -> [TISInputSource] {
  TISCreateInputSourceList(nil, true).takeRetainedValue() as! [TISInputSource]
}

private func source(identifier: String) throws -> TISInputSource {
  guard
    let source = allSources().first(where: {
      stringProperty($0, kTISPropertyInputSourceID) == identifier
    })
  else {
    throw ToolError.message("Input source is not registered: \(identifier)")
  }
  return source
}

private func baramSource(_ argument: String) throws -> TISInputSource {
  let identifier = argument.hasPrefix(baramPrefix) ? argument : baramPrefix + argument
  guard identifier.hasPrefix(baramPrefix), !identifier.dropFirst(baramPrefix.count).isEmpty else {
    throw ToolError.message("Select a Baram layout suffix, for example han3final or han390.")
  }
  return try source(identifier: identifier)
}

private func check(_ status: OSStatus, _ operation: String) throws {
  guard status == noErr else {
    throw ToolError.message("\(operation) failed with OSStatus \(status).")
  }
}

private func enableBaramSource(_ target: TISInputSource) throws -> TISInputSource {
  let parent = try source(identifier: String(baramPrefix.dropLast()))
  try check(TISEnableInputSource(parent), "Enable Baram input method")
  try check(TISEnableInputSource(target), "Enable Baram layout")
  guard let identifier = stringProperty(target, kTISPropertyInputSourceID) else {
    throw ToolError.message("Baram layout has no identifier.")
  }
  return try source(identifier: identifier)
}

private func registerBaram() throws {
  let app = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Input Methods/Baram.app")
  guard Bundle(url: app)?.bundleIdentifier == "com.sionyuel.inputmethod.Baram" else {
    throw ToolError.message("Install the verified Baram.app first.")
  }
  try check(TISRegisterInputSource(app as CFURL), "Baram registration")
}

private func run(_ arguments: [String]) throws {
  guard let command = arguments.first else {
    throw ToolError.message("Expected list, current, enable, activate, select, or restore.")
  }
  if command == "current" {
    let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    print(stringProperty(current, kTISPropertyInputSourceID) ?? "unknown")
    return
  }
  if command == "restore" {
    guard arguments.count == 2 else { throw ToolError.message("Expected restore state-file.") }
    let stateURL = URL(fileURLWithPath: arguments[1])
    let saved = try JSONDecoder().decode(SavedSelection.self, from: Data(contentsOf: stateURL))
    try check(TISSelectInputSource(source(identifier: saved.identifier)), "Restore selection")
    try FileManager.default.removeItem(at: stateURL)
    print("Restored \(saved.identifier)")
    return
  }

  try registerBaram()
  switch command {
  case "list":
    for source in allSources() {
      guard let identifier = stringProperty(source, kTISPropertyInputSourceID),
        identifier.hasPrefix(baramPrefix)
      else { continue }
      let name = stringProperty(source, kTISPropertyLocalizedName) ?? identifier
      print(
        "\(identifier)\tenabled=\(boolProperty(source, kTISPropertyInputSourceIsEnabled))\tselected=\(boolProperty(source, kTISPropertyInputSourceIsSelected))\t\(name)"
      )
    }
  case "enable":
    guard arguments.count == 2 else { throw ToolError.message("Expected enable layout-suffix.") }
    _ = try enableBaramSource(baramSource(arguments[1]))
    print("Enabled \(arguments[1])")
  case "activate":
    guard arguments.count == 2 else {
      throw ToolError.message("Expected activate layout-suffix.")
    }
    let target = try enableBaramSource(baramSource(arguments[1]))
    try check(TISSelectInputSource(target), "Activate Baram source")
    print("Activated \(stringProperty(target, kTISPropertyInputSourceID) ?? arguments[1])")
  case "select":
    guard arguments.count == 3 else {
      throw ToolError.message("Expected select layout-suffix state-file.")
    }
    let target = try baramSource(arguments[1])
    let stateURL = URL(fileURLWithPath: arguments[2])
    if !FileManager.default.fileExists(atPath: stateURL.path) {
      let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
      guard let identifier = stringProperty(current, kTISPropertyInputSourceID) else {
        throw ToolError.message("Cannot save the current input source.")
      }
      try JSONEncoder().encode(SavedSelection(identifier: identifier)).write(
        to: stateURL, options: .atomic)
      print("Saved previous input source: \(identifier)")
    }
    let enabledTarget = try enableBaramSource(target)
    let status = TISSelectInputSource(enabledTarget)
    if status == paramErr {
      throw ToolError.message(
        "macOS has registered the Baram but cannot select it yet (OSStatus -50). Add the Baram layout in System Settings > Keyboard > Text Input, or log out and back in. The previous selection is saved; use restore to return to it."
      )
    }
    try check(status, "Select Baram source")
    print("Selected \(stringProperty(target, kTISPropertyInputSourceID) ?? arguments[1])")
  default:
    throw ToolError.message("Unknown command: \(command)")
  }
}

do {
  try run(Array(CommandLine.arguments.dropFirst()))
} catch {
  let message: String
  if case ToolError.message(let detail) = error {
    message = detail
  } else {
    message = error.localizedDescription
  }
  FileHandle.standardError.write(Data((message + "\n").utf8))
  exit(1)
}
