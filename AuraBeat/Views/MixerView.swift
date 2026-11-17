import SwiftUI

struct MixerView: View {
    @ObservedObject var audio: AudioEngine

    var body: some View {
        VStack(spacing: 16) {
            // Channel Strips
            HStack(spacing: 12) {
                channelStrip(
                    title: "Drums",
                    color: Color(red: 1.0, green: 0.25, blue: 0.45),
                    volume: $audio.project.mixer.drumsVolume,
                    muted: $audio.project.mixer.drumsMuted
                )
                channelStrip(
                    title: "Bass 808",
                    color: Color(red: 1.0, green: 0.62, blue: 0.18),
                    volume: $audio.project.mixer.bassVolume,
                    muted: $audio.project.mixer.bassMuted
                )
                channelStrip(
                    title: "Chords",
                    color: Color(red: 0.68, green: 0.38, blue: 1.0),
                    volume: $audio.project.mixer.chordsVolume,
                    muted: $audio.project.mixer.chordsMuted
                )
                channelStrip(
                    title: "Lead",
                    color: Color(red: 0.0, green: 0.96, blue: 0.83),
                    volume: $audio.project.mixer.leadVolume,
                    muted: $audio.project.mixer.leadMuted
                )
                channelStrip(
                    title: "Мои звуки",
                    color: Color(red: 0.25, green: 0.72, blue: 1.0),
                    volume: $audio.project.mixer.samplerVolume,
                    muted: $audio.project.mixer.samplerMuted
                )
                masterStrip()
            }

            // Master FX & Groove
            HStack(spacing: 14) {
                fxCard(
                    title: "Reverb (Эхо зала)",
                    icon: "sparkles",
                    color: Color(red: 0.68, green: 0.38, blue: 1.0),
                    value: $audio.project.mixer.reverbWet,
                    range: 0...0.85,
                    display: "\(Int(audio.project.mixer.reverbWet * 100))%"
                )
                fxCard(
                    title: "Delay (Повтор)",
                    icon: "waveform.path.ecg",
                    color: Color(red: 0.0, green: 0.96, blue: 0.83),
                    value: $audio.project.mixer.delayWet,
                    range: 0...0.75,
                    display: "\(Int(audio.project.mixer.delayWet * 100))%"
                )
                fxCard(
                    title: "Swing (Кач)",
                    icon: "metronome",
                    color: Color(red: 1.0, green: 0.62, blue: 0.18),
                    value: $audio.project.mixer.swing,
                    range: 0...0.30,
                    display: "\(Int(audio.project.mixer.swing * 333))%"
                )
            }
        }
    }

    private func channelStrip(title: String, color: Color, volume: Binding<Float>, muted: Binding<Bool>) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("\(Int(volume.wrappedValue * 100))%")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(color)

            Slider(
                value: Binding(
                    get: { volume.wrappedValue },
                    set: { val in
                        volume.wrappedValue = val
                        audio.applyMixerSettings()
                        audio.saveProject()
                    }
                ),
                in: 0...1.2
            )
            .accentColor(color)

            Button {
                muted.wrappedValue.toggle()
                audio.applyMixerSettings()
                audio.saveProject()
            } label: {
                Text(muted.wrappedValue ? "MUTED" : "ON")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(muted.wrappedValue ? .white : .black)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(muted.wrappedValue ? Color.red.opacity(0.85) : color)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.35), lineWidth: 1)
        )
    }

    private func masterStrip() -> some View {
        VStack(spacing: 12) {
            Text("MASTER")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(.white)

            Text("\(Int(audio.project.mixer.masterVolume * 100))%")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Slider(
                value: Binding(
                    get: { audio.project.mixer.masterVolume },
                    set: { val in
                        audio.project.mixer.masterVolume = val
                        audio.applyMixerSettings()
                        audio.saveProject()
                    }
                ),
                in: 0...1.0
            )
            .accentColor(.white)

            Text("LIMITER")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 0.0, green: 0.96, blue: 0.83))
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.07))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
        )
    }

    private func fxCard(title: String, icon: String, color: Color, value: Binding<Float>, range: ClosedRange<Float>, display: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text(display)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }
            Slider(
                value: Binding(
                    get: { value.wrappedValue },
                    set: { val in
                        value.wrappedValue = val
                        audio.applyMixerSettings()
                        audio.saveProject()
                    }
                ),
                in: range
            )
            .accentColor(color)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}
