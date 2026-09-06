import Foundation
import AVFoundation

public enum AudioMeter {
    /// A bounded RMS observation for the UI; nil means the input format cannot be measured here.
    public static func decibels(_ sample: CMSampleBuffer) -> Double? {
        guard let description = CMSampleBufferGetFormatDescription(sample),
              CMFormatDescriptionGetMediaType(description) == kCMMediaType_Audio,
              let format = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee,
              format.mFormatID == kAudioFormatLinearPCM,
              format.mFormatFlags & kAudioFormatFlagIsBigEndian == 0,
              let block = CMSampleBufferGetDataBuffer(sample) else { return nil }
        let step = Int(format.mBitsPerChannel / 8)
        let floating = format.mFormatFlags & kAudioFormatFlagIsFloat != 0
        guard [2,4,8].contains(step), floating || format.mFormatFlags & kAudioFormatFlagIsSignedInteger != 0 else { return nil }
        let length = min(CMBlockBufferGetDataLength(block) / step, 2048) * step
        guard length > 0 else { return nil }
        var data = Data(repeating: 0, count: length)
        let status = data.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: $0.baseAddress!) }
        guard status == noErr else { return nil }
        let sum: Double = data.withUnsafeBytes { bytes in
            var sum = 0.0
            for offset in stride(from: 0, to: length, by: step) {
                let value: Double
                if floating && step == 4 { value = Double(bytes.loadUnaligned(fromByteOffset: offset, as: Float.self)) }
                else if floating && step == 8 { value = bytes.loadUnaligned(fromByteOffset: offset, as: Double.self) }
                else if !floating && step == 2 { value = Double(bytes.loadUnaligned(fromByteOffset: offset, as: Int16.self)) / 32768 }
                else if !floating && step == 4 { value = Double(bytes.loadUnaligned(fromByteOffset: offset, as: Int32.self)) / 2147483648 }
                else { return .nan }
                guard value.isFinite else { return .nan }; sum += value * value
            }
            return sum
        }
        guard sum.isFinite else { return nil }
        return max(-96, min(0, 10 * log10(max(1e-12, sum / Double(length / step)))))
    }
}
