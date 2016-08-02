//
//  String+Decibel.swift
//  Decibel
//
//  Created by Bryce Hammond on 7/30/16.
//  Copyright © 2016 Fluidvision Design. All rights reserved.
//

import Foundation

extension String {
    
    var length : Int {
        return self.characters.count
    }
    
    func regexMatches(pattern: String) -> [String] {
        let re: NSRegularExpression
        do {
            re = try NSRegularExpression(pattern: pattern, options: [])
        } catch {
            return []
        }
        
        let matches = re.matchesInString(self, options: [], range: NSRange(location: 0, length: self.utf16.count))
        var collectMatches = [String]()
        for match in matches {
            // range at index 0: full match
            // range at index 1: first capture group
            let substring = (self as NSString).substringWithRange(match.rangeAtIndex(1))
            collectMatches.append(substring)
        }
        return collectMatches
    }
    
}