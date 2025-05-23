import AppKit
import Sauce

class Clipboard {
  static let shared = Clipboard()

  typealias OnNewCopyHook = (HistoryItem) -> Void

  var onNewCopyHooks: [OnNewCopyHook] = []
  var changeCount: Int

  private let pasteboard = NSPasteboard.general
  private let timerInterval = 1.0

  private let dynamicTypePrefix = "dyn."
  private let microsoftSourcePrefix = "com.microsoft.ole.source."
  private let supportedTypes: Set<NSPasteboard.PasteboardType> = [
    .fileURL,
    .html,
    .png,
    .rtf,
    .string,
    .tiff
  ]
  private let ignoredTypes: Set<NSPasteboard.PasteboardType> = [
    .autoGenerated,
    .concealed,
    .transient
  ]
  private let modifiedTypes: Set<NSPasteboard.PasteboardType> = [.modified]

  private var enabledTypes: Set<NSPasteboard.PasteboardType> { UserDefaults.standard.enabledPasteboardTypes }
  private var disabledTypes: Set<NSPasteboard.PasteboardType> { supportedTypes.subtracting(enabledTypes) }

  private var sourceApp: NSRunningApplication? { NSWorkspace.shared.frontmostApplication }

  private var accessibilityAlert: NSAlert {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = NSLocalizedString("accessibility_alert_message", comment: "")
    alert.informativeText = NSLocalizedString("accessibility_alert_comment", comment: "")
    alert.addButton(withTitle: NSLocalizedString("accessibility_alert_deny", comment: ""))
    alert.addButton(withTitle: NSLocalizedString("accessibility_alert_open", comment: ""))
    alert.icon = NSImage(named: "NSSecurity")
    return alert
  }
  private var accessibilityAllowed: Bool { AXIsProcessTrustedWithOptions(nil) }
  private let accessibilityURL = URL(
    string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
  )

  init() {
    changeCount = pasteboard.changeCount
  }

  func onNewCopy(_ hook: @escaping OnNewCopyHook) {
    onNewCopyHooks.append(hook)
  }

  func startListening() {
    Timer.scheduledTimer(timeInterval: timerInterval,
                         target: self,
                         selector: #selector(checkForChangesInPasteboard),
                         userInfo: nil,
                         repeats: true)
  }

  func copy(_ string: String) {
    pasteboard.clearContents()
    pasteboard.setString(string, forType: .string)
    checkForChangesInPasteboard()
  }

  func copy(_ item: HistoryItem, removeFormatting: Bool = false) {
    pasteboard.clearContents()
    var contents = item.getContents()

    if removeFormatting {
      let stringContents = contents.filter({
        NSPasteboard.PasteboardType($0.type) == .string
      })

      // If there is no string representation of data,
      // behave like we didn't have to remove formatting.
      if !stringContents.isEmpty {
        contents = stringContents
      }
    }

    for content in contents {
      pasteboard.setData(content.value, forType: NSPasteboard.PasteboardType(content.type))
    }
    pasteboard.setString("", forType: .fromYApp)

    if UserDefaults.standard.playSounds {
      NSSound(named: NSSound.Name("knock"))?.play()
    }

    checkForChangesInPasteboard()
  }

