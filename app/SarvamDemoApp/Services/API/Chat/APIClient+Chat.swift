import Alamofire
import Foundation

extension APIClient {
  final class Chat {
    private struct StreamRequest: Encodable, Sendable {
      let text: String
    }

    private let client: APIClient
    private let session: Alamofire.Session

    init(client: APIClient) {
      self.client = client
      self.session = Alamofire.Session(
        configuration: client.session.configuration
      )
    }

    func create() async throws -> ChatCreationResponse {
      try await client.perform(
        path: "chats/new",
        method: .post
      )
    }

    func list() async throws -> [ChatSummary] {
      try await client.perform(
        path: "chats",
        method: .get
      )
    }

    func fetch(id: String) async throws -> ChatResponse {
      try await client.perform(
        path: "chats/\(id)",
        method: .get
      )
    }

    func stream(
      _ text: String,
      for chatId: String
    ) throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
      let body = try client.encode(StreamRequest(text: text))
      var request = try client.makeRequest(
        path: "chats/\(chatId)/stream",
        method: .post,
        body: body
      )
      request.setValue(
        "text/event-stream",
        forHTTPHeaderField: "Accept"
      )

      let streamTask =
        session
        .streamRequest(request, automaticallyCancelOnStreamError: true)
        .validate()
        .streamTask()
      let dataStream = streamTask.streamingData()

      return AsyncThrowingStream { continuation in
        continuation.onTermination = { _ in
          streamTask.cancel()
        }

        Task {
          var decoder = ServerSentEventDecoder()

          do {
            for await packet in dataStream {
              switch packet.event {
              case .stream(let result):
                do {
                  for event in try decoder.append(result.get()) {
                    continuation.yield(event)
                  }
                } catch let error as APIError {
                  throw error
                } catch {
                  throw APIError.request(error)
                }
              case .complete(let completion):
                if let error = completion.error {
                  if let statusCode = completion.response?.statusCode,
                    !(200..<300).contains(statusCode)
                  {
                    throw APIError.http(
                      statusCode: statusCode,
                      payload: nil
                    )
                  }

                  throw APIError.request(error)
                }

                for event in try decoder.finish() {
                  continuation.yield(event)
                }
              }
            }

            continuation.finish()
          } catch is CancellationError {
            continuation.finish(throwing: CancellationError())
          } catch let error as APIError {
            continuation.finish(throwing: error)
          } catch {
            continuation.finish(throwing: APIError.request(error))
          }
        }
      }
    }
  }
}

private struct ServerSentEventDecoder {
  private var buffer = Data()
  private let decoder = JSONDecoder()

  mutating func append(_ data: Data) throws -> [APIClient.ChatStreamEvent] {
    buffer.append(data)

    var events: [APIClient.ChatStreamEvent] = []

    while let separator = nextSeparator() {
      let frameData = buffer.subdata(in: buffer.startIndex..<separator.lowerBound)
      buffer.removeSubrange(..<separator.upperBound)

      if let event = try decode(frameData) {
        events.append(event)
      }
    }

    return events
  }

  mutating func finish() throws -> [APIClient.ChatStreamEvent] {
    guard !buffer.isEmpty else { return [] }

    let frameData = buffer
    buffer.removeAll(keepingCapacity: false)

    if String(decoding: frameData, as: UTF8.self)
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .isEmpty
    {
      return []
    }

    guard let event = try decode(frameData) else {
      throw APIClient.APIError.decoding(ServerSentEventError.incompleteFrame)
    }

    return [event]
  }

  private func nextSeparator() -> Range<Data.Index>? {
    [Data([13, 10, 13, 10]), Data([10, 10])]
      .compactMap { buffer.range(of: $0) }
      .min { $0.lowerBound < $1.lowerBound }
  }

  private func decode(_ frameData: Data) throws -> APIClient.ChatStreamEvent? {
    let frame = String(decoding: frameData, as: UTF8.self)
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
    let dataLines = frame.split(separator: "\n", omittingEmptySubsequences: false)
      .compactMap { line -> String? in
        guard line.hasPrefix("data:") else { return nil }

        let value = line.dropFirst(5)
        return value.first == " " ? String(value.dropFirst()) : String(value)
      }

    guard !dataLines.isEmpty else { return nil }

    let payload = dataLines.joined(separator: "\n")
    guard let data = payload.data(using: .utf8) else {
      throw ServerSentEventError.invalidPayload
    }

    do {
      return try decoder.decode(APIClient.ChatStreamEvent.self, from: data)
    } catch {
      throw APIClient.APIError.decoding(error)
    }
  }
}

private enum ServerSentEventError: LocalizedError {
  case incompleteFrame
  case invalidPayload

  var errorDescription: String? {
    switch self {
    case .incompleteFrame:
      "The server ended the stream with an incomplete SSE frame."
    case .invalidPayload:
      "The server returned an invalid SSE payload."
    }
  }
}
