import Foundation
import SwiftUI

// MARK: - Musical Scales & Keys

enum NoteName: Int, CaseIterable, Codable, Identifiable {
    case c = 0, cSharp, d, dSharp, e, f, fSharp, g, gSharp, a, aSharp, b

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .c: return "C"
        case .cSharp: return "C#"
        case .d: return "D"
        case .dSharp: return "D#"
        case .e: return "E"
        case .f: return "F"
        case .fSharp: return "F#"
        case .g: return "G"
        case .gSharp: return "G#"
        case .a: return "A"
        case .aSharp: return "A#"
        case .b: return "B"
        }
    }
}

enum MusicalScale: String, CaseIterable, Codable, Identifiable {
    case minor = "Minor"
    case major = "Major"
    case minorPentatonic = "Pentatonic"
    case dorian = "Dorian"
    case phrygian = "Phrygian"

    var id: String { rawValue }

    var intervals: [Int] {
        switch self {
        case .minor: return [0, 2, 3, 5, 7, 8, 10]
        case .major: return [0, 2, 4, 5, 7, 9, 11]
        case .minorPentatonic: return [0, 3, 5, 7, 10, 12, 15]
        case .dorian: return [0, 2, 3, 5, 7, 9, 10]
        case .phrygian: return [0, 1, 3, 5, 7, 8, 10]
        }
    }

    /// Returns MIDI note number for a given scale degree (0..7) and base octave.
    func midiNote(degree: Int, root: NoteName, octave: Int) -> Int {
        let base = (octave + 1) * 12 + root.rawValue
        let len = intervals.count
        let octShift = degree / len
        let idx = ((degree % len) + len) % len
        return base + intervals[idx] + octShift * 12
    }

    /// Returns a 3-note triad MIDI array for a given scale degree (0..6).
    func chordMidiNotes(degree: Int, root: NoteName, octave: Int) -> [Int] {
        [
            midiNote(degree: degree, root: root, octave: octave),
            midiNote(degree: degree + 2, root: root, octave: octave),
            midiNote(degree: degree + 4, root: root, octave: octave)
        ]
    }
}

// MARK: - Drum Lanes

enum DrumLane: Int, CaseIterable, Codable, Identifiable {
    case kick = 0
    case snare
    case clap
    case hihatClosed
    case hihatOpen
    case perc

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .kick: return "Kick"
        case .snare: return "Snare"
        case .clap: return "Clap"
        case .hihatClosed: return "Hat CL"
        case .hihatOpen: return "Hat OP"
        case .perc: return "Perc"
        }
    }

    var color: Color {
        switch self {
        case .kick: return Color(red: 1.0, green: 0.25, blue: 0.45)
        case .snare: return Color(red: 1.0, green: 0.62, blue: 0.18)
        case .clap: return Color(red: 0.98, green: 0.82, blue: 0.22)
        case .hihatClosed: return Color(red: 0.0, green: 0.96, blue: 0.83)
        case .hihatOpen: return Color(red: 0.25, green: 0.72, blue: 1.0)
        case .perc: return Color(red: 0.68, green: 0.38, blue: 1.0)
        }
    }
}

// MARK: - Synth Timbres

enum LeadTimbre: String, CaseIterable, Codable, Identifiable {
    case pluck = "Pluck"
    case warmLead = "Warm Lead"
    case retroSquare = "Retro"
    case bell = "Bell"

    var id: String { rawValue }
}

// MARK: - Custom Sample Slot

struct CustomSampleSlot: Codable, Identifiable {
    let id: Int
    var name: String
    var fileName: String? // Stored in Documents/Samples/
    var volume: Float
    var pitchSemitones: Float // -12...12
    var reverbSend: Float
    var isMuted: Bool

    static func defaults() -> [CustomSampleSlot] {
        (0..<4).map { idx in
            CustomSampleSlot(
                id: idx,
                name: "Звук \(idx + 1)",
                fileName: nil,
                volume: 0.85,
                pitchSemitones: 0,
                reverbSend: 0.2,
                isMuted: false
            )
        }
    }
}

// MARK: - Pattern Section (16 steps)

struct SongSection: Codable, Identifiable {
    var id: Int // 0=A, 1=B, 2=C, 3=D
    var label: String // "A • Intro", "B • Verse", etc.
    var drums: [[Bool]] // [6 lanes][16 steps]
    var bass: [Int?] // 16 steps: scale degree 0..7 or nil
    var lead: [Int?] // 16 steps: scale degree 0..7 or nil
    var chords: [Int?] // 16 steps: chord degree 0..6 or nil
    var customSamples: [[Bool]] // [4 sample slots][16 steps]

    static func empty(id: Int, label: String) -> SongSection {
        SongSection(
            id: id,
            label: label,
            drums: Array(repeating: Array(repeating: false, count: 16), count: DrumLane.allCases.count),
            bass: Array(repeating: nil, count: 16),
            lead: Array(repeating: nil, count: 16),
            chords: Array(repeating: nil, count: 16),
            customSamples: Array(repeating: Array(repeating: false, count: 16), count: 4)
        )
    }
}

// MARK: - Mixer Settings

struct MixerSettings: Codable {
    var masterVolume: Float = 0.88
    var drumsVolume: Float = 0.90
    var bassVolume: Float = 0.82
    var chordsVolume: Float = 0.72
    var leadVolume: Float = 0.78
    var samplerVolume: Float = 0.85

    var drumsMuted: Bool = false
    var bassMuted: Bool = false
    var chordsMuted: Bool = false
    var leadMuted: Bool = false
    var samplerMuted: Bool = false

    var reverbWet: Float = 0.24
    var delayWet: Float = 0.16
    var swing: Float = 0.0 // 0.0 ... 0.35
}

// MARK: - Full Song Project

struct SongProject: Codable {
    var title: String
    var bpm: Double
    var rootNote: NoteName
    var scale: MusicalScale
    var leadTimbre: LeadTimbre
    var sections: [SongSection] // 4 sections: A, B, C, D
    var arrangement: [Int] // Sequence of section IDs for Song Mode
    var customSamples: [CustomSampleSlot]
    var mixer: MixerSettings

    static func blank() -> SongProject {
        SongProject(
            title: "Новый трек",
            bpm: 118,
            rootNote: .a,
            scale: .minor,
            leadTimbre: .pluck,
            sections: [
                .empty(id: 0, label: "A • Intro"),
                .empty(id: 1, label: "B • Verse"),
                .empty(id: 2, label: "C • Chorus"),
                .empty(id: 3, label: "D • Drop")
            ],
            arrangement: [0, 1, 1, 2, 3, 2],
            customSamples: CustomSampleSlot.defaults(),
            mixer: MixerSettings()
        )
    }
}
