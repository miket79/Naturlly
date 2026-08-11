//
//  AudioPlayerManager.swift
//  Naturlly TTS
//
//  Manages audio playback
//

// Lock screen and Control Center playback controls are supported via MPRemoteCommandCenter and MPNowPlayingInfoCenter.
// Ensure Background Audio is enabled in your app capabilities for these controls to work while locked or in background.

import Foundation
import AVFoundation
import Combine
import MediaPlayer
import os

class AudioPlayerManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var nowPlayingTitle: String = ""
    
    // Queue management for precaching multiple clips
    struct QueuedItem: Codable {
        enum Source: String, Codable { case data, fileURL }
        let source: Source
        let title: String
        let dataBase64: String?
        let filePath: String?

        static func fromData(_ data: Data, title: String) -> QueuedItem {
            return QueuedItem(source: .data, title: title, dataBase64: data.base64EncodedString(), filePath: nil)
        }
        static func fromFileURL(_ url: URL, title: String) -> QueuedItem {
            return QueuedItem(source: .fileURL, title: title, dataBase64: nil, filePath: url.path)
        }
        func materializeData() -> Data? {
            switch source {
            case .data:
                if let b64 = dataBase64 { return Data(base64Encoded: b64) }
                return nil
            case .fileURL:
                if let path = filePath { return try? Data(contentsOf: URL(fileURLWithPath: path)) }
                return nil
            }
        }
    }
    private var queue: [QueuedItem] = []
    private var currentIndex: Int = 0
    private var nextAudioData: Data?
    private var nextTitle: String = ""

    private let queueStorageKey = "AudioPlayerManager.queue"
    private let indexStorageKey = "AudioPlayerManager.currentIndex"
    private let timeStorageKey = "AudioPlayerManager.currentTime"
    
    // Callback cuando termina de reproducir
    var onAudioFinished: (() -> Void)?
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var lastNowPlayingUpdateAt: TimeInterval = 0
    private var lastPositionPersistAt: TimeInterval = 0
    private let logger = Logger(subsystem: "com.naturlly.tts", category: "audio")
    
    override init() {
        super.init()
        setupAudioSession()
        setupNowPlayingAndRemoteCommands()
        loadPersistedQueue()
    }
    
    private func setupNowPlayingAndRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        center.stopCommand.addTarget { [weak self] _ in
            self?.stop()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if self.isPlaying { self.pause() } else { self.resume() }
            return .success
        }
        // Add skip forward/backward support for lock screen and Control Center
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { [weak self] event in
            self?.skipForward(seconds: 15)
            return .success
        }
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] event in
            self?.skipBackward(seconds: 15)
            return .success
        }
        
        // Agregar soporte para cambiar de pista (siguiente/anterior)
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.skipToNext()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.skipToPrevious()
            return .success
        }
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Configurar para reproducción en segundo plano y pantalla bloqueada
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowAirPlay])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            logger.info("Audio session configured for background playback")
        } catch {
            logger.error("Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    // Preload audio without starting playback
    func prepare(data: Data, title: String = "") throws {
        stop()
        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        duration = audioPlayer?.duration ?? 0
        currentTime = 0
        isPlaying = false
        nowPlayingTitle = title
        updateNowPlayingInfo()
    }
    
    // Queue APIs
    func enqueue(data: Data, title: String = "") {
        let item = QueuedItem.fromData(data, title: title)
        queue.append(item)
        if audioPlayer == nil && queue.count == 1 {
            try? prepare(data: data, title: title)
            currentIndex = 0
        }
        savePersistedQueue()
    }

    func enqueue(fileURL: URL, title: String = "") {
        let item = QueuedItem.fromFileURL(fileURL, title: title)
        queue.append(item)
        if audioPlayer == nil && queue.count == 1, let d = item.materializeData() {
            try? prepare(data: d, title: title)
            currentIndex = 0
        }
        savePersistedQueue()
    }

    func clearQueue() {
        queue.removeAll()
        currentIndex = 0
        nextAudioData = nil
        nextTitle = ""
        savePersistedQueue()
    }

    // Start playback from current prepared item or the first in queue
    func playQueue() {
        if audioPlayer == nil, currentIndex < queue.count {
            if let d = queue[currentIndex].materializeData() {
                try? prepare(data: d, title: queue[currentIndex].title)
            }
        }
        resume()
        savePersistedQueue()
    }
    
    func playAudio(data: Data) throws {
        // Stop current playback if any
        stop()
        
        // Create audio player
        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        
        duration = audioPlayer?.duration ?? 0
        
        // Start playback
        audioPlayer?.play()
        isPlaying = true
        
        updateNowPlayingInfo()
        
        // Start timer to update progress
        startTimer()
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
        updateNowPlayingInfo()
    }

    // Pause and persist current state (queue, index, time)
    func pauseAndPersist() {
        pause()
        savePersistedQueue()
    }

    func resume() {
        audioPlayer?.play()
        isPlaying = true
        startTimer()
        updateNowPlayingInfo()
    }

    // Resume from persisted state (reloads queue if needed and resumes playback)
    func resumeFromPersisted() {
        if audioPlayer == nil, currentIndex < queue.count, let d = queue[currentIndex].materializeData() {
            try? prepare(data: d, title: queue[currentIndex].title)
            let t = UserDefaults.standard.double(forKey: timeStorageKey)
            seek(to: t)
        }
        resume()
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        stopTimer()
        updateNowPlayingInfo()
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
        savePlaybackPosition()
    }

    func skipForward(seconds: TimeInterval = 15) {
        guard let player = audioPlayer else { return }
        let newTime = min(player.currentTime + seconds, player.duration)
        player.currentTime = newTime
        currentTime = newTime
        savePlaybackPosition()
    }

    func skipBackward(seconds: TimeInterval = 15) {
        guard let player = audioPlayer else { return }
        let newTime = max(player.currentTime - seconds, 0)
        player.currentTime = newTime
        currentTime = newTime
        savePlaybackPosition()
    }
    
    func skipToNext() {
        guard !queue.isEmpty else { return }
        let nextIdx = currentIndex + 1
        if nextIdx < queue.count {
            currentIndex = nextIdx
            if let d = queue[currentIndex].materializeData() {
                try? prepare(data: d, title: queue[currentIndex].title)
                resume()
                savePersistedQueue()
            }
        }
    }
    
    func skipToPrevious() {
        guard !queue.isEmpty else { return }
        // Si estamos cerca del inicio (menos de 3 segundos), ir a la pista anterior
        if currentTime < 3.0 && currentIndex > 0 {
            currentIndex -= 1
            if let d = queue[currentIndex].materializeData() {
                try? prepare(data: d, title: queue[currentIndex].title)
                resume()
                savePersistedQueue()
            }
        } else {
            // Si no, reiniciar la pista actual
            seek(to: 0)
        }
    }
    
    // Prepare the next item shortly before current ends
    private func prepareNextIfNeeded() {
        guard nextAudioData == nil else { return }
        guard let player = audioPlayer else { return }
        let remaining = player.duration - player.currentTime
        let nextIdx = currentIndex + 1
        if remaining <= 0.5, nextIdx < queue.count {
            let next = queue[nextIdx]
            nextAudioData = next.materializeData()
            nextTitle = next.title
        }
    }

    // Advance to next queued item when current finishes
    private func advanceToNextIfAvailable() {
        guard !queue.isEmpty else { stop(); return }
        currentIndex += 1
        if currentIndex < queue.count {
            if let nextData = nextAudioData {
                try? prepare(data: nextData, title: nextTitle)
                nextAudioData = nil
                nextTitle = ""
                resume()
            } else if let d = queue[currentIndex].materializeData() {
                try? prepare(data: d, title: queue[currentIndex].title)
                resume()
            }
        } else {
            stop()
        }
        savePersistedQueue()
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
            self.prepareNextIfNeeded()

            let now = Date().timeIntervalSince1970
            if now - self.lastNowPlayingUpdateAt >= 0.5 {
                self.updateNowPlayingInfo()
                self.lastNowPlayingUpdateAt = now
            }

            if now - self.lastPositionPersistAt >= 1.0 {
                self.savePlaybackPosition()
                self.lastPositionPersistAt = now
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateNowPlayingInfo() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: nowPlayingTitle.isEmpty ? "Naturlly TTS" : nowPlayingTitle,
            MPMediaItemPropertyArtist: "Naturlly"
        ]
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        // Agregar información de posición en la cola si hay múltiples items
        if queue.count > 1 {
            info[MPNowPlayingInfoPropertyPlaybackQueueIndex] = currentIndex
            info[MPNowPlayingInfoPropertyPlaybackQueueCount] = queue.count
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func savePersistedQueue() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(queue) {
            UserDefaults.standard.set(data, forKey: queueStorageKey)
            UserDefaults.standard.set(currentIndex, forKey: indexStorageKey)
            UserDefaults.standard.set(currentTime, forKey: timeStorageKey)
        }
    }

    private func savePlaybackPosition() {
        UserDefaults.standard.set(currentIndex, forKey: indexStorageKey)
        UserDefaults.standard.set(currentTime, forKey: timeStorageKey)
    }

    private func loadPersistedQueue() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: queueStorageKey),
           let decoded = try? JSONDecoder().decode([QueuedItem].self, from: data) {
            queue = decoded
            currentIndex = defaults.integer(forKey: indexStorageKey)
            let persistedTime = defaults.double(forKey: timeStorageKey)
            // Prime current item if available
            if currentIndex < queue.count {
                if let d = queue[currentIndex].materializeData() {
                    try? prepare(data: d, title: queue[currentIndex].title)
                    seek(to: persistedTime)
                }
            }
        }
    }
}

extension AudioPlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentTime = 0
        stopTimer()
        
        // Auto-advance in queue if available
        advanceToNextIfAvailable()
        
        // Llamar al callback si existe
        if flag {
            onAudioFinished?()
        }
    }
}


