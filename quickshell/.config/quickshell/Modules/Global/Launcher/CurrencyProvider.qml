pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Config
import qs.Services.SystemInfo
import qs.Services.Utils

Singleton {
  id: root

  property string _fromCode: ""
  property real _inputAmount: 0
  property real _outputAmount: 0
  property bool _requesting: false
  property string _resultText: ""
  property string _toCode: ""
  readonly property string fromCode: _fromCode
  readonly property string fromFlag: _getFlag(_fromCode)
  readonly property bool hasResult: _resultText !== ""
  readonly property real inputAmount: _inputAmount
  property var lastUpdated: null
  readonly property real outputAmount: _outputAmount
  property var rates: ({
      "usd": 1.0
    })
  property bool ratesLive: false
  readonly property int refreshInterval: 86400000 // 24 hours

  readonly property string lastUpdatedText: _formatLastUpdated(lastUpdated)
  readonly property string resultText: _resultText
  readonly property string toCode: _toCode
  readonly property string toFlag: _getFlag(_toCode)

  function _fetchRates(): void {
    if (_requesting)
      return;
    const url = "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json";

    _httpGet(url, data => {
      if (data && data.usd) {
        const newRates = data.usd;
        const fetchedAt = new Date();
        newRates["usd"] = 1.0;
        rates = newRates;
        ratesLive = true;
        lastUpdated = fetchedAt;

        // Persist to state in settings
        Settings.state.currency = {
          rates: newRates,
          lastUpdate: fetchedAt.toISOString()
        };
        Settings.saveState();

        Logger.log("CurrencyProvider", `Rates updated (date: ${data.date})`);
      }
    });
  }

  function _formatLastUpdated(value: var): string {
    if (!value || typeof value.getTime !== "function" || isNaN(value.getTime()))
      return "";
    const now = new Date();
    const sameDay = value.getFullYear() === now.getFullYear() && value.getMonth() === now.getMonth() && value.getDate() === now.getDate();
    const pattern = sameDay ? (TimeService.use24Hour ? "HH:mm" : "h:mm AP") : (TimeService.use24Hour ? "MMM d, HH:mm" : "MMM d, h:mm AP");
    return "Updated " + value.toLocaleString(Qt.locale(), pattern);
  }

  function _getFlag(code: string): string {
    if (!code)
      return "";
    const lower = code.toLowerCase();
    const specials = {
      "eur": "eu",
      "gbp": "gb",
      "usd": "us",
      "btc": "₿",
      "eth": "Ξ",
      "ltc": "Ł",
      "doge": "Ð",
      "xrp": "✕",
      "ada": "₳",
      "sol": "₴",
      "dot": "●",
      "usdt": "₮",
      "usdc": "₵"
    };
    const country = specials[lower] || lower.substring(0, 2);
    // Regional Indicator Symbol conversion (A=127462)
    if (country.length === 2 && /^[a-z]{2}$/i.test(country)) {
      return String.fromCodePoint(...[...country.toUpperCase()].map(c => c.charCodeAt(0) + 127397));
    }
    return country.toUpperCase();
  }

  function _httpGet(url: string, onSuccess: var): void {
    _requesting = true;
    const xhr = new XMLHttpRequest();
    xhr.timeout = 5000;
    xhr.onreadystatechange = () => {
      if (xhr.readyState !== XMLHttpRequest.DONE)
        return;
      _requesting = false;
      if (xhr.status !== 200) {
        Logger.warn("CurrencyProvider", `Failed to fetch rates: ${xhr.status}`);
        return;
      }
      try {
        onSuccess(JSON.parse(xhr.responseText));
      } catch (e) {
        Logger.warn("CurrencyProvider", "Failed to parse rates JSON");
      }
    };
    xhr.ontimeout = () => {
      _requesting = false;
      Logger.warn("CurrencyProvider", "Rate fetch timed out");
    };
    xhr.open("GET", url);
    xhr.send();
  }

  function _init(): void {
    if (!Settings.isStateLoaded)
      return;

    const cache = Settings.state.currency;
    if (cache.lastUpdate && cache.rates) {
      try {
        const last = new Date(cache.lastUpdate);
        if (cache.rates && typeof cache.rates === "object") {
          rates = cache.rates;
          lastUpdated = last;
          ratesLive = true;

          const elapsed = Date.now() - last.getTime();
          if (elapsed < refreshInterval) {
            Logger.log("CurrencyProvider", "Using cached rates");
            return;
          }
        }
      } catch (e) {
        Logger.warn("CurrencyProvider", "Failed to load cache: " + e);
      }
    }

    Logger.log("CurrencyProvider", "Refreshing rates from API (cache stale or missing)");
    _fetchRates();
  }

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
    const patterns = [
      // 100 USD to EUR or 100USD to EUR
      [/^(\d+(?:\.\d+)?)\s*([a-zA-Z]{3,5})\s+(?:to|in|->|=>|=)\s+([a-zA-Z]{3,5})$/i, m => ({
              a: parseFloat(m[1]),
              f: m[2].toLowerCase(),
              t: m[3].toLowerCase()
            })],
      // $100 to EUR
      [/^([$€£¥₹₿])\s*(\d+(?:\.\d+)?)\s+(?:to|in|->|=>|=)\s+([a-zA-Z]{3,5})$/i, m => ({
              a: parseFloat(m[2]),
              f: fromSymbol(m[1]),
              t: m[3].toLowerCase()
            })],
      // 100 USD (defaults to EGP, or USD if input is EGP)
      [/^(\d+(?:\.\d+)?)\s*([a-zA-Z]{3,5})$/i, m => {
          const f = m[2].toLowerCase();
          return {
            a: parseFloat(m[1]),
            f: f,
            t: f === "egp" ? "usd" : "egp"
          };
        }],
      // $100 (defaults to EGP, or USD if input is EGP)
      [/^([$€£¥₹₿])\s*(\d+(?:\.\d+)?)$/i, m => {
          const f = fromSymbol(m[1]);
          return {
            a: parseFloat(m[2]),
            f: f,
            t: f === "egp" ? "usd" : "egp"
          };
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

    Logger.log("CurrencyProvider", `Query success: ${parsed.a} ${parsed.f} -> ${out} ${parsed.t} (${fromFlag} -> ${toFlag})`);
    return true;
  }

  function refreshIfStale(): void {
    if (!Settings.isStateLoaded)
      return;
    if (Date.now() > ((lastUpdated?.getTime() || 0) + refreshInterval))
      _fetchRates();
  }

  function reset(): void {
    _fromCode = "";
    _toCode = "";
    _inputAmount = 0;
    _outputAmount = 0;
    _resultText = "";
  }

  Component.onCompleted: if (Settings.isStateLoaded)
    _init()

  Connections {
    function onIsStateLoadedChanged() {
      if (Settings.isStateLoaded)
        root._init();
    }

    target: Settings
  }
}
