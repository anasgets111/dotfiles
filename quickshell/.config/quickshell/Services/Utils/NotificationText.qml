pragma Singleton
import QtQuick

QtObject {
  function decodeEntities(text) {
    const named = {
      quot: "\"",
      apos: "'",
      amp: "&",
      lt: "<",
      gt: ">"
    };
    return text.replace(/&(#x[0-9a-fA-F]+|#\d+|quot|apos|amp|lt|gt);/g, (m, entity) => {
      if (named[entity] !== undefined)
        return named[entity];
      const code = entity[1].toLowerCase() === "x" ? parseInt(entity.slice(2), 16) : parseInt(entity.slice(1), 10);
      try {
        return String.fromCodePoint(code);
      } catch (_) {
        return m;
      }
    });
  }

  function escapeHtml(text) {
    return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function escapeAttribute(text) {
    return escapeHtml(text).replace(/"/g, "&quot;");
  }

  function looksLikeMarkup(text) {
    if (typeof text !== "string")
      return false;

    return text.search(/<\s*\/?\s*[a-zA-Z!][^>]*>/) !== -1;
  }

  function plainBody(raw) {
    if (typeof raw !== "string")
      return "";

    if (!looksLikeMarkup(raw))
      return decodeEntities(raw);

    return decodeEntities(raw.replace(/<\s*br\s*\/?\s*>/gi, "\n").replace(/<[^>]*>/g, ""));
  }

  function sanitizeMarkup(raw) {
    const tags = /<[^>]*>/g;
    let out = "";
    let lastIndex = 0;
    let match;
    while ((match = tags.exec(raw)) !== null) {
      out += escapeHtml(decodeEntities(raw.slice(lastIndex, match.index)));
      out += sanitizeTag(match[0]);
      lastIndex = match.index + match[0].length;
    }
    return out + escapeHtml(decodeEntities(raw.slice(lastIndex)));
  }

  function sanitizeTag(tag) {
    const parsed = tag.match(/^<\s*(\/?)\s*([a-zA-Z][\w:-]*)\b([^>]*)\/?\s*>$/);
    if (!parsed)
      return "";

    const closing = parsed[1] === "/";
    const name = parsed[2].toLowerCase();
    const attrs = parsed[3] || "";
    if (["b", "i", "u"].includes(name))
      return closing ? `</${name}>` : `<${name}>`;
    if (name === "br")
      return closing ? "" : "<br/>";
    if (name !== "a")
      return "";
    if (closing)
      return "</a>";

    const href = attrs.match(/\bhref\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/i);
    return href ? `<a href="${escapeAttribute(decodeEntities(href[1] ?? href[2] ?? href[3] ?? ""))}">` : "";
  }

  function looksLikeMarkdown(text) {
    if (typeof text !== "string")
      return false;

    const trimmed = text.trim();
    if (trimmed.length === 0 || looksLikeMarkup(trimmed))
      return false;

    return trimmed.search(/(\*\*|__|~~|`|\[[^\]]+\]\([^ )]+\)|^\s{0,3}[-*+]\s|^\s{0,3}\d+\.\s|^>\s|\n>\s|^\s{0,3}#{1,6}\s|(?:https?|file):\/\/)/m) !== -1;
  }

  function markdownToHtml(text) {
    if (!text)
      return "";

    const codeBlocks = [], inlineCode = [], linkPlaceholders = [];
    let blockIndex = 0, inlineIndex = 0, linkIndex = 0;
    let html = text.replace(/```[\s\S]*?```/g, m => {
      const trimmedCode = m.slice(3, -3).replace(/^\n+|\n+$/g, '');
      codeBlocks.push(`<pre><code>${escapeHtml(trimmedCode)}</code></pre>`);
      return `\x00CODEBLOCK${blockIndex++}\x00`;
    });
    html = html.replace(/`([^`]+)`/g, (m, code) => {
      inlineCode.push(`<code>${escapeHtml(code)}</code>`);
      return `\x00INLINECODE${inlineIndex++}\x00`;
    });
    html = escapeHtml(html);
    html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (m, label, href) => {
      const ph = `\x00MDLINK${linkIndex++}\x00`;
      linkPlaceholders.push(`<a href="${href}">${label}</a>`);
      return ph;
    });
    html = html.replace(/(^|[\s([\*_`\-])((?:https?|file):\/\/[^\s<>\'"]*)/gi, (m, pre, url) => {
      const ph = `\x00MDLINK${linkIndex++}\x00`;
      const safeUrl = url.replace(/"/g, "&quot;");
      linkPlaceholders.push(`<a href="${safeUrl}">${url}</a>`);
      return pre + ph;
    });
    html = html.replace(/^### (.*?)$/gm, '<h3>$1</h3>');
    html = html.replace(/^## (.*?)$/gm, '<h2>$1</h2>');
    html = html.replace(/^# (.*?)$/gm, '<h1>$1</h1>');
    html = html.replace(/\*\*\*(.*?)\*\*\*/g, '<b><i>$1</i></b>');
    html = html.replace(/\*\*(.*?)\*\*/g, '<b>$1</b>');
    html = html.replace(/\*(.*?)\*/g, '<i>$1</i>');
    html = html.replace(/___(.*?)___/g, '<b><i>$1</i></b>');
    html = html.replace(/__(.*?)__/g, '<b>$1</b>');
    html = html.replace(/_(.*?)_/g, '<i>$1</i>');
    html = html.replace(/^\* (.*?)$/gm, '<li>$1</li>');
    html = html.replace(/^- (.*?)$/gm, '<li>$1</li>');
    html = html.replace(/^\d+\. (.*?)$/gm, '<li>$1</li>');
    html = html.replace(/(?:<li>[\s\S]*?<\/li>\s*)+/g, m => '<ul>' + m + '</ul>');
    html = html.replace(/\x00MDLINK(\d+)\x00/g, (m, i) => linkPlaceholders[parseInt(i, 10)]);
    html = html.replace(/\x00CODEBLOCK(\d+)\x00/g, (m, i) => codeBlocks[parseInt(i, 10)]);
    html = html.replace(/\x00INLINECODE(\d+)\x00/g, (m, i) => inlineCode[parseInt(i, 10)]);
    html = html.replace(/\n\n/g, '</p><p>').replace(/\n/g, '<br/>');
    if (!/^\s*</.test(html))
      html = '<p>' + html + '</p>';

    html = html.replace(/<br\/>\s*<pre>/g, '<pre>').replace(/<br\/>\s*<ul>/g, '<ul>').replace(/<br\/>\s*<(h[1-6])>/g, '<$1>').replace(/<p>\s*<\/p>/g, '').replace(/<p>\s*<br\/>\s*<\/p>/g, '').replace(/(<br\/>){3,}/g, '<br/><br/>').replace(/(<\/p>)\s*(<p>)/g, '$1$2');
    return html.trim();
  }

  function body(raw) {
    if (typeof raw !== "string" || raw.length === 0)
      return ({
          "text": "",
          "format": Qt.PlainText,
          "plain": ""
        });

    if (looksLikeMarkup(raw))
      return ({
          "text": sanitizeMarkup(raw),
          "format": Qt.RichText,
          "plain": plainBody(raw)
        });

    if (looksLikeMarkdown(raw)) {
      try {
        return ({
            "text": markdownToHtml(decodeEntities(raw)),
            "format": Qt.RichText,
            "plain": plainBody(raw)
          });
      } catch (err) {
        console.warn("NotificationText", "markdownToHtml failed", err);
      }
    }
    return ({
        "text": decodeEntities(raw),
        "format": Qt.PlainText,
        "plain": plainBody(raw)
      });
  }

  function summary(raw) {
    const text = typeof raw === "string" && raw.length > 0 ? decodeEntities(raw) : "(No title)";
    return ({
        "text": text,
        "format": Qt.PlainText,
        "plain": text
      });
  }
}
