import Intents

@available(macOS 11.0, *)
class ClearIntentHandler: NSObject, ClearIntentHandling {
  private var yapp: Y!

  init(_ yapp: Y) {
    self.yapp = yapp
  }

  func handle(intent: ClearIntent, completion: @escaping (ClearIntentResponse) -> Void) {
    yapp.clearUnpinned()
    return completion(ClearIntentResponse(code: .success, userActivity: nil))
  }
}
