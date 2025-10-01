// Fzf for JavaScript (QML port for Quickshell)
/*
https://github.com/ajitid/fzf-for-js

BSD 3-Clause License

Copyright (c) 2021, Ajit
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
pragma Singleton
import QtQuick

QtObject {
  id: fzf

  readonly property int bonus_boundary: score_match / 2
  readonly property int bonus_camel_123: bonus_boundary + score_gap_extention
  readonly property int bonus_consecutive: -(score_gap_start + score_gap_extention)
  readonly property int bonus_first_char_multiplier: 2
  readonly property int bonus_non_word: score_match / 2
  readonly property int capital_a_rune: "A".codePointAt(0)
  readonly property int capital_z_rune: "Z".codePointAt(0)

  // default options
  readonly property var default_opts: ({
      limit: Infinity,
      selector: function (v) {
        return v;
      },
      casing: "smart-case",
      normalize: true,
      fuzzy: "v2",
      tiebreakers: [],
      sort: true,
      forward: true,
      match: basic_match
    })

  // BSD 3-Clause License — Copyright (c) 2021, Ajit
  // Original project: https://github.com/ajitid/fzf-for-js
  // Ported to QML Singleton with lower-case properties and functions for Quickshell.

  // ----------------------
  // rune constants
  // ----------------------
  readonly property int max_ascii: "\x7F".codePointAt(0)

  // ----------------------
  // normalized mapping
  // Build base map into a compact Uint16Array of code points, then augment with combining diacritics and extra ranges
  // ----------------------
  readonly property var normalized: (function () {
      const MAX_CP = 8580;
      const a = new Uint16Array(MAX_CP + 1);
      const n = {
        216: "O",
        223: "s",
        248: "o",
        273: "d",
        295: "h",
        305: "i",
        320: "l",
        322: "l",
        359: "t",
        383: "s",
        384: "b",
        385: "B",
        387: "b",
        390: "O",
        392: "c",
        393: "D",
        394: "D",
        396: "d",
        398: "E",
        400: "E",
        402: "f",
        403: "G",
        407: "I",
        409: "k",
        410: "l",
        412: "M",
        413: "N",
        414: "n",
        415: "O",
        421: "p",
        427: "t",
        429: "t",
        430: "T",
        434: "V",
        436: "y",
        438: "z",
        477: "e",
        485: "g",
        544: "N",
        545: "d",
        549: "z",
        564: "l",
        565: "n",
        566: "t",
        567: "j",
        570: "A",
        571: "C",
        572: "c",
        573: "L",
        574: "T",
        575: "s",
        576: "z",
        579: "B",
        580: "U",
        581: "V",
        582: "E",
        583: "e",
        584: "J",
        585: "j",
        586: "Q",
        587: "q",
        588: "R",
        589: "r",
        590: "Y",
        591: "y",
        592: "a",
        593: "a",
        595: "b",
        596: "o",
        597: "c",
        598: "d",
        599: "d",
        600: "e",
        603: "e",
        604: "e",
        605: "e",
        606: "e",
        607: "j",
        608: "g",
        609: "g",
        610: "G",
        613: "h",
        614: "h",
        616: "i",
        618: "I",
        619: "l",
        620: "l",
        621: "l",
        623: "m",
        624: "m",
        625: "m",
        626: "n",
        627: "n",
        628: "N",
        629: "o",
        633: "r",
        634: "r",
        635: "r",
        636: "r",
        637: "r",
        638: "r",
        639: "r",
        640: "R",
        641: "R",
        642: "s",
        647: "t",
        648: "t",
        649: "u",
        651: "v",
        652: "v",
        653: "w",
        654: "y",
        655: "Y",
        656: "z",
        657: "z",
        663: "c",
        665: "B",
        666: "e",
        667: "G",
        668: "H",
        669: "j",
        670: "k",
        671: "L",
        672: "q",
        686: "h",
        867: "a",
        868: "e",
        869: "i",
        870: "o",
        871: "u",
        872: "c",
        873: "d",
        874: "h",
        875: "m",
        876: "r",
        877: "t",
        878: "v",
        879: "x",
        7424: "A",
        7427: "B",
        7428: "C",
        7429: "D",
        7431: "E",
        7432: "e",
        7433: "i",
        7434: "J",
        7435: "K",
        7436: "L",
        7437: "M",
        7438: "N",
        7439: "O",
        7440: "O",
        7441: "o",
        7442: "o",
        7443: "o",
        7446: "o",
        7447: "o",
        7448: "P",
        7449: "R",
        7450: "R",
        7451: "T",
        7452: "U",
        7453: "u",
        7454: "u",
        7455: "m",
        7456: "V",
        7457: "W",
        7458: "Z",
        7522: "i",
        7523: "r",
        7524: "u",
        7525: "v",
        7834: "a",
        7835: "s",
        8305: "i",
        8341: "h",
        8342: "k",
        8343: "l",
        8344: "m",
        8345: "n",
        8346: "p",
        8347: "s",
        8348: "t",
        8580: "c"
      };
      // Seed base table (store integer code points)
      for (const k in n) {
        if (Object.prototype.hasOwnProperty.call(n, k)) {
          const ki = parseInt(k, 10);
          const cp = n[k].codePointAt(0);
          if (ki >= 0 && ki <= MAX_CP)
            a[ki] = cp;
        }
      }
      for (let i = "\u0300".codePointAt(0); i <= "\u036F".codePointAt(0); ++i) {
        const di = String.fromCodePoint(i);
        for (const asciiChar of "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz") {
          const withD = (asciiChar + di).normalize();
          const cp = withD.codePointAt(0);
          if (cp > 126 && cp <= MAX_CP) {
            a[cp] = asciiChar.codePointAt(0);
          }
        }
      }
      const ranges = {
        a: [7844, 7863],
        e: [7870, 7879],
        o: [7888, 7907],
        u: [7912, 7921]
      };
      for (const lowerChar of Object.keys(ranges)) {
        const upperChar = lowerChar.toUpperCase();
        for (let i = ranges[lowerChar][0]; i <= ranges[lowerChar][1]; ++i) {
          if (i <= MAX_CP)
            a[i] = (i % 2 === 0 ? upperChar : lowerChar).codePointAt(0);
        }
      }
      return a;
    })()
  readonly property int numeral_nine_rune: "9".codePointAt(0)
  readonly property int numeral_zero_rune: "0".codePointAt(0)
  readonly property int score_gap_extention: -1
  readonly property int score_gap_start: -3

  // ----------------------
  // scoring constants
  // ----------------------
  readonly property int score_match: 16

  // ----------------------
  // slab
  // ----------------------
  readonly property var slab: ({
      i16: new Int16Array(slab_16_size),
      i32: new Int32Array(slab_32_size)
    })

  // ----------------------
  // slab sizes
  // ----------------------
  readonly property int slab_16_size: 100 * 1024
  readonly property int slab_32_size: 2048
  readonly property int small_a_rune: "a".codePointAt(0)
  readonly property int small_z_rune: "z".codePointAt(0)

  // term type map
  readonly property var term_type_map: ({
      0: fuzzy_match_v2,
      1: exact_match_naive,
      2: prefix_match,
      3: suffix_match,
      4: equal_match
    })

  // ----------------------
  // whitespace runes set
  // ----------------------
  readonly property var whitespace_runes: (function () {
      const s = new Set(" \f\n\r\t\v\xA0\u1680\u2028\u2029\u202F\u205F\u3000\uFEFF".split("").map(v => v.codePointAt(0)));
      for (let codePoint = "\u2000".codePointAt(0); codePoint <= "\u200A".codePointAt(0); codePoint++) {
        s.add(codePoint);
      }
      return s;
    })()

  function _basic_match(ctx, query) {
    const {
      queryRunes,
      caseSensitive
    } = build_pattern_for_basic_match(query, ctx.opts.casing, ctx.opts.normalize);
    const scoreMap = {};
    const iter2 = _get_basic_match_iter(ctx, scoreMap, queryRunes, caseSensitive);
    const len = ctx.runesList.length;
    for (let i = 0; i < len; ++i)
      iter2(i);
    return get_result_from_score_map(scoreMap, ctx.opts.limit);
  }
  function _extended_match(ctx, query) {
    const pattern = build_pattern_for_extended_match(Boolean(ctx.opts.fuzzy), ctx.opts.casing, ctx.opts.normalize, query);
    const scoreMap = {};
    const iter2 = _get_extended_match_iter(ctx, scoreMap, pattern);
    const len = ctx.runesList.length;
    for (let i = 0; i < len; ++i)
      iter2(i);
    return get_result_from_score_map(scoreMap, ctx.opts.limit);
  }
  function _get_basic_match_iter(ctx, scoreMap, queryRunes, caseSensitive) {
    return function (idx) {
      const itemRunes = ctx.runesList[idx];
      if (queryRunes.length > itemRunes.length)
        return;
      let [match, positions] = ctx.algoFn(caseSensitive, ctx.opts.normalize, ctx.opts.forward, itemRunes, queryRunes, true, slab);
      if (match.start === -1)
        return;
      if (ctx.opts.fuzzy === false) {
        positions = new Set();
        for (let position = match.start; position < match.end; ++position)
          positions.add(position);
      }
      const scoreKey = ctx.opts.sort ? match.score : 0;
      if (scoreMap[scoreKey] === undefined)
        scoreMap[scoreKey] = [];
      scoreMap[scoreKey].push(Object.assign({
        item: ctx.items[idx],
        positions: positions != null ? positions : new Set()
      }, match));
    };
  }
  function _get_extended_match_iter(ctx, scoreMap, pattern) {
    return function (idx) {
      const runes = ctx.runesList[idx];
      const match = compute_extended_match(runes, pattern, ctx.algoFn, ctx.opts.forward);
      if (match.offsets.length !== pattern.termSets.length)
        return;

      let sidx = -1, eidx = -1;
      if (match.allPos.size > 0) {
        sidx = Math.min(...match.allPos);
        eidx = Math.max(...match.allPos) + 1;
      }
      const scoreKey = ctx.opts.sort ? match.totalScore : 0;
      if (scoreMap[scoreKey] === undefined)
        scoreMap[scoreKey] = [];
      scoreMap[scoreKey].push({
        score: match.totalScore,
        item: ctx.items[idx],
        positions: match.allPos,
        start: sidx,
        end: eidx
      });
    };
  }
  function alloc16(offset, slab2, size) {
    // Avoid optional slab reuse to satisfy static analyzer; using fresh array is fine here
    return [offset + size, new Int16Array(size)];
  }
  function alloc32(offset, slab2, size) {
    // Avoid optional slab reuse to satisfy static analyzer; using fresh array is fine here
    return [offset + size, new Int32Array(size)];
  }
  function ascii_fuzzy_index(input, pattern, caseSensitive) {
    input = Array.isArray(input) ? input : [];
    pattern = Array.isArray(pattern) ? pattern : [];
    if (!is_ascii(input))
      return 0;
    if (!is_ascii(pattern))
      return -1;
    let firstIdx = 0, idx = 0;
    for (let pidx = 0; pidx < pattern.length; pidx++) {
      idx = try_skip(input, caseSensitive, pattern[pidx], idx);
      if (idx < 0)
        return -1;
      if (pidx === 0 && idx > 0)
        firstIdx = idx - 1;
      idx++;
    }
    return firstIdx;
  }
  function basic_match(query) {
    return _basic_match(this, query);
  }
  function bonus_at(input, idx) {
    if (idx === 0)
      return bonus_boundary;
    return bonus_for(char_class_of(input[idx - 1]), char_class_of(input[idx]));
  }
  function bonus_for(prevClass, currClass) {
    if (prevClass === 0 && currClass !== 0)
      return bonus_boundary;
    else if ((prevClass === 1 && currClass === 2) || (prevClass !== 4 && currClass === 4))
      return bonus_camel_123;
    else if (currClass === 0)
      return bonus_non_word;
    return 0;
  }
  function build_pattern_for_basic_match(query, casing, normalize) {
    let caseSensitive = false;
    switch (casing) {
    case "smart-case":
      if (query.toLowerCase() !== query)
        caseSensitive = true;
      break;
    case "case-sensitive":
      caseSensitive = true;
      break;
    case "case-insensitive":
      query = query.toLowerCase();
      caseSensitive = false;
      break;
    }
    let queryRunes = str_to_runes(query);
    if (normalize)
      queryRunes = queryRunes.map(normalize_rune);
    return {
      queryRunes,
      caseSensitive
    };
  }
  function build_pattern_for_extended_match(fuzzy, caseMode, normalize, str) {
    let cacheable = true;
    // Robust trimStart/trimEnd with fallbacks for older Qt JS engines
    if (typeof str !== "string")
      str = String(str || "");
    str = (str.trimStart ? str.trimStart() : str.replace(/^\s+/, ""));
    {
      const trimmedAtRightStr = (str.trimEnd ? str.trimEnd() : str.replace(/\s+$/, ""));
      // Fix for trailing backslash handling (escaped properly)
      if (trimmedAtRightStr.endsWith("\\") && str[trimmedAtRightStr.length] === " ") {
        str = trimmedAtRightStr + " ";
      } else {
        str = trimmedAtRightStr;
      }
    }
    let sortable = false;
    let termSets = parse_terms(fuzzy, caseMode, normalize, str);
    Loop: for (const termSet of termSets) {
      for (const [idx, term] of termSet.entries()) {
        if (!term.inv)
          sortable = true;
        if (!cacheable || idx > 0 || term.inv || (fuzzy && term.typ !== 0) || (!fuzzy && term.typ !== 1)) {
          cacheable = false;
          if (sortable)
            break Loop;
        }
      }
    }
    return {
      str,
      termSets,
      sortable,
      cacheable,
      fuzzy
    };
  }
  function by_length_asc(a, b, selector) {
    a = a || {
      item: ""
    };
    b = b || {
      item: ""
    };
    const ai = a.item;
    const bi = b.item;
    const al = (ai !== undefined && selector) ? selector(ai).length : 0;
    const bl = (bi !== undefined && selector) ? selector(bi).length : 0;
    return al - bl;
  }
  function by_start_asc(a, b) {
    a = a || {
      start: 0
    };
    b = b || {
      start: 0
    };
    const as = typeof a.start === "number" ? a.start : 0;
    const bs = typeof b.start === "number" ? b.start : 0;
    return as - bs;
  }
  function calculate_score(caseSensitive, normalize, text, pattern, sidx, eidx, withPos) {
    let pidx = 0, score = 0, inGap = false, consecutive = 0, firstBonus = to_short(0);
    const pos = create_pos_set(withPos);
    let prevCharClass = 0;
    if (sidx > 0)
      prevCharClass = char_class_of(text[sidx - 1]);

    for (let idx = sidx; idx < eidx; idx++) {
      let rune = text[idx];
      const charClass = char_class_of(rune);

      if (!caseSensitive) {
        if (rune >= capital_a_rune && rune <= capital_z_rune)
          rune += 32;
        else if (rune > max_ascii)
          rune = String.fromCodePoint(rune).toLowerCase().codePointAt(0);
      }
      if (normalize)
        rune = normalize_rune(rune);

      if (rune === pattern[pidx]) {
        if (withPos && pos !== null)
          pos.add(idx);
        score += score_match;
        let bonus = bonus_for(prevCharClass, charClass);
        if (consecutive === 0) {
          firstBonus = bonus;
        } else {
          if (bonus === bonus_boundary)
            firstBonus = bonus;
          bonus = max_int16(max_int16(bonus, firstBonus), bonus_consecutive);
        }
        if (pidx === 0)
          score += bonus * bonus_first_char_multiplier;
        else
          score += bonus;

        inGap = false;
        consecutive++;
        pidx++;
      } else {
        if (inGap)
          score += score_gap_extention;
        else
          score += score_gap_start;
        inGap = true;
        consecutive = 0;
        firstBonus = 0;
      }
      prevCharClass = charClass;
    }

    return [score, pos];
  }
  function char_class_of(rune) {
    if (rune <= max_ascii)
      return char_class_of_ascii(rune);
    return char_class_of_non_ascii(rune);
  }
  function char_class_of_ascii(rune) {
    if (rune >= small_a_rune && rune <= small_z_rune)
      return 1;
    else if (rune >= capital_a_rune && rune <= capital_z_rune)
      return 2;
    else if (rune >= numeral_zero_rune && rune <= numeral_nine_rune)
      return 4;
    else
      return 0;
  }
  function char_class_of_non_ascii(rune) {
    const ch = String.fromCodePoint(rune);
    if (ch !== ch.toUpperCase())
      return 1;
    else if (ch !== ch.toLowerCase())
      return 2;
    // Try Unicode property escapes if supported; otherwise fall back
    let isNumber = false;
    let isLetter = false;
    try {
      // Construct at runtime to avoid parse-time errors on engines without \p{} support
      const numRe = new RegExp("\\\\p{Number}", "u");
      const letRe = new RegExp("\\\\p{Letter}", "u");
      isNumber = numRe.test(ch);
      isLetter = letRe.test(ch);
    } catch (e) {
      // Fallbacks: ASCII digit check; best-effort for letter classification already handled above
      isNumber = ch >= '0' && ch <= '9';
      isLetter = false;
    }
    if (isNumber)
      return 4;
    if (isLetter)
      return 3;
    return 0;
  }
  function compute_extended_match(text, pattern, fuzzyAlgo, forward) {
    text = Array.isArray(text) ? text : [];
    pattern = pattern || {
      termSets: []
    };
    const input = [
      {
        text,
        prefixLength: 0
      }
    ];
    const offsets = [];
    let totalScore = 0;
    const allPos = new Set();
    const termSets = (pattern.termSets || []);
    for (const termSet of termSets) {
      let offset = [0, 0];
      let currentScore = 0;
      let matched = false;

      for (const term of termSet) {
        let algoFn = term_type_map[term.typ];
        if (term.typ === 0)
          algoFn = fuzzyAlgo;
        const [off, score, pos] = iter(algoFn, input, term.caseSensitive, term.normalize, forward, term.text, slab);
        const sidx = off[0];
        if (sidx >= 0) {
          if (term.inv)
            continue;
          offset = off;
          currentScore = score;
          matched = true;
          if (pos !== null)
            pos.forEach(v => allPos.add(v));
          else {
            for (let idx = off[0]; idx < off[1]; ++idx)
              allPos.add(idx);
          }
          break;
        } else if (term.inv) {
          offset = [0, 0];
          currentScore = 0;
          matched = true;
          continue;
        }
      }

      if (matched) {
        offsets.push(offset);
        totalScore += currentScore;
      }
    }

    return {
      offsets,
      totalScore,
      allPos
    };
  }
  function create_pos_set(withPos) {
    return withPos ? new Set() : null;
  }
  function create_result_item_with_empty_pos(item) {
    return {
      item: item,
      start: -1,
      end: -1,
      score: 0,
      positions: new Set()
    };
  }
  function equal_match(caseSensitive, normalize, forward, text, pattern, withPos, slab2) {
    text = Array.isArray(text) ? text : [];
    pattern = Array.isArray(pattern) ? pattern : [];
    const lenPattern = pattern.length;
    if (lenPattern === 0)
      return [
        {
          start: -1,
          end: -1,
          score: 0
        },
        null];

    let trimmedLen = 0;
    if (!is_whitespace(pattern[0]))
      trimmedLen = whitespaces_at_start(text);

    let trimmedEndLen = 0;
    if (!is_whitespace(pattern[lenPattern - 1]))
      trimmedEndLen = whitespaces_at_end(text);

    if (text.length - trimmedLen - trimmedEndLen != lenPattern)
      return [
        {
          start: -1,
          end: -1,
          score: 0
        },
        null];

    let match = true;
    if (normalize) {
      const runes = text;
      for (const [idx, pchar] of pattern.entries()) {
        let rune = runes[trimmedLen + idx];
        if (!caseSensitive)
          rune = String.fromCodePoint(rune).toLowerCase().codePointAt(0);
        if (normalize_rune(pchar) !== normalize_rune(rune)) {
          match = false;
          break;
        }
      }
    } else {
      let runesStr = runes_to_str(text).substring(trimmedLen, text.length - trimmedEndLen);
      if (!caseSensitive)
        runesStr = runesStr.toLowerCase();
      match = (runesStr === runes_to_str(pattern));
    }

    if (match) {
      return [
        {
          start: trimmedLen,
          end: trimmedLen + lenPattern,
          score: (score_match + bonus_boundary) * lenPattern + (bonus_first_char_multiplier - 1) * bonus_boundary
        },
        null];
    }
    return [
      {
        start: -1,
        end: -1,
        score: 0
      },
      null];
  }
  function exact_match_naive(caseSensitive, normalize, forward, text, pattern, withPos, slab2) {
    text = Array.isArray(text) ? text : [];
    pattern = Array.isArray(pattern) ? pattern : [];
    if (pattern.length === 0)
      return [
        {
          start: 0,
          end: 0,
          score: 0
        },
        null];
    const lenRunes = text.length, lenPattern = pattern.length;
    if (lenRunes < lenPattern)
      return [
        {
          start: -1,
          end: -1,
          score: 0
        },
        null];
    if (ascii_fuzzy_index(text, pattern, caseSensitive) < 0)
      return [
        {
          start: -1,
          end: -1,
          score: 0
        },
        null];

    let pidx = 0;
    let bestPos = -1, bonus = to_short(0), bestBonus = to_short(-1);

    for (let index = 0; index < lenRunes; index++) {
      const index_ = index_at(index, lenRunes, forward);
      let rune = text[index_];

      if (!caseSensitive) {
        if (rune >= capital_a_rune && rune <= capital_z_rune)
          rune += 32;
        else if (rune > max_ascii)
          rune = String.fromCodePoint(rune).toLowerCase().codePointAt(0);
      }
      if (normalize)
        rune = normalize_rune(rune);

      const pidx_ = index_at(pidx, lenPattern, forward);
      const pchar = pattern[pidx_];
      if (pchar === rune) {
        if (pidx_ === 0)
          bonus = bonus_at(text, index_);
        pidx++;
        if (pidx === lenPattern) {
          if (bonus > bestBonus) {
            bestPos = index;
            bestBonus = bonus;
          }
          if (bonus === bonus_boundary)
            break;
          index -= pidx - 1;
          pidx = 0;
          bonus = 0;
        }
      } else {
        index -= pidx;
        pidx = 0;
        bonus = 0;
      }
    }

    if (bestPos >= 0) {
      let sidx = 0, eidx = 0;
      if (forward) {
        sidx = bestPos - lenPattern + 1;
        eidx = bestPos + 1;
      } else {
        sidx = lenRunes - (bestPos + 1);
        eidx = lenRunes - (bestPos - lenPattern + 1);
      }
      const [score] = calculate_score(caseSensitive, normalize, text, pattern, sidx, eidx, false);
      return [
        {
          start: sidx,
          end: eidx,
          score
        },
        null];
    }

    return [
      {
        start: -1,
        end: -1,
        score: 0
      },
      null];
  }
  function extended_match(query) {
    return _extended_match(this, query);
  }

  // ES5-style constructor: new finder(list, options)
  function finder(list, options) {
    const optsLocal = Object.assign({}, default_opts, options || {});
    this.opts = optsLocal;
    this.items = list;
    this.runesList = list.map(item => str_to_runes(optsLocal.selector(item).normalize()));
    let algo = exact_match_naive;
    switch (optsLocal.fuzzy) {
    case "v2":
      algo = fuzzy_match_v2;
      break;
    case "v1":
      algo = fuzzy_match_v1;
      break;
    case false:
      algo = exact_match_naive;
      break;
    }
    this.algoFn = algo;
    // Instance method instead of prototype assignment (not allowed at QML object top-level)
    this.find = function (query) {
      if (query.length === 0 || this.items.length === 0)
        return this.items.slice(0, this.opts.limit).map(create_result_item_with_empty_pos);
      query = query.normalize();
      const result = this.opts.match.bind(this)(query);
      return post_process_result_items(result, this.opts);
    };
  }
  function fuzzy_match_v1(caseSensitive, normalize, forward, text, pattern, withPos, slab2) {
    text = Array.isArray(text) ? text : [];
    pattern = Array.isArray(pattern) ? pattern : [];
    if (pattern.length === 0)
      return [
        {
          start: 0,
          end: 0,
          score: 0
        },
        null];
    if (ascii_fuzzy_index(text, pattern, caseSensitive) < 0)
      return [
        {
          start: -1,
          end: -1,
          score: 0
        },
        null];

    let pidx = 0, sidx = -1, eidx = -1;
    const lenRunes = text.length, lenPattern = pattern.length;

    for (let index = 0; index < lenRunes; index++) {
      let rune = text[index_at(index, lenRunes, forward)];
      if (!caseSensitive) {
        if (rune >= capital_a_rune && rune <= capital_z_rune)
          rune += 32;
        else if (rune > max_ascii)
          rune = String.fromCodePoint(rune).toLowerCase().codePointAt(0);
      }
      if (normalize)
        rune = normalize_rune(rune);
      const pchar = pattern[index_at(pidx, lenPattern, forward)];
      if (rune === pchar) {
        if (sidx < 0)
          sidx = index;
        pidx++;
        if (pidx === lenPattern) {
          eidx = index + 1;
          break;
        }
      }
    }

    if (sidx >= 0 && eidx >= 0) {
      pidx--;
      for (let index = eidx - 1; index >= sidx; index--) {
        const tidx = index_at(index, lenRunes, forward);
        let rune = text[tidx];
        if (!caseSensitive) {
          if (rune >= capital_a_rune && rune <= capital_z_rune)
            rune += 32;
          else if (rune > max_ascii)
            rune = String.fromCodePoint(rune).toLowerCase().codePointAt(0);
        }
        const pidx_ = index_at(pidx, lenPattern, forward);
        const pchar = pattern[pidx_];
        if (rune === pchar) {
          pidx--;
          if (pidx < 0) {
            sidx = index;
            break;
          }
        }
      }
      if (!forward) {
        const sidxTemp = sidx;
        sidx = lenRunes - eidx;
        eidx = lenRunes - sidxTemp;
      }
      const [score, pos] = calculate_score(caseSensitive, normalize, text, pattern, sidx, eidx, withPos);
      return [
        {
          start: sidx,
          end: eidx,
          score
        },
        pos];
    }

    return [
      {
        start: -1,
        end: -1,
        score: 0
      },
      null];
  }
  function fuzzy_match_v2(caseSensitive, normalize, forward, input, pattern, withPos, slab2) {
    input = Array.isArray(input) ? input : [];
    pattern = Array.isArray(pattern) ? pattern : [];
    const M = pattern.length;
    if (M === 0)
      return [
        {
          start: 0,
          end: 0,
          score: 0
        },
        create_pos_set(withPos)];
    const N = input.length;
    const idx = ascii_fuzzy_index(input, pattern, caseSensitive);
    if (idx < 0)
      return [
        {
          start: -1,
          end: -1,
          score: 0
        },
        null];

    let offset16 = 0, offset32 = 0, H0 = null, C0 = null, B = null, F = null;
    [offset16, H0] = alloc16(offset16, slab2, N);
    [offset16, C0] = alloc16(offset16, slab2, N);
    [offset16, B] = alloc16(offset16, slab2, N);
    [offset32, F] = alloc32(offset32, slab2, M);
    const allocT = alloc32(offset32, slab2, N);
    offset32 = allocT[0];
    const T = allocT[1];
    for (let i = 0; i < T.length; i++)
      T[i] = input[i];

    let maxScore = to_short(0), maxScorePos = 0;
    let pidx = 0, lastIdx = 0;
    const pchar0 = pattern[0];
    let pchar = pattern[0], prevH0 = to_short(0), prevCharClass = 0, inGap = false;

    let Tsub = T.subarray(idx);
    let H0sub = H0.subarray(idx).subarray(0, Tsub.length), C0sub = C0.subarray(idx).subarray(0, Tsub.length), Bsub = B.subarray(idx).subarray(0, Tsub.length);

    for (let [off, ch0] of Tsub.entries()) {
      let ch = ch0;
      let charClass = null;
      if (ch <= max_ascii) {
        charClass = char_class_of_ascii(ch);
        if (!caseSensitive && charClass === 2)
          ch += 32;
      } else {
        charClass = char_class_of_non_ascii(ch);
        if (!caseSensitive && charClass === 2)
          ch = String.fromCodePoint(ch).toLowerCase().codePointAt(0);
        if (normalize)
          ch = normalize_rune(ch);
      }
      Tsub[off] = ch;
      const bonus = bonus_for(prevCharClass, charClass);
      Bsub[off] = bonus;
      prevCharClass = charClass;

      if (ch === pchar) {
        if (pidx < M) {
          F[pidx] = to_int(idx + off);
          pidx++;
          pchar = pattern[Math.min(pidx, M - 1)];
        }
        lastIdx = idx + off;
      }

      if (ch === pchar0) {
        const score = score_match + bonus * bonus_first_char_multiplier;
        H0sub[off] = score;
        C0sub[off] = 1;
        if (M === 1 && ((forward && score > maxScore) || (!forward && score >= maxScore))) {
          maxScore = score;
          maxScorePos = idx + off;
          if (forward && bonus === bonus_boundary)
            break;
        }
        inGap = false;
      } else {
        if (inGap)
          H0sub[off] = max_int16(prevH0 + score_gap_extention, 0);
        else
          H0sub[off] = max_int16(prevH0 + score_gap_start, 0);
        C0sub[off] = 0;
        inGap = true;
      }
      prevH0 = H0sub[off];
    }

    if (pidx !== M)
      return [
        {
          start: -1,
          end: -1,
          score: 0
        },
        null];

    if (M === 1) {
      const result = {
        start: maxScorePos,
        end: maxScorePos + 1,
        score: maxScore
      };
      if (!withPos)
        return [result, null];
      const pos = new Set();
      pos.add(maxScorePos);
      return [result, pos];
    }

    const f0 = F[0];
    const width = lastIdx - f0 + 1;

    let H = null;
    [offset16, H] = alloc16(offset16, slab2, width * M);
    {
      const toCopy = H0.subarray(f0, lastIdx + 1);
      for (const [i, v] of toCopy.entries())
        H[i] = v;
    }

    const allocC = alloc16(offset16, slab2, width * M);
    offset16 = allocC[0];
    let C = allocC[1];
    {
      const toCopy = C0.subarray(f0, lastIdx + 1);
      for (const [i, v] of toCopy.entries())
        C[i] = v;
    }

    const Fsub = F.subarray(1);
    const Psub = pattern.slice(1).slice(0, Fsub.length);

    for (const [off, f] of Fsub.entries()) {
      let inGap2 = false;
      const pchar2 = Psub[off], pidx2 = off + 1, row = pidx2 * width, Tsub2 = T.subarray(f, lastIdx + 1), Bsub2 = B.subarray(f).subarray(0, Tsub2.length), Csub = C.subarray(row + f - f0).subarray(0, Tsub2.length), Cdiag = C.subarray(row + f - f0 - 1 - width).subarray(0, Tsub2.length), Hsub = H.subarray(row + f - f0).subarray(0, Tsub2.length), Hdiag = H.subarray(row + f - f0 - 1 - width).subarray(0, Tsub2.length), Hleft = H.subarray(row + f - f0 - 1).subarray(0, Tsub2.length);

      Hleft[0] = 0;

      for (const [off2, ch] of Tsub2.entries()) {
        const col = off2 + f;
        let s1 = 0, s2 = 0, consecutive = 0;

        if (inGap2)
          s2 = Hleft[off2] + score_gap_extention;
        else
          s2 = Hleft[off2] + score_gap_start;

        if (pchar2 === ch) {
          s1 = Hdiag[off2] + score_match;
          let b = Bsub2[off2];
          consecutive = Cdiag[off2] + 1;
          if (b === bonus_boundary) {
            consecutive = 1;
          } else if (consecutive > 1) {
            b = max_int16(b, max_int16(bonus_consecutive, B[col - consecutive + 1]));
          }
          if (s1 + b < s2) {
            s1 += Bsub2[off2];
            consecutive = 0;
          } else {
            s1 += b;
          }
        }

        Csub[off2] = consecutive;
        inGap2 = s1 < s2;
        const score = max_int16(max_int16(s1, s2), 0);
        if (pidx2 === M - 1 && ((forward && score > maxScore) || (!forward && score >= maxScore))) {
          maxScore = score;
          maxScorePos = col;
        }
        Hsub[off2] = score;
      }
    }

    const pos = create_pos_set(withPos);
    let j = f0;
    if (withPos && pos !== null) {
      let i = M - 1;
      j = maxScorePos;
      let preferMatch = true;
      while (true) {
        const I = i * width, j0 = j - f0, s = H[I + j0];
        let s1 = 0, s2 = 0;
        if (i > 0 && j >= F[i])
          s1 = H[I - width + j0 - 1];
        if (j > F[i])
          s2 = H[I + j0 - 1];
        if (s > s1 && (s > s2 || (s === s2 && preferMatch))) {
          pos.add(j);
          if (i === 0)
            break;
          i--;
        }
        preferMatch = C[I + j0] > 1 || (I + width + j0 + 1 < C.length && C[I + width + j0 + 1] > 0);
        j--;
      }
    }

    return [
      {
        start: j,
        end: maxScorePos + 1,
        score: maxScore
      },
      pos];
  }
  function get_result_from_score_map(scoreMap, limit) {
    const scoresInDesc = Object.keys(scoreMap).map(v => parseInt(v, 10)).sort((a, b) => b - a);
    let result = [];
    for (const score of scoresInDesc) {
      result = result.concat(scoreMap[score]);
      if (result.length >= limit)
        break;
    }
    return result;
  }
  function index_at(index, max, forward) {
    return forward ? index : (max - index - 1);
  }
  function is_ascii(runes) {
    for (const r of runes) {
      if (r >= 128)
        return false;
    }
    return true;
  }
  function is_whitespace(rune) {
    return whitespace_runes.has(rune);
  }
  function iter(algoFn, tokens, caseSensitive, normalize, forward, pattern, slab2) {
    for (const part of tokens) {
      const [res, pos] = algoFn(caseSensitive, normalize, forward, part.text, pattern, true, slab2);
      if (res.start >= 0) {
        const sidx = res.start + part.prefixLength;
        const eidx = res.end + part.prefixLength;
        if (pos !== null) {
          const newPos = new Set();
          pos.forEach(v => newPos.add(part.prefixLength + v));
          return [[sidx, eidx], res.score, newPos];
        }
        return [[sidx, eidx], res.score, pos];
      }
    }
    return [[-1, -1], 0, null];
  }
  function max_int16(a, b) {
    return a > b ? a : b;
  }

  // ----------------------
  // helpers
  // ----------------------
  function normalize_rune(rune) {
    if (rune < 192 || rune > 8580)
      return rune;
    const mapped = normalized[rune] || 0; // 0 means unmapped
    if (mapped !== 0)
      return mapped;
    return rune;
  }
  function parse_terms(fuzzy, caseMode, normalize, str) {
    // Protect escaped spaces ("\\ ") only, not all spaces
    if (typeof str !== "string")
      str = String(str || "");
    str = str.replace(/\\\s/g, "\t");
    const tokens = str.split(/ +/);
    const sets = [];
    let set = [];
    let switchSet = false;
    let afterBar = false;

    for (const token of tokens) {
      let typ = 0, inv = false, text = token.replace(/\t/g, " ");
      const lowerText = text.toLowerCase();
      const caseSensitive = caseMode === "case-sensitive" || (caseMode === "smart-case" && text !== lowerText);
      const normalizeTerm = normalize && lowerText === runes_to_str(str_to_runes(lowerText).map(normalize_rune));
      if (!caseSensitive)
        text = lowerText;
      if (!fuzzy)
        typ = 1;

      if (set.length > 0 && !afterBar && text === "|") {
        switchSet = false;
        afterBar = true;
        continue;
      }
      afterBar = false;

      if (text.startsWith("!")) {
        inv = true;
        typ = 1;
        text = text.substring(1);
      }
      if (text !== "$" && text.endsWith("$")) {
        typ = 3;
        text = text.substring(0, text.length - 1);
      }
      if (text.startsWith("'")) {
        if (fuzzy && !inv)
          typ = 1;
        else
          typ = 0;
        text = text.substring(1);
      } else if (text.startsWith("^")) {
        if (typ === 3)
          typ = 4;
        else
          typ = 2;
        text = text.substring(1);
      }

      if (text.length > 0) {
        if (switchSet) {
          sets.push(set);
          set = [];
        }
        let textRunes = str_to_runes(text);
        if (normalizeTerm)
          textRunes = textRunes.map(normalize_rune);
        set.push({
          typ,
          inv,
          text: textRunes,
          caseSensitive,
          normalize: normalizeTerm
        });
        switchSet = true;
      }
    }
    if (set.length > 0)
      sets.push(set);
    return sets;
  }
  function post_process_result_items(result, opts) {
    if (opts.sort) {
      const selector = opts.selector;
      result.sort((a, b) => {
        if (a.score === b.score) {
          for (const tiebreaker of opts.tiebreakers) {
            const diff = tiebreaker(a, b, selector);
            if (diff !== 0)
              return diff;
          }
        }
        return 0;
      });
    }
    if (Number.isFinite(opts.limit))
      result.splice(opts.limit);
    return result;
  }
  function prefix_match(caseSensitive, normalize, forward, text, pattern, withPos, slab2) {
    text = Array.isArray(text) ? text : [];
    pattern = Array.isArray(pattern) ? pattern : [];
    if (pattern.length === 0)
      return [
        {
          start: 0,
          end: 0,
          score: 0
        },
        null];
    let trimmedLen = 0;
    if (!is_whitespace(pattern[0]))
      trimmedLen = whitespaces_at_start(text);
    if (text.length - trimmedLen < pattern.length)
      return [
        {
          start: -1,
          end: -1,
          score: 0
        },
        null];

    for (const [index, r] of pattern.entries()) {
      let rune = text[trimmedLen + index];
      if (!caseSensitive)
        rune = String.fromCodePoint(rune).toLowerCase().codePointAt(0);
      if (normalize)
        rune = normalize_rune(rune);
      if (rune !== r)
        return [
          {
            start: -1,
            end: -1,
            score: 0
          },
          null];
    }

    const lenPattern = pattern.length;
    const [score] = calculate_score(caseSensitive, normalize, text, pattern, trimmedLen, trimmedLen + lenPattern, false);
    return [
      {
        start: trimmedLen,
        end: trimmedLen + lenPattern,
        score
      },
      null];
  }
  function runes_to_str(runes) {
    return runes.map(r => String.fromCodePoint(r)).join("");
  }
  function str_to_runes(str) {
    return str.split("").map(s => s.codePointAt(0));
  }
  function suffix_match(caseSensitive, normalize, forward, text, pattern, withPos, slab2) {
    text = Array.isArray(text) ? text : [];
    pattern = Array.isArray(pattern) ? pattern : [];
    const lenRunes = text.length;
    let trimmedLen = lenRunes;
    if (pattern.length === 0 || !is_whitespace(pattern[pattern.length - 1]))
      trimmedLen -= whitespaces_at_end(text);
    if (pattern.length === 0)
      return [
        {
          start: trimmedLen,
          end: trimmedLen,
          score: 0
        },
        null];

    const diff = trimmedLen - pattern.length;
    if (diff < 0)
      return [
        {
          start: -1,
          end: -1,
          score: 0
        },
        null];

    for (const [index, r] of pattern.entries()) {
      let rune = text[index + diff];
      if (!caseSensitive)
        rune = String.fromCodePoint(rune).toLowerCase().codePointAt(0);
      if (normalize)
        rune = normalize_rune(rune);
      if (rune !== r)
        return [
          {
            start: -1,
            end: -1,
            score: 0
          },
          null];
    }

    const lenPattern = pattern.length;
    const sidx = trimmedLen - lenPattern;
    const eidx = trimmedLen;
    const [score] = calculate_score(caseSensitive, normalize, text, pattern, sidx, eidx, false);
    return [
      {
        start: sidx,
        end: eidx,
        score
      },
      null];
  }
  function to_int(number) {
    return number;
  }
  function to_short(number) {
    return number;
  }
  function try_skip(input, caseSensitive, ch, from) {
    let rest = input.slice(from);
    let idx = rest.indexOf(ch);
    if (idx === 0)
      return from;
    if (!caseSensitive && ch >= small_a_rune && ch <= small_z_rune) {
      if (idx > 0)
        rest = rest.slice(0, idx);
      const uidx = rest.indexOf(ch - 32);
      if (uidx >= 0)
        idx = uidx;
    }
    if (idx < 0)
      return -1;
    return from + idx;
  }
  function whitespaces_at_end(runes) {
    let w = 0;
    for (let i = runes.length - 1; i >= 0; i--) {
      if (is_whitespace(runes[i]))
        w++;
      else
        break;
    }
    return w;
  }
  function whitespaces_at_start(runes) {
    let w = 0;
    for (const r of runes) {
      if (is_whitespace(r))
        w++;
      else
        break;
    }
    return w;
  }
}
