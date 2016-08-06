//
//  AudioPlayer.swift
//  Decibel
//
//  Created by Bryce Hammond on 8/4/16.
//  Copyright © 2016 Fluidvision Design. All rights reserved.
//

import UIKit
import AVFoundation

enum PlaybackState: Int, CustomStringConvertible {
    case Stopped = 0
    case Playing
    case Paused
    case Failed
    
    var description: String {
        get {
            switch self {
            case Stopped:
                return "Stopped"
            case Playing:
                return "Playing"
            case Failed:
                return "Failed"
            case Paused:
                return "Paused"
            }
        }
    }
}

enum BufferingState: Int, CustomStringConvertible {
    case Unknown = 0
    case Ready
    case Delayed
    
    var description: String {
        get {
            switch self {
            case Unknown:
                return "Unknown"
            case Ready:
                return "Ready"
            case Delayed:
                return "Delayed"
            }
        }
    }
}

protocol AudioPlayerDelegate: class {
    func playerReady(player: AudioPlayer)
    func playerPlaybackStateDidChange(player: AudioPlayer)
    func playerBufferingStateDidChange(player: AudioPlayer)
    
    func playerPlaybackWillStartFromBeginning(player: AudioPlayer)
    func playerPlaybackDidEnd(player: AudioPlayer)
}

// KVO contexts

private var PlayerObserverContext = 0
private var PlayerItemObserverContext = 0

// KVO player keys

private let PlayerTracksKey = "tracks"
private let PlayerPlayableKey = "playable"
private let PlayerDurationKey = "duration"
private let PlayerRateKey = "rate"

// KVO player item keys

private let PlayerStatusKey = "status"
private let PlayerEmptyBufferKey = "playbackBufferEmpty"
private let PlayerKeepUp = "playbackLikelyToKeepUp"


class AudioPlayer: NSObject {
    
    weak var delegate: AudioPlayerDelegate!
    
    func setUrl(url: NSURL) {
        // Make sure everything is reset beforehand
        if(self.playbackState == .Playing){
            self.pause()
        }
        
        self.setupPlayerItem(nil)
        let asset = AVURLAsset(URL: url, options: .None)
        self.setupAsset(asset)
    }
    
    
    var muted: Bool! {
        get {
            return self.player.muted
        }
        set {
            self.player.muted = newValue
        }
    }
    
    var playbackLoops: Bool! {
        get {
            return (self.player.actionAtItemEnd == .None) as Bool
        }
        set {
            if newValue.boolValue {
                self.player.actionAtItemEnd = .None
            } else {
                self.player.actionAtItemEnd = .Pause
            }
        }
    }
    var playbackFreezesAtEnd: Bool!
    var playbackState: PlaybackState!
    var bufferingState: BufferingState!
    
    var maximumDuration: NSTimeInterval! {
        get {
            if let playerItem = self.playerItem {
                return CMTimeGetSeconds(playerItem.duration)
            } else {
                return CMTimeGetSeconds(kCMTimeIndefinite)
            }
        }
    }
    
    var currentTime: NSTimeInterval! {
        get {
            if let playerItem = self.playerItem {
                return CMTimeGetSeconds(playerItem.currentTime())
            } else {
                return CMTimeGetSeconds(kCMTimeIndefinite)
            }
        }
    }
    
    private var asset: AVAsset!
    private var playerItem: AVPlayerItem?
    
    private var player: AVPlayer!
    
    // MARK: object lifecycle
    
    override init() {
        super.init()
        self.player = AVPlayer()
        self.player.actionAtItemEnd = .Pause
        self.player.addObserver(self, forKeyPath: PlayerRateKey, options: ([NSKeyValueObservingOptions.New, NSKeyValueObservingOptions.Old]) , context: &PlayerObserverContext)

        self.playbackLoops = false
        self.playbackFreezesAtEnd = false
        self.playbackState = .Stopped
        self.bufferingState = .Unknown
    }

