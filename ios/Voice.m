#import "Voice.h"
#import "RCTConvert.h"


NSString* GetDirectoryOfType_Sound(NSSearchPathDirectory dir) {
    NSArray* paths = NSSearchPathForDirectoriesInDomains(dir, NSUserDomainMask, YES);
    NSString *pathForAudioCacheFiles = [paths.firstObject stringByAppendingString:@"/AudioCacheFiles/"];
    //    [[NSFileManager defaultManager] createDirectoryAtPath:pathForAudioCacheFiles withIntermediateDirectories:YES attributes:nil error:&error];
    BOOL isDir = NO;
    NSError *error;
    if (! [[NSFileManager defaultManager] fileExistsAtPath:pathForAudioCacheFiles isDirectory:&isDir]) {
        [[NSFileManager defaultManager]createDirectoryAtPath:pathForAudioCacheFiles withIntermediateDirectories:YES attributes:nil error:&error];
    }
    NSLog(@"GetDirectoryOfType_Sound Error: %@", error);
    return pathForAudioCacheFiles;
}

@implementation Voice {
    NSNumber *_channel;
}

RCT_EXPORT_MODULE()

- (instancetype)init
{
    self = [super init];
    _recordState.mDataFormat.mSampleRate        = 16000; // 44100;
    _recordState.mDataFormat.mBitsPerChannel    = 16; // 8|16
    _recordState.mDataFormat.mChannelsPerFrame  = 1;
    _recordState.mDataFormat.mBytesPerPacket    = (_recordState.mDataFormat.mBitsPerChannel / 8) * _recordState.mDataFormat.mChannelsPerFrame;
    _recordState.mDataFormat.mBytesPerFrame     = _recordState.mDataFormat.mBytesPerPacket;
    _recordState.mDataFormat.mFramesPerPacket   = 1;
    _recordState.mDataFormat.mReserved          = 0;
    _recordState.mDataFormat.mFormatID          = kAudioFormatLinearPCM;
    _recordState.mDataFormat.mFormatFlags       = _recordState.mDataFormat.mBitsPerChannel == 8 ? kLinearPCMFormatFlagIsPacked : (kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked);
    
    _recordState.bufferByteSize = 2048;
    _recordState.mSelf = self;
    _state = StateNone;
    
    _regex = [NSRegularExpression regularExpressionWithPattern:@"[\\^.?:!,@#\$%&*()_+\\-=\"\\/|\\\\><`~{}\\[\\];]" options:NSRegularExpressionCaseInsensitive error:nil];
    return self;
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_queue_create("RNVoice", DISPATCH_QUEUE_SERIAL);
}

//- (dispatch_queue_t)methodQueue {
//    return dispatch_get_main_queue();
//}


RCT_EXPORT_METHOD(getState:(RCTPromiseResolveBlock)resolve rejecter:(__unused RCTPromiseRejectBlock)reject) {
    resolve(_state);
}

