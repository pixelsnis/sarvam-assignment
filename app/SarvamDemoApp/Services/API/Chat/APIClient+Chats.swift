import Alamofire
import Foundation

extension APIClient {
  static var chats: Chats { shared.chatsAPI }

  final class Chats {
    let client: APIClient
    let session: Alamofire.Session

    init(client: APIClient) {
      self.client = client
      self.session = Alamofire.Session(configuration: client.session.configuration)
    }

    func create() async throws -> String {
      print("[App:ChatAPI] Creating chat")
      let response: CreateResponse = try await client.perform(path: "chats/new", method: .post)
      return response.id
    }

    func list() async throws -> [ChatSummary] {
      print("[App:ChatAPI] Listing chats")
      let response: ListResponse = try await client.perform(path: "chats/list", method: .get)
      return response.chats
    }

    func get(id: String) async throws -> Chat {
      print("[App:ChatAPI] Loading chat")
      return try await client.perform(path: "chats/\(id)", method: .get)
    }

    func stream(id: String, content: String) -> AsyncThrowingStream<ChatStreamChunk, Error> {
      print("[App:ChatAPI] Starting stream")
      return AsyncThrowingStream { continuation in
        let body = StreamRequest(content: content)
        let request: URLRequest
        do {
          request = try client.makeRequest(path: "chats/\(id)/stream", method: .post, body: try client.encode(body))
        } catch { continuation.finish(throwing: error); return }

        var pending = Data()
        let dataRequest = session.streamRequest(request)
          .validate()
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

    private struct CreateResponse: Decodable { let id: String }
    private struct ListResponse: Decodable { let chats: [ChatSummary] }
    private struct StreamRequest: Encodable { let content: String }
    private enum StreamDecodeError: Error { case trailingData }
  }
}
