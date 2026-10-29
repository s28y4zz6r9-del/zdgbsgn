import Foundation

struct WordTiming: Identifiable, Codable, Equatable {
    var id = UUID()
    let word: String
    let startTime: TimeInterval
    let endTime: TimeInterval
}

struct HapticBeatEvent: Identifiable, Codable, Equatable {
    var id = UUID()
    let time: TimeInterval
    let intensity: Float
    let sharpness: Float
}

struct LyricLine: Identifiable, Codable, Equatable {
    var id = UUID()
    let time: TimeInterval
    let endTime: TimeInterval
    let text: String
    let pronunciation: String
    let translation: String
    var words: [WordTiming]

    init(time: TimeInterval, endTime: TimeInterval? = nil, text: String, pronunciation: String = "", translation: String = "", words: [WordTiming]? = nil) {
        self.time = time
        let computedEnd = endTime ?? (time + 4.5)
        self.endTime = computedEnd
        self.text = text
        self.pronunciation = pronunciation
        self.translation = translation
        if let providedWords = words, !providedWords.isEmpty {
            self.words = providedWords
        } else {
            self.words = LyricLine.generateWordTimings(text: text, start: time, end: computedEnd)
        }
    }

    static func generateWordTimings(text: String, start: TimeInterval, end: TimeInterval) -> [WordTiming] {
        let parts = text.split(separator: " ").map(String.init)
        guard !parts.isEmpty else { return [] }
        let totalDuration = max(0.6, end - start)
        let step = totalDuration / Double(parts.count)
        return parts.enumerated().map { idx, w in
            let wStart = start + Double(idx) * step
            let wEnd = wStart + step
            return WordTiming(word: w, startTime: wStart, endTime: wEnd)
        }
    }
}

struct SongItem: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let artist: String
    let album: String
    var duration: TimeInterval
    let artworkName: String
    let remoteArtworkURL: String?
    var previewAudioURL: String?
    var localFileURL: URL?
    let bpm: Double
    var isAIAnalyzed: Bool
    var lyrics: [LyricLine]
    var hapticBeats: [HapticBeatEvent]
}

final class MusicCatalog {
    static let shared = MusicCatalog()

