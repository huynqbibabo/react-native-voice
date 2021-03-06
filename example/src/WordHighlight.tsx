import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import type { WordScore } from 'react-native-voice';

type Props = {
  words: WordScore[];
};

const getColorByScore = (score: number): string => {
  return score < 70
    ? '#F44336'
    : score > 70 && score < 80
    ? '#F2994A'
    : '#009FE0';
};

const WordHighlight: React.FunctionComponent<Props> = (props) => {
  return (
    <View style={styles.container}>
      {props.words?.map((word, index) => {
        return (
          <Text
            key={word.word + index}
            style={[styles.text, { color: getColorByScore(word.qualityScore) }]}
          >
            {word.word}{' '}
          </Text>
        );
      })}
    </View>
  );
};

export default WordHighlight;

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    width: '100%',
    flexWrap: 'wrap',
    paddingTop: 16,
  },
  text: {
    fontWeight: 'bold',
    fontSize: 18,
    lineHeight: 21,
    flexWrap: 'wrap',
  },
});
