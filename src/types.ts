export type Options = {
  locale?: string;
  RECOGNIZER_ENGINE?: string;
  EXTRA_LANGUAGE_MODEL?: string;
  EXTRA_MAX_RESULTS?: number;
  EXTRA_PARTIAL_RESULTS?: boolean;
  REQUEST_PERMISSIONS_AUTO?: boolean;
  /**
   * Khoảng thời gian cần thiết sau khi ngừng nghe giọng nói để xem xét việc nhập liệu đã hoàn tất
   */
  EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS?: number;
  /**
   * Độ dài tối thiểu của một câu nói. Module sẽ không ngừng ghi trước khoảng thời gian này.
   */
  EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS?: number;
  /**
   * Khoảng thời gian cần thiết sau khi ngừng nghe giọng nói để xem xét việc nhập liệu có thể hoàn thành
   */
  EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS?: number;
  /**
   * see https://developer.android.com/reference/android/speech/RecognizerIntent.html#summary for more option
   */
};

export interface WordScore {
  qualityScore: number;
  levenshteinScore: number;
  word: string;
}

export interface TextScore {
  fidelityClass: 'CORRECT' | 'NO_SPEECH' | 'INCOMPLETE' | 'FREE_SPEAK';
  qualityScore: number;
  text?: string;
  wordScoreList?: WordScore[];
  transcripts?: string[];
}

export type SpeechEvents = {
  onVoiceStart?: () => void;
  onVoice?: (e: VoiceEvent) => void;
  onVoiceEnd?: () => void;

  onError?: (e: ErrorEvent) => void;
  onSpeechRecognized?: (e: SpeechRecognizedEvent) => void;
  onModuleStateChange?: (e: StateChangeEvent) => void;
};

export type SpeechEvent = keyof SpeechEvents;

export interface ChannelSubscription {
  channel: number;
}

export interface SpeechStartEvent extends ChannelSubscription {
  error?: boolean;
}

export interface SpeechRecognizedEvent extends ChannelSubscription {
  filePath: string;
  response: TextScore;
}

export interface VoiceStartEvent extends ChannelSubscription {}

export interface VoiceEvent extends ChannelSubscription {
  size: number;
}

export interface VoiceEndEvent extends ChannelSubscription {}

export interface ErrorEvent {
  channel: number;
  error?: {
    code?: string;
    message?: string;
  };
}

export interface StateChangeEvent {
  state: SpeechModuleState;
  channel: number;
}

export type SpeechModuleState = 'NONE' | 'RECORDING' | 'RECOGNIZING';
