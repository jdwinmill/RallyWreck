import AVFoundation
import Observation

@Observable
final class SynthEngine {
    private var engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var isRunning = false

    // Active tone state (accessed from render thread via atomic-like pattern)
    private var activeTones: [(frequency: Double, waveform: Waveform, startSample: Int, duration: Int, sweep: Double?)] = []
    private let lock = NSLock()
    private var sampleRate: Double = 44100
    private var currentSample: Int = 0

    enum Waveform {
        case sine, square, sawtooth
    }

    func start() {
        guard !isRunning else { return }

        let format = engine.outputNode.inputFormat(forBus: 0)
        sampleRate = format.sampleRate
        currentSample = 0

        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            self.lock.lock()
            let tones = self.activeTones
            let sample = self.currentSample
            self.currentSample += Int(frameCount)
            self.lock.unlock()

            for frame in 0..<Int(frameCount) {
                var value: Float = 0.0

                for tone in tones {
                    let elapsed = sample + frame - tone.startSample
                    guard elapsed >= 0 && elapsed < tone.duration else { continue }

                    let progress = Double(elapsed) / Double(tone.duration)
                    let freq: Double
                    if let sweep = tone.sweep {
                        freq = tone.frequency + (sweep - tone.frequency) * progress
                    } else {
                        freq = tone.frequency
                    }

                    let phase = Double(elapsed) * freq / self.sampleRate
                    let sample: Double
                    switch tone.waveform {
                    case .sine:
                        sample = sin(phase * 2.0 * .pi)
                    case .square:
                        sample = sin(phase * 2.0 * .pi) >= 0 ? 1.0 : -1.0
                    case .sawtooth:
                        sample = 2.0 * (phase - floor(phase + 0.5))
                    }

                    // Envelope: quick attack, sustain, quick release
                    let envelope: Double
                    let attackSamples = Int(0.005 * self.sampleRate)
                    let releaseSamples = Int(0.03 * self.sampleRate)
                    if elapsed < attackSamples {
                        envelope = Double(elapsed) / Double(attackSamples)
                    } else if elapsed > tone.duration - releaseSamples {
                        envelope = Double(tone.duration - elapsed) / Double(releaseSamples)
                    } else {
                        envelope = 1.0
                    }

                    value += Float(sample * envelope * 0.07)
                }

                for buffer in ablPointer {
                    let buf = buffer.mData!.assumingMemoryBound(to: Float.self)
                    buf[frame] = value
                }
            }

            return noErr
        }

        self.sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
            isRunning = true
        } catch {
            print("SynthEngine failed to start: \(error)")
        }
    }

    func stop() {
        guard isRunning else { return }
        engine.stop()
        if let node = sourceNode {
            engine.disconnectNodeOutput(node)
            engine.detach(node)
            sourceNode = nil
        }
        lock.lock()
        activeTones.removeAll()
        lock.unlock()
        isRunning = false
    }

    // MARK: - Sound Events

    func playCountdown(remaining: Int = 3) {
        let freq: Double
        switch remaining {
        case 3: freq = 440
        case 2: freq = 660
        default: freq = 880
        }
        scheduleTone(frequency: freq, waveform: .sine, durationMs: 150)
    }

    func playYourTurn() {
        scheduleTone(frequency: 880, waveform: .sine, durationMs: 80)
        scheduleTone(frequency: 1100, waveform: .sine, durationMs: 80, delayMs: 120)
    }

    func playTap() {
        scheduleTone(frequency: 440, waveform: .sine, durationMs: 50)
    }

    func playElimination() {
        scheduleTone(frequency: 400, waveform: .sawtooth, durationMs: 250, sweepTo: 100)
    }

    func playGameOver() {
        // Victory arpeggio: C4-E4-G4-C5
        let notes: [(Double, Int)] = [
            (261.63, 0),    // C4
            (329.63, 100),  // E4
            (392.00, 200),  // G4
            (523.25, 300),  // C5
        ]
        for (freq, delayMs) in notes {
            scheduleTone(frequency: freq, waveform: .sine, durationMs: 100, delayMs: delayMs)
        }
    }

    // MARK: - Internal

    private func scheduleTone(frequency: Double, waveform: Waveform, durationMs: Int, delayMs: Int = 0, sweepTo: Double? = nil) {
        guard isRunning else { return }
        lock.lock()
        let start = currentSample + Int(Double(delayMs) / 1000.0 * sampleRate)
        let duration = Int(Double(durationMs) / 1000.0 * sampleRate)
        activeTones.append((frequency, waveform, start, duration, sweepTo))

        // Clean up expired tones
        activeTones.removeAll { currentSample > $0.startSample + $0.duration + Int(sampleRate * 0.1) }
        lock.unlock()
    }
}
