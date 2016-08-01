//
//  GoogleSpeech.h
//  Decibel
//
//  Created by Bryce Hammond on 7/31/16.
//  Copyright © 2016 Fluidvision Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol GoogleSpeechDelegate <NSObject>

- (void)googleSpeechDidReceiveTranscript:(NSString *)transcript isFinal:(BOOL)isFinal;

@end



@interface GoogleSpeech : NSObject

@property (nonatomic, weak) id<GoogleSpeechDelegate> delegate;

+ (instancetype) sharedInstance;

- (void)startRecording;
- (void)stopRecording;

@end
