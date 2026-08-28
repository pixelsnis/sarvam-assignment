import Foundation

@MainActor
final class APIEndpointDiscovery: NSObject {
  static let serviceType = "_sarvam-api._tcp."

  private let browser = NetServiceBrowser()
  private var services: [NetService] = []
  private var resolvedService: NetService?
  private let onEndpointDiscovered: (URL) -> Void

  init(onEndpointDiscovered: @escaping (URL) -> Void) {
    self.onEndpointDiscovered = onEndpointDiscovered
    super.init()
    browser.delegate = self
  }

  func start() {
    print("[App:Discovery] Search started")
    browser.searchForServices(ofType: Self.serviceType, inDomain: "local.")
  }

  func stop() {
    print("[App:Discovery] Search stopped")
    browser.stop()
    services.removeAll()
    resolvedService?.stop()
    resolvedService = nil
  }

  private func resolve(_ service: NetService) {
    resolvedService?.stop()
    resolvedService = service
    service.delegate = self
    service.resolve(withTimeout: 5)
  }
}

extension APIEndpointDiscovery: NetServiceBrowserDelegate {
  nonisolated func netServiceBrowser(
    _ browser: NetServiceBrowser,
    didFind service: NetService,
    moreComing: Bool
  ) {
    Task { @MainActor [weak self] in
      guard let self, !services.contains(where: { $0 === service }) else { return }
      print("[App:Discovery] Service found")
      services.append(service)
      resolve(service)
    }
  }

  nonisolated func netServiceBrowser(
    _ browser: NetServiceBrowser,
    didRemove service: NetService,
    moreComing: Bool
  ) {
    Task { @MainActor [weak self] in
      self?.services.removeAll { $0 === service }
    }
  }

  nonisolated func netServiceBrowser(
    _ browser: NetServiceBrowser,
    didNotSearch errorDict: [String: NSNumber]
  ) {
    print("[App:Discovery] Search failed")
  }
}

extension APIEndpointDiscovery: NetServiceDelegate {
  nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
    guard let host = sender.hostName else { return }
    Task { @MainActor [weak self] in
      guard let self, let url = URL(string: "http://\(host):\(sender.port)") else { return }
      print("[App:Discovery] Service resolved")
      APIClient.shared.updateBaseURL(url)
      onEndpointDiscovered(url)
    }
  }

  nonisolated func netService(
    _ sender: NetService,
    didNotResolve errorDict: [String: NSNumber]
  ) {
    print("[App:Discovery] Resolution failed")
  }
}
