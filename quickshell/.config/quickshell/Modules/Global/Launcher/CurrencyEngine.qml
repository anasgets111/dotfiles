pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

Singleton {
  id: root

  property string _fromCode: ""
  property real _inputAmount: 0
  property real _outputAmount: 0
  property string _resultText: ""
  property string _toCode: ""
  readonly property string fromCode: _fromCode
  readonly property bool hasResult: _resultText !== ""
  readonly property real inputAmount: _inputAmount
  readonly property real outputAmount: _outputAmount
  readonly property var rates: ({
      "usd": 1.0,
      "eur": 0.92,
      "gbp": 0.79,
      "egp": 50.75,
      "jpy": 149.50,
      "cny": 7.24,
      "inr": 83.40,
      "cad": 1.36,
      "aud": 1.53,
      "chf": 0.88,
      "krw": 1330.0,
      "brl": 4.97,
      "mxn": 17.15,
      "sar": 3.75,
      "aed": 3.67,
      "try": 32.40,
      "rub": 92.50,
      "zar": 18.60,
      "sek": 10.45,
      "nok": 10.55,
      "dkk": 6.87,
      "pln": 3.98,
      "thb": 35.20,
      "idr": 15650.0,
      "myr": 4.72,
      "sgd": 1.34,
      "hkd": 7.82,
      "php": 56.10,
      "ngn": 1550.0,
      "pkr": 278.50,
      "bdt": 110.0,
      "vnd": 24500.0,
      "cop": 3950.0,
      "ars": 870.0,
      "clp": 935.0,
      "pen": 3.72,
      "uah": 38.50,
      "czk": 22.80,
      "huf": 355.0,
      "ron": 4.57,
      "bgn": 1.80,
      "hrk": 6.92,
      "ils": 3.65,
      "qar": 3.64,
      "kwd": 0.31,
      "bhd": 0.376,
      "omr": 0.385,
      "jod": 0.709,
      "lbp": 89500.0,
      "mad": 10.0,
      "tnd": 3.11,
      "dzd": 134.50,
      "lyd": 4.85,
      "kes": 153.0,
      "ghs": 12.50,
      "tzs": 2520.0,
      "ugx": 3780.0,
      "xof": 603.0,
      "xaf": 603.0,
      "nzd": 1.64,
      "gel": 2.70,
      "kzt": 450.0,
      "uzs": 12350.0,
      "azn": 1.70,
      "twd": 31.50,
      "lkr": 310.0,
      "mmk": 2100.0,
      "byn": 3.27,
      "isk": 137.0,
      "btc": 0.0000098,
      "eth": 0.00028
    })
  readonly property bool ratesLive: false
  readonly property string resultText: _resultText
  readonly property string toCode: _toCode

  function parseAndConvert(text: string): bool {
    reset();
    const input = String(text || "").trim();
    if (!input)
      return false;
    const fromSymbol = s => ({
          "$": "usd",
          "€": "eur",
          "£": "gbp",
          "¥": "jpy",
          "₹": "inr",
          "₿": "btc"
        }[s] || "usd");
    const patterns = [[/^(\d+\.?\d*)\s*([a-zA-Z]{2,5})\s+(?:to|in|->|=>|=)\s+([a-zA-Z]{2,5})$/i, m => ({
              a: parseFloat(m[1]),
              f: m[2].toLowerCase(),
              t: m[3].toLowerCase()
            })], [/^[$€£¥₹₿]\s*(\d+\.?\d*)\s+(?:to|in|->|=>|=)\s+([a-zA-Z]{2,5})$/i, m => ({
              a: parseFloat(m[1]),
              f: fromSymbol(input.charAt(0)),
              t: m[2].toLowerCase()
            })], [/^([a-zA-Z]{2,5})\s+(?:to|in|->|=>|=)\s+([a-zA-Z]{2,5})$/i, m => ({
              a: 1,
              f: m[1].toLowerCase(),
              t: m[2].toLowerCase()
            })], [/^(\d+\.?\d*)\s+([a-zA-Z]{2,5})\s+([a-zA-Z]{2,5})$/i, m => ({
              a: parseFloat(m[1]),
              f: m[2].toLowerCase(),
              t: m[3].toLowerCase()
            })], [/^(\d+\.?\d*)\s*([a-zA-Z]{2,5})$/i, m => {
          const f = m[2].toLowerCase();
          return ({
              a: parseFloat(m[1]),
              f,
              t: f === "usd" ? "eur" : "usd"
            });
        }]];
    let parsed = null;
    for (const [re, fn] of patterns) {
      const m = input.match(re);
      if (m) {
        parsed = fn(m);
        break;
      }
    }
    if (!parsed || !(parsed.f in rates) || !(parsed.t in rates) || parsed.f === parsed.t)
      return false;
    const out = (parsed.a / rates[parsed.f]) * rates[parsed.t];
    const decimals = out >= 100 ? 2 : (out >= 1 ? 4 : 6);
    _fromCode = parsed.f;
    _toCode = parsed.t;
    _inputAmount = parsed.a;
    _outputAmount = out;
    _resultText = Math.abs(out) < 0.01 && out !== 0 ? out.toPrecision(6) : out.toLocaleString(Qt.locale(), "f", decimals);
    return true;
  }

  function reset(): void {
    _fromCode = "";
    _toCode = "";
    _inputAmount = 0;
    _outputAmount = 0;
    _resultText = "";
  }
}
