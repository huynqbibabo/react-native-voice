#import <React/RCTBridgeModule.h>

#import <AVFoundation/AVFoundation.h>
#import <React/RCTEventEmitter.h>
#import <React/RCTLog.h>
#import <React/RCTUtils.h>
#import <React/RCTEventEmitter.h>
#import <Speech/Speech.h>
#import <Accelerate/Accelerate.h>
#import <MDCDamerauLevenshtein.h>


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


@interface Voice : RCTEventEmitter <RCTBridgeModule, SFSpeechRecognizerDelegate>
@property (nonatomic, assign) AQRecordState recordState;
@property (nonatomic, strong) NSString* state;
@property (nonatomic, strong) NSString* filePath;
@property (nonatomic, strong) NSDictionary* configs;
@property (nonatomic, weak) NSNumber *key;

@property (nonatomic, strong) NSRegularExpression *regex;
@property (nonatomic, strong) NSString *textualString;
@property (nonatomic, weak) NSArray<NSString *> *contextualStrings;
@property (nonatomic, strong) SFSpeechRecognizer* speechRecognizer;
@property (nonatomic, strong) SFSpeechURLRecognitionRequest* recognitionRequest;
@property (nonatomic, strong) AVAudioEngine* audioEngine;
@property (nonatomic, strong) SFSpeechRecognitionTask* recognitionTask;
@property (nonatomic, strong) AVAudioSession* audioSession;
/** Whether speech recognition is finishing.. */
@property (nonatomic) BOOL isTearingDown;
@property (nonatomic) BOOL continuous;

@property (nonatomic) NSString *sessionId;
/** Previous category the user was on prior to starting speech recognition */
@property (nonatomic) NSString* priorAudioCategory;
/** Volume level Metering*/
@property float averagePowerForChannel0;
@property float averagePowerForChannel1;


@end
