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
    let url = configuration.baseURL.appendingPathComponent(path)
    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    if let body {
      request.httpBody = body
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    return request
  }

  func encode<Body: Encodable>(_ body: Body) throws -> Data {
    do {
      return try encoder.encode(body)
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
    let data: Data
    let response: URLResponse

    do {
      (data, response) = try await session.data(for: request)
    } catch let error as URLError {
      throw APIError.transport(error)
    } catch {
      throw APIError.request(error)
    }

    guard let response = response as? HTTPURLResponse else {
      throw APIError.invalidResponse
    }

    guard (200..<300).contains(response.statusCode) else {
      let payload = try? decoder.decode(APIError.ErrorPayload.self, from: data)
      throw APIError.http(
        statusCode: response.statusCode,
        payload: payload
      )
    }

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
