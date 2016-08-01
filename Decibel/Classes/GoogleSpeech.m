//
//  GoogleSpeech.m
//  Decibel
//
//  Created by Bryce Hammond on 7/31/16.
//  Copyright © 2016 Fluidvision Design. All rights reserved.
//

#import "GoogleSpeech.h"
#import "SpeechRecognitionService.h"
#import "AudioController.h"

#define SAMPLE_RATE 16000.0f

@interface GoogleSpeech() <AudioControllerDelegate>

@property (nonatomic, strong) NSMutableData *audioData;

@end

@implementation GoogleSpeech

+ (instancetype) sharedInstance {
    static GoogleSpeech *instance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        instance = [[GoogleSpeech alloc] init];
    });
    
    return instance;
}

- (void)startRecording
{
    self.audioData = [[NSMutableData alloc] init];
    [[AudioController sharedInstance] prepareWithSampleRate:SAMPLE_RATE];
    [AudioController sharedInstance].delegate = self;
    [[SpeechRecognitionService sharedInstance] setSampleRate:SAMPLE_RATE];
    [[AudioController sharedInstance] start];
}

- (void)stopRecording
{
    [[AudioController sharedInstance] stop];
    [[SpeechRecognitionService sharedInstance] stopStreaming];
}

- (void) processSampleData:(NSData *)data
{
    [self.audioData appendData:data];
    NSInteger frameCount = [data length] / 2;
    int16_t *samples = (int16_t *) [data bytes];
    int64_t sum = 0;
    for (int i = 0; i < frameCount; i++) {
        sum += abs(samples[i]);
    }
    //NSLog(@"audio %d %d", (int) frameCount, (int) (sum * 1.0 / frameCount));
    
    // We recommend sending samples in 100ms chunks
    int chunk_size = 0.1 /* seconds/chunk */ * SAMPLE_RATE * 2 /* bytes/sample */ ; /* bytes/chunk */
    
    if ([self.audioData length] > chunk_size) {
        NSLog(@"SENDING");
        [[SpeechRecognitionService sharedInstance] streamAudioData:self.audioData
                                                    withCompletion:^(StreamingRecognizeResponse *response, NSError *error) {
                                                        if (response) {
                                                            BOOL finished = NO;
                                                            NSLog(@"RESPONSE RECEIVED");
                                                            if (error) {
                                                                NSLog(@"ERROR: %@", error);
                                                            } else {
                                                                NSLog(@"RESPONSE: %@", response);
                                                                for (StreamingRecognitionResult *result in response.resultsArray) {
                                                                    if (result.isFinal) {
                                                                        finished = YES;
                                                                    }
                                                                }
                                                                
                                                                [self.delegate googleSpeechDidReceiveTranscript:@"" isFinal:finished];
                                                            }
                                                        }
                                                    }];
        self.audioData = [[NSMutableData alloc] init];
    }
}

@end
