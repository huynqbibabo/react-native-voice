import {
  NativeModules,
  NativeEventEmitter,
  EmitterSubscription,
  Platform,
} from 'react-native';
import type {
  Options,
  SpeechModuleState,
  ErrorEvent,
  StateChangeEvent,
  VoiceStartEvent,
  VoiceEvent,
  VoiceEndEvent,
  ChannelSubscription,
  SpeechEvents,
  SpeechRecognizedEvent,
  SpeechStartEvent,
  SpeechEvent,
  TextScore,
  WordScore,
} from './types';

import {
  useModuleState,
  useModuleStateChanges,
  useSpeechEvent,
  useSpeechRecognizer,
} from './hooks';

const VoiceModule = NativeModules.Voice;
const VoiceModuleEmitter = new NativeEventEmitter(VoiceModule);

class RCTVoice {
  async start(channel?: number, textToScore?: string, options?: Options) {
    return await VoiceModule.start(
      channel || 0,
      textToScore,
      Object.assign(
        {
          locale: 'en-US',
          RECOGNIZER_ENGINE: 'GOOGLE',
          EXTRA_LANGUAGE_MODEL: 'LANGUAGE_MODEL_FREE_FORM',
          EXTRA_MAX_RESULTS: 5,
          EXTRA_PARTIAL_RESULTS: true,
          REQUEST_PERMISSIONS_AUTO: true,
        },
        options
      )
    );
  }

  async stop(channel?: number) {
    return await VoiceModule.stop(channel ?? 0);
  }

  async cancel(channel?: number) {
    return await VoiceModule.cancel(channel ?? 0);
  }

  async release() {
    return await VoiceModule.release();
  }

  async isAvailable() {
    return await VoiceModule.isSpeechAvailable();
  }

  /**
   * (Android) Get a list of the speech recognition engines available on the device
   * */
  async getState(): Promise<SpeechModuleState> {
    return await VoiceModule.getState();
  }

  async getSpeechRecognitionServices() {
    if (Platform.OS !== 'android') {
      return;
    }

    return await VoiceModule.getSpeechRecognitionServices();
  }

  onVoiceStart = (fn: (e: VoiceStartEvent) => void): EmitterSubscription => {
    return VoiceModuleEmitter.addListener('onVoiceStart', fn);
  };

  onVoice(fn: (data: VoiceEvent) => void): EmitterSubscription {
    return VoiceModuleEmitter.addListener('onVoice', fn);
  }

  onVoiceEnd(fn: (e: VoiceEndEvent) => void): EmitterSubscription {
    return VoiceModuleEmitter.addListener('onVoiceEnd', fn);
  }

  onError(fn: (error: ErrorEvent) => void): EmitterSubscription {
    return VoiceModuleEmitter.addListener('onError', fn);
  }

  onModuleStateChange(fn: (e: StateChangeEvent) => void): EmitterSubscription {
    return VoiceModuleEmitter.addListener('onModuleStateChange', fn);
  }

  onSpeechRecognized(
    fn: (e: SpeechRecognizedEvent) => void
  ): EmitterSubscription {
    return VoiceModuleEmitter.addListener('onSpeechRecognized', fn);
  }

  addListener(
    event: SpeechEvent,
    handler: (payload: any) => void
  ): EmitterSubscription {
    return VoiceModuleEmitter.addListener(event, handler);
  }
}

export type {
  Options,
  SpeechModuleState,
  ErrorEvent,
  StateChangeEvent,
  VoiceStartEvent,
  VoiceEvent,
  VoiceEndEvent,
  ChannelSubscription,
  SpeechEvents,
  SpeechRecognizedEvent,
  SpeechStartEvent,
  SpeechEvent,
  TextScore,
  WordScore,
};
export {
  useModuleState,
  useModuleStateChanges,
  useSpeechEvent,
  useSpeechRecognizer,
};
const VoiceRecognizer = new RCTVoice();
export default VoiceRecognizer;
