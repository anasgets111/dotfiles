// Fzf for JavaScript (QML port for Quickshell)
// BSD 3-Clause License - Copyright (c) 2021, Ajit
pragma Singleton
import QtQuick

QtObject {
  id: fzf

  readonly property int bonus_boundary: score_match / 2
  readonly property int bonus_camel_123: bonus_boundary + score_gap_extention
  readonly property int bonus_consecutive: -(score_gap_start + score_gap_extention)
  readonly property int bonus_first_char_multiplier: 2
  readonly property int bonus_non_word: score_match / 2
  readonly property int capital_a_rune: 65
  readonly property int capital_z_rune: 90
  // Rune constants
  readonly property int max_ascii: 127
  readonly property int numeral_nine_rune: 57
  readonly property int numeral_zero_rune: 48
  readonly property int score_gap_extention: -1
  readonly property int score_gap_start: -3

  // Scoring constants
  readonly property int score_match: 16
  readonly property int small_a_rune: 97
  readonly property int small_z_rune: 122

  function ascii_fuzzy_index(input, pattern, caseSensitive) {
    const inp = Array.isArray(input) ? input : [];
    const pat = Array.isArray(pattern) ? pattern : [];
    if (pat.length === 0)
      return 0;

    if (!is_ascii(inp) || !is_ascii(pat))
      return -1;

    let firstIdx = 0, idx = 0;
    for (let pidx = 0; pidx < pat.length; pidx++) {
      idx = try_skip(inp, caseSensitive, pat[pidx], idx);
      if (idx < 0)
        return -1;

      if (pidx === 0 && idx > 0)
        firstIdx = idx - 1;

      idx++;
    }
    return firstIdx;
  }

  function bonus_for(prevClass, currClass) {
    if (prevClass === 0 && currClass !== 0)
      return bonus_boundary;

    if ((prevClass === 1 && currClass === 2) || (prevClass !== 4 && currClass === 4))
      return bonus_camel_123;

    if (currClass === 0)
      return bonus_non_word;

    return 0;
  }

  function by_length_asc(a, b, selector) {
    a = a || {
      "item": ""
    };
    b = b || {
      "item": ""
    };
    if (!selector)
      return 0;

    const aLen = a.item ? selector(a.item).length : 0;
    const bLen = b.item ? selector(b.item).length : 0;
    return aLen - bLen;
  }

  // Tiebreaker functions (for equal scores)
  function by_start_asc(a, b) {
    a = a || {
      "start": 0
    };
    b = b || {
      "start": 0
    };
    return (a.start || 0) - (b.start || 0);
  }

  // Character classification for scoring
  function char_class_of(rune) {
    if (rune <= max_ascii) {
      if (rune >= small_a_rune && rune <= small_z_rune)
        return 1;
      // lowercase
      if (rune >= capital_a_rune && rune <= capital_z_rune)
        return 2;
      // uppercase
      if (rune >= numeral_zero_rune && rune <= numeral_nine_rune)
        return 4;
      // number
      return 0; // non-word
    }
    // Simplified non-ASCII handling
    const ch = String.fromCodePoint(rune);
    if (ch !== ch.toUpperCase())
      return 1;

    if (ch !== ch.toLowerCase())
      return 2;

    return 0;
  }

  // Finder constructor
  function finder(list, options) {
    const opts = Object.assign({
      "limit": Infinity,
      "selector": v => {
        return v;
      },
      "casing": "smart-case",
      "sort": true
    }, options || {});
    this.opts = opts;
    this.items = list;
    this.runesList = list.map(item => {
      return str_to_runes(opts.selector(item));
    });
    this.find = function (query) {
      if (query.length === 0 || this.items.length === 0)
        return this.items.slice(0, this.opts.limit).map(item => {
          return ({
              "item": item,
              "start": -1,
              "end": -1,
              "score": 0,
              "positions": new Set()
            });
        });

      let caseSensitive = opts.casing === "case-sensitive" || (opts.casing === "smart-case" && query !== query.toLowerCase());
      if (!caseSensitive)
        query = query.toLowerCase();

      const queryRunes = str_to_runes(query);
      const results = [];
      for (let i = 0; i < this.runesList.length; i++) {
        if (queryRunes.length > this.runesList[i].length)
          continue;

        const [match, positions] = fuzzy_match_v2(caseSensitive, this.runesList[i], queryRunes, true);
        if (match.start === -1)
          continue;

        results.push(Object.assign({
          "item": this.items[i],
          "positions": positions
        }, match));
      }
      if (opts.sort) {
        results.sort((a, b) => {
          if (a.score !== b.score)
            return b.score - a.score;

          const tiebreakers = opts.tiebreakers || [];
          for (const tiebreaker of tiebreakers) {
            const diff = tiebreaker(a, b, opts.selector);
            if (diff !== 0)
              return diff;
          }
          return 0;
        });
      }
      return Number.isFinite(opts.limit) ? results.slice(0, opts.limit) : results;
    };
  }

  // Fuzzy Match V2 algorithm
  function fuzzy_match_v2(caseSensitive, input, pattern, withPos) {
    const inp = Array.isArray(input) ? input : [];
    const pat = Array.isArray(pattern) ? pattern : [];
    const M = pat.length;
    if (M === 0)
      return [
        {
          "start": 0,
          "end": 0,
          "score": 0
        },
        withPos ? new Set() : null];

    const N = inp.length;
    const idx = ascii_fuzzy_index(inp, pat, caseSensitive);
    if (idx < 0)
      return [
        {
          "start": -1,
          "end": -1,
          "score": 0
        },
        null];

    const H0 = new Int16Array(N);
    const C0 = new Int16Array(N);
    const B = new Int16Array(N);
    const F = new Int32Array(M);
    const T = new Int32Array(inp);
    let maxScore = 0, maxScorePos = 0, pidx = 0, lastIdx = 0;
    const pchar0 = pat[0];
    let pchar = pat[0], prevH0 = 0, prevCharClass = 0, inGap = false;
    for (let off = idx; off < T.length; off++) {
      let ch = T[off];
      const charClass = char_class_of(ch);
      if (!caseSensitive && charClass === 2)
        ch += 32;
      T[off] = ch;
      const bonus = bonus_for(prevCharClass, charClass);
      B[off] = bonus;
      prevCharClass = charClass;
      if (ch === pchar && pidx < M) {
        F[pidx] = off;
        pidx++;
        pchar = pat[Math.min(pidx, M - 1)];
        lastIdx = off;
      }
      if (ch === pchar0) {
        const score = score_match + bonus * bonus_first_char_multiplier;
        H0[off] = score;
        C0[off] = 1;
        if (M === 1 && score > maxScore) {
          maxScore = score;
          maxScorePos = off;
          if (bonus === bonus_boundary)
            break;
        }
        inGap = false;
      } else {
        H0[off] = Math.max((inGap ? prevH0 + score_gap_extention : prevH0 + score_gap_start), 0);
        C0[off] = 0;
        inGap = true;
      }
      prevH0 = H0[off];
    }
    if (pidx !== M)
      return [
        {
          "start": -1,
          "end": -1,
          "score": 0
        },
        null];

    if (M === 1) {
      const pos = withPos ? new Set([maxScorePos]) : null;
      return [
        {
          "start": maxScorePos,
          "end": maxScorePos + 1,
          "score": maxScore
        },
        pos];
    }
    const f0 = F[0];
    const width = lastIdx - f0 + 1;
    const H = new Int16Array(width * M);
    const C = new Int16Array(width * M);
    H.set(H0.subarray(f0, lastIdx + 1));
    C.set(C0.subarray(f0, lastIdx + 1));
    for (let pidx2 = 1; pidx2 < M; pidx2++) {
      const f = F[pidx2];
      const pchar2 = pat[pidx2];
      const row = pidx2 * width;
      let inGap2 = false;
      for (let off2 = 0; off2 < lastIdx - f + 1; off2++) {
        const col = off2 + f;
        const ch = T[col];
        let s1 = 0, s2 = 0, consecutive = 0;
        s2 = (off2 > 0 ? H[row + col - f0 - 1] : 0) + (inGap2 ? score_gap_extention : score_gap_start);
        if (pchar2 === ch) {
          s1 = H[row - width + col - f0 - 1] + score_match;
          consecutive = C[row - width + col - f0 - 1] + 1;
          let b = B[col];
          if (b === bonus_boundary)
            consecutive = 1;
          else if (consecutive > 1)
            b = Math.max(b, Math.max(bonus_consecutive, B[col - consecutive + 1]));
          s1 += (s1 + b < s2) ? B[col] : b;
        }
        C[row + col - f0] = consecutive;
        inGap2 = s1 < s2;
        const score = Math.max(Math.max(s1, s2), 0);
        if (pidx2 === M - 1 && score > maxScore) {
          maxScore = score;
          maxScorePos = col;
        }
        H[row + col - f0] = score;
      }
    }
    const pos = withPos ? new Set() : null;
    if (withPos && pos) {
      let i = M - 1, j = maxScorePos;
      while (true) {
        const I = i * width, j0 = j - f0;
        const s = H[I + j0];
        const s1 = (i > 0 && j >= F[i]) ? H[I - width + j0 - 1] : 0;
        const s2 = (j > F[i]) ? H[I + j0 - 1] : 0;
        if (s > s1 && s > s2) {
          pos.add(j);
          if (i === 0)
            break;

          i--;
        }
        j--;
      }
    }
    return [
      {
        "start": f0,
        "end": maxScorePos + 1,
        "score": maxScore
      },
      pos];
  }

  function is_ascii(runes) {
    return runes.every(r => {
      return r < 128;
    });
  }

  // String/rune conversion
  function str_to_runes(str) {
    const runes = [];
    for (let i = 0; i < str.length; i++) {
      const code = str.codePointAt(i);
      runes.push(code);
      if (code > 65535)
        i++;
      // Skip surrogate pair
    }
    return runes;
  }

  // ASCII fast path
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
}
