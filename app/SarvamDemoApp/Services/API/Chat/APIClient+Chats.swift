// APIClient+Chats: UI and service logic for this feature.
import Alamofire
import Foundation

// Defines APIClient.
extension APIClient {
  static var chats: Chats { shared.chatsAPI }

  final class Chats {
    let client: APIClient
    let session: Alamofire.Session

    init(client: APIClient) {
      self.client = client
      self.session = Alamofire.Session(configuration: client.session.configuration)
    }

    // Handles create.
    func create() async throws -> String {
      print("[App:ChatAPI] Creating chat")
      let response: CreateResponse = try await client.perform(path: "chats/new", method: .post)
      return response.id
    }

    // Handles list.
    func list() async throws -> [ChatSummary] {
      print("[App:ChatAPI] Listing chats")
      let response: ListResponse = try await client.perform(path: "chats/list", method: .get)
      return response.chats
    }

    // Handles get.
    func get(id: String) async throws -> Chat {
      print("[App:ChatAPI] Loading chat")
      return try await client.perform(path: "chats/\(id)", method: .get)
    }

    // Handles stream.
    func stream(id: String, content: String) -> AsyncThrowingStream<ChatStreamChunk, Error> {
      print("[App:ChatAPI] Starting stream")
      return AsyncThrowingStream { continuation in
        let body = StreamRequest(content: content)
        var request: URLRequest
        do {
          request = try client.makeRequest(path: "chats/\(id)/stream", method: .post, body: try client.encode(body))
        } catch { continuation.finish(throwing: error); return }
        request.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")

        var pending = Data()
        let dataRequest = session.streamRequest(request)
          .validate(statusCode: 200..<300)
          .responseStreamString { stream in
            switch stream.event {
            case .stream(let result):
              if case .success(let string) = result {
                pending.append(Data(string.utf8))
                while let newline = pending.firstIndex(of: 10) {
                  let line = pending[..<newline]
                  pending.removeSubrange(pending.startIndex..<(newline + 1))
                  guard !line.isEmpty else { continue }
                  do {
                    continuation.yield(try self.client.decoder.decode(ChatStreamChunk.self, from: Data(line)))
                  } catch { continuation.finish(throwing: APIError.decoding(error)); return }
                }
              }
            case .complete(let completion):
              if let error = completion.error { continuation.finish(throwing: APIError.request(error)) }
              else if !pending.isEmpty { continuation.finish(throwing: APIError.decoding(StreamDecodeError.trailingData)) }
              else { continuation.finish() }
            }
          }
        continuation.onTermination = { _ in dataRequest.cancel() }
      }
    }

    // Defines CreateResponse.
    private struct CreateResponse: Decodable { let id: String }
    // Defines ListResponse.
    private struct ListResponse: Decodable { let chats: [ChatSummary] }
    // Defines StreamRequest.
    private struct StreamRequest: Encodable { let content: String }
    // Defines StreamDecodeError.
    private enum StreamDecodeError: Error { case trailingData }
  }
}
