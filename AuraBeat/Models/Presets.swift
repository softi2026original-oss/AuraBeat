import Foundation

enum SongPreset: String, CaseIterable, Identifiable {
    case sadRainyNight = "Sad Rainy Night"
    case midnightLoFi = "Midnight Lo-Fi"
    case neonSynthwave = "Neon Synthwave"
    case trapBounce = "808 Trap Bounce"
    case deepHouse = "Deep House"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .sadRainyNight: return "76 BPM • D Minor (Sad Vibe)"
        case .midnightLoFi: return "88 BPM • C Minor"
        case .neonSynthwave: return "116 BPM • A Minor"
        case .trapBounce: return "138 BPM • F# Phrygian"
        case .deepHouse: return "124 BPM • D Dorian"
        }
    }

    func buildProject() -> SongProject {
        switch self {
        case .sadRainyNight: return Self.makeSadRainyNight()
        case .midnightLoFi: return Self.makeLoFi()
        case .neonSynthwave: return Self.makeSynthwave()
        case .trapBounce: return Self.makeTrap()
        case .deepHouse: return Self.makeHouse()
        }
    }

    private static func makeDrums(
        kick: [Int],
        snare: [Int],
        clap: [Int] = [],
        hatClosed: [Int] = [],
        hatOpen: [Int] = [],
        perc: [Int] = []
    ) -> [[Bool]] {
        var grid = Array(repeating: Array(repeating: false, count: 16), count: DrumLane.allCases.count)
        for s in kick { grid[DrumLane.kick.rawValue][s] = true }
        for s in snare { grid[DrumLane.snare.rawValue][s] = true }
        for s in clap { grid[DrumLane.clap.rawValue][s] = true }
        for s in hatClosed { grid[DrumLane.hihatClosed.rawValue][s] = true }
        for s in hatOpen { grid[DrumLane.hihatOpen.rawValue][s] = true }
        for s in perc { grid[DrumLane.perc.rawValue][s] = true }
        return grid
    }

    private static func makeSadRainyNight() -> SongProject {
        var proj = SongProject.blank()
        proj.title = "Sad Rainy Night"
        proj.bpm = 76
        proj.rootNote = .d
        proj.scale = .minor
        proj.leadTimbre = .bell
        proj.mixer.swing = 0.10
        proj.mixer.reverbWet = 0.45
        proj.mixer.delayWet = 0.28

        // Pre-assign Sad Vibe Pack to the 4 custom sampler slots
        proj.customSamples = [
            CustomSampleSlot(id: 0, name: "Angel Pad", fileName: "bundle:angel_pad", volume: 0.72, pitchSemitones: 0, reverbSend: 0.4, isMuted: false),
            CustomSampleSlot(id: 1, name: "Bell Harmonics", fileName: "bundle:bell_harmonics", volume: 0.65, pitchSemitones: 0, reverbSend: 0.5, isMuted: false),
            CustomSampleSlot(id: 2, name: "Ambient Wind", fileName: "bundle:ambient_wind", volume: 0.55, pitchSemitones: 0, reverbSend: 0.4, isMuted: false),
            CustomSampleSlot(id: 3, name: "Reverb Kick", fileName: "bundle:reverb_kick", volume: 0.85, pitchSemitones: 0, reverbSend: 0.2, isMuted: false)
        ]

        // Section A: Intro (Atmospheric pads + wind + soft bells)
        proj.sections[0].chords = [0, nil, nil, nil, nil, nil, nil, nil, 5, nil, nil, nil, nil, nil, nil, nil]
        proj.sections[0].lead = [4, nil, nil, nil, 2, nil, nil, nil, 0, nil, nil, nil, nil, nil, nil, nil]
        proj.sections[0].customSamples[0][0] = true
        proj.sections[0].customSamples[2][0] = true

        // Section B: Verse (Slow emotional beat + 808 bass)
        proj.sections[1].drums = makeDrums(
            kick: [0, 10],
            snare: [8],
            hatClosed: [0, 2, 4, 6, 8, 10, 12, 14]
        )
        proj.sections[1].chords = [0, nil, nil, nil, 5, nil, nil, nil, 2, nil, nil, nil, 6, nil, nil, nil]
        proj.sections[1].bass = [0, nil, nil, nil, 5, nil, nil, nil, 2, nil, nil, nil, 6, nil, nil, nil]
        proj.sections[1].lead = [4, nil, nil, 2, nil, nil, 0, nil, 4, nil, nil, 5, nil, nil, 4, nil]
        proj.sections[1].customSamples[1][0] = true
        proj.sections[1].customSamples[3][0] = true

        // Section C: Chorus (Full sad drop)
        proj.sections[2].drums = makeDrums(
            kick: [0, 3, 10],
            snare: [8],
            clap: [8],
            hatClosed: [0, 2, 4, 5, 6, 8, 10, 12, 14, 15],
            hatOpen: [14]
        )
        proj.sections[2].chords = [0, nil, nil, nil, 5, nil, nil, nil, 2, nil, nil, nil, 4, nil, nil, nil]
        proj.sections[2].bass = [0, nil, nil, 0, 5, nil, nil, nil, 2, nil, nil, 2, 4, nil, nil, nil]
        proj.sections[2].lead = [7, nil, nil, 5, 4, nil, 2, nil, 4, nil, 5, nil, 2, nil, 0, nil]
        proj.sections[2].customSamples[0][0] = true
        proj.sections[2].customSamples[1][8] = true
        proj.sections[2].customSamples[3][0] = true

        // Section D: Outro / Breakdown
        proj.sections[3].chords = [5, nil, nil, nil, nil, nil, nil, nil, 0, nil, nil, nil, nil, nil, nil, nil]
        proj.sections[3].lead = [2, nil, nil, 0, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
        proj.sections[3].customSamples[0][0] = true
        proj.sections[3].customSamples[2][0] = true

        proj.arrangement = [0, 1, 2, 2, 3]
        return proj
    }

    private static func makeLoFi() -> SongProject {
        var proj = SongProject.blank()
        proj.title = "Midnight Lo-Fi"
        proj.bpm = 88
        proj.rootNote = .c
        proj.scale = .minor
        proj.leadTimbre = .bell
        proj.mixer.swing = 0.14
        proj.mixer.reverbWet = 0.34
        proj.mixer.delayWet = 0.22

        // Section A: Intro (Chords + soft hats)
        proj.sections[0].drums = makeDrums(
            kick: [0, 10],
            snare: [],
            hatClosed: [0, 2, 4, 6, 8, 10, 12, 14]
        )
        proj.sections[0].chords = [0, nil, nil, nil, nil, nil, nil, nil, 5, nil, nil, nil, 3, nil, nil, nil]
        proj.sections[0].bass = [0, nil, nil, nil, nil, nil, nil, nil, 5, nil, nil, nil, 3, nil, nil, nil]

        // Section B: Verse
        proj.sections[1].drums = makeDrums(
            kick: [0, 7, 10],
            snare: [4, 12],
            hatClosed: [0, 2, 4, 6, 8, 10, 12, 14],
            hatOpen: [14],
            perc: [3, 15]
        )
        proj.sections[1].chords = [0, nil, nil, nil, nil, nil, nil, nil, 5, nil, nil, nil, 3, nil, nil, nil]
        proj.sections[1].bass = [0, nil, 0, nil, nil, nil, 2, nil, 5, nil, nil, nil, 3, nil, 4, nil]
        proj.sections[1].lead = [4, nil, nil, 2, nil, nil, 4, nil, 7, nil, nil, 5, nil, nil, 4, nil]

        // Section C: Chorus
        proj.sections[2].drums = makeDrums(
            kick: [0, 3, 7, 10, 14],
            snare: [4, 12],
            clap: [4, 12],
            hatClosed: [0, 2, 4, 6, 8, 10, 12, 14],
            hatOpen: [6, 14],
            perc: [2, 11]
        )
        proj.sections[2].chords = [0, nil, nil, nil, 4, nil, nil, nil, 5, nil, nil, nil, 3, nil, nil, nil]
        proj.sections[2].bass = [0, nil, 0, nil, 4, nil, nil, nil, 5, nil, 5, nil, 3, nil, 4, nil]
        proj.sections[2].lead = [7, nil, 6, nil, 4, nil, 2, nil, 5, nil, 4, nil, 2, nil, 0, nil]

        // Section D: Drop / Bridge
        proj.sections[3].drums = makeDrums(
            kick: [0, 6, 10],
            snare: [4, 12],
            hatClosed: [0, 2, 4, 6, 8, 10, 12, 14],
            perc: [5, 9, 13]
        )
        proj.sections[3].chords = [3, nil, nil, nil, nil, nil, nil, nil, 4, nil, nil, nil, nil, nil, nil, nil]
        proj.sections[3].bass = [3, nil, nil, 3, nil, nil, 2, nil, 4, nil, nil, 4, nil, nil, 2, nil]
        proj.sections[3].lead = [2, nil, 4, nil, 5, nil, 7, nil, 6, nil, 4, nil, 2, nil, nil, nil]

        proj.arrangement = [0, 1, 2, 2, 3, 2]
        return proj
    }

    private static func makeSynthwave() -> SongProject {
        var proj = SongProject.blank()
        proj.title = "Neon Synthwave"
        proj.bpm = 116
        proj.rootNote = .a
        proj.scale = .minor
        proj.leadTimbre = .retroSquare
        proj.mixer.reverbWet = 0.30
        proj.mixer.delayWet = 0.25

        proj.sections[0].drums = makeDrums(
            kick: [0, 4, 8, 12],
            hatClosed: [2, 6, 10, 14]
        )
        proj.sections[0].chords = [0, nil, nil, nil, nil, nil, nil, nil, 5, nil, nil, nil, nil, nil, nil, nil]
        proj.sections[0].bass = [0, 0, 0, 0, 0, 0, 0, 0, 5, 5, 5, 5, 5, 5, 5, 5]

        proj.sections[1].drums = makeDrums(
            kick: [0, 4, 8, 12],
            snare: [4, 12],
            clap: [4, 12],
            hatClosed: [0, 2, 4, 6, 8, 10, 12, 14],
            hatOpen: [14]
        )
        proj.sections[1].chords = [0, nil, nil, nil, 5, nil, nil, nil, 2, nil, nil, nil, 4, nil, nil, nil]
        proj.sections[1].bass = [0, 0, 0, 0, 5, 5, 5, 5, 2, 2, 2, 2, 4, 4, 4, 4]
        proj.sections[1].lead = [4, nil, 4, nil, 5, nil, 4, nil, 2, nil, nil, nil, 4, nil, 2, nil]

        proj.sections[2].drums = makeDrums(
            kick: [0, 4, 8, 12],
            snare: [4, 12],
            clap: [4, 12],
            hatClosed: [1, 2, 3, 5, 6, 7, 9, 10, 11, 13, 14, 15],
            hatOpen: [6, 14],
            perc: [3, 11]
        )
        proj.sections[2].chords = [0, nil, nil, nil, 5, nil, nil, nil, 2, nil, nil, nil, 6, nil, nil, nil]
        proj.sections[2].bass = [0, 0, 7, 0, 5, 5, 5, 5, 2, 2, 2, 2, 6, 6, 4, 4]
        proj.sections[2].lead = [7, nil, 6, nil, 4, nil, 2, nil, 4, nil, 5, nil, 6, nil, 4, nil]

        proj.sections[3] = proj.sections[2]
        proj.sections[3].id = 3
        proj.sections[3].label = "D • Drop"
        proj.sections[3].lead = [7, nil, 7, 6, 4, nil, 4, 5, 7, nil, 6, nil, 4, nil, 2, nil]

        proj.arrangement = [0, 1, 2, 3, 2]
        return proj
    }

    private static func makeTrap() -> SongProject {
        var proj = SongProject.blank()
        proj.title = "808 Trap Bounce"
        proj.bpm = 138
        proj.rootNote = .fSharp
        proj.scale = .phrygian
        proj.leadTimbre = .pluck
        proj.mixer.reverbWet = 0.22
        proj.mixer.delayWet = 0.20

        proj.sections[0].drums = makeDrums(
            kick: [0, 10],
            clap: [8],
            hatClosed: [0, 2, 4, 6, 8, 10, 12, 14]
        )
        proj.sections[0].bass = [0, nil, nil, nil, nil, nil, nil, nil, nil, nil, 0, nil, 1, nil, nil, nil]
        proj.sections[0].lead = [0, nil, 1, nil, 4, nil, 1, nil, 0, nil, 1, nil, 4, nil, 5, nil]

        proj.sections[1].drums = makeDrums(
            kick: [0, 3, 10, 14],
            snare: [8],
            clap: [8],
            hatClosed: [0, 2, 4, 5, 6, 8, 10, 12, 13, 14, 15],
            hatOpen: [6],
            perc: [11]
        )
        proj.sections[1].bass = [0, nil, nil, 0, nil, nil, nil, nil, nil, nil, 0, nil, nil, nil, 1, nil]
        proj.sections[1].chords = [0, nil, nil, nil, nil, nil, nil, nil, 1, nil, nil, nil, nil, nil, nil, nil]
        proj.sections[1].lead = [4, nil, 5, nil, 4, nil, 1, nil, 0, nil, 1, nil, 4, nil, nil, nil]

        proj.sections[2].drums = makeDrums(
            kick: [0, 3, 6, 10, 14],
            snare: [8],
            clap: [8],
            hatClosed: [0, 1, 2, 4, 5, 6, 8, 9, 10, 12, 13, 14, 15],
            hatOpen: [4, 12],
            perc: [7, 15]
        )
        proj.sections[2].bass = [0, nil, nil, 0, nil, nil, 3, nil, nil, nil, 0, nil, nil, nil, 1, nil]
        proj.sections[2].chords = [0, nil, nil, nil, nil, nil, nil, nil, 1, nil, nil, nil, 4, nil, nil, nil]
        proj.sections[2].lead = [7, nil, 5, nil, 4, nil, 1, nil, 4, nil, 5, nil, 7, nil, 4, nil]

        proj.sections[3] = proj.sections[2]
        proj.sections[3].id = 3
        proj.sections[3].label = "D • Drop"
        proj.arrangement = [0, 1, 2, 3, 2]
        return proj
    }

    private static func makeHouse() -> SongProject {
        var proj = SongProject.blank()
        proj.title = "Deep House"
        proj.bpm = 124
        proj.rootNote = .d
        proj.scale = .dorian
        proj.leadTimbre = .warmLead
        proj.mixer.swing = 0.08
        proj.mixer.reverbWet = 0.28
        proj.mixer.delayWet = 0.18

        proj.sections[0].drums = makeDrums(
            kick: [0, 4, 8, 12],
            hatClosed: [2, 6, 10, 14],
            perc: [7, 15]
        )
        proj.sections[0].chords = [0, nil, nil, 0, nil, nil, 3, nil, nil, nil, 2, nil, nil, nil, nil, nil]

        proj.sections[1].drums = makeDrums(
            kick: [0, 4, 8, 12],
            clap: [4, 12],
            hatClosed: [0, 2, 4, 6, 8, 10, 12, 14],
            hatOpen: [2, 6, 10, 14],
            perc: [3, 11]
        )
        proj.sections[1].chords = [0, nil, nil, 0, nil, nil, 3, nil, nil, nil, 2, nil, nil, nil, 4, nil]
        proj.sections[1].bass = [0, nil, 0, nil, nil, 0, 3, nil, 2, nil, nil, 2, nil, nil, 4, nil]
        proj.sections[1].lead = [4, nil, nil, 2, nil, nil, 4, nil, 5, nil, nil, 4, nil, nil, 2, nil]

        proj.sections[2] = proj.sections[1]
        proj.sections[2].id = 2
        proj.sections[2].label = "C • Chorus"
        proj.sections[2].lead = [7, nil, 6, nil, 4, nil, 5, nil, 7, nil, 6, nil, 4, nil, 2, nil]

        proj.sections[3] = proj.sections[2]
        proj.sections[3].id = 3
        proj.sections[3].label = "D • Drop"
        proj.arrangement = [0, 1, 2, 3, 2]
        return proj
    }
}

