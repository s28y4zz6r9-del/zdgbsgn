import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var engine: AudioHapticEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.25, green: 0.29, blue: 0.34), Color(red: 0.11, green: 0.13, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                // Top Dismiss Bar
                HStack {
                    Button { dismiss() } label: {
                        Text("⌄ رجوع")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.15), in: Capsule())
                    }
                    Spacer()
                    Capsule()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 40, height: 5)
                    Spacer()
                    Text(engine.currentSong.isAIAnalyzed ? "AI Word Sync" : "Synced")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.18), in: Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)

                // Song Header
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 60, height: 60)
                        .overlay(Image(systemName: "waveform.circle.fill").font(.title).foregroundStyle(.white))
                        .scaleEffect(1.0 + engine.beatIntensity * 0.06)
                        .animation(.spring(response: 0.15, dampingFraction: 0.5), value: engine.beatIntensity)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(engine.currentSong.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(engine.currentSong.artist)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 22)

                // WORD-BY-WORD TIME-SYNCED LYRICS SCROLL VIEW
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .trailing, spacing: 20) {
                            ForEach(Array(engine.currentSong.lyrics.enumerated()), id: \.element.id) { index, line in
                                let isActive = isCurrentLine(index: index)
                                VStack(alignment: .trailing, spacing: 6) {
                                    if engine.showPronunciation && !line.pronunciation.isEmpty {
                                        Text(line.pronunciation)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.yellow.opacity(isActive ? 0.9 : 0.35))
                                    }
                                    // Word-by-Word Karaoke Flow
                                    WordByWordLineView(
                                        line: line,
                                        currentTime: engine.currentTime,
                                        isLineActive: isActive
                                    )
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(isActive ? 0.10 : 0.0))
                                )
                                .blur(radius: isActive ? 0 : 1.2)
                                .scaleEffect(isActive ? 1.02 : 0.96, anchor: .trailing)
                                .animation(.easeOut(duration: 0.22), value: isActive)
                                .id(line.id)
                                .onTapGesture {
                                    engine.seek(to: line.time)
                                }
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 16)
                    }
                    .onChange(of: engine.currentTime) { _, _ in
                        if let active = currentActiveLyric() {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(active.id, anchor: .center)
                            }
                        }
                    }
                }

                // Pronunciation & Sing Mic Buttons
                HStack {
                    Button {
                        engine.showPronunciation.toggle()
                    } label: {
                        Image(systemName: "character.bubble.fill")
                            .foregroundStyle(engine.showPronunciation ? .black : .white)
                            .frame(width: 38, height: 38)
                            .background(engine.showPronunciation ? Color.white : Color.white.opacity(0.15), in: Circle())
                    }
                    Spacer()
                    Button {
                        engine.isSingMicEnabled.toggle()
                    } label: {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(engine.isSingMicEnabled ? .black : .white)
                            .frame(width: 38, height: 38)
                            .background(engine.isSingMicEnabled ? Color.white : Color.white.opacity(0.15), in: Circle())
                    }
                }
                .padding(.horizontal, 26)

                // Scrubber + Music Haptics Badge
                VStack(spacing: 6) {
                    Slider(
                        value: Binding(
                            get: { engine.currentTime },
                            set: { engine.seek(to: $0) }
                        ),
                        in: 0...max(1, engine.currentSong.duration)
                    )
                    .tint(.white)

                    HStack {
                        Text(formatTime(engine.currentTime))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.65))
                        Spacer()
                        Button {
                            engine.isMusicHapticsEnabled.toggle()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "water.waves")
                                Text("Music Haptics")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.white.opacity(engine.isMusicHapticsEnabled ? 0.95 : 0.45))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(engine.isMusicHapticsEnabled ? 0.18 : 0.08), in: RoundedRectangle(cornerRadius: 8))
                            .scaleEffect(1.0 + engine.beatIntensity * 0.08)
                        }
                        Spacer()
                        Text("-\(formatTime(max(0, engine.currentSong.duration - engine.currentTime)))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                .padding(.horizontal, 26)

                // Transport Controls
                HStack(spacing: 52) {
                    Button { engine.previousTrack() } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }
                    Button { engine.togglePlayPause() } label: {
                        Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white)
                    }
                    Button { engine.nextTrack() } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.vertical, 4)

                // Volume Slider
                HStack(spacing: 12) {
                    Image(systemName: "speaker.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Slider(value: $engine.volume, in: 0...1)
                        .tint(.white)
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 10)
            }
        }
    }

    private func isCurrentLine(index: Int) -> Bool {
        let lyrics = engine.currentSong.lyrics
        guard index < lyrics.count else { return false }
        let start = lyrics[index].time
        let end = (index + 1 < lyrics.count) ? lyrics[index + 1].time : engine.currentSong.duration
        return engine.currentTime >= start && engine.currentTime < end
    }

    private func currentActiveLyric() -> LyricLine? {
        for i in 0..<engine.currentSong.lyrics.count {
            if isCurrentLine(index: i) {
                return engine.currentSong.lyrics[i]
            }
        }
        return nil
    }

    private func formatTime(_ sec: TimeInterval) -> String {
        let total = Int(max(0, sec))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct WordByWordLineView: View {
    let line: LyricLine
    let currentTime: TimeInterval
    let isLineActive: Bool

    var body: some View {
        // Renders each word with individual opacity and glow based on exact word timestamp!
        let attributed = buildWordHighlightedText()
        Text(attributed)
            .font(.system(size: 26, weight: .bold))
            .multilineTextAlignment(.trailing)
            .environment(\.layoutDirection, .rightToLeft)
    }

    private func buildWordHighlightedText() -> AttributedString {
        var result = AttributedString()
        for (idx, w) in line.words.enumerated() {
            var wordAttr = AttributedString(w.word + (idx < line.words.count - 1 ? " " : ""))
            if !isLineActive {
                wordAttr.foregroundColor = Color.white.opacity(0.28)
            } else if currentTime >= w.endTime {
                // Already sung word in current active line
                wordAttr.foregroundColor = Color.white
            } else if currentTime >= w.startTime && currentTime < w.endTime {
                // Currently singing this exact word right now!
                wordAttr.foregroundColor = Color(red: 1.0, green: 0.92, blue: 0.45)
            } else {
                // Upcoming word in current active line
                wordAttr.foregroundColor = Color.white.opacity(0.45)
            }
            result.append(wordAttr)
        }
        return result
    }
}
