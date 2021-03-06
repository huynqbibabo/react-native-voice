import { useEffect, useRef, useState } from 'react';
import type {
  SpeechModuleState,
  SpeechRecognizedEvent,
  StateChangeEvent,
} from './index';
import Speecher, { ErrorEvent, Options, SpeechEvent } from './index';
import type { EmitterSubscription } from 'react-native';

let recognizeChannel = 1;
/**
 *   Get current module state and subsequent updates
 */
const useModuleState = () => {
  const [state, setState] = useState<SpeechModuleState>('NONE');

  useEffect(() => {
    async function updateState() {
      const moduleState = await Speecher.getState();
      setState(moduleState);
    }

    updateState();

    const sub = Speecher.onModuleStateChange((event) => {
      setState(event.state);
    });
    let handlerSubscription: EmitterSubscription;
    return () => {
      sub.remove();
      handlerSubscription?.remove();
    };
  }, []);

  return state;
};

/**
 * @description
 *   Attaches a handler to the given Speechace events and performs cleanup on unmount
 * @param {Array<string>} event - Speechace events to subscribe to
 * @param {(payload: any) => void} handler - callback invoked when the event fires
 */
const useSpeechEvent = (event: SpeechEvent, handler: (event: any) => void) => {
  const savedHandler = useRef();

  useEffect(() => {
    // @ts-ignore
    savedHandler.current = handler;
  }, [handler]);

  useEffect(() => {
    const sub = Speecher.addListener(event, (payload) =>
      // @ts-ignore
      savedHandler.current(payload)
    );

    return () => {
      sub.remove();
    };
  }, [event]);
};

const useModuleStateChanges = (handler: (event: SpeechModuleState) => void) => {
  useSpeechEvent('onModuleStateChange', ({ state }) => {
    handler(state);
  });
  useEffect(() => {
    let didCancel = false;
    const updateState = async () => {
      const moduleState = await Speecher.getState();
      if (!didCancel) {
        handler(moduleState);
      }
    };
    updateState();
    return () => {
      didCancel = true;
    };
  }, [handler]);
};

const useSpeechRecognizer = (textToScore?: string, options?: Options) => {
  const _channel = useRef(recognizeChannel++);
  const [state, setState] = useState<SpeechModuleState>('NONE');
  const [audioFile, setAudioFile] = useState<string | null>(null);
  const [response, setSpeechResponse] = useState<any | null>(null);

  useEffect(() => {
    let didCancel = false;
    const channelStateSubscription = Speecher.addListener(
      'onModuleStateChange',
      ({ state: moduleState, channel }: StateChangeEvent) => {
        if (channel === _channel.current && !didCancel) {
          console.log('onModuleStateChange', moduleState, channel);
          setState(moduleState);
        }
      }
    );

    const recognizeChannelSubscription = Speecher.addListener(
      'onSpeechRecognized',
      ({
        filePath,
        response: speechResult,
        channel,
      }: SpeechRecognizedEvent) => {
        if (channel === _channel.current && !didCancel) {
          console.log('onSpeechRecognized', filePath, speechResult, channel);
          setAudioFile(filePath);
          setSpeechResponse(speechResult);
        }
      }
    );

    const recognizeChannelErrorSubscription = Speecher.addListener(
      'onError',
      ({ channel, error }: ErrorEvent) => {
        if (channel === _channel.current && !didCancel) {
          console.log(error);
          setState('NONE');
        }
      }
    );

    return () => {
      didCancel = true;
      channelStateSubscription.remove();
      recognizeChannelSubscription.remove();
      recognizeChannelErrorSubscription.remove();
    };
  }, []);

  const start = async () => {
    await Speecher.start(_channel.current, textToScore, options);
  };

  const stop = async () => {
    await Speecher.stop(_channel.current);
  };

  const cancel = async () => {
    await Speecher.cancel(_channel.current);
  };

  return {
    state,
    audioFile,
    response,
    start,
    stop,
    cancel,
  };
};

export {
  useModuleState,
  useSpeechEvent,
  useModuleStateChanges,
  useSpeechRecognizer,
};
