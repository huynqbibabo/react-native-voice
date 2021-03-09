import React, { useMemo } from 'react';
import { Button, StyleSheet, Text, View } from 'react-native';
import WordHighlight from './WordHighlight';
import { useSpeechRecognizer } from 'react-native-voice';
import { AudioPlayback } from './AudioPlayback';

type Props = {
  text: string;
};
const Separator = () => <View style={styles.separator} />;

export const Item = (props: Props) => {
  const {
    state,
    start,
    stop,
    cancel,
    response,
    audioFile,
  } = useSpeechRecognizer(props.text, {
    // EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS: 30000,
    // EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS: 3000,
  });

  return useMemo(() => {
    return (
      <View style={styles.container}>
        <View style={{ width: '100%' }}>
          <Text style={[styles.title, { fontWeight: '600' }]}>
            Try me: {props.text}
          </Text>
          <Text style={styles.title}>Recorder state: {state}</Text>
        </View>
        <View
          style={{
            flexDirection: 'row',
            flex: 1,
            justifyContent: 'space-evenly',
            alignItems: 'center',
          }}
        >
          <Button title="Start" onPress={start} color={'#4F83CC'} />
          <Button title="Stop recording" color="#FF5C8D" onPress={stop} />
          <Button title="Cancel" color="#FFA040" onPress={cancel} />
        </View>
        <View>
          <View style={styles.result}>
            {response?.wordScoreList && (
              <WordHighlight words={response?.wordScoreList} />
            )}
          </View>
        </View>
        {audioFile && <AudioPlayback filePath={audioFile} />}
        <Separator />
      </View>
    );
  }, [
    audioFile,
    cancel,
    props.text,
    response?.wordScoreList,
    start,
    state,
    stop,
  ]);
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 20,
  },
  actions: {
    flexDirection: 'row',
    flex: 1,
    justifyContent: 'space-evenly',
    alignItems: 'center',
  },
  title: {
    textAlign: 'center',
    marginVertical: 8,
  },
  fixToText: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  separator: {
    marginVertical: 8,
    height: 1,
    width: '100%',
    borderBottomColor: '#737373',
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  result: {
    alignItems: 'center',
    justifyContent: 'center',
  },
});
