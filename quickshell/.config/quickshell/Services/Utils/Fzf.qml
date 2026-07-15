// Fzf for JavaScript (QML port for Quickshell)
// BSD 3-Clause License - Copyright (c) 2021, Ajit
pragma Singleton
import Quickshell

Singleton {
  id: root

  readonly property int asciiMax: 127
  readonly property int bonusBoundary: scoreMatch / 2
  readonly property int bonusCamelOrNumber: bonusBoundary + scoreGapExtension
  readonly property int bonusConsecutive: -(scoreGapStart + scoreGapExtension)
  readonly property int bonusFirstCharMultiplier: 2
  readonly property int bonusNonWord: scoreMatch / 2
  readonly property int capitalARune: 65
  readonly property int capitalZRune: 90
  readonly property int charClassLower: 1
  readonly property int charClassNonWord: 0
  readonly property int charClassNumber: 4
  readonly property int charClassUpper: 2
  readonly property int numeralNineRune: 57
  readonly property int numeralZeroRune: 48
  readonly property int scoreGapExtension: -1
  readonly property int scoreGapStart: -3
  readonly property int scoreMatch: 16
  readonly property int smallARune: 97
  readonly property int smallZRune: 122

  function asciiFuzzyIndex(inputRunes: var, patternRunes: var, caseSensitive: bool): int {
    if (patternRunes.length === 0)
      return 0;
    if (!root.isAscii(inputRunes) || !root.isAscii(patternRunes))
      return -1;

    let searchIndex = 0;
    let firstMatchStart = 0;
    for (let patternIndex = 0; patternIndex < patternRunes.length; patternIndex++) {
      searchIndex = root.trySkip(inputRunes, caseSensitive, patternRunes[patternIndex], searchIndex);
      if (searchIndex < 0)
        return -1;
      if (patternIndex === 0 && searchIndex > 0)
        firstMatchStart = searchIndex - 1;
      searchIndex++;
    }
    return firstMatchStart;
  }
  function bonusFor(previousClass: int, currentClass: int): int {
    if (previousClass === root.charClassNonWord && currentClass !== root.charClassNonWord)
      return root.bonusBoundary;
    if ((previousClass === root.charClassLower && currentClass === root.charClassUpper) || (previousClass !== root.charClassNumber && currentClass === root.charClassNumber))
      return root.bonusCamelOrNumber;
    return currentClass === root.charClassNonWord ? root.bonusNonWord : 0;
  }
  function byLengthAsc(leftMatch: var, rightMatch: var, selector: var): int {
    if (!selector)
      return 0;

    const leftLength = leftMatch?.item ? selector(leftMatch.item).length : 0;
    const rightLength = rightMatch?.item ? selector(rightMatch.item).length : 0;
    return leftLength - rightLength;
  }
  function byStartAsc(leftMatch: var, rightMatch: var): int {
    return (leftMatch?.start ?? 0) - (rightMatch?.start ?? 0);
  }
  function charClassOf(rune: int): int {
    if (rune <= root.asciiMax) {
      if (rune >= root.smallARune && rune <= root.smallZRune)
        return root.charClassLower;
      if (rune >= root.capitalARune && rune <= root.capitalZRune)
        return root.charClassUpper;
      if (rune >= root.numeralZeroRune && rune <= root.numeralNineRune)
        return root.charClassNumber;
      return root.charClassNonWord;
    }

    const character = String.fromCodePoint(rune);
    if (character !== character.toUpperCase())
      return root.charClassLower;
    if (character !== character.toLowerCase())
      return root.charClassUpper;
    return root.charClassNonWord;
  }
  function createFinder(list: var, options: var): var {
    const settings = Object.assign({
      limit: Infinity,
      selector: item => item,
      casing: "smart-case",
      sort: true,
      tiebreakers: []
    }, options || {});

    const finderInstance = {
      options: settings,
      items: Array.isArray(list) ? list : []
    };
    finderInstance.textByItem = finderInstance.items.map(item => String(settings.selector(item) ?? ""));
    finderInstance.runesByItem = finderInstance.textByItem.map(text => root.stringToRunes(text));
    finderInstance.find = query => root.find(finderInstance, String(query ?? ""));
    return finderInstance;
  }
  function emptyResult(item: var): var {
    return {
      item: item,
      start: -1,
      end: -1,
      score: 0,
      positions: new Set()
    };
  }
  function failedMatch(): var {
    return [
      {
        start: -1,
        end: -1,
        score: 0
      },
      null];
  }
  function find(finderInstance: var, query: string): var {
    const items = finderInstance.items;
    const options = finderInstance.options;
    if (query.length === 0 || items.length === 0)
      return items.slice(0, options.limit).map(item => root.emptyResult(item));

    const caseSensitive = options.casing === "case-sensitive" || (options.casing === "smart-case" && query !== query.toLowerCase());
    const patternRunes = root.stringToRunes(caseSensitive ? query : query.toLowerCase());
    const results = [];

    for (let itemIndex = 0; itemIndex < finderInstance.runesByItem.length; itemIndex++) {
      const inputRunes = finderInstance.runesByItem[itemIndex];
      if (patternRunes.length > inputRunes.length)
        continue;

      const [match, positions] = root.isAscii(inputRunes) && root.isAscii(patternRunes) ? root.fuzzyMatchV2(caseSensitive, inputRunes, patternRunes, true) : root.fuzzyMatchUnicode(caseSensitive, finderInstance.textByItem[itemIndex], query);
      if (match.start !== -1)
        results.push(Object.assign({
          item: items[itemIndex],
          positions: positions
        }, match));
    }

    if (options.sort)
      root.sortResults(results, options);
    return Number.isFinite(options.limit) ? results.slice(0, options.limit) : results;
  }
  function fuzzyMatchUnicode(caseSensitive: bool, inputText: string, patternText: string): var {
    // ponytail: Unicode fallback uses locale-aware subsequence scoring rather than
    // full fzf normalization. Upgrade only if localized ranking needs exact parity.
    const input = Array.from(caseSensitive ? inputText : inputText.toLocaleLowerCase());
    const pattern = Array.from(caseSensitive ? patternText : patternText.toLocaleLowerCase());
    if (pattern.length === 0)
      return [
        {
          start: 0,
          end: 0,
          score: 0
        },
        new Set()];

    const positions = new Set();
    let inputIndex = 0;
    let firstIndex = -1;
    let previousIndex = -2;
    let score = 0;

    for (const character of pattern) {
      while (inputIndex < input.length && input[inputIndex] !== character)
        inputIndex++;
      if (inputIndex >= input.length)
        return root.failedMatch();

      if (firstIndex < 0)
        firstIndex = inputIndex;
      const previousCharacter = inputIndex > 0 ? input[inputIndex - 1] : "";
      const atBoundary = inputIndex === 0 || previousCharacter.toLocaleUpperCase() === previousCharacter.toLocaleLowerCase();
      score += root.scoreMatch;
      if (inputIndex === previousIndex + 1)
        score += root.bonusConsecutive;
      else if (atBoundary)
        score += root.bonusBoundary;
      score += root.scoreGapExtension * Math.max(0, inputIndex - previousIndex - 1);
      positions.add(inputIndex);
      previousIndex = inputIndex;
      inputIndex++;
    }

    return [
      {
        start: firstIndex,
        end: previousIndex + 1,
        score
      },
      positions];
  }
  function fuzzyMatchV2(caseSensitive: bool, input: var, pattern: var, withPositions: bool): var {
    const inputRunes = Array.isArray(input) ? input : [];
    const patternRunes = Array.isArray(pattern) ? pattern : [];
    const patternLength = patternRunes.length;
    if (patternLength === 0)
      return [
        {
          start: 0,
          end: 0,
          score: 0
        },
        withPositions ? new Set() : null];

    const inputLength = inputRunes.length;
    const matchStart = root.asciiFuzzyIndex(inputRunes, patternRunes, caseSensitive);
    if (matchStart < 0)
      return root.failedMatch();

    const firstRowScores = new Int16Array(inputLength);
    const firstRowConsecutive = new Int16Array(inputLength);
    const bonuses = new Int16Array(inputLength);
    const firstMatchByPattern = new Int32Array(patternLength);
    const normalizedRunes = new Int32Array(inputRunes);
    const firstPatternRune = patternRunes[0];
    let currentPatternRune = firstPatternRune;
    let maxScore = 0;
    let maxScoreIndex = 0;
    let patternIndex = 0;
    let lastMatchIndex = 0;
    let previousClass = root.charClassNonWord;
    let previousScore = 0;
    let inGap = false;

    for (let inputIndex = matchStart; inputIndex < normalizedRunes.length; inputIndex++) {
      let inputRune = normalizedRunes[inputIndex];
      const currentClass = root.charClassOf(inputRune);
      if (!caseSensitive && currentClass === root.charClassUpper)
        inputRune += 32;

      normalizedRunes[inputIndex] = inputRune;
      bonuses[inputIndex] = root.bonusFor(previousClass, currentClass);
      previousClass = currentClass;

      if (inputRune === currentPatternRune && patternIndex < patternLength) {
        firstMatchByPattern[patternIndex] = inputIndex;
        patternIndex++;
        currentPatternRune = patternRunes[Math.min(patternIndex, patternLength - 1)];
        lastMatchIndex = inputIndex;
      }

      if (inputRune === firstPatternRune) {
        const score = root.scoreMatch + bonuses[inputIndex] * root.bonusFirstCharMultiplier;
        firstRowScores[inputIndex] = score;
        firstRowConsecutive[inputIndex] = 1;
        if (patternLength === 1 && score > maxScore) {
          maxScore = score;
          maxScoreIndex = inputIndex;
          if (bonuses[inputIndex] === root.bonusBoundary)
            break;
        }
        inGap = false;
      } else {
        firstRowScores[inputIndex] = Math.max(previousScore + (inGap ? root.scoreGapExtension : root.scoreGapStart), 0);
        firstRowConsecutive[inputIndex] = 0;
        inGap = true;
      }
      previousScore = firstRowScores[inputIndex];
    }

    if (patternIndex !== patternLength)
      return root.failedMatch();
    if (patternLength === 1)
      return root.singleRuneMatch(maxScoreIndex, maxScore, withPositions);

    return root.scoreMultiRuneMatch(patternRunes, normalizedRunes, bonuses, firstRowScores, firstRowConsecutive, firstMatchByPattern, lastMatchIndex, maxScore, maxScoreIndex, withPositions);
  }
  function isAscii(runes: var): bool {
    return runes.every(rune => rune < 128);
  }
  function scoreMultiRuneMatch(patternRunes: var, inputRunes: var, bonuses: var, firstRowScores: var, firstRowConsecutive: var, firstMatchByPattern: var, lastMatchIndex: int, initialMaxScore: int, initialMaxScoreIndex: int, withPositions: bool): var {
    const patternLength = patternRunes.length;
    const firstMatchIndex = firstMatchByPattern[0];
    const matrixWidth = lastMatchIndex - firstMatchIndex + 1;
    const scores = new Int16Array(matrixWidth * patternLength);
    const consecutiveMatches = new Int16Array(matrixWidth * patternLength);
    let maxScore = initialMaxScore;
    let maxScoreIndex = initialMaxScoreIndex;

    scores.set(firstRowScores.subarray(firstMatchIndex, lastMatchIndex + 1));
    consecutiveMatches.set(firstRowConsecutive.subarray(firstMatchIndex, lastMatchIndex + 1));

    for (let patternIndex = 1; patternIndex < patternLength; patternIndex++) {
      const firstInputIndex = firstMatchByPattern[patternIndex];
      const patternRune = patternRunes[patternIndex];
      const rowOffset = patternIndex * matrixWidth;
      let inGap = false;

      for (let relativeIndex = 0; relativeIndex < lastMatchIndex - firstInputIndex + 1; relativeIndex++) {
        const inputIndex = relativeIndex + firstInputIndex;
        const cellIndex = rowOffset + inputIndex - firstMatchIndex;
        const leftScore = (relativeIndex > 0 ? scores[cellIndex - 1] : 0) + (inGap ? root.scoreGapExtension : root.scoreGapStart);
        let diagonalScore = 0;
        let consecutive = 0;

        if (patternRune === inputRunes[inputIndex]) {
          const previousCellIndex = rowOffset - matrixWidth + inputIndex - firstMatchIndex - 1;
          diagonalScore = scores[previousCellIndex] + root.scoreMatch;
          consecutive = consecutiveMatches[previousCellIndex] + 1;

          let bonus = bonuses[inputIndex];
          if (bonus === root.bonusBoundary)
            consecutive = 1;
          else if (consecutive > 1)
            bonus = Math.max(bonus, Math.max(root.bonusConsecutive, bonuses[inputIndex - consecutive + 1]));

          diagonalScore += diagonalScore + bonus < leftScore ? bonuses[inputIndex] : bonus;
        }

        consecutiveMatches[cellIndex] = consecutive;
        inGap = diagonalScore < leftScore;
        scores[cellIndex] = Math.max(Math.max(diagonalScore, leftScore), 0);
        if (patternIndex === patternLength - 1 && scores[cellIndex] > maxScore) {
          maxScore = scores[cellIndex];
          maxScoreIndex = inputIndex;
        }
      }
    }

    const positions = withPositions ? root.tracePositions(scores, firstMatchByPattern, patternLength, matrixWidth, firstMatchIndex, maxScoreIndex) : null;
    return [
      {
        start: firstMatchIndex,
        end: maxScoreIndex + 1,
        score: maxScore
      },
      positions];
  }
  function singleRuneMatch(maxScoreIndex: int, maxScore: int, withPositions: bool): var {
    return [
      {
        start: maxScoreIndex,
        end: maxScoreIndex + 1,
        score: maxScore
      },
      withPositions ? new Set([maxScoreIndex]) : null];
  }
  function sortResults(results: var, options: var): void {
    results.sort((leftMatch, rightMatch) => {
      if (leftMatch.score !== rightMatch.score)
        return rightMatch.score - leftMatch.score;

      for (const tiebreaker of options.tiebreakers) {
        const difference = tiebreaker(leftMatch, rightMatch, options.selector);
        if (difference !== 0)
          return difference;
      }
      return 0;
    });
  }
  function stringToRunes(text: var): var {
    const runes = [];
    const source = String(text ?? "");
    for (let inputIndex = 0; inputIndex < source.length; inputIndex++) {
      const codePoint = source.codePointAt(inputIndex);
      runes.push(codePoint);
      if (codePoint > 0xffff)
        inputIndex++;
    }
    return runes;
  }
  function tracePositions(scores: var, firstMatchByPattern: var, patternLength: int, matrixWidth: int, firstMatchIndex: int, maxScoreIndex: int): var {
    const positions = new Set();
    let patternIndex = patternLength - 1;
    let inputIndex = maxScoreIndex;

    while (patternIndex >= 0 && inputIndex >= firstMatchIndex) {
      const rowOffset = patternIndex * matrixWidth;
      const relativeIndex = inputIndex - firstMatchIndex;
      const score = scores[rowOffset + relativeIndex];
      const diagonalScore = patternIndex > 0 && inputIndex >= firstMatchByPattern[patternIndex] ? scores[rowOffset - matrixWidth + relativeIndex - 1] : 0;
      const leftScore = inputIndex > firstMatchByPattern[patternIndex] ? scores[rowOffset + relativeIndex - 1] : 0;

      if (score > diagonalScore && score > leftScore) {
        positions.add(inputIndex);
        if (patternIndex === 0)
          break;
        patternIndex--;
      }
      inputIndex--;
    }
    return positions;
  }
  function trySkip(inputRunes: var, caseSensitive: bool, rune: int, startIndex: int): int {
    const upperRune = !caseSensitive && rune >= root.smallARune && rune <= root.smallZRune ? rune - 32 : -1;
    for (let inputIndex = startIndex; inputIndex < inputRunes.length; inputIndex++) {
      if (inputRunes[inputIndex] === rune || inputRunes[inputIndex] === upperRune)
        return inputIndex;
    }
    return -1;
  }
}
