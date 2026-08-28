import Foundation

extension APIClient {
  enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
  }

  func makeRequest(
    path: String,
    method: HTTPMethod,
    body: Data? = nil
  ) throws -> URLRequest {
    print("[App:API] Building \(method.rawValue) \(path)")
    let url = configuration.baseURL.appendingPathComponent(path)
    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    // Better Auth validates the Origin header for cookie-authenticated POSTs.
    // URLSession does not add one for native requests, so provide the API's
    // origin explicitly (without including a path).
    if var originComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {
      originComponents.path = ""
      originComponents.query = nil
      originComponents.fragment = nil
      if let origin = originComponents.string {
        request.setValue(origin, forHTTPHeaderField: "Origin")
      }
    }

    if let body {
      request.httpBody = body
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    return request
  }

  func encode<Body: Encodable>(_ body: Body) throws -> Data {
    do {
      let data = try encoder.encode(body)
      print("[App:API] Request body encoded")
      return data
    } catch {
      throw APIError.encoding(error)
    }
  }

  func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
    let data = try await performData(request)

    do {
      return try decoder.decode(Response.self, from: data)
    } catch {
      throw APIError.decoding(error)
    }
  }

  func perform(_ request: URLRequest) async throws {
    _ = try await performData(request)
  }

  private func performData(_ request: URLRequest) async throws -> Data {
    print("[App:API] Request started")
    let data: Data
    let response: URLResponse

    do {
      (data, response) = try await session.data(for: request)
    } catch let error as URLError {
      print("[App:API] Transport request failed")
      throw APIError.transport(error)
    } catch {
      print("[App:API] Request failed")
      throw APIError.request(error)
    }

    guard let response = response as? HTTPURLResponse else {
      throw APIError.invalidResponse
    }

    guard (200..<300).contains(response.statusCode) else {
      print("[App:API] Request failed with HTTP \(response.statusCode)")
      let payload = try? decoder.decode(APIError.ErrorPayload.self, from: data)
      throw APIError.http(
        statusCode: response.statusCode,
        payload: payload
      )
    }

    print("[App:API] Request succeeded with HTTP \(response.statusCode)")
    return data
  }

  func perform<Response: Decodable>(
    path: String,
    method: HTTPMethod,
    body: Data? = nil
  ) async throws -> Response {
    let request = try makeRequest(path: path, method: method, body: body)
    return try await perform(request)
  }

  func perform(
    path: String,
    method: HTTPMethod,
    body: Data? = nil
  ) async throws {
    let request = try makeRequest(path: path, method: method, body: body)
    try await perform(request)
  }
}
