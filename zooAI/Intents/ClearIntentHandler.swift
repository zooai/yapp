import Intents

@available(macOS 11.0, *)
class ClearIntentHandler: NSObject, ClearIntentHandling {
  private var maccy: ZooAI!

  init(_ maccy: ZooAI) {
    self.maccy = maccy
  }

  func handle(intent: ClearIntent, completion: @escaping (ClearIntentResponse) -> Void) {
    maccy.clearUnpinned()
    return completion(ClearIntentResponse(code: .success, userActivity: nil))
  }
}
