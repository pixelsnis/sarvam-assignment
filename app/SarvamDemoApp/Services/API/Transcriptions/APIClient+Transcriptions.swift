import Alamofire
import Foundation
import UniformTypeIdentifiers

extension APIClient.Transcriptions {
  /// Transcribes the audio file at the specified URL.
  ///
  /// - Parameter fileURL: The local URL of the audio file to transcribe.
  /// - Returns: The transcribed audio text.
  /// - Throws: An `APIClient.APIError` when the upload or response fails.
  func transcribe(fileAt fileURL: URL) async throws -> String {
    print("[App:TranscriptionAPI] Upload started")
    let url = client.configuration.baseURL.appendingPathComponent("transcriptions")

    let response =
      await session
      .upload(
        multipartFormData: { formData in
          formData.append(
            fileURL,
            withName: "file",
            fileName: fileURL.lastPathComponent.isEmpty
              ? "audio"
              : fileURL.lastPathComponent,
            mimeType: Self.mimeType(for: fileURL)
          )
        },
        to: url,
        method: .post,
        headers: HTTPHeaders(["Accept": "application/json"])
      )
      .serializingData()
      .response

    guard let httpResponse = response.response else {
      if let error = response.error {
        throw APIClient.APIError.request(error)
      }
      throw APIClient.APIError.invalidResponse
    }

    guard (200..<300).contains(httpResponse.statusCode) else {
      let payload = response.data.flatMap {
        try? client.decoder.decode(
          APIClient.APIError.ErrorPayload.self,
          from: $0
        )
      }
      throw APIClient.APIError.http(
        statusCode: httpResponse.statusCode,
        payload: payload
      )
    }

    guard let data = response.data else {
      throw APIClient.APIError.invalidResponse
    }

    let transcriptionResponse: APIClient.TranscriptionResponse
    do {
      transcriptionResponse = try client.decoder.decode(
        APIClient.TranscriptionResponse.self,
        from: data
      )
    } catch {
      throw APIClient.APIError.decoding(error)
    }

    print("[App:TranscriptionAPI] Upload succeeded")
    return transcriptionResponse.transcript
  }

  private static func mimeType(for fileURL: URL) -> String {
    guard
      let type = UTType(filenameExtension: fileURL.pathExtension),
      let mimeType = type.preferredMIMEType
    else {
      return "application/octet-stream"
    }

    return mimeType
  }
}
