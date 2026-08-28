import UIKit

extension Auth {
  func start() {
    guard lifecycleTask == nil else { return }

    lifecycleTask = Task { [weak self] in
      guard let self else { return }

      await refreshSession()

      for await _ in NotificationCenter.default.notifications(
        named: UIApplication.didBecomeActiveNotification
      ) {
        guard !Task.isCancelled else { return }
        await refreshSession()
      }
    }
  }

  func stop() {
    lifecycleTask?.cancel()
    lifecycleTask = nil
  }
}
