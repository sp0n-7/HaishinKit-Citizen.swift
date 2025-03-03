import AVFoundation

final class AudioCaptureUnit: CaptureUnit {
    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.AudioCaptureUnit.lock")
    var mixerSettings: AudioMixerSettings {
        get {
            audioMixer.settings
        }
        set {
            audioMixer.settings = newValue
        }
    }
    var isMonitoringEnabled = false {
        didSet {
            if isMonitoringEnabled {
                monitor.startRunning()
            } else {
                monitor.stopRunning()
            }
        }
    }
    var isMultiTrackAudioMixingEnabled = false
    var inputFormats: [UInt8: AVAudioFormat] {
        return audioMixer.inputFormats
    }
    var output: AsyncStream<(AVAudioPCMBuffer, AVAudioTime)> {
        AsyncStream<(AVAudioPCMBuffer, AVAudioTime)> { continutation in
            self.continutation = continutation
        }
    }
    private lazy var audioMixer: any AudioMixer = {
        if isMultiTrackAudioMixingEnabled {
            var mixer = AudioMixerByMultiTrack()
            mixer.delegate = self
            return mixer
        } else {
            var mixer = AudioMixerBySingleTrack()
            mixer.delegate = self
            return mixer
        }
    }()
    private var monitor: AudioMonitor = .init()

    #if os(tvOS)
    private var _devices: [UInt8: Any] = [:]
    @available(tvOS 17.0, *)
    var devices: [UInt8: AudioDeviceUnit] {
        return _devices as! [UInt8: AudioDeviceUnit]
    }
    #elseif os(iOS) || os(macOS)
    var devices: [UInt8: AudioDeviceUnit] = [:]
    #endif

    private let session: CaptureSession
    private var continutation: AsyncStream<(AVAudioPCMBuffer, AVAudioTime)>.Continuation?

    init(_ session: CaptureSession) {
        self.session = session
    }

    #if os(iOS) || os(macOS) || os(tvOS)
    @available(tvOS 17.0, *)
    func attachAudio(_ track: UInt8, device: AVCaptureDevice?, configuration: AudioDeviceConfigurationBlock?) throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("HaishinKit: AudioCaptureUnit.attachAudio started at \(startTime) for track \(track)")
        
        try session.configuration { _ in
            let configStartTime = CFAbsoluteTimeGetCurrent()
            print("HaishinKit: AudioCaptureUnit.attachAudio session configuration started at \(configStartTime), elapsed: \(configStartTime - startTime)")
            
            for capture in devices.values where capture.device == device {
                let detachStartTime = CFAbsoluteTimeGetCurrent()
                print("HaishinKit: AudioCaptureUnit detaching existing device at \(detachStartTime), elapsed: \(detachStartTime - startTime)")
                try? capture.attachDevice(nil, session: session, audioUnit: self)
                print("HaishinKit: AudioCaptureUnit detach completed at \(CFAbsoluteTimeGetCurrent()), took: \(CFAbsoluteTimeGetCurrent() - detachStartTime)")
            }
            
            let deviceLookupTime = CFAbsoluteTimeGetCurrent()
            print("HaishinKit: AudioCaptureUnit getting device for track \(track) at \(deviceLookupTime), elapsed: \(deviceLookupTime - startTime)")
            
            guard let capture = self.device(for: track) else {
                print("HaishinKit: AudioCaptureUnit no device found for track \(track) at \(CFAbsoluteTimeGetCurrent())")
                return
            }
            
            let configureTime = CFAbsoluteTimeGetCurrent()
            print("HaishinKit: AudioCaptureUnit configuring device at \(configureTime), elapsed: \(configureTime - startTime)")
            try? configuration?(capture)
            
            let attachStartTime = CFAbsoluteTimeGetCurrent()
            print("HaishinKit: AudioCaptureUnit attaching device at \(attachStartTime), elapsed: \(attachStartTime - startTime)")
            try capture.attachDevice(device, session: session, audioUnit: self)
            
            let attachEndTime = CFAbsoluteTimeGetCurrent()
            print("HaishinKit: AudioCaptureUnit device attached at \(attachEndTime), elapsed: \(attachEndTime - startTime), attachment took: \(attachEndTime - attachStartTime)")
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        print("HaishinKit: AudioCaptureUnit.attachAudio completed at \(endTime), total time: \(endTime - startTime)")
    }

    @available(tvOS 17.0, *)
    func makeDataOutput(_ track: UInt8) -> AudioDeviceUnitDataOutput {
        return .init(track: track, audioMixer: audioMixer)
    }

    @available(tvOS 17.0, *)
    private func device(for track: UInt8) -> AudioDeviceUnit? {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("HaishinKit: AudioCaptureUnit.device(for:) started at \(startTime) for track \(track)")
        
        #if os(tvOS)
        if _devices[track] == nil {
            print("HaishinKit: AudioCaptureUnit creating new device for track \(track)")
            _devices[track] = .init(track)
        }
        let result = _devices[track] as? AudioDeviceUnit
        #else
        if devices[track] == nil {
            print("HaishinKit: AudioCaptureUnit creating new device for track \(track)")
            devices[track] = .init(track)
        }
        let result = devices[track]
        #endif
        
        let endTime = CFAbsoluteTimeGetCurrent()
        print("HaishinKit: AudioCaptureUnit.device(for:) completed at \(endTime), took: \(endTime - startTime)")
        return result
    }
    #endif

    func append(_ track: UInt8, buffer: CMSampleBuffer) {
        audioMixer.append(track, buffer: buffer)
    }

    func append(_ track: UInt8, buffer: AVAudioBuffer, when: AVAudioTime) {
        switch buffer {
        case let buffer as AVAudioPCMBuffer:
            audioMixer.append(track, buffer: buffer, when: when)
        default:
            break
        }
    }

    func finish() {
        continutation?.finish()
    }
}

extension AudioCaptureUnit: AudioMixerDelegate {
    // MARK: AudioMixerDelegate
    func audioMixer(_ audioMixer: some AudioMixer, track: UInt8, didInput buffer: AVAudioPCMBuffer, when: AVAudioTime) {
    }

    func audioMixer(_ audioMixer: some AudioMixer, errorOccurred error: AudioMixerError) {
    }

    func audioMixer(_ audioMixer: some AudioMixer, didOutput audioFormat: AVAudioFormat) {
        monitor.inputFormat = audioFormat
    }

    func audioMixer(_ audioMixer: some AudioMixer, didOutput audioBuffer: AVAudioPCMBuffer, when: AVAudioTime) {
        if let audioBuffer = audioBuffer.clone() {
            continutation?.yield((audioBuffer, when))
        }
        monitor.append(audioBuffer, when: when)
    }
}
