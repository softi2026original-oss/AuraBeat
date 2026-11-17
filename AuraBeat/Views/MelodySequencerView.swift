import SwiftUI

enum MelodyTrackMode: String, CaseIterable, Identifiable {
    case lead = "Мелодия (Lead)"
    case bass = "Бас (808)"
    case chords = "Аккорды (Pad)"

    var id: String { rawValue }

    var accentColor: Color {
        switch self {
        case .lead: return Color(red: 0.0, green: 0.96, blue: 0.83)
        case .bass: return Color(red: 1.0, green: 0.25, blue: 0.45)
        case .chords: return Color(red: 0.68, green: 0.38, blue: 1.0)
        }
    }
}

struct MelodySequencerView: View {
    @ObservedObject var audio: AudioEngine
    @State private var mode: MelodyTrackMode = .lead

    private let degreesTopToBottom = [7, 6, 5, 4, 3, 2, 1, 0]

    var body: some View {
        let secIdx = min(audio.activeSectionIndex, audio.project.sections.count - 1)

        VStack(spacing: 12) {
            // Mode & Timbre bar
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    ForEach(MelodyTrackMode.allCases) { item in
                        Button {
                            mode = item
                        } label: {
                            Text(item.rawValue)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(mode == item ? .black : .white.opacity(0.8))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(mode == item ? item.accentColor : Color.white.opacity(0.08))
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if mode == .lead {
                    Picker("Тембр", selection: $audio.project.leadTimbre) {
                        ForEach(LeadTimbre.allCases) { timbre in
                            Text(timbre.rawValue).tag(timbre)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                }

                Spacer()

                Button(action: generateSmartIdea) {
                    Label("Идея", systemImage: "wand.and.stars")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(StudioPillButtonStyle(color: mode.accentColor))

                Button(action: clearCurrentTrack) {
                    Label("Очистить", systemImage: "trash")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(StudioPillButtonStyle(color: Color(red: 1.0, green: 0.25, blue: 0.45)))
            }

            // Scale-Locked Piano Roll Grid (8 degrees x 16 steps)
            VStack(spacing: 5) {
                ForEach(degreesTopToBottom, id: \.self) { degree in
                    HStack(spacing: 5) {
                        Text(noteLabel(degree: degree))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.75))
                            .frame(width: 58, height: 32)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(6)

                        ForEach(0..<16, id: \.self) { step in
                            let activeDeg = currentStepValue(secIdx: secIdx, step: step)
                            let isOn = (activeDeg == degree)
                            let isCurrent = audio.isPlaying && audio.currentStep == step
                            let isBeat = (step / 4) % 2 == 0

                            Button {
                                toggleStep(secIdx: secIdx, step: step, degree: degree)
                            } label: {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        isOn
                                        ? mode.accentColor.opacity(isCurrent ? 1.0 : 0.85)
                                        : Color.white.opacity(isBeat ? 0.07 : 0.035)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(
                                                isCurrent ? Color.white : (isOn ? mode.accentColor : Color.white.opacity(0.06)),
                                                lineWidth: isCurrent ? 2 : 1
                                            )
                                    )
                                    .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 34)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            // Live Touch Pads (Play in Key!)
            HStack(spacing: 10) {
                ForEach(0..<8, id: \.self) { degree in
                    Button {
                        previewDegree(degree)
                    } label: {
                        VStack(spacing: 4) {
                            Text(noteLabel(degree: degree))
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                            Text(mode == .chords ? "CHORD \(degree + 1)" : "NOTE \(degree + 1)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(mode.accentColor)
                        }
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(mode.accentColor.opacity(0.16))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(mode.accentColor.opacity(0.5), lineWidth: 1.2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func noteLabel(degree: Int) -> String {
        let midi = audio.project.scale.midiNote(degree: degree, root: audio.project.rootNote, octave: 4)
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let name = names[((midi % 12) + 12) % 12]
        return mode == .chords ? "\(name)m/\(degree + 1)" : name
    }

    private func currentStepValue(secIdx: Int, step: Int) -> Int? {
        switch mode {
        case .lead: return audio.project.sections[secIdx].lead[step]
        case .bass: return audio.project.sections[secIdx].bass[step]
        case .chords: return audio.project.sections[secIdx].chords[step]
        }
    }

    private func toggleStep(secIdx: Int, step: Int, degree: Int) {
        switch mode {
        case .lead:
            let cur = audio.project.sections[secIdx].lead[step]
            audio.project.sections[secIdx].lead[step] = (cur == degree) ? nil : degree
            if cur != degree { previewDegree(degree) }
        case .bass:
            let cur = audio.project.sections[secIdx].bass[step]
            audio.project.sections[secIdx].bass[step] = (cur == degree) ? nil : degree
            if cur != degree { previewDegree(degree) }
        case .chords:
            let cur = audio.project.sections[secIdx].chords[step]
            audio.project.sections[secIdx].chords[step] = (cur == degree) ? nil : degree
            if cur != degree { previewDegree(degree) }
        }
        audio.saveProject()
    }

    private func previewDegree(_ degree: Int) {
        switch mode {
        case .lead:
            let midi = audio.project.scale.midiNote(degree: degree, root: audio.project.rootNote, octave: 4)
            audio.playLead(midi: midi)
        case .bass:
            let midi = audio.project.scale.midiNote(degree: degree, root: audio.project.rootNote, octave: 2)
            audio.playBass(midi: midi)
        case .chords:
            let notes = audio.project.scale.chordMidiNotes(degree: degree, root: audio.project.rootNote, octave: 3)
            audio.playChord(midiNotes: notes)
        }
    }

    private func generateSmartIdea() {
        let secIdx = min(audio.activeSectionIndex, audio.project.sections.count - 1)
        switch mode {
        case .chords:
            let progressions = [
                [0, 5, 3, 4],
                [0, 3, 5, 4],
                [0, 4, 5, 2],
                [0, 2, 3, 4]
            ].randomElement()!
            var arr: [Int?] = Array(repeating: nil, count: 16)
            arr[0] = progressions[0]
            arr[4] = progressions[1]
            arr[8] = progressions[2]
            arr[12] = progressions[3]
            audio.project.sections[secIdx].chords = arr
        case .bass:
            var arr: [Int?] = Array(repeating: nil, count: 16)
            let chords = audio.project.sections[secIdx].chords
            var lastRoot = 0
            for s in 0..<16 {
                if let c = chords[s] { lastRoot = c }
                if s % 4 == 0 || (s % 4 == 2 && Bool.random()) || (s % 4 == 3 && Int.random(in: 0...3) == 0) {
                    arr[s] = lastRoot
                }
            }
            audio.project.sections[secIdx].bass = arr
        case .lead:
            var arr: [Int?] = Array(repeating: nil, count: 16)
            let pool = [0, 2, 4, 5, 7]
            for s in stride(from: 0, to: 16, by: 2) {
                if Int.random(in: 0...10) > 3 {
                    arr[s] = pool.randomElement()!
                }
            }
            audio.project.sections[secIdx].lead = arr
        }
        audio.saveProject()
    }

    private func clearCurrentTrack() {
        let secIdx = min(audio.activeSectionIndex, audio.project.sections.count - 1)
        let empty: [Int?] = Array(repeating: nil, count: 16)
        switch mode {
        case .lead: audio.project.sections[secIdx].lead = empty
        case .bass: audio.project.sections[secIdx].bass = empty
        case .chords: audio.project.sections[secIdx].chords = empty
        }
        audio.saveProject()
    }
}
