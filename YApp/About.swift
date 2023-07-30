import Cocoa

class About {
  private let familyCredits = NSAttributedString(
    string: "Special thank Anthropic & Hugging Face! ❤️",
    attributes: [NSAttributedString.Key.foregroundColor: NSColor.labelColor]
  )

  private var kossCredits: NSMutableAttributedString {
    let string = NSMutableAttributedString(string: "Donate to save animals! 🏂",
                                           attributes: [NSAttributedString.Key.foregroundColor: NSColor.labelColor])
    string.addAttribute(.link, value: "https://zoo.ngo", range: NSRange(location: 9, length: 10))
    return string
  }

  private var links: NSMutableAttributedString {
    let string = NSMutableAttributedString(string: "Website│GitHub│Support",
                                           attributes: [NSAttributedString.Key.foregroundColor: NSColor.labelColor])
    string.addAttribute(.link, value: "https://yapp.io", range: NSRange(location: 0, length: 7))
    string.addAttribute(.link, value: "https://github.com/zeekay/yapp", range: NSRange(location: 8, length: 6))
    string.addAttribute(.link, value: "mailto:support@yapp.io", range: NSRange(location: 15, length: 7))
    return string
  }

  private var credits: NSMutableAttributedString {
    let credits = NSMutableAttributedString(string: "",
                                            attributes: [NSAttributedString.Key.foregroundColor: NSColor.labelColor])
    credits.append(links)
    credits.append(NSAttributedString(string: "\n\n"))
    credits.append(kossCredits)
    credits.append(NSAttributedString(string: "\n"))
    credits.append(familyCredits)
    credits.setAlignment(.center, range: NSRange(location: 0, length: credits.length))
    return credits
  }

  @objc
  func openAbout(_ sender: NSMenuItem) {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.orderFrontStandardAboutPanel(options: [NSApplication.AboutPanelOptionKey.credits: credits])
  }
}
