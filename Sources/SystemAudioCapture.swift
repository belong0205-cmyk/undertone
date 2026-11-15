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

            var streamDescription = try tapStreamDescription()
            guard let format = AVAudioFormat(streamDescription: &streamDescription) else {
                throw Failure(step: "Đọc định dạng âm thanh", status: -1)
            }

            try check("Đăng ký luồng âm thanh", AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue) { _, input, _, _, _ in
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: input, deallocator: nil) else { return }
                onBuffer(buffer)
            })
            try check("Bắt đầu thu âm", AudioDeviceStart(aggregateID, procID))
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

    private func check(_ step: String, _ status: OSStatus) throws {
        guard status == noErr else { throw Failure(step: step, status: status) }
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