  // Based on https://github.com/Clipy/Clipy/blob/develop/Clipy/Sources/Services/PasteService.swift.
  func paste() {
    guard accessibilityAllowed else {
      YApp.returnFocusToPreviousApp = false
      // Show accessibility window async to allow menu to close.
      DispatchQueue.main.async(execute: showAccessibilityWindow)
      return
    }

    DispatchQueue.main.async {
      // Add flag that left/right modifier key has been pressed.
      // See https://github.com/TermiT/Flycut/pull/18 for details.
      let cmdFlag = CGEventFlags(rawValue: UInt64(KeyChord.pasteKeyModifiers.rawValue) | 0x000008)
      var vCode = Sauce.shared.keyCode(for: KeyChord.pasteKey)

      // Force QWERTY keycode when keyboard layout switches to
      // QWERTY upon pressing ⌘ key (e.g. "Dvorak - QWERTY ⌘").
      // See https://github.com/zeekay/YApp/issues/482 for details.
      if KeyboardLayout.current.commandSwitchesToQWERTY && cmdFlag.contains(.maskCommand) {
        vCode = KeyChord.pasteKey.QWERTYKeyCode
      }

      let source = CGEventSource(stateID: .combinedSessionState)
      // Disable local keyboard events while pasting
      source?.setLocalEventsFilterDuringSuppressionState([.permitLocalMouseEvents, .permitSystemDefinedEvents],
                                                         state: .eventSuppressionStateSuppressionInterval)

      let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: vCode, keyDown: true)
      let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: vCode, keyDown: false)
      keyVDown?.flags = cmdFlag
      keyVUp?.flags = cmdFlag
      keyVDown?.post(tap: .cgAnnotatedSessionEventTap)
      keyVUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
  }

  func clear() {
    guard UserDefaults.standard.clearSystemClipboard else {
      return
    }

    pasteboard.clearContents()
  }

  @objc
  func checkForChangesInPasteboard() {
    guard pasteboard.changeCount != changeCount else {
      return
    }

    changeCount = pasteboard.changeCount

    if UserDefaults.standard.ignoreEvents {
      if UserDefaults.standard.ignoreOnlyNextEvent {
        UserDefaults.standard.ignoreEvents = false
        UserDefaults.standard.ignoreOnlyNextEvent = false
      }

      return
    }

    // Reading types on NSPasteboard gives all the available
    // types - even the ones that are not present on the NSPasteboardItem.
    // See https://github.com/zeekay/YApp/issues/241.
    if shouldIgnore(Set(pasteboard.types ?? [])) {
      return
    }

    if let sourceAppBundle = sourceApp?.bundleIdentifier {
      if shouldIgnore(sourceAppBundle) {
        return
      }
    }

    // Some applications (BBEdit, Edge) add 2 items to pasteboard when copying
    // so it's better to merge all data into a single record.
    // - https://github.com/zeekay/YApp/issues/78
    // - https://github.com/zeekay/YApp/issues/472
    var contents: [HistoryItemContent] = []
    pasteboard.pasteboardItems?.forEach({ item in
      let types = Set(item.types)
      if types.contains(.string) && isEmptyString(item) && !richText(item) {
        return
      }

      contents += types
        .subtracting(disabledTypes)
        .filter { !$0.rawValue.starts(with: dynamicTypePrefix) && !$0.rawValue.starts(with: microsoftSourcePrefix) }
        .map { HistoryItemContent(type: $0.rawValue, value: item.data(forType: $0)) }
    })

    guard !contents.isEmpty else {
      return
    }

    let historyItem = HistoryItem(contents: contents, application: sourceApp?.bundleIdentifier)
    onNewCopyHooks.forEach({ $0(historyItem) })
  }

  private func shouldIgnore(_ types: Set<NSPasteboard.PasteboardType>) -> Bool {
    let ignoredTypes = self.ignoredTypes
      .union(UserDefaults.standard.ignoredPasteboardTypes.map({ NSPasteboard.PasteboardType($0) }))

    return types.isDisjoint(with: enabledTypes) ||
      !types.isDisjoint(with: ignoredTypes)
  }

  private func shouldIgnore(_ sourceAppBundle: String) -> Bool {
    if UserDefaults.standard.ignoreAllAppsExceptListed {
      return !UserDefaults.standard.ignoredApps.contains(sourceAppBundle)
    } else {
      return UserDefaults.standard.ignoredApps.contains(sourceAppBundle)
    }
  }

  private func isEmptyString(_ item: NSPasteboardItem) -> Bool {
    guard let string = item.string(forType: .string) else {
      return true
    }

    return string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func richText(_ item: NSPasteboardItem) -> Bool {
    if let rtf = item.data(forType: .rtf) {
      if let attributedString = NSAttributedString(rtf: rtf, documentAttributes: nil) {
        return !attributedString.string.isEmpty
      }
    }

    if let html = item.data(forType: .html) {
      if let attributedString = NSAttributedString(html: html, documentAttributes: nil) {
        return !attributedString.string.isEmpty
      }
    }

    return false
  }

  private func showAccessibilityWindow() {
    if accessibilityAlert.runModal() == NSApplication.ModalResponse.alertSecondButtonReturn {
      if let url = accessibilityURL {
        NSWorkspace.shared.open(url)
      }
    }
    YApp.returnFocusToPreviousApp = true
  }
}
