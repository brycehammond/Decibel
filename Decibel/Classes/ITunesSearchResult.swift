//
//  ITunesSearchResult.swift
//  Decibel
//
//  Created by Bryce Hammond on 7/31/16.
//  Copyright © 2016 Fluidvision Design. All rights reserved.
//

import UIKit
import SwiftyJSON

struct ITunesSearchResult {

    var artist = ""
    var artworkURL = ""
    var trackName = ""
    var albumName = ""
    var previewURL = ""
    
    init(iTunesResponse: JSON) {
        if let artist = iTunesResponse["artistName"].string {
            self.artist = artist
        }
        
        if let artworkURL = iTunesResponse["artworkUrl100"].string {
            self.artworkURL = artworkURL
        }
        
        if let trackName = iTunesResponse["trackName"].string {
            self.trackName = trackName
        }
        
        if let albumName = iTunesResponse["collectionName"].string {
            self.albumName = albumName
        }
        
        if let previewURL = iTunesResponse["previewUrl"].string {
            self.previewURL = previewURL
        }
    }
    
}
