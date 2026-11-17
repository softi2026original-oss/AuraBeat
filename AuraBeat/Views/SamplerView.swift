import SwiftUI
import UniformTypeIdentifiers

struct SamplerView: View {
    @ObservedObject var audio: AudioEngine
    @State private var importingSlot: Int? = nil
    @State private var showFileImporter: Bool = false

    private let slotColors: [Color] = [
        Color(red: 0.0, green: 0.96, blue: 0.83),
        Color(red: 1.0, green: 0.62, blue: 0.18),
        Color(red: 0.68, green: 0.38, blue: 1.0),
        Color(red: 1.0, green: 0.25, blue: 0.45)
    ]

    var body: some View {
        let secIdx = min(audio.activeSectionIndex, audio.project.sections.count - 1)

        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("МОИ ЗВУКИ • СЭМПЛЕР")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                        .tracking(1.5)
                    Text("Загружай свои WAV/MP3/M4A из «Файлов» или записывай с микрофона iPad")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.45))
                }
                Spacer()
            }

            // 4 Custom Sample Pads
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { idx in
                    sampleCard(slotIndex: idx, color: slotColors[idx])
                }
            }

            // 4-lane 16-step sequencer for custom sounds
            VStack(spacing: 8) {
                HStack {
                    Text("СЕКВЕНСОР МОИХ ЗВУКОВ")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                }

                ForEach(0..<4, id: \.self) { idx in
                    let slot = audio.project.customSamples[idx]
                    let color = slotColors[idx]
                    HStack(spacing: 6) {
                        Button {
                            audio.playCustomSample(slotIndex: idx)
                        } label: {
                            Text(slot.name)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .foregroundColor(.white)
                                .frame(width: 96, height: 40)
                                .background(color.opacity(slot.fileName != nil ? 0.22 : 0.08))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(color.opacity(0.45), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)

                        ForEach(0..<16, id: \.self) { step in
                            let isOn = audio.project.sections[secIdx].customSamples[idx][step]
                            let isCurrent = audio.isPlaying && audio.currentStep == step
                            let isBeat = (step / 4) % 2 == 0

                            Button {
                                audio.project.sections[secIdx].customSamples[idx][step].toggle()
                                if audio.project.sections[secIdx].customSamples[idx][step] {
                                    audio.playCustomSample(slotIndex: idx)
                                }
                                audio.saveProject()
                            } label: {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(
                                        isOn
                                        ? color.opacity(isCurrent ? 1.0 : 0.85)
                                        : Color.white.opacity(isBeat ? 0.08 : 0.04)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7)
                                            .stroke(
                                                isCurrent ? Color.white : (isOn ? color : Color.white.opacity(0.08)),
                                                lineWidth: isCurrent ? 2 : 1
                                            )
                                    )
                                    .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 42)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            guard let slotIdx = importingSlot else { return }
            if case .success(let urls) = result, let url = urls.first {
                _ = audio.importCustomSample(from: url, slotIndex: slotIdx)
            }
            importingSlot = nil
        }
    }

    private func sampleCard(slotIndex: Int, color: Color) -> some View {
        let slot = audio.project.customSamples[slotIndex]
        let isRecordingThis = audio.isRecordingMic && audio.recordingSlotIndex == slotIndex
        let hasAudio = slot.fileName != nil

        return VStack(spacing: 10) {
            // Live trigger pad
            Button {
                audio.playCustomSample(slotIndex: slotIndex)
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: hasAudio ? "waveform" : "plus.circle.dashed")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(hasAudio ? color : .white.opacity(0.4))
                    Text(slot.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(hasAudio ? "Нажми для игры" : "Пустой слот")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, minHeight: 92)
                .background(color.opacity(hasAudio ? 0.16 : 0.05))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(hasAudio ? 0.6 : 0.2), lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)

            // Pack, Import & Mic record buttons
            HStack(spacing: 6) {
                Menu {
                    ForEach(BundledSadSample.all) { item in
                        Button(item.title) {
                            audio.loadBundledSample(fileKey: item.fileKey, title: item.title, slotIndex: slotIndex)
                            audio.playCustomSample(slotIndex: slotIndex)
                        }
                    }
                } label: {
                    Label("Пак", systemImage: "music.note")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(Color(red: 0.68, green: 0.38, blue: 1.0).opacity(0.28))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(red: 0.68, green: 0.38, blue: 1.0).opacity(0.65), lineWidth: 1)
                        )
                }

                Button {
                    importingSlot = slotIndex
                    showFileImporter = true
                } label: {
                    Label("Файл", systemImage: "folder.fill")
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(StudioPillButtonStyle(color: color))

                Button {
                    if isRecordingThis {
                        audio.stopMicRecording()
                    } else {
                        audio.startMicRecording(slotIndex: slotIndex)
                    }
                } label: {
                    Label(
                        isRecordingThis ? String(format: "%.1fс", audio.recordingSeconds) : "Микр.",
                        systemImage: isRecordingThis ? "stop.circle.fill" : "mic.fill"
                    )
                    .font(.system(size: 11, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(StudioPillButtonStyle(color: isRecordingThis ? .red : Color(red: 1.0, green: 0.25, blue: 0.45)))
            }

            // Pitch & Volume controls
            VStack(spacing: 6) {
                HStack {
                    Text("Тон:")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("\(Int(slot.pitchSemitones)) st")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(color)
                }
                Slider(
                    value: Binding(
                        get: { audio.project.customSamples[slotIndex].pitchSemitones },
                        set: { val in
                            audio.project.customSamples[slotIndex].pitchSemitones = round(val)
                            audio.applyMixerSettings()
                            audio.saveProject()
                        }
                    ),
                    in: -12...12
                )
                .accentColor(color)

                HStack {
                    Text("Громк.:")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    if hasAudio {
                        Button("Удалить") {
                            audio.clearCustomSample(slotIndex: slotIndex)
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.red.opacity(0.85))
                    }
                }
                Slider(
                    value: Binding(
                        get: { audio.project.customSamples[slotIndex].volume },
                        set: { val in
                            audio.project.customSamples[slotIndex].volume = val
                            audio.applyMixerSettings()
                            audio.saveProject()
                        }
                    ),
                    in: 0...1.2
                )
                .accentColor(color)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
