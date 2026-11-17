import Foundation
import AVFoundation
import Combine

final class AudioEngine: ObservableObject {
    @Published var project: SongProject
    @Published var isPlaying: Bool = false
    @Published var currentStep: Int = 0
    @Published var activeSectionIndex: Int = 0
    @Published var songMode: Bool = false
    @Published var arrangementPlayIndex: Int = 0
    @Published var spectrumLevels: [Float] = Array(repeating: 0.05, count: 16)

    // Recording state
    @Published var isRecordingMic: Bool = false
    @Published var recordingSlotIndex: Int? = nil
    @Published var recordingSeconds: Double = 0

    private let engine = AVAudioEngine()
    private let drumsMixer = AVAudioMixerNode()
    private let bassMixer = AVAudioMixerNode()
    private let chordsMixer = AVAudioMixerNode()
    private let leadMixer = AVAudioMixerNode()
    private let samplerMixer = AVAudioMixerNode()
    private let fxMixer = AVAudioMixerNode()

    private let reverb = AVAudioUnitReverb()
    private let delay = AVAudioUnitDelay()

    private var drumPlayers: [AVAudioPlayerNode] = []
    private var bassPlayer = AVAudioPlayerNode()
    private var leadPlayers: [AVAudioPlayerNode] = []
    private var chordPlayers: [AVAudioPlayerNode] = []
    private var samplePlayers: [AVAudioPlayerNode] = []
    private var samplePitchUnits: [AVAudioUnitTimePitch] = []

    private var leadVoiceIndex = 0
    private var chordVoiceIndex = 0

    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    private var drumBuffers: [DrumLane: AVAudioPCMBuffer] = [:]
    private var synthBufferCache: [String: AVAudioPCMBuffer] = [:]
    private var customBuffers: [Int: AVAudioPCMBuffer] = [:]

