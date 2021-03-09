import Sound from 'react-native-sound';

import React, { useCallback, useMemo, useState } from 'react';
import { Alert, Button, StyleSheet, Text, View } from 'react-native';

type Props = {
  filePath: string;
};
export const AudioPlayback = (props: Props) => {
  const [playing, togglePlay] = useState(false);

  const playSound = useCallback(() => {
    // If the audio is a 'require' then the second parameter must be the callback.
    // @ts-ignore
    const sound = new Sound(props.filePath, undefined, (error) =>
      callback(error, sound)
    );
    // eslint-disable-next-line no-shadow
    const callback = (error: any, sound: any) => {
      if (error) {
        Alert.alert('error', error.message);
        togglePlay(false);
        return;
      }
      togglePlay(true);
      // Run optional pre-play callback
      sound.play(() => {
        // Success counts as getting to the end
        togglePlay(false);
        // Release when it's done so we're not using up resources
        sound.release();
      });
    };
  }, [props.filePath]);

  return useMemo(
    () => (
      <View style={styles.container}>
        <Text style={{ marginTop: 20 }}>{props.filePath}</Text>
        <Text>Player State: {playing ? 'playing' : 'stop'}</Text>
        <View style={styles.actions}>
          <Button title="Play" color="#5E92F3" onPress={playSound} />
          {/*<Button title="Pause" color="#FFB04C" onPress={pause} />*/}
          {/*<Button title="Stop" color="#F05545" onPress={stop} />*/}
          {/*<Button title="Release" color="#F05545" onPress={release} />*/}
        </View>
      </View>
    ),
    [playSound, playing, props.filePath]
  );
};

const styles = StyleSheet.create({
  container: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  actions: {
    flexDirection: 'row',
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
    borderBottomColor: '#737373',
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  result: {
    minHeight: 50,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
