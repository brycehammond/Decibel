//
//  ViewController.swift
//  Decibel
//
//  Created by Bryce Hammond on 7/30/16.
//  Copyright © 2016 Fluidvision Design. All rights reserved.
//

import UIKit
import Async
import SwiftyJSON
import AVFoundation
import SDWebImage
import MediaPlayer

class RootViewController: UIViewController {
    
    @IBOutlet weak var resultsView: UITextView!
    @IBOutlet weak var startStopButton: UIButton!
    @IBOutlet weak var albumImageView: UIImageView!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var albumLabel: UILabel!
    @IBOutlet weak var trackLabel: UILabel!
    @IBOutlet weak var playPauseButton: UIButton!
    
    private let googleVoiceSearch = GoogleSpeech.sharedInstance()
    private var audioPlayer: AudioPlayer?
    private var listening = false
    private var fullTranscription = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
        
        self.artistLabel.text = ""
        self.albumLabel.text = ""
        self.trackLabel.text = ""
        self.playPauseButton.hidden = true
    }
    
    //MARK: - IBAction
    
    @IBAction func startStopPressed(sender: UIButton) {
        
        let startButtonTitle = "Start"
        if sender.currentTitle == startButtonTitle {
            self.startGoogleSpeech()
        } else {
            self.stopGoogleSpeech()
        }
    }
    
    @IBAction func playPausePressed(sender: UIButton) {
        self.playPause()
    }
    
    @objc func playPause() {
        let playButtonTitle = "Play"
        if self.playPauseButton.currentTitle == playButtonTitle {
            self.play()
        } else {
            self.pause()
        }
    }
    
    @objc func play() {
        self.audioPlayer?.playFromCurrentTime()
        self.playPauseButton.setTitle("Pause", forState: .Normal)
    }
    
    @objc func pause() {
        self.audioPlayer?.pause()
        self.playPauseButton.setTitle("Play", forState: .Normal)
    }
    
    @objc func stop() {
        self.audioPlayer?.stop()
        
    }
    
    //MARK: - Audio Handling
    
    private func loadSongForPlayback(song: ITunesSearchResult) {
        
        if let previewLocation = song.previewURL, let previewURL = NSURL(string: previewLocation) {
            self.stopGoogleSpeech()
            self.stop()
            self.audioPlayer = AudioPlayer()
            self.audioPlayer?.delegate = self
            self.audioPlayer?.setUrl(previewURL)
            self.playPauseButton.hidden = false
        }
    }
    
    //MARK: - Transcription Handling
    
    private func handleTranscription(transcription: String, isFinal: Bool = false) {
        let updatedTranscription = self.fullTranscription + " " + transcription
        self.resultsView.text = updatedTranscription
        if isFinal {
            self.fullTranscription = updatedTranscription
        }
        
        if let searchTerm = self.songSearchTermInTranscription(self.fullTranscription) {
            ITunesSearch.sharedInstance.findSongWithSearchTerm(searchTerm) { result in
                if let song = result {
                    self.albumLabel.text = song.albumName
                    self.trackLabel.text = song.trackName
                    self.artistLabel.text = song.artist
                    if let artworkURL = song.artworkURL, let albumImageURL = NSURL(string: artworkURL) {
                        self.albumImageView.sd_setImageWithURL(albumImageURL)
                    }
                    self.loadSongForPlayback(song)
                }
            }
        }
    }
    
    private func songSearchTermInTranscription(transcription: String) -> String? {
        let matches = transcription.regexMatches("of is(.+?)(about|is that) right")
        return matches.first
    }
}

//MARK: - Remote Control Events

extension RootViewController {
    
    func registerRemoteHandlers() {
        let commandCenter = MPRemoteCommandCenter.sharedCommandCenter()
        
        commandCenter.playCommand.addTarget(self, action: #selector(play))
        commandCenter.stopCommand.addTarget(self, action: #selector(stop))
        commandCenter.pauseCommand.addTarget(self, action: #selector(pause))
        commandCenter.togglePlayPauseCommand.addTarget(self, action: #selector(playPause))
        
        //Disable all the commands we don't support
        commandCenter.nextTrackCommand.enabled = false
        commandCenter.previousTrackCommand.enabled = false
        commandCenter.bookmarkCommand.enabled = false
        commandCenter.changePlaybackRateCommand.enabled = false
        commandCenter.seekForwardCommand.enabled = false
        commandCenter.seekBackwardCommand.enabled = false
        commandCenter.skipForwardCommand.enabled = false
        commandCenter.skipBackwardCommand.enabled = false
        commandCenter.ratingCommand.enabled = false
        commandCenter.likeCommand.enabled = false
        commandCenter.dislikeCommand.enabled = false
        
    }
    
}

//MARK: - Google Speech

extension RootViewController : GoogleSpeechDelegate {
    private func startGoogleSpeech() {
        self.startStopButton.setTitle("Stop", forState: .Normal)
        self.resultsView.text = ""
        self.fullTranscription = ""
        self.googleVoiceSearch.delegate = self
        self.googleVoiceSearch.startRecording()
    }
    
    private func stopGoogleSpeech() {
        self.startStopButton.setTitle("Start", forState: .Normal)
        self.googleVoiceSearch.stopRecording()
    }

    func googleSpeechDidReceiveTranscript(transcript: String, isFinal: Bool) {
        self.handleTranscription(transcript, isFinal: isFinal)
    }
    
}

//MARK: - AudioPlayerDelegate

extension RootViewController : AudioPlayerDelegate {
    func playerReady(player: AudioPlayer) {
        self.playPauseButton.hidden = false
        
        //Play then pause audio player so we become current playing app
        player.playFromBeginning()
        player.pause()
    }
    
    func playerPlaybackStateDidChange(player: AudioPlayer) {
        if player.playbackState == .Stopped {
            player.seekToTime(kCMTimeZero)
            self.playPauseButton.setTitle("Play", forState: .Normal)
        }
    }
    
    func playerBufferingStateDidChange(player: AudioPlayer) {
        
    }
    
    func playerPlaybackWillStartFromBeginning(player: AudioPlayer) {
        
    }
    
    func playerPlaybackDidEnd(player: AudioPlayer) {
        player.seekToTime(kCMTimeZero)
        self.playPauseButton.setTitle("Play", forState: .Normal)
    }
}
