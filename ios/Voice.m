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
    NSMutableDictionary *_players;
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
    return self;
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_queue_create("vn.bibabo.ReactNativeSpeechace", DISPATCH_QUEUE_SERIAL);
}

RCT_EXPORT_METHOD(setApiKey:(NSString *)key) {
    _apiKey = key;
}

RCT_EXPORT_METHOD(getState:(RCTPromiseResolveBlock)resolve rejecter:(__unused RCTPromiseRejectBlock)reject) {
    resolve(_state);
}

RCT_EXPORT_METHOD(start:(nonnull NSNumber *)channel params:(NSDictionary *)params formData:(NSDictionary *)formData configs:(NSDictionary *)configs resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if (!_apiKey) {
        reject(@"api_missing", @"Set a valid api key to start!", nil);
        return;
    }
    
    if (![_state  isEqual: StateNone]) {
        [self stopRecording];
        [self releaseResouce];
        [self cancelRequestTask];
    }
    
    if(_key) {
        [[self playerForKey:_key] stop];
    }
    
    if (formData[@"audioFile"] != nil) {
        _filePath = formData[@"audioFile"];
    }
    _channel = channel;
    if (_filePath != nil) {
        resolve(@{});
        [self makeRequest];
        return;
    }
    @try {
        _params = params;
        _formData = formData;
        _configs = configs;
        
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
        
        if (configs[@"audioLengthInSeconds"] != nil) {
            NSInteger timeIntervalInSeconds = [RCTConvert NSInteger:configs[@"audioLengthInSeconds"]];
            [self startTimer:timeIntervalInSeconds];
        }
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
            [self makeRequest];
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
    [self cancelRequestTask];
    _state = StateNone;
    resolve(@{});
    [self sendEventWithName:@"onModuleStateChange" body:[NSDictionary dictionaryWithObjectsAndKeys: _state,@"state", channel, @"channel", nil]];
}

RCT_EXPORT_METHOD(clear:(RCTPromiseResolveBlock)resolve rejecter:(__unused RCTPromiseRejectBlock)reject) {
    @synchronized(self) {
        [self stopRecording];
        [self releaseResouce];
        [self cancelRequestTask];
        _state = StateNone;
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:GetDirectoryOfType_Sound(NSCachesDirectory) error:&error];
        NSLog(@"%@", error);
        for (id key in [_players allKeys]) {
            AVAudioPlayer *player = [self playerForKey:key];
            if (player) {
                [player stop];
                [[self players] removeObjectForKey:key];
                NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
                [notificationCenter removeObserver:self];
            }
        }
        resolve(@"");
    }
}

RCT_EXPORT_METHOD(setVolume:(double) volume withKey:(nonnull NSNumber *)key resolve:(RCTPromiseResolveBlock) resolve reject:(RCTPromiseRejectBlock) reject) {
    [[self playerForKey:key] setVolume: volume];
    resolve(@"");
}

RCT_EXPORT_METHOD(prepare:(NSString *)filePath withKey:(nonnull NSNumber *)key resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([self playerForKey:key]) {
            [self releasePlayer:nil withKey:key];
        }
        NSError *error;
        NSString * audioFile = filePath != nil ? filePath : self->_filePath;
        // [filePath != nil ? filePath : _filePath stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
        
        NSLog(@"prepare for path: %@", audioFile);
        if (!audioFile) {
            reject(@"file error", @"There no audio file for playback", nil);
            return;
        }
        AVAudioPlayer *audioPlayer;
        NSURL *audioFileURL;
        if ([audioFile hasPrefix:@"http"]) {
            audioFileURL = [[NSURLComponents alloc] initWithString:audioFile].URL;
            NSData *data = [NSData dataWithContentsOfURL:audioFileURL];
            audioPlayer = [[AVAudioPlayer alloc] initWithData:data error:&error];
        } else if ([audioFile hasPrefix:@"ipod-library://"] || [audioFile hasPrefix:@"file://"]) {
            audioFileURL = [NSURL URLWithString:audioFile];
            audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:audioFileURL error:&error];
        } else {
            audioFileURL = [NSURL fileURLWithPath:audioFile];
            audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:audioFileURL error:&error];
        }
        RCTLogInfo(@"audio player alloc");
        
        if (audioPlayer) {
            @synchronized(self) {
                audioPlayer.delegate = self;
                audioPlayer.enableRate = YES;
                [audioPlayer prepareToPlay];
                [[self players] setObject:audioPlayer forKey:key];
                resolve(@"");
            }
        } else {
            reject(@"player error", [NSString stringWithFormat:@"Can't prepare player for path %@", audioFile], error);
        }
    });
}


