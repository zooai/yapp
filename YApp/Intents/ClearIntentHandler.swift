import Intents

@available(macOS 11.0, *)
class ClearIntentHandler: NSObject, ClearIntentHandling {
  private var yapp: YApp!

  init(_ yapp: YApp) {
    self.yapp = yapp
  }

  func handle(intent: ClearIntent, completion: @escaping (ClearIntentResponse) -> Void) {
    yapp.clearUnpinned()
    return completion(ClearIntentResponse(code: .success, userActivity: nil))
  }
}
