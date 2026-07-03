import Foundation
import VideoToolbox

enum VTSessionMode {
    case compression
    case decompression

    func makeSession(_ videoCodec: VideoCodec) throws -> any VTSessionConvertible {
        switch self {
        case .compression:
            var session: VTCompressionSession?
            let encoderSpecification: CFDictionary?
            #if targetEnvironment(simulator)
            // The simulator has no hardware H.264 encoder; a nil spec makes VTCompressionSessionCreate
            // select the (absent) hardware encoder and fail with -12908. Forcing enable/require = false
            // at create time selects the software encoder instead so encoding can produce output.
            if #available(iOS 17.4, tvOS 17.4, visionOS 1.1, macOS 10.9, *) {
                encoderSpecification = [
                    kVTVideoEncoderSpecification_EnableHardwareAcceleratedVideoEncoder: kCFBooleanFalse as Any,
                    kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder: kCFBooleanFalse as Any
                ] as CFDictionary
            } else {
                encoderSpecification = nil
            }
            #else
            encoderSpecification = nil
            #endif
            var status = VTCompressionSessionCreate(
                allocator: kCFAllocatorDefault,
                width: Int32(videoCodec.settings.videoSize.width),
                height: Int32(videoCodec.settings.videoSize.height),
                codecType: videoCodec.settings.format.codecType,
                encoderSpecification: encoderSpecification,
                imageBufferAttributes: videoCodec.makeImageBufferAttributes(.compression) as CFDictionary?,
                compressedDataAllocator: nil,
                outputCallback: nil,
                refcon: nil,
                compressionSessionOut: &session
            )
            guard status == noErr, let session else {
                throw VTSessionError.failedToCreate(status: status)
            }
            status = session.setOptions(videoCodec.settings.options(videoCodec))
            guard status == noErr else {
                throw VTSessionError.failedToPrepare(status: status)
            }
            status = session.prepareToEncodeFrames()
            guard status == noErr else {
                throw VTSessionError.failedToPrepare(status: status)
            }
            videoCodec.frameInterval = videoCodec.settings.frameInterval
            return session
        case .decompression:
            guard let formatDescription = videoCodec.inputFormat else {
                throw VTSessionError.failedToCreate(status: kVTParameterErr)
            }
            var session: VTDecompressionSession?
            let status = VTDecompressionSessionCreate(
                allocator: kCFAllocatorDefault,
                formatDescription: formatDescription,
                decoderSpecification: nil,
                imageBufferAttributes: videoCodec.makeImageBufferAttributes(.decompression) as CFDictionary?,
                outputCallback: nil,
                decompressionSessionOut: &session
            )
            guard let session, status == noErr else {
                throw VTSessionError.failedToCreate(status: status)
            }
            return session
        }
    }
}