RCT_EXPORT_METHOD(play:(nonnull NSNumber *)key resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    NSLog(@"%@", key);
    AVAudioPlayer *player = [self playerForKey:key];
    if (player) {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
        [session setActive:TRUE error:nil];
        
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(audioSessionChangeObserver:)
         name:AVAudioSessionRouteChangeNotification
         object:nil];
        _key = key;
        [player play];
        resolve(@"");
        [self sendEventWithName:@"onPlayerStateChange" body:[NSDictionary dictionaryWithObjectsAndKeys: key,@"key", [NSNumber numberWithBool:[player isPlaying]], @"isPlaying", nil]];
    } else {
        reject(@"player error", @"AudioPlayer not started yet", nil);
    }
}


RCT_EXPORT_METHOD(pause:(nonnull NSNumber *)key resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    RCTLogInfo(@"pause");
    AVAudioPlayer *audioPlayer = [self playerForKey:key];
    if (audioPlayer && [audioPlayer isPlaying]) {
        [audioPlayer pause];
        resolve(@"");
        [self sendEventWithName:@"onPlayerStateChange" body:[NSDictionary dictionaryWithObjectsAndKeys:key,@"key", [NSNumber numberWithBool:[audioPlayer isPlaying]], @"isPlaying", nil]];
    } else {
        reject(@"player error", @"AudioPlayer not started yet", nil);
    }
}

RCT_EXPORT_METHOD(seek:(nonnull NSNumber*)time withKey:(nonnull NSNumber *)key resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    AVAudioPlayer *audioPlayer = [self playerForKey:key];
    if (audioPlayer) {
        audioPlayer.currentTime = [time doubleValue];
        resolve(@"");
    } else {
        reject(@"player error", @"AudioPlayer not started yet", nil);
    }
}

RCT_EXPORT_METHOD(stopPlayer:(nonnull NSNumber *)key resolver:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    AVAudioPlayer *audioPlayer = [self playerForKey:key];
    if (audioPlayer) {
        [audioPlayer stop];
        resolve(@"");
        NSDictionary *payload = [NSDictionary dictionaryWithObjectsAndKeys: key,@"key", [NSNumber numberWithBool:[audioPlayer isPlaying]], @"isPlaying", nil];
        [self sendEventWithName:@"onPlayerStateChange" body:payload];
    } else {
        reject(@"player error", @"AudioPlayer not started yet", nil);
    }
}

RCT_EXPORT_METHOD(release : (nonnull NSNumber *)key) {
    @synchronized(self) {
        AVAudioPlayer *player = [self playerForKey:key];
        if (player) {
            [player stop];
            [[self players] removeObjectForKey:key];
            NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
            [notificationCenter removeObserver:self];
            NSLog(@"released player for key %@", key);
        }
    }
}

- (void)audioSessionChangeObserver:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    AVAudioSessionRouteChangeReason audioSessionRouteChangeReason =
    [userInfo[@"AVAudioSessionRouteChangeReasonKey"] longValue];
    AVAudioSessionInterruptionType audioSessionInterruptionType =
    [userInfo[@"AVAudioSessionInterruptionTypeKey"] longValue];
    AVAudioPlayer *player = [self playerForKey:self.key];
    if (audioSessionInterruptionType == AVAudioSessionInterruptionTypeEnded) {
        if (player && player.isPlaying) {
            [player play];
        }
    }
    if (audioSessionRouteChangeReason ==
        AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        if (player) {
            [player pause];
        }
    }
    if (audioSessionInterruptionType == AVAudioSessionInterruptionTypeBegan) {
        if (player) {
            [player pause];
        }
    }
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    NSLog(@"audioPlayerDidFinishPlaying");
    NSNumber *key = [self keyForPlayer:player];
    // Send last event then finish it.
    NSDictionary *payload = [NSDictionary dictionaryWithObjectsAndKeys:key,@"key",  [NSNumber numberWithBool:[player isPlaying]], @"isPlaying", nil];
    [self sendEventWithName:@"onPlayerStateChange" body:payload];
}

