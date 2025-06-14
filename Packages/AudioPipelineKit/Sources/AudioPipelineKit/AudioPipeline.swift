import AVFoundation
import Combine

public final class AudioPipeline: ObservableObject {
    private let engine = AVAudioEngine()
    private let bus = 0
    @Published public private(set) var pcmBuffer: AVAudioPCMBuffer?

    public init() {}

    public func start() throws {
        let input = engine.inputNode
        let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
        input.installTap(onBus: bus, bufferSize: 1024, format: format) { [weak self] buf, _ in
            self?.pcmBuffer = buf
        }
        try engine.start()
    }

    public func stop() {
        engine.inputNode.removeTap(onBus: bus)
        engine.stop()
    }
}
