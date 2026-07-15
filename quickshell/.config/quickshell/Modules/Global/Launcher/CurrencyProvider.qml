pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Components
import qs.Config
import qs.Services.SystemInfo
import qs.Services.Utils

Singleton {
  id: root

  property string _fromCode: ""
  property real _inputAmount: 0
  property bool _requesting: false
  property string _resultText: ""
  readonly property var _symbolCodes: ({
      "$": "usd",
      "€": "eur",
      "£": "gbp",
      "¥": "jpy",
      "₹": "inr",
      "₿": "btc"
    })
  property string _toCode: ""
  readonly property Component delegate: Component {
    ColumnLayout {
      anchors.fill: parent
      spacing: Theme.spacingXs

      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm

        OText {
          bold: true
          color: Theme.activeColor
          font.pixelSize: Theme.fontXs
          text: qsTr("Currency")
        }
        Rectangle {
          color: Theme.inactiveColor
          implicitHeight: Theme.controlHeightXs
          implicitWidth: staticLabel.implicitWidth + Theme.spacingSm
          radius: height / 2
          visible: !root.ratesLive

          OText {
            id: staticLabel

            anchors.centerIn: parent
            color: Theme.textInactiveColor
            size: "xs"
            text: qsTr("Static rates")
          }
        }
        Item {
          Layout.fillWidth: true
        }
        OText {
          color: Theme.textInactiveColor
          font.pixelSize: Theme.fontXs
          opacity: 0.8
          text: root.lastUpdatedText
          visible: text !== ""
        }
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm

        OText {
          font.pixelSize: Theme.fontLg
          text: root.fromFlag
        }
        OText {
          bold: true
          font.pixelSize: Theme.fontLg
          text: root._inputAmount + " " + root._fromCode.toUpperCase()
        }
        OText {
          color: Theme.textInactiveColor
          font.pixelSize: Theme.fontLg
          text: "→"
        }
        OText {
          font.pixelSize: Theme.fontLg
          text: root.toFlag
        }
        OText {
          bold: true
          color: Theme.activeColor
          font.pixelSize: Theme.fontLg
          text: root._resultText + " " + root._toCode.toUpperCase()
        }
      }
      LauncherHint {
        text: qsTr("Enter to copy result")
      }
    }
  }
  readonly property string fromFlag: _getFlag(_fromCode)
  property var lastUpdated: null
  readonly property string lastUpdatedText: _formatLastUpdated(lastUpdated)
  property var rates: ({
      "usd": 1.0
    })
  property bool ratesLive: false
  readonly property int refreshInterval: 86400000 // 24 hours

  readonly property string statusLabel: ratesLive ? "FX" : "FX-STATIC"
  readonly property string toFlag: _getFlag(_toCode)

  function _currencyCode(token: string): string {
    return root._symbolCodes[token] ?? token.toLowerCase();
  }
  function _fetchRates(): void {
    if (_requesting)
      return;
    _requesting = true;
    const xhr = new XMLHttpRequest();
    xhr.timeout = 5000;
    xhr.onerror = xhr.ontimeout = () => {
      _requesting = false;
      Logger.warn("CurrencyProvider", "Rate fetch failed");
    };
    xhr.onreadystatechange = () => {
      if (xhr.readyState !== XMLHttpRequest.DONE)
        return;
      _requesting = false;
      if (xhr.status !== 200) {
        Logger.warn("CurrencyProvider", `Failed to fetch rates: ${xhr.status}`);
        return;
      }
      let data;
      try {
        data = JSON.parse(xhr.responseText);
      } catch (e) {
        Logger.warn("CurrencyProvider", "Failed to parse rates JSON");
        return;
      }
      if (!data?.usd)
        return;
      data.usd["usd"] = 1.0;
      rates = data.usd;
      ratesLive = true;
      lastUpdated = new Date();
      Settings.state.currency = {
        rates: data.usd,
        lastUpdate: lastUpdated.toISOString()
      };
      Settings.saveState();
      Logger.log("CurrencyProvider", `Rates updated (date: ${data.date})`);
    };
    xhr.open("GET", "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json");
    xhr.send();
  }
  function _formatLastUpdated(value: var): string {
    if (!value || Number.isNaN(value.getTime()))
      return "";
    const now = new Date();
    const sameDay = value.getFullYear() === now.getFullYear() && value.getMonth() === now.getMonth() && value.getDate() === now.getDate();
    const pattern = sameDay ? (TimeService.use24Hour ? "HH:mm" : "h:mm AP") : (TimeService.use24Hour ? "MMM d, HH:mm" : "MMM d, h:mm AP");
    return qsTr("Updated %1").arg(value.toLocaleString(Qt.locale(), pattern));
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
  function _init(): void {
    const cache = Settings.state.currency ?? ({});
    if (cache.lastUpdate && cache.rates && typeof cache.rates === "object") {
      const last = new Date(cache.lastUpdate);
      if (!Number.isNaN(last.getTime())) {
        rates = cache.rates;
        lastUpdated = last;
        ratesLive = true;

        if (Date.now() - last.getTime() < refreshInterval) {
          Logger.log("CurrencyProvider", "Using cached rates");
          return;
        }
      }
    }

    Logger.log("CurrencyProvider", "Refreshing rates from API (cache stale or missing)");
    _fetchRates();
  }
  function _parseSource(text: string, allowImplicitAmount: bool): var {
    let match = text.match(/^(\d+(?:\.\d+)?)\s*([a-zA-Z]{3,5}|[$€£¥₹₿])$/i);
    if (match)
      return {
        a: parseFloat(match[1]),
        f: root._currencyCode(match[2])
      };
    match = text.match(/^([$€£¥₹₿])\s*(\d+(?:\.\d+)?)?$/);
    if (match)
      return {
        a: match[2] ? parseFloat(match[2]) : 1,
        f: root._currencyCode(match[1])
      };
    if (!allowImplicitAmount)
      return null;
    match = text.match(/^[a-zA-Z]{3,5}$/i);
    return match ? {
      a: 1,
      f: root._currencyCode(match[0])
    } : null;
  }
  function activate(): void {
    Utils.copyText(_resultText);
  }
  function claims(query: string): bool {
    const input = String(query || "").trim();
    const conversion = input.match(/^(.+?)\s+(?:to|in|->|=>|=)\s*([a-zA-Z]{3,5}|[$€£¥₹₿])?$/i);
    const parsed = root._parseSource(conversion ? conversion[1] : input, !!conversion);
    if (!parsed)
      return false;
    parsed.t = conversion?.[2] ? root._currencyCode(conversion[2]) : parsed.f === "egp" ? "usd" : "egp";
    if (parsed.f === parsed.t)
      return false;
    const fromRate = Number(rates[parsed.f]);
    const toRate = Number(rates[parsed.t]);
    if (!Number.isFinite(parsed.a) || !Number.isFinite(fromRate) || !Number.isFinite(toRate) || fromRate <= 0 || toRate <= 0)
      return false;
    const out = (parsed.a / fromRate) * toRate;
    if (!Number.isFinite(out))
      return false;
    const decimals = out >= 100 ? 2 : (out >= 1 ? 4 : 6);
    _fromCode = parsed.f;
    _toCode = parsed.t;
    _inputAmount = parsed.a;
    _resultText = Math.abs(out) < 0.01 && out !== 0 ? out.toPrecision(6) : out.toLocaleString(Qt.locale(), "f", decimals);

    Logger.log("CurrencyProvider", `Query success: ${parsed.a} ${parsed.f} -> ${out} ${parsed.t} (${root.fromFlag} -> ${root.toFlag})`);
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
