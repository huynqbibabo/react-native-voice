package com.reactnativevoice

import android.util.Log
import java.util.*
import kotlin.collections.ArrayList
import kotlin.collections.HashMap

internal class Levenshtein(private val sentenceToScore: String, private val recognitionResults: ArrayList<String>) {
  private var sentencesToScore: Text
  private var results = mutableListOf<Text>()

  init {
    sentencesToScore = toArrayWithDuplicateWordsCount(sentenceToScore)
    for (partialTextResult in recognitionResults) {
      val partialResult = toArrayWithDuplicateWordsCount(partialTextResult)
      results.add(partialResult)
    }
  }

  fun scoreSentence(): MutableList<LevenshteinWord> {
    val sentenceScoreList = mutableListOf<LevenshteinWord>()
    for (i in sentencesToScore.text.indices) {
      val wordsScore = mutableListOf<WordScore>()
      for (j in results.indices) {
        val word = getMostSimilarWordByLevenshteinDistance(sentencesToScore.text[i], results[j].text)
//        val paragraph = paragraphs[i]
//        if (word != null) {
//          paragraph.removeAt(word.positionInWordList)
//        }
//        paragraphs[i] = paragraph
        wordsScore.add(word)
      }
      val highestScore = getWordByHighestScore(sentencesToScore.text[i], wordsScore)
      sentenceScoreList.add(LevenshteinWord(highestScore, i))
    }
    Log.i(TAG, "scoreByLevenshteinDistance: $sentenceScoreList")

    return sentenceScoreList
  }

  fun getMostSimilarWordByLevenshteinDistance(sentence: Word, wordsListToScore: MutableList<Word>): WordScore {
    val wordScoreList = mutableListOf<WordScore>()
    for (i in wordsListToScore.indices) {
      val wordScore = scoreByLevenshteinDistance(sentence, wordsListToScore[i])
      wordScoreList.add(wordScore)
    }
    return getWordByHighestScore(sentence, wordScoreList)
  }

  private fun getWordByHighestScore(sentence: Word, words: MutableList<WordScore>): WordScore {
    var wordHighestScore: WordScore? = null
    for (word in words) {
      if (wordHighestScore != null) {
//          if (
//            wordHighestScore.percentageOfTextMatch < word.percentageOfTextMatch
//          ) {
//            wordHighestScore = word
//          } else
        if (
          word.percentageOfTextMatch >= wordHighestScore.percentageOfTextMatch
//            wordHighestScore.levenshteinDistance > word.levenshteinDistance
        ) {
          wordHighestScore = word
        }
      } else if (word.levenshteinDistance != word.word.length) {
        wordHighestScore = word
      }
    }
//    if (wordByHighestScore.wordScore.levenshteinDistance )
    if (wordHighestScore == null || (wordHighestScore.levenshteinDistance * 100) / sentence.word.length >= 75) {
      wordHighestScore = WordScore(sentence.word, "", sentence.word.length, 0)
    }
    return wordHighestScore
  }

  /**
   * compare two word by levenshtein distance and percentage of text march
   */
  private fun scoreByLevenshteinDistance(sentence: Word, word: Word): WordScore {
    val levenshteinScore = levenshteinDistance(sentence.word, word.word)
    val score = percentageOfTextMatch(sentence.word, word.word)
    Log.i(TAG, "word: ${sentence.word}, transcript: ${word.word} levenshteinScore: $levenshteinScore, qualityScore: $score")
    return WordScore(sentence.letters, word.word, levenshteinScore, score)
  }

  /**
   * Percentage of Sentence Match :
   * It separates two Texts into Sentences and it will give result of that sentences matching
   */
  private fun percentageOfSentenceMatch(s0: String, s1: String): Int {
    // Trim and Replace all . ? ! with ". " to make easy to split to sentences
    var s0 = s0
    var s1 = s1
    s0 = s0.trim { it <= ' ' }.replace("[.?!]".toRegex(), ". ")
    s1 = s1.trim { it <= ' ' }.replace("[.?!]".toRegex(), ". ")
    //Split by ". "
    val as0 = s0.split("(?i)(?<=[.])\\s+(?=[a-zA-Z])".toRegex()).toTypedArray()
    val as1 = s1.split("(?i)(?<=[.])\\s+(?=[a-zA-Z])".toRegex()).toTypedArray()
    return percentageOfMatch(as0, as1)
  }

  /**
   * Percentage of Word Match :
   * It separates two sentences into words and it will give result of that words matching
   */
  private fun percentageOfWordMatch(s0: String, s1: String): Int {
    // Trim and Replace all . ? ! with spaces to make easy to split to words
    var s0 = s0
    var s1 = s1
    s0 = s0.trim { it <= ' ' }.replace("[.?!]".toRegex(), " ")
    s1 = s1.trim { it <= ' ' }.replace("[.?!]".toRegex(), " ")
    //Split by space
    val as0 = s0.split(" ".toRegex()).toTypedArray()
    val as1 = s1.split(" ".toRegex()).toTypedArray()
    return percentageOfMatch(as0, as1)
  }

