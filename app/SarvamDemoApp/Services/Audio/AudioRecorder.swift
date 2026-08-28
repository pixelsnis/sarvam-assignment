// AudioRecorder: UI and service logic for this feature.
import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class AudioRecorder {
  // Defines Error.
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

  private static let waveformIntervalNanoseconds: UInt64 = 100_000_000
  private static let waveformNoiseFloorDB: Float = -50
  private static let waveformCeilingDB: Float = -10
  private static let waveformPeakAdjustmentDB: Float = 12

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

  // Handles requestPermission.
  func requestPermission() async -> Bool {
    // 1. Reuse an existing permission or request access from the system.
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

  // Handles start.
  func start() async throws {
    // 1. Check recording prerequisites and clear any previous recording state.
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
      // 2. Configure the audio session and start recording to a temporary file.
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
  // Handles stop.
  func stop() -> URL? {
    // 1. Stop sampling and finalize the current recording, if one exists.
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

  // Handles fileURL.
  func fileURL() -> URL? {
    guard let recordingURL,
          fileManager.fileExists(atPath: recordingURL.path) else {
      return nil
    }

    return recordingURL
  }

  // Handles makeRecordingURL.
  private func makeRecordingURL() -> URL {
    fileManager.temporaryDirectory
      .appendingPathComponent("recording-\(UUID().uuidString)")
      .appendingPathExtension("m4a")
  }

  // Handles startWaveformSampling.
  private func startWaveformSampling() {
    // 1. Sample the recorder meter until recording stops or the task is cancelled.
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

  // Handles captureWaveformSample.
  private func captureWaveformSample() {
    // 1. Convert the current meter values into a normalized UI amplitude.
    guard let recorder, recorder.isRecording else {
      return
    }

    recorder.updateMeters()
    let averagePower = recorder.averagePower(forChannel: 0)
    let peakPower = recorder.peakPower(forChannel: 0)

    // AVAudioRecorder reports dBFS. Converting that directly to linear
    // amplitude makes normal speech (often around -30 dBFS) nearly invisible
    // in a small UI waveform. Normalize the meter into a display range and
    // let recent peaks contribute without allowing them to dominate noise.
    let displayPower = max(averagePower, peakPower - Self.waveformPeakAdjustmentDB)
    let normalizedPower = (displayPower - Self.waveformNoiseFloorDB) /
      (Self.waveformCeilingDB - Self.waveformNoiseFloorDB)
    let amplitude = sqrt(min(max(normalizedPower, 0), 1))
    waveformSamples.append(amplitude)
  }
}
