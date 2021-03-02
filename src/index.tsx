import { NativeModules } from 'react-native';

type VoiceType = {
  multiply(a: number, b: number): Promise<number>;
};

const { Voice } = NativeModules;

export default Voice as VoiceType;
