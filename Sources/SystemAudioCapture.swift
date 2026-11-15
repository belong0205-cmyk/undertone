import AVFoundation
import AudioToolbox
import CoreAudio

/// Captures everything the Mac plays (every app) through a Core Audio process tap.
/// Requires macOS 14.2+ and the "System Audio Recording" permission (NSAudioCaptureUsageDescription).
final class SystemAudioCapture {
    struct Failure: LocalizedError {
        let step: String
        let status: OSStatus
        var errorDescription: String? { "\(step) thất bại (mã \(status))" }
    }

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "local.undertone.audio", qos: .userInitiated)

    deinit { stop() }

    /// `onBuffer` runs on a private queue; the buffer is only valid for the duration of the call.
    func start(onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws {
        stop()
        do {
            let tap = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
            tap.uuid = UUID()
            tap.muteBehavior = .unmuted
            tap.isPrivate = true
            try check("Tạo audio tap", AudioHardwareCreateProcessTap(tap, &tapID))

            let outputUID = try defaultOutputDeviceUID()
            let aggregate: [String: Any] = [
                kAudioAggregateDeviceNameKey: "Undertone Tap",
                kAudioAggregateDeviceUIDKey: UUID().uuidString,
                kAudioAggregateDeviceMainSubDeviceKey: outputUID,
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceIsStackedKey: false,
                kAudioAggregateDeviceTapAutoStartKey: true,
                kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
                kAudioAggregateDeviceTapListKey: [[
                    kAudioSubTapDriftCompensationKey: true,
                    kAudioSubTapUIDKey: tap.uuid.uuidString,
                ]],
            ]
            try check("Tạo thiết bị thu", AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID))

            // Every IO cycle delivers the aggregate device's buffer, so the audio runs at the device's
            // sample rate, which can differ from the rate the tap reports (e.g. 44.1 kHz speakers with
            // a 48 kHz tap). A wrong rate speeds the speech up or slows it down for the recognizer.
            var streamDescription = try tapStreamDescription()
            let box = FormatBox()
            let meter = DebugLog.enabled ? RateMeter(tapRate: streamDescription.mSampleRate) : nil
            try check("Đăng ký luồng âm thanh", AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue) { _, input, _, _, _ in
                guard let format = box.format,
                      let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: input, deallocator: nil)
                else { return }
                meter?.count(buffer)
                onBuffer(buffer)
            })
            try check("Bắt đầu thu âm", AudioDeviceStart(aggregateID, procID))
            streamDescription.mSampleRate = try deviceSampleRate() // read once running
            guard let format = AVAudioFormat(streamDescription: &streamDescription) else {
                throw Failure(step: "Đọc định dạng âm thanh", status: -1)
            }
            box.format = format
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        if aggregateID != kAudioObjectUnknown {
            if let procID {
                AudioDeviceStop(aggregateID, procID)
                AudioDeviceDestroyIOProcID(aggregateID, procID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
        }
        procID = nil
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
    }

    private func defaultOutputDeviceUID() throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        try check("Tìm thiết bị phát", AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID))

        address.mSelector = kAudioDevicePropertyDeviceUID
        var uid: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        try check("Đọc UID thiết bị phát", AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &uid))
        guard let uid else { throw Failure(step: "Đọc UID thiết bị phát", status: -1) }
        return uid.takeRetainedValue() as String
    }

    private func tapStreamDescription() throws -> AudioStreamBasicDescription {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var description = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check("Đọc định dạng tap", AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &description))
        return description
    }

    private func deviceSampleRate() throws -> Float64 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var rate: Float64 = 0
        var size = UInt32(MemoryLayout<Float64>.size)
        try check("Đọc tần số lấy mẫu", AudioObjectGetPropertyData(aggregateID, &address, 0, nil, &size, &rate))
        return rate
    }

    private func check(_ step: String, _ status: OSStatus) throws {
        guard status == noErr else { throw Failure(step: step, status: status) }
    }
}

/// The buffer format, set once the device runs; read from the audio thread.
private final class FormatBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: AVAudioFormat?
    var format: AVAudioFormat? {
        get { lock.withLock { value } }
        set { lock.withLock { value = newValue } }
    }
}

/// Debug only: every 10 s, prints how many frames per second actually arrive versus the declared rate.
private final class RateMeter: @unchecked Sendable {
    private let tapRate: Double
    private var frames = 0
    private var since = Date()

    init(tapRate: Double) { self.tapRate = tapRate }

    func count(_ buffer: AVAudioPCMBuffer) { // audio thread only
        frames += Int(buffer.frameLength)
        let elapsed = Date().timeIntervalSince(since)
        guard elapsed >= 10 else { return }
        DebugLog.log(String(format: "capture: %.0f frames/s measured, %.0f Hz declared, tap reports %.0f Hz",
                            Double(frames) / elapsed, buffer.format.sampleRate, tapRate))
        frames = 0
        since = Date()
    }
}

/// Audio-thread helper: RMS of a buffer and a throttled 0...1 value for the level meter.
final class LevelSampler {
    private var lastEmit: UInt64 = 0

    func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
        let stride = buffer.stride // > 1 when interleaved
        let count = Int(buffer.frameLength)
        let samples = channels[0]
        var sum: Float = 0
        for i in 0..<count {
            let s = samples[i * stride]
            sum += s * s
        }
        return (sum / Float(count)).squareRoot()
    }

    /// At most ~20 values per second, mapped from -55...-10 dBFS to 0...1.
    func throttledLevel(_ rms: Float) -> Float? {
        let now = DispatchTime.now().uptimeNanoseconds
        guard now &- lastEmit > 50_000_000 else { return nil }
        lastEmit = now
        let db = 20 * log10(max(rms, 1e-6))
        return min(max((db + 55) / 45, 0), 1)
    }
}
