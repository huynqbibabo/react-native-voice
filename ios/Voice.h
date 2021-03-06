#import <React/RCTBridgeModule.h>

#import <AVFoundation/AVFoundation.h>
#import <React/RCTEventEmitter.h>
#import <React/RCTLog.h>

#define kNumberBuffers 3
#define StateNone @"NONE"
#define StateRecording @"RECORDING"
#define StateRecognizing @"RECOGNIZING"

typedef struct {
    __unsafe_unretained id      mSelf;
    AudioStreamBasicDescription mDataFormat;
    AudioQueueRef               mQueue;
    AudioQueueBufferRef         mBuffers[kNumberBuffers];
    AudioFileID                 mAudioFile;
    UInt32                      bufferByteSize;
    SInt64                      mCurrentPacket;
    bool                        mIsRunning;
} AQRecordState;


@interface Voice : RCTEventEmitter <RCTBridgeModule, AVAudioPlayerDelegate>
@property (nonatomic, assign) AQRecordState recordState;
@property (nonatomic, strong) NSString* state;
@property (nonatomic, strong) NSString* filePath;
@property (nonatomic, strong) NSString* apiKey;
@property (nonatomic, strong) NSDictionary* params;
@property (nonatomic, strong) NSDictionary* formData;
@property (nonatomic, strong) NSDictionary* configs;
@property (nonatomic, strong) NSURLSessionTask* requestTask;
@property (nonatomic, weak) NSNumber *key;
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player
    successfully:(BOOL)flag;

@end
