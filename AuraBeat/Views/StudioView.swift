import SwiftUI
import UIKit

enum StudioTab: String, CaseIterable, Identifiable {
    case drums = "Бит / Драм"
    case melody = "Бас и Мелодия"
    case sampler = "Мои звуки"
    case mixer = "Микшер и FX"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .drums: return "square.grid.4x3.fill"
        case .melody: return "pianokeys"
        case .sampler: return "waveform.badge.plus"
        case .mixer: return "slider.vertical.3"
        }
    }
}

struct StudioView: View {
    @ObservedObject var audio: AudioEngine
    @State private var selectedTab: StudioTab = .drums
    @State private var exportedURL: URL? = nil
    @State private var showShareSheet: Bool = false
    @State private var isExporting: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.05, blue: 0.09),
                    Color(red: 0.08, green: 0.06, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                transportBar()
                sectionArrangementBar()
                tabSelectorBar()

                ScrollView(.vertical, showsIndicators: false) {
                    Group {
                        switch selectedTab {
                        case .drums:
                            DrumSequencerView(audio: audio)
                        case .melody:
                            MelodySequencerView(audio: audio)
                        case .sampler:
                            SamplerView(audio: audio)
                        case .mixer:
                            MixerView(audio: audio)
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    // MARK: - Top Transport Bar

    private func transportBar() -> some View {
        HStack(spacing: 14) {
            // Brand + Live Visualizer
            HStack(spacing: 10) {
                Text("AuraBeat")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.0, green: 0.96, blue: 0.83),
                                Color(red: 0.78, green: 0.45, blue: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                // Mini Spectrum
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<12, id: \.self) { i in
                        let lvl = CGFloat(audio.isPlaying ? audio.spectrumLevels[i] : 0.12)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(red: 0.0, green: 0.96, blue: 0.83))
                            .frame(width: 3, height: max(4, lvl * 22))
                    }
                }
                .frame(height: 24)
            }

            // Play / Stop
            Button {
                audio.togglePlay()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: audio.isPlaying ? "stop.fill" : "play.fill")
                    Text(audio.isPlaying ? "СТОП" : "PLAY")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 18)
                .frame(height: 40)
                .background(
                    audio.isPlaying
                    ? Color(red: 1.0, green: 0.25, blue: 0.45)
                    : Color(red: 0.0, green: 0.96, blue: 0.83)
                )
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            // BPM Control
            HStack(spacing: 6) {
                Button {
                    audio.project.bpm = max(60, audio.project.bpm - 2)
                    audio.saveProject()
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 28, height: 32)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Text("\(Int(audio.project.bpm)) BPM")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(minWidth: 66)

                Button {
                    audio.project.bpm = min(180, audio.project.bpm + 2)
                    audio.saveProject()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 32)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)

            // Key & Scale
            HStack(spacing: 6) {
                Menu {
                    ForEach(NoteName.allCases) { note in
                        Button(note.title) {
                            audio.project.rootNote = note
                            audio.saveProject()
                        }
                    }
                } label: {
                    Text(audio.project.rootNote.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 36)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)
                }

                Menu {
                    ForEach(MusicalScale.allCases) { sc in
                        Button(sc.rawValue) {
                            audio.project.scale = sc
                            audio.saveProject()
                        }
                    }
                } label: {
                    Text(audio.project.scale.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 0.0, green: 0.96, blue: 0.83))
                        .padding(.horizontal, 10)
                        .frame(height: 36)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)
                }
            }

            Spacer()

            // Pattern vs Song Mode
            Button {
                audio.songMode.toggle()
            } label: {
                Label(
                    audio.songMode ? "РЕЖИМ ПЕСНИ" : "ПАТТЕРН",
                    systemImage: audio.songMode ? "music.note.list" : "repeat"
                )
                .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .buttonStyle(
                StudioPillButtonStyle(
                    color: audio.songMode
                        ? Color(red: 0.68, green: 0.38, blue: 1.0)
                        : Color.white.opacity(0.65)
                )
            )

            // Presets Menu
            Menu {
                ForEach(SongPreset.allCases) { preset in
                    Button("\(preset.rawValue) (\(preset.subtitle))") {
                        audio.loadPreset(preset)
                    }
                }
                Divider()
                Button("Создать пустой трек", role: .destructive) {
                    audio.resetBlankProject()
                }
            } label: {
                Label("Стили", systemImage: "wand.and.rays")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
            }

            // Export WAV
            Button {
                exportSong()
            } label: {
                Label(isExporting ? "Рендер..." : "WAV", systemImage: "square.and.arrow.up")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(Color(red: 1.0, green: 0.62, blue: 0.18))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(isExporting)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
    }

    // MARK: - Song Sections & Arrangement

    private func sectionArrangementBar() -> some View {
        HStack(spacing: 12) {
            Text("ЧАСТИ:")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.5))

            ForEach(0..<audio.project.sections.count, id: \.self) { idx in
                let sec = audio.project.sections[idx]
                let isSelected = audio.activeSectionIndex == idx
                Button {
                    audio.activeSectionIndex = idx
                } label: {
                    Text(sec.label)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? .black : .white.opacity(0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(isSelected ? Color(red: 0.0, green: 0.96, blue: 0.83) : Color.white.opacity(0.08))
                        .cornerRadius(9)
                }
                .buttonStyle(.plain)
            }

            Button {
                copyActiveSectionToNext()
            } label: {
                Label("Копировать →", systemImage: "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(9)
            }
            .buttonStyle(.plain)

            Spacer()

            // Arrangement chain
            HStack(spacing: 4) {
                Text("АРАНЖИРОВКА:")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))

                ForEach(Array(audio.project.arrangement.enumerated()), id: \.offset) { pos, secId in
                    let letter = ["A", "B", "C", "D"][min(secId, 3)]
                    let isPlayingThis = audio.isPlaying && audio.songMode && audio.arrangementPlayIndex == pos
                    Button {
                        if audio.project.arrangement.count > 1 {
                            audio.project.arrangement.remove(at: pos)
                            audio.saveProject()
                        }
                    } label: {
                        Text(letter)
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundColor(isPlayingThis ? .black : .white)
                            .frame(width: 24, height: 24)
                            .background(
                                isPlayingThis
                                ? Color(red: 0.0, green: 0.96, blue: 0.83)
                                : Color(red: 0.68, green: 0.38, blue: 1.0).opacity(0.4)
                            )
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                Menu {
                    Button("+ A (Intro)") { appendArrangement(0) }
                    Button("+ B (Verse)") { appendArrangement(1) }
                    Button("+ C (Chorus)") { appendArrangement(2) }
                    Button("+ D (Drop)") { appendArrangement(3) }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Color(red: 0.0, green: 0.96, blue: 0.83))
                        .font(.system(size: 18))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }

    // MARK: - Workspace Tabs

    private func tabSelectorBar() -> some View {
        HStack(spacing: 10) {
            ForEach(StudioTab.allCases) { tab in
                let isSel = selectedTab == tab
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(isSel ? .white : .white.opacity(0.55))
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(
                        isSel
                        ? LinearGradient(
                            colors: [
                                Color(red: 0.51, green: 0.22, blue: 0.93).opacity(0.65),
                                Color(red: 0.0, green: 0.96, blue: 0.83).opacity(0.28)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        : LinearGradient(
                            colors: [Color.white.opacity(0.05), Color.white.opacity(0.05)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSel ? Color(red: 0.0, green: 0.96, blue: 0.83).opacity(0.65) : Color.clear, lineWidth: 1.2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func copyActiveSectionToNext() {
        let cur = audio.activeSectionIndex
        let next = (cur + 1) % audio.project.sections.count
        var copied = audio.project.sections[cur]
        copied.id = next
        copied.label = audio.project.sections[next].label
        audio.project.sections[next] = copied
        audio.activeSectionIndex = next
        audio.saveProject()
    }

    private func appendArrangement(_ secId: Int) {
        guard audio.project.arrangement.count < 12 else { return }
        audio.project.arrangement.append(secId)
        audio.saveProject()
    }

    private func exportSong() {
        isExporting = true
        DispatchQueue.global(qos: .userInitiated).async {
            let url = audio.exportToWAV(fullSong: true)
            DispatchQueue.main.async {
                isExporting = false
                if let url = url {
                    exportedURL = url
                    showShareSheet = true
                }
            }
        }
    }
}

// MARK: - Shared UI Components

struct StudioPillButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(color.opacity(configuration.isPressed ? 0.45 : 0.22))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.65), lineWidth: 1)
            )
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        if let pop = vc.popoverPresentationController {
            pop.sourceView = UIApplication.shared.windows.first
            pop.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: 100, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
