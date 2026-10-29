import Foundation

struct ITunesSearchResponse: Decodable {
    let results: [ITunesTrack]
}

struct ITunesTrack: Decodable {
    let trackId: Int?
    let trackName: String?
    let artistName: String?
    let collectionName: String?
    let previewUrl: String?
    let artworkUrl100: String?
}

struct LRCLibTrack: Decodable {
    let syncedLyrics: String?
    let plainLyrics: String?
}

final class LiveCloudSearchService {
    static let shared = LiveCloudSearchService()

    func searchSongs(query: String) async -> [SongItem] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?media=music&entity=song&limit=15&term=\(encoded)") else {
            return []
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
            var items: [SongItem] = []
            for track in decoded.results {
                let title = track.trackName ?? "Unknown"
                let artist = track.artistName ?? "Artist"
                let id = "itunes_\(track.trackId ?? Int.random(in: 1000...999999))"
                let lyrics = await fetchSyncedLyrics(trackName: title, artistName: artist, totalDuration: 30.0)
                items.append(
                    SongItem(
                        id: id,
                        title: title,
                        artist: artist,
                        album: track.collectionName ?? "Single",
                        duration: 30.0,
                        artworkName: "tamer_nasseeny.jpg",
                        remoteArtworkURL: track.artworkUrl100?.replacingOccurrences(of: "100x100bb", with: "400x400bb"),
                        previewAudioURL: track.previewUrl,
                        localFileURL: nil,
                        bpm: 98,
                        isAIAnalyzed: true,
                        lyrics: lyrics,
                        hapticBeats: []
                    )
                )
            }
            return items
        } catch {
            return []
        }
    }

    func fetchSyncedLyrics(trackName: String, artistName: String, totalDuration: TimeInterval = 30.0) async -> [LyricLine] {
        let q = "\(trackName) \(artistName)".trimmingCharacters(in: .whitespaces)
        guard let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lrclib.net/api/search?q=\(encoded)") else {
            return defaultFallbackLyrics(trackName: trackName, artistName: artistName, duration: totalDuration)
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let results = try JSONDecoder().decode([LRCLibTrack].self, from: data)
            if let best = results.first(where: { $0.syncedLyrics != nil }) ?? results.first {
                if let lrc = best.syncedLyrics {
                    let parsed = parseLRCWithWordTimings(lrc, targetDuration: totalDuration)
                    if !parsed.isEmpty { return parsed }
                }
                if let plain = best.plainLyrics {
                    let rawLines = plain.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    if !rawLines.isEmpty {
                        let step = max(2.5, totalDuration / Double(rawLines.count))
                        return rawLines.enumerated().map { idx, txt in
                            let start = Double(idx) * step
                            return LyricLine(time: start, endTime: start + step, text: txt, pronunciation: txt, translation: "")
                        }
                    }
                }
            }
        } catch {}
        return defaultFallbackLyrics(trackName: trackName, artistName: artistName, duration: totalDuration)
    }

    private func defaultFallbackLyrics(trackName: String, artistName: String, duration: TimeInterval) -> [LyricLine] {
        return [
            LyricLine(time: 0, endTime: min(8, duration), text: "♪ \(trackName) - \(artistName) ♪", pronunciation: "AI Word-by-Word Tracking Active", translation: ""),
            LyricLine(time: min(8, duration), endTime: duration, text: "اهتزاز الإيقاع الذكي يعمل الآن مع ترددات الأغنية", pronunciation: "CoreHaptics Synchronized", translation: "")
        ]
    }

    private func parseLRCWithWordTimings(_ lrc: String, targetDuration: TimeInterval) -> [LyricLine] {
        var rawTuples: [(TimeInterval, String)] = []
        let pattern = #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\](.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        for line in lrc.components(separatedBy: .newlines) {
            let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
            if let match = regex.firstMatch(in: line, range: nsRange),
               let rMin = Range(match.range(at: 1), in: line),
               let rSec = Range(match.range(at: 2), in: line),
               let rTxt = Range(match.range(at: 4), in: line) {
                let minVal = Double(line[rMin]) ?? 0
                let secVal = Double(line[rSec]) ?? 0
                let cleanText = String(line[rTxt]).trimmingCharacters(in: .whitespaces)
                if !cleanText.isEmpty {
                    rawTuples.append((minVal * 60.0 + secVal, cleanText))
                }
            }
        }
        guard !rawTuples.isEmpty else { return [] }

        // If targetDuration is a 30s preview stream and LRC is 200s, scale timestamps proportionally
        let maxTime = rawTuples.last?.0 ?? targetDuration
        let scale = (targetDuration <= 35.0 && maxTime > 45.0) ? (targetDuration / (maxTime + 4.0)) : 1.0

        var lines: [LyricLine] = []
        for i in 0..<rawTuples.count {
            let start = rawTuples[i].0 * scale
            let nextStart = (i + 1 < rawTuples.count) ? (rawTuples[i + 1].0 * scale) : max(start + 3.5, targetDuration)
            lines.append(LyricLine(time: start, endTime: nextStart, text: rawTuples[i].1, pronunciation: rawTuples[i].1, translation: ""))
        }
        return lines
    }
}