  /**
   * Percentage of Match between array of Strings
   * Get as0, as1 (arrary of Strings)
   * Calculate String frequency of as0, as1 with HashMaps hm0, hm1
   * Calculate frequency difference of hm0, hm1 with diff HashMap
   * Calculate total frequency difference ( Summation of  diff frequencies and hm1 frequencies)
   * Calculate percentage of  match
   */
  private fun percentageOfMatch(as0: Array<String>, as1: Array<String>): Int {
    var n = as0.size
    var temp: Int? = null

    // String frequency of as0
    val hm0 = HashMap<String, Int>()
    for (i in 0 until n) {
      temp = hm0[as0[i]]
      if (temp == null) {
        hm0[as0[i]] = 1
      } else {
        hm0[as0[i]] = temp.toInt() + 1
      }
    }

    // String frequency of as1
    n = as1.size
    val hm1 = HashMap<String, Int>()
    for (i in 0 until n) {
      temp = hm1[as1[i]]
      if (temp == null) {
        hm1[as1[i]] = 1
      } else {
        hm1[as1[i]] = temp.toInt() + 1
      }
    }

    // Frequency difference between hm0 and hm1 to diff
    val diff = HashMap<String, Int>()
    var key: String
    var value: Int
    var value1: Int?
    var rval: Int
    var it: MutableIterator<*> = hm0.entries.iterator()
//    var it: MutableIterator<*> = hm0.entrySet().iterator()
    while (it.hasNext()) {
      val pairs = it
        .next() as Map.Entry<*, *>
      key = pairs.key as String
      value = pairs.value as Int
      value1 = hm1[key]
      it.remove()
      hm1.remove(key)
      rval = if (value1 != null) Math.abs(value1.toInt()
        - value) else value
      diff[key] = rval
    }

    // Sum all remaining String frequencies in hm1
    var `val` = 0
    it = hm1.entries.iterator()
    while (it.hasNext()) {
      val pairs = it
        .next() as Map.Entry<String, Int>
      `val` += pairs.value
    }

    // Sum all frequencies in diff
    it = diff.entries.iterator()
    while (it.hasNext()) {
      val pairs = it
        .next() as Map.Entry<String, Int>
      `val` += pairs.value
    }

    // Calculate word match percentage
    var per = (`val`.toFloat() * 100 / (as0.size + as1.size).toFloat()).toInt()
    per = 100 - per
    return per
  }

  /**
   * Percentage of Text Match
   */
  private fun percentageOfTextMatch(s0: String, s1: String): Int {
    var s0 = s0
    var s1 = s1
    var percentage = 0
    // Trim and remove duplicate spaces
    s0 = s0.trim { it <= ' ' }.replace("\\s+".toRegex(), " ")
    s1 = s1.trim { it <= ' ' }.replace("\\s+".toRegex(), " ")
    percentage = (100 - levenshteinDistance(s0, s1).toFloat() * 100 / (s0.length + s1.length).toFloat()).toInt()
    return percentage
  }

  /**
   * Method to find Levenshtein Distance
   */
  private fun levenshteinDistance(s0: String, s1: String): Int {
    val len0 = s0.length + 1
    val len1 = s1.length + 1

    // the array of distances
    var cost = IntArray(len0)
    var newcost = IntArray(len0)

    // initial cost of skipping prefix in String s0
    for (i in 0 until len0) cost[i] = i

    // dynamicaly computing the array of distances

    // transformation cost for each letter in s1
    for (j in 1 until len1) {

      // initial cost of skipping prefix in String s1
      newcost[0] = j - 1

      // transformation cost for each letter in s0
      for (i in 1 until len0) {

        // matching current letters in both strings
        val match = if (s0[i - 1] == s1[j - 1]) 0 else 1

        // computing cost for each transformation
        val costReplace = cost[i - 1] + match
        val costInsert = cost[i] + 1
        val costDelete = newcost[i - 1] + 1

        // keep minimum cost
        newcost[i] = Math.min(Math.min(costInsert, costDelete),
          costReplace)
      }

      // swap cost/newcost arrays
      val swap = cost
      cost = newcost
      newcost = swap
    }

    // the distance is the cost for transforming all letters in both strings
    return cost[len0 - 1]
  }

  private fun toArrayWithDuplicateWordsCount(string: String): Text {
    val words = string.split(" ".toRegex()).toMutableList()
    val result = mutableListOf<Word>()
    for (i in words.indices) {
      var count = 0
      for (j in 0 until words.size) {
        if (words[i] == words[j]) {
          count++
        }
      }
      var word = words[i].replace(Regex("[\\^.?:!,@#\$%&*()_+\\-=\"\\/|\\\\><`~{}\\[\\];]"), "")
      word = word.trim { it <= ' ' }.replace("\\s+".toRegex(), "")
      //Displays the duplicate word if count is greater than 1
      result.add(Word(word.toLowerCase(Locale.ROOT), words[i], count))
    }
    return Text(result, result.size)
  }

  data class Word(var word: String, var letters: String, var count: Int)
  data class Text(val text: MutableList<Word>, var length: Int)
  data class WordScore(var word: String, var transcript: String, var levenshteinDistance: Int, var percentageOfTextMatch: Int)
  data class LevenshteinWord(var wordScore: WordScore?, var positionInWordList: Int)
  companion object {
    private const val TAG = "LEVENSHTEIN"
  }

}
