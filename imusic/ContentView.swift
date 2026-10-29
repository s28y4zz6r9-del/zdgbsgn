import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var engine: AudioHapticEngine
    @ObservedObject var aiAnalyzer = AISongAnalyzer.shared
    @State private var selectedTab: Int = 1
    @State private var showNowPlayingSheet: Bool = false
    @State private var showFileImporter: Bool = false
    @State private var searchText: String = ""
    @State private var cloudResults: [SongItem] = []
    @State private var isSearchingCloud: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                // TAB 0: HOME
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack {
                                Text("Home")
                                    .font(.system(size: 34, weight: .bold))
                                Spacer()
                                aiImportButton
                            }
                            .padding(.horizontal)

                            if aiAnalyzer.isAnalyzing {
                                aiProgressCard
                            }

                            ForEach(engine.songs) { song in
                                SongRowView(song: song) {
                                    engine.selectSong(song)
                                    showNowPlayingSheet = true
                                }
                            }
                        }
                        .padding(.bottom, 130)
                    }
                }
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

                // TAB 1: NEW
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack {
                                Text("New")
                                    .font(.system(size: 34, weight: .bold))
                                Spacer()
                                aiImportButton
                            }
                            .padding(.horizontal)

                            if aiAnalyzer.isAnalyzing {
                                aiProgressCard
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("AI WORD-BY-WORD LYRICS & COREHAPTICS")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.blue)
                                Text("استورد أي أغنية من ملفات الأيفون أو ابحث عنها ليقوم الذكاء الاصطناعي باستخراج الكلمات كلمة بكلمة مع اهتزاز الإيقاع.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)

                            Text("Best New Songs")
                                .font(.title2.weight(.bold))
                                .padding(.horizontal)

                            ForEach(engine.songs) { song in
                                SongRowView(song: song) {
                                    engine.selectSong(song)
                                    showNowPlayingSheet = true
                                }
                            }
                        }
                        .padding(.bottom, 130)
                    }
                }
                .tabItem { Label("New", systemImage: "square.grid.2x2.fill") }
                .tag(1)

                // TAB 2: RADIO
                NavigationStack {
                    VStack(spacing: 20) {
                        Text("iMusic AI Haptic Radio")
                            .font(.title.weight(.bold))
                        aiImportButton
                    }
                }
                .tabItem { Label("Radio", systemImage: "dot.radiowaves.left.and.right") }
                .tag(2)

                // TAB 3: LIBRARY
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Library")
                                    .font(.system(size: 34, weight: .bold))
                                Spacer()
                                aiImportButton
                            }
                            .padding(.horizontal)

                            if aiAnalyzer.isAnalyzing {
                                aiProgressCard
                            }

                            ForEach(engine.songs) { song in
                                SongRowView(song: song) {
                                    engine.selectSong(song)
                                    showNowPlayingSheet = true
                                }
                            }
                        }
                        .padding(.bottom, 130)
                    }
                }
                .tabItem { Label("Library", systemImage: "music.note.list") }
                .tag(3)

                // TAB 4: SEARCH
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Search")
                                .font(.system(size: 34, weight: .bold))
                                .padding(.horizontal)

                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField("ابحث عن أي أغنية أو مطرب...", text: $searchText)
                                    .onSubmit {
                                        triggerCloudSearch()
                                    }
                                if !searchText.isEmpty {
                                    Button {
                                        searchText = ""
                                        cloudResults = []
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(12)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.horizontal)
                            .onChange(of: searchText) { _, _ in
                                triggerCloudSearch()
                            }

                            if isSearchingCloud {
                                HStack(spacing: 10) {
                                    ProgressView()
                                    Text("جاري البحث وجلب الكلمات المتزامنة كلمة بكلمة...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal)
                            }

                            ForEach(displayedSearchSongs) { song in
                                SongRowView(song: song) {
                                    engine.addAndSelectSong(song)
                                    showNowPlayingSheet = true
                                }
                            }
                        }
                        .padding(.bottom, 130)
                    }
                }
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(4)
            }
            .tint(.blue)

            // Floating MiniPlayer
            Button {
                showNowPlayingSheet = true
            } label: {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .overlay(Image(systemName: "waveform").foregroundStyle(.white))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(engine.currentSong.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(engine.currentSong.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        engine.togglePlayPause()
                    } label: {
                        Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 6)
                    Button {
                        engine.nextTrack()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.horizontal, 12)
                .padding(.bottom, 56)
            }
            .buttonStyle(.plain)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.audio, .mp3, .mpeg4Audio, .wav],
            allowsMultipleSelection: false
        ) { result in
            handleImportedAudio(result)
        }
        .fullScreenCover(isPresented: $showNowPlayingSheet) {
            NowPlayingView()
                .environmentObject(engine)
        }
    }

    private var aiImportButton: some View {
        Button {
            showFileImporter = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                Text("تحليل أغنية محلية بـ AI")
                    .font(.caption.weight(.bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue, in: Capsule())
            .foregroundStyle(.white)
        }
    }

    private var aiProgressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ProgressView()
                Text(aiAnalyzer.statusMessage)
                    .font(.caption.weight(.semibold))
            }
            ProgressView(value: aiAnalyzer.progress)
                .tint(.blue)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var displayedSearchSongs: [SongItem] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return engine.songs
        }
        let q = searchText.lowercased()
        let localMatches = engine.songs.filter {
            $0.title.lowercased().contains(q) || $0.artist.lowercased().contains(q)
        }
        return localMatches + cloudResults
    }

    private func triggerCloudSearch() {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else {
            cloudResults = []
            return
        }
        isSearchingCloud = true
        Task {
            let res = await LiveCloudSearchService.shared.searchSongs(query: q)
            await MainActor.run {
                self.cloudResults = res
                self.isSearchingCloud = false
            }
        }
    }

    private func handleImportedAudio(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let pickedURL = urls.first else { return }
        let secured = pickedURL.startAccessingSecurityScopedResource()
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destURL = docsDir.appendingPathComponent(pickedURL.lastPathComponent)
        try? FileManager.default.removeItem(at: destURL)
        try? FileManager.default.copyItem(at: pickedURL, to: destURL)
        if secured { pickedURL.stopAccessingSecurityScopedResource() }

        let cleanTitle = pickedURL.deletingPathExtension().lastPathComponent
        Task {
            let analyzedSong = await aiAnalyzer.analyzeLocalSong(fileURL: destURL, title: cleanTitle, artist: "أغنية محلية (AI Synced)")
            engine.addAndSelectSong(analyzedSong)
            showNowPlayingSheet = true
        }
    }
}

struct SongRowView: View {
    let song: SongItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.28))
                    .frame(width: 54, height: 54)
                    .overlay(
                        Image(systemName: song.localFileURL != nil ? "sparkles.tv.fill" : "music.note")
                            .foregroundStyle(.white)
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("Song · \(song.artist)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
