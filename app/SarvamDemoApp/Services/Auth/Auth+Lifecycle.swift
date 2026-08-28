import UIKit

extension Auth {
  func start() {
    print("[App:Auth] Lifecycle started")
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
    print("[App:Auth] Lifecycle stopped")
    lifecycleTask?.cancel()
    lifecycleTask = nil
  }
}
