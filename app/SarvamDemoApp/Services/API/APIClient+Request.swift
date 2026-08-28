// APIClient+Request: UI and service logic for this feature.
import Foundation

// Defines APIClient.
extension APIClient {
  // Defines HTTPMethod.
  enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
  }

  // Handles makeRequest.
  func makeRequest(
    path: String,
    method: HTTPMethod,
    body: Data? = nil
  ) throws -> URLRequest {
    // 1. Build the URL request and add the headers required by the API.
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

  // Handles encode.
  func encode<Body: Encodable>(_ body: Body) throws -> Data {
    // 1. Encode the request body and map encoding failures to API errors.
    do {
      let data = try encoder.encode(body)
      print("[App:API] Request body encoded")
      return data
    } catch {
      throw APIError.encoding(error)
    }
  }

  // Handles perform.
  func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
    // 1. Execute the request, then decode the successful response.
    let data = try await performData(request)

    do {
      return try decoder.decode(Response.self, from: data)
    } catch {
      throw APIError.decoding(error)
    }
  }

  // Handles perform.
  func perform(_ request: URLRequest) async throws {
    _ = try await performData(request)
  }

  // Handles performData.
  private func performData(_ request: URLRequest) async throws -> Data {
    // 1. Send the request and translate transport or HTTP failures.
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

  // Handles perform.
  func perform<Response: Decodable>(
    path: String,
    method: HTTPMethod,
    body: Data? = nil
  ) async throws -> Response {
    // 1. Build the request, then execute and decode it.
    let request = try makeRequest(path: path, method: method, body: body)
    return try await perform(request)
  }

  // Handles perform.
  func perform(
    path: String,
    method: HTTPMethod,
    body: Data? = nil
  ) async throws {
    // 1. Build the request, then execute it without a response body.
    let request = try makeRequest(path: path, method: method, body: body)
    try await perform(request)
  }
}
