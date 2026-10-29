import Foundation
import AVFoundation
import Speech
import Accelerate

@MainActor
final class AISongAnalyzer: ObservableObject {
    static let shared = AISongAnalyzer()

    @Published var isAnalyzing: Bool = false
    @Published var statusMessage: String = ""
    @Published var progress: Double = 0.0

    /// Analyzes a local audio file using:
    /// 1) Apple's on-device AI SFSpeechRecognizer for word-by-word timestamp extraction
    /// 2) AVAudioFile + Accelerate vDSP for bass/kick transient detection to build a custom CoreHaptics map
    /// 3) LRCLIB fallback/merge for studio lyrics
    func analyzeLocalSong(fileURL: URL, title: String, artist: String) async -> SongItem {
        isAnalyzing = true
        progress = 0.1
        statusMessage = "جاري قراءة الموجات الصوتية واستخراج الإيقاع..."

        let asset = AVURLAsset(url: fileURL)
        let durationSeconds: TimeInterval
        if let cmDur = try? await asset.load(.duration) {
            durationSeconds = max(1.0, CMTimeGetSeconds(cmDur))
        } else {
            durationSeconds = 180.0
        }

        // Step 1: Extract real beat transients & haptic events from the audio waveform using Accelerate vDSP
        let extractedBeats = await Task.detached(priority: .userInitiated) {
            Self.extractHapticBeatsFromWaveform(url: fileURL)
        }.value

        progress = 0.45
        statusMessage = "جاري تحليل كلمات الأغنية كلمة بكلمة بالذكاء الاصطناعي..."

        // Step 2: Try On-Device AI Speech Recognition (Arabic & English) for word-by-word timestamps
        var aiLyrics = await recognizeWordsWithAI(url: fileURL, localeId: "ar-SA")
        if aiLyrics.isEmpty {
            aiLyrics = await recognizeWordsWithAI(url: fileURL, localeId: "en-US")
        }

        progress = 0.80
        statusMessage = "جاري مطابقة الكلمات المتزامنة ودمج خريطة الاهتزاز..."

        // Step 3: If AI speech recognition was blocked or song had heavy instruments, also check LRCLIB and convert to word-by-word
        if aiLyrics.isEmpty {
            aiLyrics = await LiveCloudSearchService.shared.fetchSyncedLyrics(trackName: title, artistName: artist, totalDuration: durationSeconds)
        }

        progress = 1.0
        isAnalyzing = false
        statusMessage = "اكتمل التحليل بالذكاء الاصطناعي بنجاح!"

        return SongItem(
            id: "local_ai_\(UUID().uuidString)",
            title: title,
            artist: artist,
            album: "محلل بالذكاء الاصطناعي (كلمة بكلمة + Haptics)",
            duration: durationSeconds,
            artworkName: "tamer_nasseeny.jpg",
            remoteArtworkURL: nil,
            previewAudioURL: nil,
            localFileURL: fileURL,
            bpm: 98,
            isAIAnalyzed: true,
            lyrics: aiLyrics,
            hapticBeats: extractedBeats
        )
    }

    private func recognizeWordsWithAI(url: URL, localeId: String) async -> [LyricLine] {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authStatus in
                continuation.resume(returning: authStatus)
            }
        }
        guard status == .authorized,
              let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId)),
              recognizer.isAvailable else {
            return []
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false

        return await withCheckedContinuation { continuation in
            var hasResumed = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !hasResumed else { return }
                if let result = result, result.isFinal {
                    hasResumed = true
                    let lines = Self.groupSegmentsIntoLines(segments: result.bestTranscription.segments)
                    continuation.resume(returning: lines)
                } else if error != nil {
                    hasResumed = true
                    continuation.resume(returning: [])
                }
            }
        }
    }

    nonisolated private static func groupSegmentsIntoLines(segments: [SFTranscriptionSegment]) -> [LyricLine] {
        guard !segments.isEmpty else { return [] }
        var lines: [LyricLine] = []
        var currentWords: [WordTiming] = []

        for seg in segments {
            let wordText = seg.substring.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !wordText.isEmpty else { continue }
            let start = seg.timestamp
            let end = seg.timestamp + max(0.2, seg.duration)
            let wt = WordTiming(word: wordText, startTime: start, endTime: end)

            if let last = currentWords.last {
                // Start a new lyric line if pause > 1.2s or word count >= 6
                if (start - last.endTime) > 1.2 || currentWords.count >= 6 {
                    let lineText = currentWords.map { $0.word }.joined(separator: " ")
                    let lineStart = currentWords.first?.startTime ?? 0
                    let lineEnd = currentWords.last?.endTime ?? (lineStart + 3)
                    lines.append(LyricLine(time: lineStart, endTime: lineEnd, text: lineText, words: currentWords))
                    currentWords = [wt]
                } else {
                    currentWords.append(wt)
                }
            } else {
                currentWords.append(wt)
            }
        }

        if !currentWords.isEmpty {
            let lineText = currentWords.map { $0.word }.joined(separator: " ")
            let lineStart = currentWords.first?.startTime ?? 0
            let lineEnd = currentWords.last?.endTime ?? (lineStart + 3)
            lines.append(LyricLine(time: lineStart, endTime: lineEnd, text: lineText, words: currentWords))
        }

        return lines
    }

    nonisolated private static func extractHapticBeatsFromWaveform(url: URL) -> [HapticBeatEvent] {
        guard let audioFile = try? AVAudioFile(forReading: url) else { return [] }
        let format = audioFile.processingFormat
        let sampleRate = format.sampleRate
        let windowSize = AVAudioFrameCount(max(1024, Int(sampleRate * 0.05))) // 50ms windows
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: windowSize) else { return [] }

        var events: [HapticBeatEvent] = []
        var framePosition: AVAudioFramePosition = 0
        var rollingAverage: Float = 0.05
        var lastBeatTime: TimeInterval = -1.0

        while audioFile.framePosition < audioFile.length {
            do {
                try audioFile.read(into: buffer, frameCount: windowSize)
                let frameCount = Int(buffer.frameLength)
                if frameCount == 0 { break }
                if let channelData = buffer.floatChannelData?[0] {
                    var rms: Float = 0
                    vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameCount))
                    let currentTime = Double(framePosition) / sampleRate

                    if rms > rollingAverage * 1.45 && rms > 0.03 && (currentTime - lastBeatTime) >= 0.22 {
                        let normIntensity = min(1.0, max(0.35, rms * 2.8))
                        let sharpness: Float = normIntensity > 0.75 ? 0.85 : 0.50
                        events.append(HapticBeatEvent(time: currentTime, intensity: normIntensity, sharpness: sharpness))
                        lastBeatTime = currentTime
                    }
                    rollingAverage = rollingAverage * 0.90 + rms * 0.10
                }
                framePosition += AVAudioFramePosition(frameCount)
            } catch {
                break
            }
        }
        return events
    }
}
