//
//  ITunesSearch.swift
//  Decibel
//
//  Created by Bryce Hammond on 7/31/16.
//  Copyright © 2016 Fluidvision Design. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

class ITunesSearch {

    static let sharedInstance = ITunesSearch()
    
    func findSongWithSearchTerm(term: String, completion: ((ITunesSearchResult?) -> Void)) {
        
        //Get the first song matching the search request from iTunes API
        Alamofire.request(.GET, "https://itunes.apple.com/search",
                          parameters: ["term" : term, "entity" : "song", "limit" : 1])
                .responseJSON { response in
                    if let value = response.result.value {
                        let iTunesResponse = JSON(value)
                        if let results = iTunesResponse["results"].array,
                            let firstResult = results.first {
            
                             completion(ITunesSearchResult(iTunesResponse: firstResult))
                        } else {
                            completion(nil)
                        }
                    } else {
                        completion(nil)
                    }
                }
    }
}