struct BundledSadSample: Identifiable {
    let id: String
    let title: String
    let fileKey: String

    static let all: [BundledSadSample] = [
        BundledSadSample(id: "angel_pad", title: "Angel Pad (Грустный пэд)", fileKey: "angel_pad"),
        BundledSadSample(id: "bell_harmonics", title: "Bell Harmonics (Колокольчик)", fileKey: "bell_harmonics"),
        BundledSadSample(id: "ambient_wind", title: "Ambient Wind (Ветер/Фон)", fileKey: "ambient_wind"),
        BundledSadSample(id: "reverb_kick", title: "Reverb Kick (Глубокий кик)", fileKey: "reverb_kick"),
        BundledSadSample(id: "lofi_kick", title: "Lo-Fi Kick (Тёплый)", fileKey: "lofi_kick"),
        BundledSadSample(id: "lofi_snare", title: "Lo-Fi Snare (Тёплый)", fileKey: "lofi_snare"),
        BundledSadSample(id: "lofi_hat", title: "Lo-Fi Hat (Мягкий)", fileKey: "lofi_hat"),
        BundledSadSample(id: "808_sub_kick", title: "808 Sub Kick (Глубокий)", fileKey: "808_sub_kick"),
        BundledSadSample(id: "808_snare", title: "808 Snare (Мягкий)", fileKey: "808_snare"),
        BundledSadSample(id: "808_hat", title: "808 Hat (Чёткий)", fileKey: "808_hat")
    ]
}