    private let audioQueue = DispatchQueue(label: "com.aurabeat.sequencer", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var stepCounter: Int = 0

    private var micRecorder: AVAudioRecorder?
    private var micTimer: Timer?

    private static let projectFileName = "AuraBeatProject.json"

    init() {
        if let loaded = Self.loadSavedProject() {
            self.project = loaded
        } else {
            self.project = SongPreset.sadRainyNight.buildProject()
        }
        setupAudioSession()
        setupEngineGraph()
        generateDrumBuffers()
        loadAllCustomSamples()
        applyMixerSettings()
    }

    deinit {
        stop()
        engine.mainMixerNode.removeTap(onBus: 0)
        engine.stop()
    }

    // MARK: - Audio Session & Graph

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try session.setPreferredIOBufferDuration(0.01)
            try session.setActive(true)
        } catch {
            print("AVAudioSession error: \(error)")
        }
    }

    private func setupEngineGraph() {
        reverb.loadFactoryPreset(.largeHall2)
        reverb.wetDryMix = 24
        delay.delayTime = 0.28
        delay.feedback = 35
        delay.wetDryMix = 16

        engine.attach(drumsMixer)
        engine.attach(bassMixer)
        engine.attach(chordsMixer)
        engine.attach(leadMixer)
        engine.attach(samplerMixer)
        engine.attach(fxMixer)
        engine.attach(reverb)
        engine.attach(delay)

        // Drum players
        for _ in DrumLane.allCases {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: drumsMixer, format: format)
            drumPlayers.append(p)
        }

        // Bass
        engine.attach(bassPlayer)
        engine.connect(bassPlayer, to: bassMixer, format: format)

        // Lead polyphony (4 voices)
        for _ in 0..<4 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: leadMixer, format: format)
            leadPlayers.append(p)
        }

        // Chord polyphony (2x3 voices = 6)
        for _ in 0..<6 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: chordsMixer, format: format)
            chordPlayers.append(p)
        }

        // Custom sampler (4 slots with pitch unit)
        for _ in 0..<4 {
            let p = AVAudioPlayerNode()
            let pitch = AVAudioUnitTimePitch()
            engine.attach(p)
            engine.attach(pitch)
            engine.connect(p, to: pitch, format: format)
            engine.connect(pitch, to: samplerMixer, format: format)
            samplePlayers.append(p)
            samplePitchUnits.append(pitch)
        }

        // Route instrument mixers -> fxMixer (dry+wet) -> delay -> reverb -> mainMixer
        engine.connect(drumsMixer, to: engine.mainMixerNode, format: format)
        engine.connect(bassMixer, to: engine.mainMixerNode, format: format)
        engine.connect(chordsMixer, to: fxMixer, format: format)
        engine.connect(leadMixer, to: fxMixer, format: format)
        engine.connect(samplerMixer, to: fxMixer, format: format)

        engine.connect(fxMixer, to: delay, format: format)
        engine.connect(delay, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)

        // Tap main mixer for spectrum visualizer
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            guard let self = self, let data = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            guard frameCount >= 16 else { return }
            let chunk = frameCount / 16
            var levels = [Float](repeating: 0.05, count: 16)
            for i in 0..<16 {
                var sum: Float = 0
                let start = i * chunk
                for j in 0..<chunk {
                    sum += abs(data[start + j])
                }
                let avg = sum / Float(chunk)
                levels[i] = min(1.0, max(0.05, avg * 3.8))
            }
            DispatchQueue.main.async {
                self.spectrumLevels = levels
            }
        }

        do {
            try engine.start()
        } catch {
            print("AVAudioEngine start error: \(error)")
        }
    }

    func ensureEngineRunning() {
        if !engine.isRunning {
            try? engine.start()
        }
    }

    // MARK: - Mixer & Project Updates

    func applyMixerSettings() {
        let m = project.mixer
        engine.mainMixerNode.outputVolume = m.masterVolume
        drumsMixer.outputVolume = m.drumsMuted ? 0 : m.drumsVolume
        bassMixer.outputVolume = m.bassMuted ? 0 : m.bassVolume
        chordsMixer.outputVolume = m.chordsMuted ? 0 : m.chordsVolume
        leadMixer.outputVolume = m.leadMuted ? 0 : m.leadVolume
        samplerMixer.outputVolume = m.samplerMuted ? 0 : m.samplerVolume

        reverb.wetDryMix = m.reverbWet * 100
        delay.wetDryMix = m.delayWet * 100

        for (idx, slot) in project.customSamples.enumerated() where idx < samplePitchUnits.count {
            samplePitchUnits[idx].pitch = slot.pitchSemitones * 100 // cents
            samplePlayers[idx].volume = slot.isMuted ? 0 : slot.volume
        }
    }

    func loadPreset(_ preset: SongPreset) {
        let wasPlaying = isPlaying
        if wasPlaying { stop() }
        var newProj = preset.buildProject()
        // Keep user's custom recorded/imported samples if they already loaded some
        let hasUserFiles = project.customSamples.contains { ($0.fileName ?? "").isEmpty == false && !($0.fileName ?? "").hasPrefix("bundle:") }
        if hasUserFiles {
            newProj.customSamples = project.customSamples
        }
        project = newProj
        synthBufferCache.removeAll()
        activeSectionIndex = 0
        arrangementPlayIndex = 0
        loadAllCustomSamples()
        applyMixerSettings()
        saveProject()
        if wasPlaying { play() }
    }

    func resetBlankProject() {
        stop()
        project = SongProject.blank()
        synthBufferCache.removeAll()
        customBuffers.removeAll()
        activeSectionIndex = 0
        arrangementPlayIndex = 0
        applyMixerSettings()
        saveProject()
    }

    func saveProject() {
        let url = Self.documentsDirectory().appendingPathComponent(Self.projectFileName)
        if let data = try? JSONEncoder().encode(project) {
            try? data.write(to: url)
        }
    }

    private static func loadSavedProject() -> SongProject? {
        let url = documentsDirectory().appendingPathComponent(projectFileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SongProject.self, from: data)
    }

    static func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func samplesDirectory() -> URL {
        let dir = documentsDirectory().appendingPathComponent("Samples", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - Transport & Sequencer

    func togglePlay() {
        if isPlaying {
            stop()
        } else {
            play()
        }
    }

    func play() {
        ensureEngineRunning()
        guard !isPlaying else { return }
        isPlaying = true
        stepCounter = 0
        currentStep = 0
        if songMode && !project.arrangement.isEmpty {
            arrangementPlayIndex = 0
            activeSectionIndex = project.arrangement[0]
        }
        scheduleNextTick(immediate: true)
    }

    func stop() {
        isPlaying = false
        timer?.cancel()
        timer = nil
        currentStep = 0
        stepCounter = 0
    }

    private func scheduleNextTick(immediate: Bool = false) {
        timer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: audioQueue)
        let baseStepDuration = 60.0 / project.bpm / 4.0 // 16th note
        let swingOffset = (stepCounter % 2 == 1) ? Double(project.mixer.swing) * baseStepDuration : -Double(project.mixer.swing) * baseStepDuration * 0.5
        let interval = max(0.04, baseStepDuration + swingOffset)

        t.schedule(deadline: immediate ? .now() : .now() + interval)
        t.setEventHandler { [weak self] in
            guard let self = self, self.isPlaying else { return }
            self.triggerStep(self.stepCounter)

            let current = self.stepCounter
            DispatchQueue.main.async {
                self.currentStep = current
            }

            self.stepCounter += 1
            if self.stepCounter >= 16 {
                self.stepCounter = 0
                if self.songMode && !self.project.arrangement.isEmpty {
                    DispatchQueue.main.async {
                        self.arrangementPlayIndex = (self.arrangementPlayIndex + 1) % self.project.arrangement.count
                        self.activeSectionIndex = self.project.arrangement[self.arrangementPlayIndex]
                    }
                }
            }
            self.scheduleNextTick(immediate: false)
        }
        timer = t
        t.resume()
    }

    private func triggerStep(_ step: Int) {
        let secIdx = min(activeSectionIndex, project.sections.count - 1)
        let section = project.sections[secIdx]

        // 1. Drums
        for lane in DrumLane.allCases {
            if section.drums[lane.rawValue][step] {
                playDrum(lane)
            }
        }

        // 2. Bass
        if let degree = section.bass[step] {
            let midi = project.scale.midiNote(degree: degree, root: project.rootNote, octave: 2)
            playBass(midi: midi)
        }

        // 3. Chords
        if let chordDeg = section.chords[step] {
            let notes = project.scale.chordMidiNotes(degree: chordDeg, root: project.rootNote, octave: 3)
            playChord(midiNotes: notes)
        }

        // 4. Lead
        if let leadDeg = section.lead[step] {
            let midi = project.scale.midiNote(degree: leadDeg, root: project.rootNote, octave: 4)
            playLead(midi: midi)
        }

        // 5. Custom Samples
        for slotIdx in 0..<4 {
            if section.customSamples[slotIdx][step] {
                playCustomSample(slotIndex: slotIdx)
            }
        }
    }

    // MARK: - Live Trigger Methods

    func playDrum(_ lane: DrumLane) {
        ensureEngineRunning()
        guard let buf = drumBuffers[lane] else { return }
        let player = drumPlayers[lane.rawValue]
        player.stop()
        player.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        player.play()
    }

    func playBass(midi: Int) {
        ensureEngineRunning()
        let buf = synthBuffer(instrument: "bass", midi: midi, duration: 0.38)
        bassPlayer.stop()
        bassPlayer.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        bassPlayer.play()
    }

    func playLead(midi: Int) {
        ensureEngineRunning()
        let key = "lead_\(project.leadTimbre.rawValue)"
        let buf = synthBuffer(instrument: key, midi: midi, duration: 0.45)
        let player = leadPlayers[leadVoiceIndex % leadPlayers.count]
        leadVoiceIndex += 1
        player.stop()
        player.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        player.play()
    }

    func playChord(midiNotes: [Int]) {
        ensureEngineRunning()
        for midi in midiNotes {
            let buf = synthBuffer(instrument: "pad", midi: midi, duration: 1.15)
            let player = chordPlayers[chordVoiceIndex % chordPlayers.count]
            chordVoiceIndex += 1
            player.stop()
            player.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
            player.play()
        }
    }

    func playCustomSample(slotIndex: Int) {
        ensureEngineRunning()
        guard slotIndex >= 0 && slotIndex < samplePlayers.count,
              let buf = customBuffers[slotIndex],
              !project.customSamples[slotIndex].isMuted else { return }
        let player = samplePlayers[slotIndex]
        player.stop()
        player.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        player.play()
    }

    // MARK: - Custom Sample Import & Mic Recording

    func importCustomSample(from sourceURL: URL, slotIndex: Int) -> Bool {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed { sourceURL.stopAccessingSecurityScopedResource() }
        }
        let ext = sourceURL.pathExtension.isEmpty ? "wav" : sourceURL.pathExtension
        let destName = "sample_slot_\(slotIndex)_\(Int(Date().timeIntervalSince1970)).\(ext)"
        let destURL = Self.samplesDirectory().appendingPathComponent(destName)
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            let displayName = sourceURL.deletingPathExtension().lastPathComponent
            project.customSamples[slotIndex].name = String(displayName.prefix(18))
            project.customSamples[slotIndex].fileName = destName
            loadCustomSampleBuffer(slotIndex: slotIndex, fileName: destName)
            saveProject()
            return true
        } catch {
            print("Import sample error: \(error)")
            return false
        }
    }

    func startMicRecording(slotIndex: Int) {
        ensureEngineRunning()
        let destName = "mic_slot_\(slotIndex)_\(Int(Date().timeIntervalSince1970)).m4a"
        let destURL = Self.samplesDirectory().appendingPathComponent(destName)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            let recorder = try AVAudioRecorder(url: destURL, settings: settings)
            recorder.record()
            micRecorder = recorder
            recordingSlotIndex = slotIndex
            isRecordingMic = true
            recordingSeconds = 0
            micTimer?.invalidate()
            micTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.recordingSeconds += 0.1
                if (self?.recordingSeconds ?? 0) >= 12.0 {
                    self?.stopMicRecording()
                }
            }
        } catch {
            print("Mic record error: \(error)")
        }
    }

    func stopMicRecording() {
        micTimer?.invalidate()
        micTimer = nil
        guard let recorder = micRecorder, let slotIdx = recordingSlotIndex else {
            isRecordingMic = false
            return
        }
        let url = recorder.url
        recorder.stop()
        micRecorder = nil
        isRecordingMic = false
        recordingSlotIndex = nil

        let fileName = url.lastPathComponent
        project.customSamples[slotIdx].name = "Запись \(slotIdx + 1)"
        project.customSamples[slotIdx].fileName = fileName
        loadCustomSampleBuffer(slotIndex: slotIdx, fileName: fileName)
        saveProject()
    }

    func loadBundledSample(fileKey: String, title: String, slotIndex: Int) {
        let shortTitle = title.components(separatedBy: " (").first ?? title
        project.customSamples[slotIndex].name = String(shortTitle.prefix(18))
        project.customSamples[slotIndex].fileName = "bundle:\(fileKey)"
        loadCustomSampleBuffer(slotIndex: slotIndex, fileName: "bundle:\(fileKey)")
        saveProject()
    }

    func clearCustomSample(slotIndex: Int) {
        if let name = project.customSamples[slotIndex].fileName, !name.hasPrefix("bundle:") {
            let url = Self.samplesDirectory().appendingPathComponent(name)
            try? FileManager.default.removeItem(at: url)
        }
        project.customSamples[slotIndex].fileName = nil
        project.customSamples[slotIndex].name = "Звук \(slotIndex + 1)"
        customBuffers.removeValue(forKey: slotIndex)
        saveProject()
    }

    private func loadAllCustomSamples() {
        for slot in project.customSamples {
            if let fileName = slot.fileName {
                loadCustomSampleBuffer(slotIndex: slot.id, fileName: fileName)
            }
        }
    }

    private func loadCustomSampleBuffer(slotIndex: Int, fileName: String) {
        let url: URL
        if fileName.hasPrefix("bundle:") {
            let key = String(fileName.dropFirst("bundle:".count))
            if let bUrl = Bundle.main.url(forResource: key, withExtension: "wav")
                ?? Bundle.main.url(forResource: key, withExtension: "wav", subdirectory: "SadVibePack") {
                url = bUrl
            } else {
                return
            }
        } else {
            url = Self.samplesDirectory().appendingPathComponent(fileName)
        }
        guard let file = try? AVAudioFile(forReading: url) else { return }
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let rawBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else { return }
        do {
            try file.read(into: rawBuffer)
            if file.processingFormat.sampleRate == format.sampleRate && file.processingFormat.channelCount == 2 {
                customBuffers[slotIndex] = rawBuffer
            } else if let converter = AVAudioConverter(from: file.processingFormat, to: format) {
                let ratio = format.sampleRate / file.processingFormat.sampleRate
                let outFrames = AVAudioFrameCount(Double(frameCount) * ratio) + 64
                if let converted = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: outFrames) {
                    var error: NSError?
                    var consumed = false
                    converter.convert(to: converted, error: &error) { _, outStatus in
                        if consumed {
                            outStatus.pointee = .endOfStream
                            return nil
                        }
                        consumed = true
                        outStatus.pointee = .haveData
                        return rawBuffer
                    }
                    customBuffers[slotIndex] = converted
                }
            }
        } catch {
            print("Load custom sample buffer error: \(error)")
        }
    }

    // MARK: - In-Memory Sound Synthesis (Zero external assets needed)

    private func generateDrumBuffers() {
        drumBuffers[.kick] = synthKick()
        drumBuffers[.snare] = synthSnare()
        drumBuffers[.clap] = synthClap()
        drumBuffers[.hihatClosed] = synthHiHat(open: false)
        drumBuffers[.hihatOpen] = synthHiHat(open: true)
        drumBuffers[.perc] = synthPerc()
    }

    private func makeBuffer(duration: Double) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(44100.0 * duration)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buf.frameLength = frames
        return buf
    }

    private func synthKick() -> AVAudioPCMBuffer {
        let buf = makeBuffer(duration: 0.42)
        let n = Int(buf.frameLength)
        let L = buf.floatChannelData![0]
        let R = buf.floatChannelData![1]
        var phase: Float = 0
        for i in 0..<n {
            let t = Float(i) / 44100.0
            let freq = 48.0 + 145.0 * exp(-t * 28.0)
            phase += 2.0 * .pi * freq / 44100.0
            let env = exp(-t * 8.5)
            let click = exp(-t * 160.0) * 0.35
            let sample = tanh((sin(phase) * env + click) * 1.35) * 0.85
            L[i] = sample
            R[i] = sample
        }
        return buf
    }

    private func synthSnare() -> AVAudioPCMBuffer {
        let buf = makeBuffer(duration: 0.28)
        let n = Int(buf.frameLength)
        let L = buf.floatChannelData![0]
        let R = buf.floatChannelData![1]
        var phase: Float = 0
        for i in 0..<n {
            let t = Float(i) / 44100.0
            let bodyFreq = 185.0 + 90.0 * exp(-t * 35.0)
            phase += 2.0 * .pi * bodyFreq / 44100.0
            let body = sin(phase) * exp(-t * 18.0) * 0.55
            let noise = Float.random(in: -1...1) * exp(-t * 14.0) * 0.52
            let sample = tanh((body + noise) * 1.2) * 0.78
            L[i] = sample
            R[i] = sample
        }
        return buf
    }

    private func synthClap() -> AVAudioPCMBuffer {
        let buf = makeBuffer(duration: 0.30)
        let n = Int(buf.frameLength)
        let L = buf.floatChannelData![0]
        let R = buf.floatChannelData![1]
        var last: Float = 0
        for i in 0..<n {
            let t = Float(i) / 44100.0
            let burst1 = (t < 0.012) ? 1.0 : 0.0
            let burst2 = (t >= 0.015 && t < 0.028) ? 0.9 : 0.0
            let burst3 = (t >= 0.032) ? exp(-(t - 0.032) * 16.0) : 0.0
            let env = Float(max(burst1, burst2, burst3))
            let raw = Float.random(in: -1...1)
            let hp = raw - last * 0.7
            last = raw
            let sample = hp * env * 0.65
            L[i] = sample
            R[i] = sample
        }
        return buf
    }

    private func synthHiHat(open: Bool) -> AVAudioPCMBuffer {
        let dur = open ? 0.38 : 0.08
        let buf = makeBuffer(duration: dur)
        let n = Int(buf.frameLength)
        let L = buf.floatChannelData![0]
        let R = buf.floatChannelData![1]
        var last: Float = 0
        let decay: Float = open ? 8.5 : 52.0
        for i in 0..<n {
            let t = Float(i) / 44100.0
            let raw = Float.random(in: -1...1)
            let hp = raw - last * 0.85
            last = raw
            let metal = sin(2.0 * .pi * 800.0 * t) * 0.15
            let sample = (hp + metal) * exp(-t * decay) * 0.42
            L[i] = sample
            R[i] = sample
        }
        return buf
    }

    private func synthPerc() -> AVAudioPCMBuffer {
        let buf = makeBuffer(duration: 0.18)
        let n = Int(buf.frameLength)
        let L = buf.floatChannelData![0]
        let R = buf.floatChannelData![1]
        for i in 0..<n {
            let t = Float(i) / 44100.0
            let freq: Float = 520.0 + 240.0 * exp(-t * 45.0)
            let s = sin(2.0 * .pi * freq * t) + 0.4 * sin(2.0 * .pi * freq * 1.5 * t)
            let sample = s * exp(-t * 24.0) * 0.45
            L[i] = sample
            R[i] = sample
        }
        return buf
    }

    private func synthBuffer(instrument: String, midi: Int, duration: Double) -> AVAudioPCMBuffer {
        let key = "\(instrument)_\(midi)"
        if let cached = synthBufferCache[key] {
            return cached
        }
        let buf = makeBuffer(duration: duration)
        let n = Int(buf.frameLength)
        let L = buf.floatChannelData![0]
        let R = buf.floatChannelData![1]
        let freq = Float(440.0 * pow(2.0, Double(midi - 69) / 12.0))

        for i in 0..<n {
            let t = Float(i) / 44100.0
            var sample: Float = 0
            let attack = min(1.0, t / 0.012)

            if instrument == "bass" {
                let sub = sin(2.0 * .pi * freq * t)
                let harm = sin(2.0 * .pi * freq * 2.0 * t) * 0.35 * exp(-t * 6.0)
                let env = attack * exp(-t * 4.5)
                sample = tanh((sub + harm) * 1.4) * env * 0.68
            } else if instrument == "pad" {
                let softAtk = min(1.0, t / 0.08)
                let rel = exp(-t * 2.2)
                let s1 = sin(2.0 * .pi * freq * t)
                let s2 = sin(2.0 * .pi * freq * 1.004 * t) * 0.5
                let s3 = sin(2.0 * .pi * freq * 0.996 * t) * 0.5
                sample = (s1 + s2 + s3) * 0.28 * softAtk * rel
            } else if instrument.contains("Retro") {
                let saw = 2.0 * ((freq * t).truncatingRemainder(dividingBy: 1.0)) - 1.0
                let sq: Float = sin(2.0 * .pi * freq * t) >= 0 ? 0.6 : -0.6
                let env = attack * exp(-t * 5.0)
                sample = (saw * 0.4 + sq * 0.4) * env * 0.38
            } else if instrument.contains("Bell") {
                let car = sin(2.0 * .pi * freq * t)
                let mod = sin(2.0 * .pi * freq * 2.41 * t) * 0.45 * exp(-t * 8.0)
                let env = attack * exp(-t * 4.2)
                sample = (car + mod) * env * 0.42
            } else if instrument.contains("Warm Lead") {
                let s1 = sin(2.0 * .pi * freq * t)
                let s2 = sin(2.0 * .pi * freq * 2.0 * t) * 0.3
                let s3 = sin(2.0 * .pi * freq * 1.005 * t) * 0.4
                let env = attack * exp(-t * 3.8)
                sample = (s1 + s2 + s3) * env * 0.40
            } else {
                // Pluck default
                let s1 = sin(2.0 * .pi * freq * t)
                let s2 = sin(2.0 * .pi * freq * 2.0 * t) * 0.5 * exp(-t * 14.0)
                let s3 = sin(2.0 * .pi * freq * 3.0 * t) * 0.25 * exp(-t * 20.0)
                let env = attack * exp(-t * 6.5)
                sample = (s1 + s2 + s3) * env * 0.48
            }

            L[i] = sample
            R[i] = sample
        }

        if synthBufferCache.count > 120 {
            synthBufferCache.removeAll()
        }
        synthBufferCache[key] = buf
        return buf
    }

    // MARK: - Offline WAV Export

    func exportToWAV(fullSong: Bool) -> URL? {
        let sectionsToRender: [SongSection]
        if fullSong && !project.arrangement.isEmpty {
            sectionsToRender = project.arrangement.compactMap { id in
                project.sections.first(where: { $0.id == id })
            }
        } else {
            let secIdx = min(activeSectionIndex, project.sections.count - 1)
            sectionsToRender = [project.sections[secIdx]]
        }

        let sampleRate = 44100.0
        let baseStepDur = 60.0 / project.bpm / 4.0
        let totalSteps = sectionsToRender.count * 16
        let tailSeconds = 1.5
        let totalDuration = Double(totalSteps) * baseStepDur + tailSeconds
        let totalFrames = Int(totalDuration * sampleRate)

        var mixL = [Float](repeating: 0, count: totalFrames)
        var mixR = [Float](repeating: 0, count: totalFrames)

        func addBuffer(_ buf: AVAudioPCMBuffer, atFrame startFrame: Int, gain: Float) {
            guard gain > 0.001, let chL = buf.floatChannelData?[0] else { return }
            let chR = buf.channelCount > 1 ? buf.floatChannelData![1] : chL
            let count = Int(buf.frameLength)
            let limit = min(count, totalFrames - startFrame)
            guard limit > 0 else { return }
            for i in 0..<limit {
                mixL[startFrame + i] += chL[i] * gain
                mixR[startFrame + i] += chR[i] * gain
            }
        }

        let m = project.mixer
        var currentTime = 0.0
        var stepIdx = 0

        for section in sectionsToRender {
            for s in 0..<16 {
                let startFrame = Int(currentTime * sampleRate)

                if !m.drumsMuted {
                    for lane in DrumLane.allCases where section.drums[lane.rawValue][s] {
                        if let buf = drumBuffers[lane] {
                            addBuffer(buf, atFrame: startFrame, gain: m.drumsVolume)
                        }
                    }
                }

                if !m.bassMuted, let deg = section.bass[s] {
                    let midi = project.scale.midiNote(degree: deg, root: project.rootNote, octave: 2)
                    let buf = synthBuffer(instrument: "bass", midi: midi, duration: 0.38)
                    addBuffer(buf, atFrame: startFrame, gain: m.bassVolume)
                }

                if !m.chordsMuted, let cDeg = section.chords[s] {
                    let notes = project.scale.chordMidiNotes(degree: cDeg, root: project.rootNote, octave: 3)
                    for midi in notes {
                        let buf = synthBuffer(instrument: "pad", midi: midi, duration: 1.15)
                        addBuffer(buf, atFrame: startFrame, gain: m.chordsVolume)
                    }
                }

                if !m.leadMuted, let lDeg = section.lead[s] {
                    let midi = project.scale.midiNote(degree: lDeg, root: project.rootNote, octave: 4)
                    let buf = synthBuffer(instrument: "lead_\(project.leadTimbre.rawValue)", midi: midi, duration: 0.45)
                    addBuffer(buf, atFrame: startFrame, gain: m.leadVolume)
                }

                if !m.samplerMuted {
                    for slotIdx in 0..<4 where section.customSamples[slotIdx][s] {
                        if let buf = customBuffers[slotIdx], !project.customSamples[slotIdx].isMuted {
                            addBuffer(buf, atFrame: startFrame, gain: m.samplerVolume * project.customSamples[slotIdx].volume)
                        }
                    }
                }

                let swing = (stepIdx % 2 == 1) ? Double(m.swing) * baseStepDur : -Double(m.swing) * baseStepDur * 0.5
                currentTime += max(0.04, baseStepDur + swing)
                stepIdx += 1
            }
        }

        // Master gain & soft limiter
        for i in 0..<totalFrames {
            mixL[i] = tanh(mixL[i] * m.masterVolume) * 0.92
            mixR[i] = tanh(mixR[i] * m.masterVolume) * 0.92
        }

        let safeTitle = project.title.replacingOccurrences(of: " ", with: "_")
        let outURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeTitle)_AuraBeat.wav")
        try? FileManager.default.removeItem(at: outURL)

        guard let outBuf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames)) else {
            return nil
        }
        outBuf.frameLength = AVAudioFrameCount(totalFrames)
        let outL = outBuf.floatChannelData![0]
        let outR = outBuf.floatChannelData![1]
        for i in 0..<totalFrames {
            outL[i] = mixL[i]
            outR[i] = mixR[i]
        }

        do {
            let outFile = try AVAudioFile(forWriting: outURL, settings: format.settings)
            try outFile.write(from: outBuf)
            return outURL
        } catch {
            print("Export WAV error: \(error)")
            return nil
        }
    }
}