    var builtInSongs: [SongItem] = [
        SongItem(
            id: "nasseeny_leih",
            title: "Nasseeny Leih",
            artist: "Tamer Hosny",
            album: "Eish Besho'ak",
            duration: 30,
            artworkName: "tamer_nasseeny.jpg",
            remoteArtworkURL: nil,
            previewAudioURL: nil,
            localFileURL: nil,
            bpm: 96,
            isAIAnalyzed: true,
            lyrics: [
                LyricLine(time: 0.0, endTime: 3.5, text: "أنا مقدرش أبعد ثانية", pronunciation: "Ana ma'darsh ab'ed sanya", translation: "I cannot stay away for a second"),
                LyricLine(time: 3.5, endTime: 7.0, text: "أنا بعدك مليش في الدنيا", pronunciation: "Ana ba'dak maleesh fel donya", translation: "Without you I have nothing in this world"),
                LyricLine(time: 7.0, endTime: 10.5, text: "يا أول حب عاش قلبي معاه", pronunciation: "Ya awwal hob 'ash 'albi ma'ah", translation: "O first love my heart ever lived with"),
                LyricLine(time: 10.5, endTime: 14.0, text: "الأيام بقت مش هي", pronunciation: "El-ayyam ba'et mesh heya", translation: "The days are no longer the same"),
                LyricLine(time: 14.0, endTime: 17.5, text: "ياريت ترجع وحشت عينيا", pronunciation: "Yareet terga' wahasht 'einaya", translation: "I wish you'd return, my eyes miss you"),
                LyricLine(time: 17.5, endTime: 21.5, text: "حياتي في بعدك انت مش حياة", pronunciation: "Hayati fi bo'dak enta mesh hayah", translation: "My life away from you is not a life"),
                LyricLine(time: 21.5, endTime: 25.5, text: "ناسيني ليه؟ بتتعب قلبي وياك", pronunciation: "Nasseeny leih? Betet'eb 'albi wayyak", translation: "Why have you forgotten me? You tire my heart"),
                LyricLine(time: 25.5, endTime: 30.0, text: "ده ميهونش أبداً عليا أنساك", pronunciation: "Da mayhoonsh abadan 'alaya ansak", translation: "I could never bear to forget you")
            ],
            hapticBeats: []
        ),
        SongItem(
            id: "fatet_sineen",
            title: "Fatet Sineen",
            artist: "Elissa",
            album: "Bastanak",
            duration: 30,
            artworkName: "elissa_fatet_sineen.jpg",
            remoteArtworkURL: nil,
            previewAudioURL: nil,
            localFileURL: nil,
            bpm: 90,
            isAIAnalyzed: true,
            lyrics: [
                LyricLine(time: 0.0, endTime: 6.0, text: "فاتت سنين وأنا بسمعك ولا عمري جيت على بالك", pronunciation: "Fatet sineen wana basma'ak wala 'omri geet 'ala balak", translation: "Years passed listening to you"),
                LyricLine(time: 6.0, endTime: 12.0, text: "حبيت حنانك ومشتقالك يا حبيبي قرب لي", pronunciation: "Habbeit hananak w moshta'alak ya habibi 'arrab li", translation: "I loved your tenderness and miss you"),
                LyricLine(time: 12.0, endTime: 18.0, text: "لو تعرف إيه بيحصل فيا لما بشوف عينيك", pronunciation: "Law te'raf eih beyehsal feya lamma bashoof 'eineik", translation: "If you knew what happens when I see your eyes"),
                LyricLine(time: 18.0, endTime: 24.0, text: "بنسى الدنيا وبنسى روحي وبهرب مني إليك", pronunciation: "Bansa el-donya w bansa roohi w bahrab menni eleyk", translation: "I forget the world and run to you"),
                LyricLine(time: 24.0, endTime: 30.0, text: "خدني في حضنك خاف عليا حس بيا يا حبيبي", pronunciation: "Khodni fi hodnak khaf 'alaya hess beya ya habibi", translation: "Hold me close and feel my heart")
            ],
            hapticBeats: []
        ),
        SongItem(
            id: "nase_shaklaha",
            title: "Nase Shaklaha",
            artist: "Tamer Ashour",
            album: "Khayali",
            duration: 30,
            artworkName: "tamer_ashour_nase.jpg",
            remoteArtworkURL: nil,
            previewAudioURL: nil,
            localFileURL: nil,
            bpm: 94,
            isAIAnalyzed: true,
            lyrics: [
                LyricLine(time: 0.0, endTime: 7.5, text: "خلاص أنا مش فاكرها أنا حتى ناسي شكلها", pronunciation: "Khalas ana mesh fakerha ana hatta nasi shaklaha", translation: "I don't remember her anymore"),
                LyricLine(time: 7.5, endTime: 15.0, text: "من النهاردة مفيش جراح واللي راح من عمري راح", pronunciation: "Men el-naharda mafeesh gerah welli rah men 'omri rah", translation: "From today no more wounds"),
                LyricLine(time: 15.0, endTime: 22.5, text: "أنا فوقت ليها ولقيتها متستاهلش أزعل عليها", pronunciation: "Ana fo't leeha w la'eitha matestahlsh az'al 'aleiha", translation: "I realized she isn't worth my sorrow"),
                LyricLine(time: 22.5, endTime: 30.0, text: "صفحة واتقفلت في حياتي ومش هرجع تاني ليها", pronunciation: "Safha w et'afalet fi hayati w mesh harga' tani leeha", translation: "A closed chapter in my life")
            ],
            hapticBeats: []
        )
    ]
}
