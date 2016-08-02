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

class RootViewController: UIViewController {
    
    @IBOutlet weak var resultsView: UITextView!
    @IBOutlet weak var startStopButton: UIButton!
    @IBOutlet weak var albumImageView: UIImageView!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var albumLabel: UILabel!
    @IBOutlet weak var trackLabel: UILabel!
    @IBOutlet weak var playPauseButton: UIButton!
    
    private enum VoiceRecognitionService {
        case Google
        case Hound
    }
    
    private let houndVoiceSearch = HoundVoiceSearch.instance()
    private let googleVoiceSearch = GoogleSpeech.sharedInstance()
    private var listening = false
    private var recognitionService = VoiceRecognitionService.Hound
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
        
        if self.recognitionService == .Hound {
            if sender.currentTitle == startButtonTitle {
                self.startHound()
            } else {
                self.stopHound()
            }
        } else {
            if sender.currentTitle == startButtonTitle {
                self.startGoogleSpeech()
            } else {
                self.stopGoogleSpeech()
            }
        }
    }
    
    @IBAction func recognizerTypeChanged(sender: UISegmentedControl) {
        
        if self.startStopButton.currentTitle == "Stop" {
            self.startStopPressed(self.startStopButton) //stop current recorder if present
            self.resultsView.text = ""
        }
        
        if sender.selectedSegmentIndex == 0 {
            self.recognitionService = .Hound
        } else {
            self.recognitionService = .Google
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
                }
            }
        }
    }
    
    private func songSearchTermInTranscription(transcription: String) -> String? {
        let matches = transcription.regexMatches("of is(.+?)is that right")
        return matches.first
    }
}

//MARK: - Houndify

extension RootViewController {
    private func startHound() {
        self.houndVoiceSearch.enableEndOfSpeechDetection = false
        self.houndVoiceSearch.enableSpeech = false
        self.houndVoiceSearch.enableHotPhraseDetection = false
        self.startStopButton.setTitle("Stop", forState: .Normal)
        self.resultsView.text = ""
        self.fullTranscription = ""
        self.houndVoiceSearch.startListeningWithCompletionHandler({ [weak self] (error) in
            
        if let strongSelf = self {
            if (error != nil) {
                
            } else {
                strongSelf.listening = true
                strongSelf.houndVoiceSearch.startSearchWithRequestInfo([NSObject : AnyObject](), endPointURL: NSURL(string: "https://api.houndify.com/v1/audio"), responseHandler: { [weak self] (error, responseType, response, dictionary) in
                    
                    if let strongSelf = self {
                        
                        Async.main {
                            
                            if nil == error {
                                if responseType == .PartialTranscription  {
                                    if let partialTranscript = response as? HoundDataPartialTranscript {
                                        if partialTranscript.partialTranscript.length > 0 {
                                            strongSelf.handleTranscription(partialTranscript.partialTranscript)
                                        }
                                    }
                                } else if responseType == .HoundServer {
                                    if let houndServer = response as? HoundDataHoundServer {
                                        
                                        let commandResult = JSON(houndServer.allResults.firstObject()["NativeData"])
                                        if let finalTranscript = commandResult["FormattedTranscription"].string {
                                            strongSelf.handleTranscription(finalTranscript, isFinal: true)
                                        }
                                    }
                                    
                                    strongSelf.stopHound()
                                }
                            } else {
                                //An error occured so handle appropriately
                                strongSelf.stopHound()
                            }
                        }
                    }
                    })
                }
            }
        })
    }
    
    private func stopHound() {
        self.startStopButton.setTitle("Start", forState: .Normal)
        self.listening = false
        self.houndVoiceSearch.stopListeningWithCompletionHandler({ (error) in
        })
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