-(void) releasePlayer:(AVAudioPlayer *)player withKey:(NSNumber *)key {
    if(player) {
        [player stop];
        [[self players] removeObjectForKey:[self keyForPlayer:player]];
    } else if (key) {
        AVAudioPlayer *audioPlayer = [self playerForKey:key];
        [audioPlayer stop];
        [[self players] removeObjectForKey:key];
    }
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self];
    _key = nil;
}

- (NSMutableDictionary *)players {
    if (!_players) {
        _players = [NSMutableDictionary new];
    }
    return _players;
}

- (AVAudioPlayer *)playerForKey:(nonnull NSNumber *)key {
    return [[self players] objectForKey:key];
}

- (NSNumber *)keyForPlayer:(nonnull AVAudioPlayer *)player {
    return [[[self players] allKeysForObject:player] firstObject];
}

- (void) makeRequest {
    if ([_filePath isEqual: nil]) {
        [self handleModuleExeption:[NSException exceptionWithName:@"file error" reason:@"There no audio file to score!" userInfo:nil]];
        return;
    }
    
    _state = StateRecognizing;
    NSDictionary *payload = [NSDictionary dictionaryWithObjectsAndKeys: _state,@"state", _channel, @"channel", nil];
    [self sendEventWithName:@"onModuleStateChange" body:payload];
    @try {
        NSURLComponents *urlBuilder = [[NSURLComponents alloc] init];
        urlBuilder.scheme = @"https";
        urlBuilder.host = @"api2.speechace.com";
        
        NSString *apiPaths = [NSString stringWithFormat:@"/api/%@/%@/%@/json", [_configs valueForKey:@"callForAction"], [_configs valueForKey:@"actionForDatatype"], [[_params valueForKey:@"dialect"] isEqual: @"en-gb"] ? @"v0.1" : @"v0.5"];
        urlBuilder.path = apiPaths;
        
        NSArray<NSURLQueryItem *> *queryItems = @[[NSURLQueryItem queryItemWithName:@"key" value:_apiKey]];
        // add url get params
        if (_params.count > 0) {
            for(id key in _params) {
                id value = [_params objectForKey:key];
                queryItems = [queryItems arrayByAddingObject:[NSURLQueryItem queryItemWithName:key value:value]];
            }
        }
        urlBuilder.queryItems = queryItems;
        NSURL *url = urlBuilder.URL;
        NSLog(@"%@", url);
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10.0];
        
        [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
        [request setHTTPShouldHandleCookies:NO];
        [request setTimeoutInterval:60];
        [request setHTTPMethod:@"POST"];
        
        NSString *boundary = @"react-native-speechace";
        
        // set Content-Type in HTTP header
        NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
        [request setValue:contentType forHTTPHeaderField: @"Content-Type"];
        
        // post body
        NSMutableData *body = [NSMutableData data];
        
        // add form data (all params are strings)
        if (_formData.count > 0) {
            for(id key in _formData) {
                if (![key  isEqual: @"user_audio_file"]) {
                    id value = [_formData objectForKey:key];
                    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
                    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=%@\r\n\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
                    [body appendData:[[NSString stringWithFormat:@"%@\r\n", value] dataUsingEncoding:NSUTF8StringEncoding]];
                }
            }
        }
        
        [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithString:[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"user_audio_file\"; filename=%@\r\n", [_filePath stringByDeletingPathExtension]]] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        NSData *fileData = [[NSData alloc] initWithContentsOfURL:[NSURL fileURLWithPath:_filePath]];
        [body appendData:[NSData dataWithData:fileData]];
        [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        
        [request setHTTPBody:body];
        _requestTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                NSLog(@"%@", error);
                [self handleModuleExeption:[NSException exceptionWithName:@"request_error" reason:[error localizedDescription] userInfo:nil]];
                return;
            } else {
                NSError * jsonError;
                NSDictionary *dictionary = [NSJSONSerialization  JSONObjectWithData:data options:kNilOptions error:&jsonError];
                NSDictionary *response = @{@"response": [self dictionaryWithCamelCaseKeys: dictionary], @"filePath": self->_filePath, @"channel": self->_channel};
                [self sendEventWithName:@"onSpeechRecognized" body:response];
            }
            
            self->_state = StateNone;
            NSDictionary *payload = [NSDictionary dictionaryWithObjectsAndKeys: self->_state,@"state", self->_channel, @"channel", nil];
            [self sendEventWithName:@"onModuleStateChange" body:payload];
            self->_filePath = nil;
            self->_channel = nil;
        }];
        [_requestTask resume];
    } @catch (NSException * e) {
        [self handleModuleExeption:e];
    }
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

