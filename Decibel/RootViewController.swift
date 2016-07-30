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

class RootViewController: UIViewController {
    
    @IBOutlet weak var resultsView: UITextView!
    @IBOutlet weak var startStopButton: UIButton!
    
    let voiceSearch: HoundVoiceSearch = HoundVoiceSearch.instance()
    var listening = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    //MARK: - IBAction
    
    @IBAction func startStopPressed(sender: UIButton) {
        if sender.currentTitle == "Start" {
            self.startHound()
        } else {
            self.stopHound()
        }
    }
    
    //MARK: - Transcription Handling
    
    func handleTranscription(transcription: String) {
        self.resultsView.text = transcription
    }
}

//MARK: - Houndify

extension RootViewController {
    private func startHound() {
        self.voiceSearch.enableEndOfSpeechDetection = false
        self.voiceSearch.enableSpeech = false
        self.voiceSearch.enableHotPhraseDetection = false
        self.startStopButton.setTitle("Stop", forState: .Normal)
        self.voiceSearch.startListeningWithCompletionHandler({ [weak self] (error) in
            
            if let strongSelf = self {
                if (error != nil) {
                    
                } else {
                    strongSelf.listening = true
                    strongSelf.voiceSearch.startSearchWithRequestInfo([NSObject : AnyObject](), endPointURL: NSURL(string: "https://api.houndify.com/v1/audio"), responseHandler: { [weak self] (error, responseType, response, dictionary) in
                        
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
                                                strongSelf.handleTranscription(finalTranscript)
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
        self.voiceSearch.stopListeningWithCompletionHandler({ (error) in
        })
    }
}