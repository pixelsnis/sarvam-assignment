import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class AudioRecorder {
  enum Error: LocalizedError {
    case microphonePermissionDenied
    case microphoneUnavailable
    case alreadyRecording
    case configurationFailed(Swift.Error)
    case failedToStart

    var errorDescription: String? {
      switch self {
      case .microphonePermissionDenied:
        "Microphone access is required to record audio."
      case .microphoneUnavailable:
        "No microphone is available on this device."
      case .alreadyRecording:
        "A recording is already in progress."
      case .configurationFailed(let error):
        "The audio recorder could not be configured: \(error.localizedDescription)"
      case .failedToStart:
        "The audio recorder could not start recording."
      }
    }
  }

  private static let waveformIntervalNanoseconds: UInt64 = 200_000_000

  private let audioSession: AVAudioSession
  private let fileManager: FileManager
  private let recorderSettings: [String: Any]

  private var recorder: AVAudioRecorder?
  private var waveformTask: Task<Void, Never>?

  private(set) var isRecording = false
  private(set) var waveformSamples: [Float] = []
  private(set) var recordingURL: URL?
  private(set) var activeMicrophoneMode: AVCaptureDevice.MicrophoneMode?

  init(
    audioSession: AVAudioSession = .sharedInstance(),
    fileManager: FileManager = .default,
    recorderSettings: [String: Any] = [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVSampleRateKey: 44_100,
      AVNumberOfChannelsKey: 1,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]
  ) {
    self.audioSession = audioSession
    self.fileManager = fileManager
    self.recorderSettings = recorderSettings
  }

  func requestPermission() async -> Bool {
    print("[App:Audio] Checking microphone permission")
    return switch AVAudioApplication.shared.recordPermission {
    case .granted:
      true
    case .denied:
      false
    case .undetermined:
      await withCheckedContinuation { continuation in
        AVAudioApplication.requestRecordPermission { granted in
          continuation.resume(returning: granted)
        }
      }
    @unknown default:
      false
    }
  }

  func start() async throws {
    print("[App:Audio] Recording started")
    guard !isRecording else {
      throw Error.alreadyRecording
    }

    guard await requestPermission() else {
      throw Error.microphonePermissionDenied
    }

    guard audioSession.isInputAvailable else {
      throw Error.microphoneUnavailable
    }

    waveformTask?.cancel()
    waveformTask = nil
    recorder?.stop()
    recorder = nil
    waveformSamples = []
    recordingURL = nil
    activeMicrophoneMode = nil

    do {
      // Voice Isolation is selected by the system/user microphone mode. The
      // voice-chat mode provides the supported voice-processing fallback on
      // OS versions where recording mic modes cannot be set programmatically.
      try audioSession.setCategory(
        .playAndRecord,
        mode: .voiceChat,
        options: [.allowBluetoothHFP]
      )
      try audioSession.setActive(true)

      let url = makeRecordingURL()
      let recorder = try AVAudioRecorder(url: url, settings: recorderSettings)
      recorder.isMeteringEnabled = true

      guard recorder.prepareToRecord(), recorder.record() else {
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        try? fileManager.removeItem(at: url)
        throw Error.failedToStart
      }

      self.recorder = recorder
      recordingURL = url
      isRecording = true
      // Mic modes are read-only; expose the mode the active route provides.
      activeMicrophoneMode = AVCaptureDevice.activeMicrophoneMode
      startWaveformSampling()
    } catch let error as Error {
      throw error
    } catch {
      try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
      throw Error.configurationFailed(error)
    }
  }

  @discardableResult
  func stop() -> URL? {
    print("[App:Audio] Recording stopped")
    waveformTask?.cancel()
    waveformTask = nil

    guard isRecording else {
      return fileURL()
    }

    recorder?.stop()
    recorder = nil
    isRecording = false
    activeMicrophoneMode = nil
    try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)

    return fileURL()
  }

  func fileURL() -> URL? {
    guard let recordingURL,
          fileManager.fileExists(atPath: recordingURL.path) else {
      return nil
    }

    return recordingURL
  }

  private func makeRecordingURL() -> URL {
    fileManager.temporaryDirectory
      .appendingPathComponent("recording-\(UUID().uuidString)")
      .appendingPathExtension("m4a")
  }

  private func startWaveformSampling() {
    waveformTask = Task { [weak self] in
      while !Task.isCancelled {
        do {
          try await Task.sleep(nanoseconds: Self.waveformIntervalNanoseconds)
        } catch {
          return
        }

        guard let self, self.isRecording else {
          return
        }

        self.captureWaveformSample()
      }
    }
  }

  private func captureWaveformSample() {
    guard let recorder, recorder.isRecording else {
      return
    }

    recorder.updateMeters()
    let averagePower = recorder.averagePower(forChannel: 0)
    let amplitude = pow(10, averagePower / 20)
    waveformSamples.append(min(max(amplitude, 0), 1))
  }
}
