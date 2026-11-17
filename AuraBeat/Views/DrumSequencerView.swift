import SwiftUI

struct DrumSequencerView: View {
    @ObservedObject var audio: AudioEngine

    var body: some View {
        let secIdx = min(audio.activeSectionIndex, audio.project.sections.count - 1)
        VStack(spacing: 14) {
            // Header & Quick Beat Helpers
            HStack {
                Text("ДРАМ-МАШИНА • 16 ШАГОВ")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
                    .tracking(1.5)

                Spacer()

                HStack(spacing: 10) {
                    Button(action: fillFourOnFloor) {
                        Label("House Kick", systemImage: "metronome")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(StudioPillButtonStyle(color: Color(red: 0.0, green: 0.96, blue: 0.83)))

                    Button(action: fillTrapHats) {
                        Label("8/16 Hats", systemImage: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(StudioPillButtonStyle(color: Color(red: 0.68, green: 0.38, blue: 1.0)))

                    Button(action: clearDrums) {
                        Label("Очистить", systemImage: "trash")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(StudioPillButtonStyle(color: Color(red: 1.0, green: 0.25, blue: 0.45)))
                }
            }

            // 6-lane 16-step grid
            VStack(spacing: 8) {
                // Step numbers
                HStack(spacing: 6) {
                    Text("ПЭД")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 96, alignment: .leading)

                    ForEach(0..<16, id: \.self) { step in
                        Text("\(step + 1)")
                            .font(.system(size: 11, weight: step % 4 == 0 ? .heavy : .medium, design: .monospaced))
                            .foregroundColor(
                                audio.isPlaying && audio.currentStep == step
                                ? Color(red: 0.0, green: 0.96, blue: 0.83)
                                : (step % 4 == 0 ? .white.opacity(0.8) : .white.opacity(0.35))
                            )
                            .frame(maxWidth: .infinity)
                    }
                }

                ForEach(DrumLane.allCases) { lane in
                    HStack(spacing: 6) {
                        // Live trigger pad
                        Button {
                            audio.playDrum(lane)
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(lane.color)
                                    .frame(width: 10, height: 10)
                                Text(lane.name)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .frame(width: 96, height: 44)
                            .background(lane.color.opacity(0.16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(lane.color.opacity(0.5), lineWidth: 1)
                            )
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)

                        // 16 step buttons
                        ForEach(0..<16, id: \.self) { step in
                            let isOn = audio.project.sections[secIdx].drums[lane.rawValue][step]
                            let isCurrent = audio.isPlaying && audio.currentStep == step
                            let isBeat = (step / 4) % 2 == 0

                            Button {
                                audio.project.sections[secIdx].drums[lane.rawValue][step].toggle()
                                if audio.project.sections[secIdx].drums[lane.rawValue][step] {
                                    audio.playDrum(lane)
                                }
                                audio.saveProject()
                            } label: {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        isOn
                                        ? lane.color.opacity(isCurrent ? 1.0 : 0.85)
                                        : Color.white.opacity(isBeat ? 0.08 : 0.04)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                isCurrent ? Color.white : (isOn ? lane.color : Color.white.opacity(0.08)),
                                                lineWidth: isCurrent ? 2 : 1
                                            )
                                    )
                                    .shadow(color: isOn ? lane.color.opacity(0.35) : .clear, radius: 6)
                                    .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 48)
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

            // Big Live Finger-Drumming Pads
            HStack(spacing: 12) {
                ForEach(DrumLane.allCases) { lane in
                    Button {
                        audio.playDrum(lane)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(lane.color)
                            Text(lane.name.uppercased())
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, minHeight: 74)
                        .background(
                            LinearGradient(
                                colors: [lane.color.opacity(0.24), lane.color.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(lane.color.opacity(0.55), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func fillFourOnFloor() {
        let secIdx = min(audio.activeSectionIndex, audio.project.sections.count - 1)
        for s in [0, 4, 8, 12] {
            audio.project.sections[secIdx].drums[DrumLane.kick.rawValue][s] = true
        }
        audio.saveProject()
    }

    private func fillTrapHats() {
        let secIdx = min(audio.activeSectionIndex, audio.project.sections.count - 1)
        for s in stride(from: 0, to: 16, by: 2) {
            audio.project.sections[secIdx].drums[DrumLane.hihatClosed.rawValue][s] = true
        }
        audio.saveProject()
    }

    private func clearDrums() {
        let secIdx = min(audio.activeSectionIndex, audio.project.sections.count - 1)
        audio.project.sections[secIdx].drums = Array(repeating: Array(repeating: false, count: 16), count: DrumLane.allCases.count)
        audio.saveProject()
    }
}
