import Intents

@available(macOS 11.0, *)
class SelectIntentHandler: NSObject, SelectIntentHandling {
  private let positionOffset = 1
  private var yapp: YApp!

  init(_ yapp: YApp) {
    self.yapp = yapp
  }

  func handle(intent: SelectIntent, completion: @escaping (SelectIntentResponse) -> Void) {
    guard let number = intent.number as? Int,
          let value = yapp.select(position: number - positionOffset) else {
      return completion(SelectIntentResponse(code: .failure, userActivity: nil))
    }

    let response = SelectIntentResponse(code: .success, userActivity: nil)
    response.value = value
    return completion(response)
  }

  func resolveNumber(for intent: SelectIntent, with completion: @escaping (SelectNumberResolutionResult) -> Void) {
    guard let number = intent.number as? Int else {
      return completion(.needsValue())
    }

    return completion(.success(with: number))
  }
}
