import Foundation
import AVFoundation
import ClipsCore

/// Deterministic test input. This does not exercise a screen, camera, or microphone.
public enum SyntheticSamples {
    public static func video(frame: Int, time: Double) throws -> CMSampleBuffer {
        var pixel: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, 320, 180, kCVPixelFormatType_32BGRA,
                                  [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &pixel) == kCVReturnSuccess,
              let pixel else { throw ClipsError.media("Fixture pixel allocation failed.") }
        CVPixelBufferLockBaseAddress(pixel, [])
        let pointer = CVPixelBufferGetBaseAddress(pixel)!.assumingMemoryBound(to: UInt8.self)
        let stride = CVPixelBufferGetBytesPerRow(pixel)
        for y in 0..<180 {
            for x in 0..<320 {
                let i = y * stride + x * 4
                pointer[i] = UInt8((x + frame * 3) % 256)
                pointer[i + 1] = UInt8(y % 256)
                pointer[i + 2] = UInt8(frame % 256)
                pointer[i + 3] = 255
            }
        }
        CVPixelBufferUnlockBaseAddress(pixel, [])
        var format: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixel,
                                                           formatDescriptionOut: &format) == noErr, let format else {
            throw ClipsError.media("Fixture format creation failed.")
        }
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30),
                                       presentationTimeStamp: CMTime(seconds: time, preferredTimescale: 60_000),
                                       decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        guard CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixel,
                formatDescription: format, sampleTiming: &timing, sampleBufferOut: &sample) == noErr, let sample else {
            throw ClipsError.media("Fixture sample creation failed.")
        }
        return sample
    }

    public static func audio(frame: Int, time: Double, channels: Int, frequency: Double) throws -> CMSampleBuffer {
        let count = 1600
        var samples = [Int16](repeating: 0, count: count * channels)
        for index in 0..<count {
            let value = Int16(sin(Double(frame * count + index) * 2 * .pi * frequency / 48_000) * 8000)
            for channel in 0..<channels { samples[index * channels + channel] = value }
        }
        var block: CMBlockBuffer?
        let bytes = samples.count * MemoryLayout<Int16>.size
        guard CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil,
                blockLength: bytes, blockAllocator: kCFAllocatorDefault, customBlockSource: nil,
                offsetToData: 0, dataLength: bytes, flags: 0, blockBufferOut: &block) == noErr, let block else {
            throw ClipsError.media("Fixture audio allocation failed.")
        }
        let copied = samples.withUnsafeBytes {
            CMBlockBufferReplaceDataBytes(with: $0.baseAddress!, blockBuffer: block, offsetIntoDestination: 0, dataLength: bytes)
        }
        guard copied == noErr else { throw ClipsError.media("Fixture audio copy failed.") }
        var asbd = AudioStreamBasicDescription(mSampleRate: 48_000, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: UInt32(channels * 2), mFramesPerPacket: 1, mBytesPerFrame: UInt32(channels * 2),
            mChannelsPerFrame: UInt32(channels), mBitsPerChannel: 16, mReserved: 0)
        var format: CMAudioFormatDescription?
        guard CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &asbd, layoutSize: 0,
                layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil,
                formatDescriptionOut: &format) == noErr, let format else { throw ClipsError.media("Fixture audio format failed.") }
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 48_000),
            presentationTimeStamp: CMTime(seconds: time, preferredTimescale: 60_000), decodeTimeStamp: .invalid)
        var size = channels * 2
        var sample: CMSampleBuffer?
        guard CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: block, formatDescription: format,
                sampleCount: count, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
                sampleSizeEntryCount: 1, sampleSizeArray: &size, sampleBufferOut: &sample) == noErr, let sample else {
            throw ClipsError.media("Fixture audio sample failed.")
        }
        return sample
    }
}