    deinit {
        self.delegate = nil
        
        NSNotificationCenter.defaultCenter().removeObserver(self)
        
        self.player.removeObserver(self, forKeyPath: PlayerRateKey, context: &PlayerObserverContext)
        
        self.player.pause()
        
        self.setupPlayerItem(nil)
    }
    
    
    // MARK: methods
    
    func playFromBeginning() {
        self.delegate?.playerPlaybackWillStartFromBeginning(self)
        self.player.seekToTime(kCMTimeZero)
        self.playFromCurrentTime()
    }
    
    func playFromCurrentTime() {
        self.playbackState = .Playing
        self.delegate?.playerPlaybackStateDidChange(self)
        self.player.play()
    }
    
    func pause() {
        if self.playbackState != .Playing {
            return
        }
        
        self.player.pause()
        self.playbackState = .Paused
        self.delegate?.playerPlaybackStateDidChange(self)
    }
    
    func stop() {
        if self.playbackState == .Stopped {
            return
        }
        
        self.player.pause()
        self.playbackState = .Stopped
        self.delegate?.playerPlaybackStateDidChange(self)
        self.delegate?.playerPlaybackDidEnd(self)
    }
    
    func seekToTime(time: CMTime) {
        if let playerItem = self.playerItem {
            return playerItem.seekToTime(time)
        }
    }
    
    // MARK: private setup
    
    private func setupAsset(asset: AVAsset) {
        if self.playbackState == .Playing {
            self.pause()
        }
        
        self.bufferingState = .Unknown
        self.delegate?.playerBufferingStateDidChange(self)
        
        self.asset = asset
        if let _ = self.asset {
            self.setupPlayerItem(nil)
        }
        
        let keys: [String] = [PlayerTracksKey, PlayerPlayableKey, PlayerDurationKey]
        
        self.asset.loadValuesAsynchronouslyForKeys(keys, completionHandler: { () -> Void in
            dispatch_sync(dispatch_get_main_queue(), { () -> Void in
                
                for key in keys {
                    var error: NSError?
                    let status = self.asset.statusOfValueForKey(key, error:&error)
                    if status == .Failed {
                        self.playbackState = .Failed
                        self.delegate?.playerPlaybackStateDidChange(self)
                        return
                    }
                }
                
                if self.asset.playable.boolValue == false {
                    self.playbackState = .Failed
                    self.delegate?.playerPlaybackStateDidChange(self)
                    return
                }
                
                let playerItem: AVPlayerItem = AVPlayerItem(asset:self.asset)
                self.setupPlayerItem(playerItem)
                
            })
        })
    }
    
