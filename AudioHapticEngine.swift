import Foundation
import AVFoundation
import CoreHaptics
import MediaPlayer

@MainActor
final class AudioHapticEngine: ObservableObject {
    @Published var songs: [SongItem]
    @Published var currentSong: SongItem
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var volume: Float = 0.85
    @Published var isShuffle: Bool = false
    @Published var repeatMode: Int = 0
    @Published var isAutoplayInfinity: Bool = true
    @Published var isAutoMixEnabled: Bool = true
    @Published var isMusicHapticsEnabled: Bool = true
    @Published var isLyricsMode: Bool = true
    @Published var showPronunciation: Bool = false
    @Published var isSingMicEnabled: Bool = false
    @Published var beatIntensity: CGFloat = 0.0

    private var hapticEngine: CHHapticEngine?
    private var timer: Timer?
    private var player: AVPlayer?
    private var lastTriggeredBeatIndex: Int = -1

    init() {
        let initial = MusicCatalog.shared.builtInSongs
        self.songs = initial
        self.currentSong = initial[0]
        setupAudioSession()
        setupCoreHaptics()
        setupRemoteTransportControls()
        Task {
            await resolveBuiltInStreams()
        }
    }

    private func resolveBuiltInStreams() async {
        for idx in songs.indices {
            if songs[idx].previewAudioURL == nil && songs[idx].localFileURL == nil {
                let query = "\(songs[idx].artist) \(songs[idx].title)"
                let results = await LiveCloudSearchService.shared.searchSongs(query: query)
                if let first = results.first, let preview = first.previewAudioURL {
                    songs[idx].previewAudioURL = preview
                    if currentSong.id == songs[idx].id {
                        currentSong.previewAudioURL = preview
                    }
                }
            }
        }
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            print("AVAudioSession error: \(error)")
        }
    }

    private func setupCoreHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            hapticEngine?.resetHandler = { [weak self] in
                try? self?.hapticEngine?.start()
            }
        } catch {
            print("CoreHaptics error: \(error)")
        }
    }

    func triggerBeatHaptic(intensity: Float, sharpness: Float) {
        guard isMusicHapticsEnabled else { return }
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics, let engine = hapticEngine {
            let iParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
            let sParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            let transient = CHHapticEvent(eventType: .hapticTransient, parameters: [iParam, sParam], relativeTime: 0)
            let continuous = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * 0.65),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness * 0.45)
                ],
                relativeTime: 0.015,
                duration: 0.11
            )
            if let pattern = try? CHHapticPattern(events: [transient, continuous], parameters: []),
               let player = try? engine.makePlayer(with: pattern) {
                try? player.start(atTime: 0)
                return
            }
        }
        let generator = UIImpactFeedbackGenerator(style: intensity > 0.7 ? .heavy : .medium)
        generator.impactOccurred(intensity: CGFloat(intensity))
    }

    func addAndSelectSong(_ song: SongItem) {
        if !songs.contains(where: { $0.id == song.id }) {
            songs.insert(song, at: 0)
        }
        selectSong(song)
    }

    func selectSong(_ song: SongItem) {
        currentSong = song
        currentTime = 0
        lastTriggeredBeatIndex = -1

        if let localURL = song.localFileURL {
            player = AVPlayer(url: localURL)
            player?.volume = volume
            play()
        } else if let urlStr = song.previewAudioURL, let url = URL(string: urlStr) {
            player = AVPlayer(url: url)
            player?.volume = volume
            play()
        } else {
            Task {
                let found = await LiveCloudSearchService.shared.searchSongs(query: "\(song.artist) \(song.title)")
                if let match = found.first, let urlStr = match.previewAudioURL, let url = URL(string: urlStr) {
                    self.currentSong.previewAudioURL = urlStr
                    self.player = AVPlayer(url: url)
                    self.player?.volume = self.volume
                    self.play()
                }
            }
        }
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func play() {
        isPlaying = true
        player?.play()
        startHighPrecisionSyncTimer()
        updateNowPlayingInfo()
    }

    func pause() {
        isPlaying = false
        player?.pause()
        timer?.invalidate()
        beatIntensity = 0
        updateNowPlayingInfo()
    }

    func seek(to time: TimeInterval) {
        currentTime = max(0, min(time, currentSong.duration))
        lastTriggeredBeatIndex = -1
        player?.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600))
        triggerBeatHaptic(intensity: 0.7, sharpness: 0.75)
        updateNowPlayingInfo()
    }

    func nextTrack() {
        guard !songs.isEmpty else { return }
        if let idx = songs.firstIndex(where: { $0.id == currentSong.id }) {
            let nextIdx = (idx + 1) % songs.count
            selectSong(songs[nextIdx])
        } else {
            selectSong(songs[0])
        }
    }

    func previousTrack() {
        if currentTime > 4 {
            seek(to: 0)
            return
        }
        guard !songs.isEmpty else { return }
        if let idx = songs.firstIndex(where: { $0.id == currentSong.id }) {
            let prevIdx = (idx - 1 + songs.count) % songs.count
            selectSong(songs[prevIdx])
        }
    }

    private func startHighPrecisionSyncTimer() {
        timer?.invalidate()
        let beatPeriod = 60.0 / max(60.0, currentSong.bpm)
        // 30ms high-precision loop for smooth word-by-word karaoke highlighting & AI beat haptics
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isPlaying else { return }
                if let p = self.player {
                    let sec = CMTimeGetSeconds(p.currentTime())
                    if sec.isFinite && sec >= 0 {
                        self.currentTime = sec
                    }
                    if let itemDur = p.currentItem?.duration {
                        let d = CMTimeGetSeconds(itemDur)
                        if d.isFinite && d > 1 {
                            self.currentSong.duration = d
                        }
                    }
                } else {
                    self.currentTime += 0.03
                }

                if self.currentTime >= self.currentSong.duration - 0.15 {
                    self.nextTrack()
                    return
                }

                // 1) If song has AI-extracted waveform haptic beats, trigger exact waveform beats!
                if !self.currentSong.hapticBeats.isEmpty {
                    if let beatIdx = self.currentSong.hapticBeats.firstIndex(where: { abs($0.time - self.currentTime) < 0.035 }),
                       beatIdx != self.lastTriggeredBeatIndex {
                        self.lastTriggeredBeatIndex = beatIdx
                        let ev = self.currentSong.hapticBeats[beatIdx]
                        self.beatIntensity = CGFloat(ev.intensity)
                        self.triggerBeatHaptic(intensity: ev.intensity, sharpness: ev.sharpness)
                    } else {
                        self.beatIntensity = max(0.0, self.beatIntensity * 0.82)
                    }
                } else {
                    // 2) Rhythmic BPM beat sync
                    let phase = self.currentTime.truncatingRemainder(dividingBy: beatPeriod) / beatPeriod
                    if phase < 0.07 {
                        let isStrong = Int(self.currentTime / beatPeriod) % 2 == 0
                        self.beatIntensity = isStrong ? 1.0 : 0.65
                        self.triggerBeatHaptic(intensity: isStrong ? 0.90 : 0.62, sharpness: isStrong ? 0.80 : 0.50)
                    } else {
                        self.beatIntensity = max(0.0, self.beatIntensity * 0.82)
                    }
                }
            }
        }
    }

    private func setupRemoteTransportControls() {
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        cc.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        cc.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.nextTrack() }
            return .success
        }
        cc.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previousTrack() }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentSong.title,
            MPMediaItemPropertyArtist: currentSong.artist,
            MPMediaItemPropertyAlbumTitle: currentSong.album,
            MPMediaItemPropertyPlaybackDuration: currentSong.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
