import Foundation
import Observation

extension ChatView {
  @MainActor
  @Observable
  final class ViewModel {
    // MARK: Input
    
    var text: String = ""
  }
}