RCT_EXPORT_METHOD(start:(nonnull NSNumber *)channel textToScore:(NSString *)textToScore opts:(NSDictionary *)opts resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    
    if (![_state  isEqual: StateNone]) {
        [self stopRecording];
        [self releaseResouce];
        [self teardown];
    }
    if (!textToScore) {
        reject(@"1", @"Can't score with empty string", nil);
        return;
    }
    _channel = channel;
    @try {
        _configs = opts;
        _textualString = textToScore;
        textToScore = [textToScore stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *modifiedString = [_regex stringByReplacingMatchesInString:textToScore options:0 range:NSMakeRange(0, [textToScore length]) withTemplate:@""];
        _contextualStrings = [modifiedString componentsSeparatedByString: @" "];
        _state = StateRecording;
        
        NSString *fileName = [NSString stringWithFormat:@"%@%@",[[NSProcessInfo processInfo] globallyUniqueString], @".wav"];
        //        NSString *docDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        _filePath = [NSString stringWithFormat:@"%@", [GetDirectoryOfType_Sound(NSCachesDirectory) stringByAppendingString:fileName]];
        
        NSLog(@"_filePath: %@", _filePath);
        // most audio players set session category to "Playback", record won't work in this mode
        // therefore set session category to "Record" before recording
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
        
        _recordState.mIsRunning = true;
        _recordState.mCurrentPacket = 0;
        
        CFURLRef url = CFURLCreateWithString(kCFAllocatorDefault, (CFStringRef)_filePath, NULL);
        AudioFileCreateWithURL(url, kAudioFileWAVEType, &_recordState.mDataFormat, kAudioFileFlags_EraseFile, &_recordState.mAudioFile);
        CFRelease(url);
        
        AudioQueueNewInput(&_recordState.mDataFormat, HandleInputBuffer, &_recordState, NULL, NULL, 0, &_recordState.mQueue);
        for (int i = 0; i < kNumberBuffers; i++) {
            AudioQueueAllocateBuffer(_recordState.mQueue, _recordState.bufferByteSize, &_recordState.mBuffers[i]);
            AudioQueueEnqueueBuffer(_recordState.mQueue, _recordState.mBuffers[i], 0, NULL);
        }
        AudioQueueStart(_recordState.mQueue, NULL);
        
        resolve(@{});
        [self sendEventWithName:@"onModuleStateChange" body:[NSDictionary dictionaryWithObjectsAndKeys: _state,@"state", channel, @"channel", nil]];
        
    }
    @catch (NSException * e) {
        reject(@"-1", e.reason, nil);
        [self handleModuleExeption:e];
    }
}

RCT_EXPORT_METHOD(stop:(nonnull NSNumber *)channel resolve:(RCTPromiseResolveBlock)resolve rejecter:(__unused RCTPromiseRejectBlock)reject) {
    @try {
        _channel = channel;
        [self stopRecording];
        
        resolve(@{});
        if (_filePath != nil) {
            [self transcribeFile];
        } else {
            _state = StateNone;
            [self sendEventWithName:@"onModuleStateChange" body:[NSDictionary dictionaryWithObjectsAndKeys: _state,@"state", channel, @"channel", nil]];
        }
    }
    @catch (NSException * e) {
        reject(@"-1", e.reason, nil);
        [self handleModuleExeption:e];
    }
}

RCT_EXPORT_METHOD(cancel:(nonnull NSNumber *)channel resolve:(RCTPromiseResolveBlock)resolve rejecter:(__unused RCTPromiseRejectBlock)reject) {
    [self stopRecording];
    [self releaseResouce];
    [self teardown];
    _state = StateNone;
    resolve(@{});
    [self sendEventWithName:@"onModuleStateChange" body:[NSDictionary dictionaryWithObjectsAndKeys: _state,@"state", channel, @"channel", nil]];
}

RCT_EXPORT_METHOD(release:(RCTPromiseResolveBlock)resolve rejecter:(__unused RCTPromiseRejectBlock)reject) {
    @synchronized(self) {
        [self stopRecording];
        [self releaseResouce];
        [self teardown];
        _state = StateNone;
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:GetDirectoryOfType_Sound(NSCachesDirectory) error:&error];
        NSLog(@"%@", error);
        
        resolve(@"");
    }
}

RCT_EXPORT_METHOD(isSpeechAvailable:(RCTPromiseResolveBlock)resolve rejecter:(__unused RCTPromiseRejectBlock)reject) {
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        switch (status) {
            case SFSpeechRecognizerAuthorizationStatusAuthorized:
                resolve(@true);
                break;
            default:
                resolve(@false);
        }
    }];
}