- (void) cancelRequestTask {
    if (_requestTask != nil){
        if (_requestTask.state == NSURLSessionTaskStateRunning || _requestTask.state != NSURLSessionTaskStateSuspended) {
            [_requestTask cancel];
            _requestTask = nil;
        }
    }
}

- (void) handleModuleExeption:(NSException *)e {
    NSLog(@"Exception: %@", e);
    [self stopRecording];
    [self releaseResouce];
    [self cancelRequestTask];
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

/*
 Recursive algorithm to find all nested dictionary keys and create an NSMutableDictionary copy with all keys converted to lowercase
 Returns an NSMutableDictionary with all keys and nested keys converted to lowercase.
 */
- (NSMutableDictionary *)dictionaryWithCamelCaseKeys:(NSDictionary *)dictionary
{
    NSMutableDictionary *resultDict = [NSMutableDictionary dictionaryWithCapacity:[dictionary count]];
    [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        // There are 3 types of objects to consider, NSDictionary, NSArray and everything else
        id resultObj;
        if ([obj isKindOfClass:NSDictionary.class])
        {
            // Recursively dig deeper into this nested dictionary
            resultObj = [self dictionaryWithCamelCaseKeys:obj];
        }
        else if ([obj isKindOfClass:NSArray.class])
        {
            /*
             Iterate over this nested NSArray. Recursively convert any NSDictionary objects to the lowercase version.
             If the array contains another array then continue to recursively dig deeper.
             */
            resultObj = [NSMutableArray arrayWithCapacity:[obj count]];
            for (id arrayObj in obj)
            {
                if ([arrayObj isKindOfClass:NSDictionary.class])
                    [resultObj addObject:[self dictionaryWithCamelCaseKeys:arrayObj]];
                else if ([arrayObj isKindOfClass:NSArray.class])
                    [resultObj addObject:[self arrayWithCamelcaseKeysForDictionaryArray:arrayObj]];
                else
                    [resultObj addObject:arrayObj];
            }
        }
        else
        {
            // The object is not an NSDictionary or NSArray so keep the object as is
            resultObj = obj;
        }
        
        // The result object has been converted and can be added to the dictionary. Note this object may be nested inside a larger dictionary.
        [resultDict setObject:resultObj forKey:[self toCamelCase:key]];
    }];
    return resultDict;
}

/*
 Convert NSDictionary keys to lower case when embedded in an NSArray
 */
- (NSMutableArray *)arrayWithCamelcaseKeysForDictionaryArray:(NSArray *)dictionaryArray
{
    NSMutableArray *resultArray = [NSMutableArray arrayWithCapacity:[dictionaryArray count]];
    for (id eachObj in dictionaryArray)
    {
        if ([eachObj isKindOfClass:NSDictionary.class])
            [resultArray addObject:[self dictionaryWithCamelCaseKeys:eachObj]];
        else if ([eachObj isKindOfClass:NSArray.class])
            [resultArray addObject:[self arrayWithCamelcaseKeysForDictionaryArray:eachObj]];
    }
    return resultArray;
}


- (NSString *)toCamelCase:(NSString *)string
{
    NSString* letterCases =  [[[string capitalizedString] componentsSeparatedByCharactersInSet:[[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"] invertedSet]] componentsJoinedByString:@""];
    return [NSString stringWithFormat:@"%@%@",[[letterCases substringToIndex:1] lowercaseString],[letterCases substringFromIndex:1]];
}

- (void)dealloc {
    AudioQueueDispose(_recordState.mQueue, true);
}

@end
