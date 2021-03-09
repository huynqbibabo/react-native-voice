import Speecher from 'react-native-voice';
import React, { useCallback, useEffect, useState } from 'react';
import {
  Button,
  FlatList,
  PermissionsAndroid,
  SafeAreaView,
  StyleSheet,
  View,
} from 'react-native';
import { Item } from './Item';

const App = () => {
  useEffect(() => {
    PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.RECORD_AUDIO, {
      title: 'Cool Photo App Camera Permission',
      message:
        'Cool Photo App needs access to your camera ' +
        'so you can take awesome pictures.',
      buttonNeutral: 'Ask Me Later',
      buttonNegative: 'Cancel',
      buttonPositive: 'OK',
    });
    PermissionsAndroid.request(
      PermissionsAndroid.PERMISSIONS.READ_EXTERNAL_STORAGE,
      {
        title: 'Cool Photo App Camera Permission',
        message:
          'Cool Photo App needs access to your camera ' +
          'so you can take awesome pictures.',
        buttonNeutral: 'Ask Me Later',
        buttonNegative: 'Cancel',
        buttonPositive: 'OK',
      }
    );

    PermissionsAndroid.request(
      PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE,
      {
        title: 'Cool Photo App Camera Permission',
        message:
          'Cool Photo App needs access to your camera ' +
          'so you can take awesome pictures.',
        buttonNeutral: 'Ask Me Later',
        buttonNegative: 'Cancel',
        buttonPositive: 'OK',
      }
    );
  }, []);

  const [files] = useState<any[]>([
    {
      text: 'Cool Photo App needs access to your camera',
    },
    {
      text: 'This is beta functionality.',
    },
    {
      text: 'pictures',
    },
  ]);

  const getservices = useCallback(async () => {
    const services = await Speecher.getSpeechRecognitionServices();
    console.log(services);
  }, []);
  // const [state, setState] = useState<any[]>([]);
  useEffect(() => {
    Speecher.isAvailable().then((result) => console.log(result));
    getservices();
    return () => {
      Speecher.release();
    };
  }, [getservices]);

  const clear = async () => {
    // await Speecher.clear();
  };

  return (
    <SafeAreaView style={styles.container}>
      <View>
        <Button title="Clear all" onPress={clear} color={'#4F83CC'} />
      </View>
      <FlatList
        // extraData={state.length}
        style={{ flex: 1 }}
        data={files}
        keyExtractor={(_item, index) => index + ''}
        renderItem={({ item }) => <Item text={item.text} />}
      />
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    marginHorizontal: 16,
  },
});

export default App;