- (void) transcribeFile {
    if ([_filePath isEqual: nil]) {
        [self handleModuleExeption:[NSException exceptionWithName:@"file error" reason:@"There no audio file to score!" userInfo:nil]];
        return;
    }
    
    _state = StateRecognizing;
    NSDictionary *payload = [NSDictionary dictionaryWithObjectsAndKeys: _state,@"state", _channel, @"channel", nil];
    [self sendEventWithName:@"onModuleStateChange" body:payload];
    @try {
        _sessionId = [[NSUUID UUID] UUIDString];
        NSLocale* locale = nil;
        if ([_configs[@"locale"] length] > 0) {
            locale = [NSLocale localeWithLocaleIdentifier:_configs[@"locale"]];
        }
        if (locale) {
            _speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:locale];
        } else {
            _speechRecognizer = [[SFSpeechRecognizer alloc] init];
        }
        
        _speechRecognizer.delegate = self;
        
        NSURL *audioFileURL = [NSURL fileURLWithPath:_filePath];
        
        _recognitionRequest = [[SFSpeechURLRecognitionRequest alloc] initWithURL:audioFileURL];
        _recognitionRequest.shouldReportPartialResults = YES;
        //        _recognitionRequest.contextualStrings = _contextualStrings;
        //        _recognitionRequest.taskHint = SFSpeechRecognitionTaskHintDictation;
        
        _recognitionTask = [self.speechRecognizer recognitionTaskWithRequest:self.recognitionRequest resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
            
            if (error != nil) {
                NSString *errorMessage = [NSString stringWithFormat:@"%ld/%@", error.code, [error localizedDescription]];
                [self handleModuleExeption:[NSException exceptionWithName:@"RecognitionTask Exception" reason:errorMessage userInfo:@{}]];
                [self teardown];
                return;
            }
            
            BOOL isFinal = result.isFinal;
            
            //            [self sendResult :nil :result.bestTranscription.formattedString :transcriptionDics :[NSNumber numberWithBool:isFinal]];
            // || self.recognitionTask.isCancelled || self.recognitionTask.isFinishing
            if (isFinal) {
                NSMutableArray* transcripts = [NSMutableArray new];
                NSMutableArray* transcriptionDics = [NSMutableArray new];
                for (SFTranscription* transcription in result.transcriptions) {
                    [transcripts addObject:transcription.formattedString];
                    [transcriptionDics addObject:[self toArrayWithDuplicateWordsCount:transcription.formattedString]];
                }
                NSArray *contextualDicts = [self toArrayWithDuplicateWordsCount:self->_textualString];
                
                NSMutableArray *wordScoreList = [NSMutableArray new];
                NSInteger summaryQualityScore = 0;
                //                NSMutableString *transcript = [NSMutableString new];
                for (NSDictionary *word in contextualDicts) {
                    NSMutableArray<NSDictionary *> *wordScoreDic = [NSMutableArray new];
                    for (NSArray *transcriptionDic in transcriptionDics) {
                        [wordScoreDic addObject:[self getMostSimilarWordByLevenshteinDistance:word transcriptionDic:transcriptionDic]];
                    }
                    NSDictionary *wordScore = [self getWordByHighestScoreL:word wordScoreDic:wordScoreDic];
                    
                    summaryQualityScore = summaryQualityScore + [wordScore[@"percentageOfTextMatch"] intValue];
                    //                    [transcript appendString:[NSString stringWithFormat:@"%@ ", wordScore[@"transcript"]]];
                    //                    [wordScoreList addObject:@{@"word": wordScore[@"word"], @"qualityScore": wordScore[@"percentageOfTextMatch"], @"levenshteinScore": wordScore[@"levenshteinDistance"]}];
                    [wordScoreList addObject:[NSDictionary dictionaryWithObjectsAndKeys:word[@"letters"], @"word", wordScore[@"percentageOfTextMatch"], @"qualityScore", wordScore[@"levenshteinDistance"], @"levenshteinScore", nil]];
                    
                }
                
                long qualityScore = (summaryQualityScore / [wordScoreList count]);
                NSMutableDictionary *response = [[NSMutableDictionary alloc] init];
                [response setValue:self->_textualString forKey:@"text"];
                [response setValue:@"CORRECT" forKey:@"fidelityClass"];
                [response setValue:[NSNumber numberWithLong:qualityScore] forKey:@"qualityScore"];
                [response setValue:transcripts forKey:@"transcripts"];
                [response setObject:wordScoreList forKey:@"wordScoreList"];
                
                NSMutableDictionary *resultDict = [[NSMutableDictionary alloc] init];
                [resultDict setValue:self->_filePath forKey:@"filePath"];
                [resultDict setValue:self->_channel forKey:@"channel"];
                [resultDict setObject:response forKey:@"response"];
                
                [self teardown];
                [self sendEventWithName:@"onSpeechRecognized" body:resultDict];
                [self emitModuleStateChangeEvent:StateNone];
                
                return;
            }
        }];
    } @catch (NSException * e) {
        [self handleModuleExeption:e];
    }
}