    private func setupPlayerItem(playerItem: AVPlayerItem?) {
        if self.playerItem != nil {
            self.playerItem?.removeObserver(self, forKeyPath: PlayerEmptyBufferKey, context: &PlayerItemObserverContext)
            self.playerItem?.removeObserver(self, forKeyPath: PlayerKeepUp, context: &PlayerItemObserverContext)
            self.playerItem?.removeObserver(self, forKeyPath: PlayerStatusKey, context: &PlayerItemObserverContext)
            
            NSNotificationCenter.defaultCenter().removeObserver(self, name: AVPlayerItemDidPlayToEndTimeNotification, object: self.playerItem)
            NSNotificationCenter.defaultCenter().removeObserver(self, name: AVPlayerItemFailedToPlayToEndTimeNotification, object: self.playerItem)
        }
        
        self.playerItem = playerItem
    
        if self.playerItem != nil {
            self.playerItem?.addObserver(self, forKeyPath: PlayerEmptyBufferKey, options: ([NSKeyValueObservingOptions.New, NSKeyValueObservingOptions.Old]), context: &PlayerItemObserverContext)
            self.playerItem?.addObserver(self, forKeyPath: PlayerKeepUp, options: ([NSKeyValueObservingOptions.New, NSKeyValueObservingOptions.Old]), context: &PlayerItemObserverContext)
            self.playerItem?.addObserver(self, forKeyPath: PlayerStatusKey, options: ([NSKeyValueObservingOptions.New, NSKeyValueObservingOptions.Old]), context: &PlayerItemObserverContext)
            
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(playerItemDidPlayToEndTime(_:)), name: AVPlayerItemDidPlayToEndTimeNotification, object: self.playerItem)
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(playerItemFailedToPlayToEndTime(_:)), name: AVPlayerItemFailedToPlayToEndTimeNotification, object: self.playerItem)
        }
        
        if let item = self.playerItem {
            self.addFadeInOutToPlayerItem(item)
        }
        
        self.player.replaceCurrentItemWithPlayerItem(self.playerItem)
        
        if self.playbackLoops.boolValue == true {
            self.player.actionAtItemEnd = .None
        } else {
            self.player.actionAtItemEnd = .Pause
        }
    }
    
    private func addFadeInOutToPlayerItem(playerItem: AVPlayerItem) {
        
        var allAudioParams = [AVAudioMixInputParameters]()
        for track in playerItem.asset.tracksWithMediaType(AVMediaTypeAudio) {

            let fadeDuration = CMTimeMakeWithSeconds(2, 1)
            let fadeOutStartTime = CMTimeMakeWithSeconds(CMTimeGetSeconds(playerItem.duration) - fadeDuration.seconds , 1)
            let fadeInStartTime = CMTimeMakeWithSeconds(0, 1)
            
            let audioInputParams = AVMutableAudioMixInputParameters(track: track)
            audioInputParams.setVolumeRampFromStartVolume(1.0, toEndVolume: 0, timeRange: CMTimeRangeMake(fadeOutStartTime, fadeDuration))
            audioInputParams.setVolumeRampFromStartVolume(0.0, toEndVolume: 1.0, timeRange: CMTimeRangeMake(fadeInStartTime, fadeDuration))
            allAudioParams.append(audioInputParams)
        }
        
        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = allAudioParams
        playerItem.audioMix = audioMix
    }
    
    // MARK: NSNotifications
    
    func playerItemDidPlayToEndTime(aNotification: NSNotification) {
        if self.playbackLoops.boolValue == true || self.playbackFreezesAtEnd.boolValue == true {
            self.player.seekToTime(kCMTimeZero)
        }
        
        if self.playbackLoops.boolValue == false {
            self.stop()
        }
    }
    
    func playerItemFailedToPlayToEndTime(aNotification: NSNotification) {
        self.playbackState = .Failed
        self.delegate?.playerPlaybackStateDidChange(self)
    }
    
    // MARK: KVO
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        
        switch (keyPath, context) {
        case (.Some(PlayerRateKey), &PlayerObserverContext):
            true
        case (.Some(PlayerStatusKey), &PlayerItemObserverContext):
            let status = (change?[NSKeyValueChangeNewKey] as! NSNumber).integerValue as AVPlayerStatus.RawValue
            if status == AVPlayerStatus.ReadyToPlay.rawValue {
                self.delegate?.playerReady(self)
            }
        case (.Some(PlayerKeepUp), &PlayerItemObserverContext):
            if let item = self.playerItem {
                self.bufferingState = .Ready
                self.delegate?.playerBufferingStateDidChange(self)
                
                if item.playbackLikelyToKeepUp && self.playbackState == .Playing {
                    self.playFromCurrentTime()
                }
            }
            
            let status = (change?[NSKeyValueChangeNewKey] as! NSNumber).integerValue as AVPlayerStatus.RawValue
            
            switch (status) {
            case AVPlayerStatus.Failed.rawValue:
                self.playbackState = PlaybackState.Failed
                self.delegate?.playerPlaybackStateDidChange(self)
            default:
                true
            }
        case (.Some(PlayerEmptyBufferKey), &PlayerItemObserverContext):
            if let item = self.playerItem {
                if item.playbackBufferEmpty {
                    self.bufferingState = .Delayed
                    self.delegate?.playerBufferingStateDidChange(self)
                }
            }
            
            let status = (change?[NSKeyValueChangeNewKey] as! NSNumber).integerValue as AVPlayerStatus.RawValue
            
            switch (status) {
            case AVPlayerStatus.Failed.rawValue:
                self.playbackState = PlaybackState.Failed
                self.delegate?.playerPlaybackStateDidChange(self)
            default:
                true
            }        default:
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
            
        }
        
    }
    
}