- (void) teardown {
    self.isTearingDown = YES;
    [self.recognitionTask cancel];
    self.recognitionTask = nil;
    
    // Set back audio session category
    
    // End recognition request
    //    [self.recognitionRequest endAudio];
    
    // Remove tap on bus
    [self.audioEngine.inputNode removeTapOnBus:0];
    [self.audioEngine.inputNode reset];
    
    // Stop audio engine and dereference it for re-allocation
    if (self.audioEngine.isRunning) {
        [self.audioEngine stop];
        [self.audioEngine reset];
        self.audioEngine = nil;
    }
    
    self.recognitionRequest = nil;
    self.sessionId = nil;
    self.isTearingDown = NO;
}

void HandleInputBuffer(void *inUserData,
                       AudioQueueRef inAQ,
                       AudioQueueBufferRef inBuffer,
                       const AudioTimeStamp *inStartTime,
                       UInt32 inNumPackets,
                       const AudioStreamPacketDescription *inPacketDesc) {
    AQRecordState* pRecordState = (AQRecordState *)inUserData;
    
    if (!pRecordState->mIsRunning) {
        return;
    }
    
    if (AudioFileWritePackets(pRecordState->mAudioFile, false, inBuffer->mAudioDataByteSize, inPacketDesc, pRecordState->mCurrentPacket, &inNumPackets, inBuffer->mAudioData) == noErr) {
        pRecordState->mCurrentPacket += inNumPackets;
    }
    
    short *samples = (short *) inBuffer->mAudioData;
    long nsamples = inBuffer->mAudioDataByteSize;
    //    NSData *data = [NSData dataWithBytes:samples length:nsamples];
    
    [pRecordState->mSelf sendEventWithName:@"onVoice" body:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithShort:*samples],@"size", [NSNumber numberWithLong:(long) nsamples], @"length", nil]];
    
    AudioQueueEnqueueBuffer(pRecordState->mQueue, inBuffer, 0, NULL);
}

- (void) emitModuleStateChangeEvent:(NSString * _Nullable) withState{
    if (withState) {
        _state = withState;
    }
    [self sendEventWithName:@"onModuleStateChange" body:[NSDictionary dictionaryWithObjectsAndKeys:self->_state,@"state", self->_channel, @"channel", nil]];
}

- (void) startTimer:(NSInteger)timeIntervalInSeconds {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeIntervalInSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([self->_state  isEqual: StateRecording]) {
            [self stopRecording];
            [self releaseResouce];
            
            self->_state = StateNone;
            [self sendEventWithName:@"onModuleStateChange" body:[NSDictionary dictionaryWithObjectsAndKeys:self->_state,@"state", self->_channel, @"channel", nil]];
        }
    });
}

- (void) releaseResouce {
    NSLog(@"release resouce");
    if (![_filePath isEqual:nil]) {
        [[NSFileManager defaultManager] removeItemAtPath:_filePath error:nil];
        _filePath = nil;
    }
}

- (void) stopRecording {
    if (_recordState.mIsRunning) {
        _recordState.mIsRunning = false;
        AudioQueueStop(_recordState.mQueue, true);
        AudioQueueDispose(_recordState.mQueue, true);
        AudioFileClose(_recordState.mAudioFile);
    }
}

- (void) handleModuleExeption:(NSException *)e {
    NSLog(@"Exception: %@", e);
    [self stopRecording];
    [self releaseResouce];
    [self teardown];
    _state = StateNone;
    [self sendEventWithName:@"onError" body:[NSDictionary dictionaryWithObjectsAndKeys:e.reason,@"error", self->_channel, @"channel", nil]];
    [self sendEventWithName:@"onModuleStateChange" body:[NSDictionary dictionaryWithObjectsAndKeys:self->_state,@"state", self->_channel, @"channel", nil]];
}

- (NSArray<NSString *> *)supportedEvents
{
    return @[
        @"onVoiceStart",
        @"onVoice",
        @"onVoiceEnd",
        @"onError",
        @"onSpeechRecognized",
        @"onModuleStateChange",
        @"onPlayerStateChange",
        @"onPlayerDidFinishPlaying"
    ];
}

- (NSDictionary *) getMostSimilarWordByLevenshteinDistance:(NSDictionary *)word transcriptionDic:(NSArray<NSDictionary *> *)transcriptionDic
{
    NSMutableArray* wordDics = [NSMutableArray new];
    for (NSDictionary *transcription in transcriptionDic) {
        [wordDics addObject:[self scoreByLevenshteinDistance:word right:transcription]];
    }
    
    return [self getWordByHighestScoreL:word wordScoreDic:wordDics];
}

- (NSDictionary *) getWordByHighestScoreL:(NSDictionary *)sentence wordScoreDic:(NSArray<NSDictionary *> *)wordScoreDic
{
    // var word: String, var transcript: String, var levenshteinDistance: Int, var percentageOfTextMatch: Int
    NSDictionary *wordScore = @{
        @"word" : sentence[@"word"],
        @"transcript": @"",
        @"levenshteinDistance": [NSNumber numberWithLong:[sentence[@"word"] length]],
        @"percentageOfTextMatch": @0
    };
    for (NSDictionary *word in wordScoreDic) {
        if (
            [word[@"levenshteinDistance"] doubleValue] <= [wordScore[@"levenshteinDistance"] doubleValue] &&
            [word[@"percentageOfTextMatch"] doubleValue] >= [wordScore[@"percentageOfTextMatch"] doubleValue] &&
            [word[@"word"] length] > [word[@"levenshteinDistance"] intValue]
            ) {
            wordScore = word;
        }
    }
    return wordScore;
}

- (NSDictionary *) scoreByLevenshteinDistance:(NSDictionary *)left right:(NSDictionary *)right
{
    NSUInteger levenshteinDistance = [[left valueForKey:@"word"] mdc_damerauLevenshteinDistanceTo:[right valueForKey:@"word"]];
    
    return @{
        @"word": [left valueForKey:@"letters"],
        @"transcript": [right valueForKey:@"word"],
        @"levenshteinDistance": [NSNumber numberWithLong:levenshteinDistance],
        @"percentageOfTextMatch": [self percentageOfTextMatch:[left valueForKey:@"word"] right:[right valueForKey:@"word"]]
    };
}

- (NSArray<NSDictionary *> *) toArrayWithDuplicateWordsCount:(NSString *)text {
    
    NSString *modifiedString = [_regex stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, [text length]) withTemplate:@""];
    NSMutableArray* transcriptionDics = [NSMutableArray new];
    NSArray *words = [modifiedString componentsSeparatedByString: @" "];
    
    for( int i = 0; i < [words count]; i++)
    {
        NSString *word = [words[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        [transcriptionDics addObject:@{@"word": [word lowercaseString], @"letters": words[i] }];
    }
    return transcriptionDics;
}

- (NSNumber *) percentageOfTextMatch:(NSString*)left right:(NSString*)right {
    NSString *s0 = [left stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *s1 = [right stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    NSInteger distance = [s0 mdc_damerauLevenshteinDistanceTo:s1];
    NSInteger percent = (100 - (int)distance * 100 / ([s0 length] + [s1 length]));
    return [NSNumber numberWithLong:percent];
}

- (void)dealloc {
    AudioQueueDispose(_recordState.mQueue, true);
}

@end
