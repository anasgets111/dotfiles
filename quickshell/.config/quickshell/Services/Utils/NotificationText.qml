pragma Singleton
import QtQuick
import Quickshell

Singleton {
  readonly property var htmlEntities: ({
      quot: "\"",
      apos: "'",
      amp: "&",
      lt: "<",
      gt: ">"
    })
  readonly property var safeUrlPattern: /^(https?|file):\/\//i

  function body(value: var): var {
    if (typeof value !== "string" || value.length === 0)
      return result("", Qt.PlainText, "");
    if (looksLikeMarkup(value))
      return result(sanitizeMarkup(value), Qt.RichText, plainBody(value));
    if (looksLikeMarkdown(value)) {
      try {
        return result(markdownToHtml(decodeEntities(value)), Qt.RichText, plainBody(value));
      } catch (error) {
        console.warn("NotificationText", "markdownToHtml failed", error);
      }
    }
    return result(decodeEntities(value), Qt.PlainText, plainBody(value));
  }

  function decodeEntities(value: var): string {
    return typeof value !== "string" ? "" : value.replace(/&(#x[0-9a-fA-F]+|#\d+|quot|apos|amp|lt|gt);/g, (match, entity) => {
      if (htmlEntities[entity] !== undefined)
        return htmlEntities[entity];

      const codePoint = entity[1].toLowerCase() === "x" ? parseInt(entity.slice(2), 16) : parseInt(entity.slice(1), 10);
      try {
        return String.fromCodePoint(codePoint);
      } catch (error) {
        return match;
      }
    });
  }

  function escapeAttribute(value: var): string {
    return escapeHtml(value).replace(/"/g, "&quot;");
  }

  function escapeHtml(value: var): string {
    return String(value ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  function looksLikeMarkdown(value: var): bool {
    if (typeof value !== "string")
      return false;

    const trimmedText = value.trim();
    return trimmedText.length > 0 && !looksLikeMarkup(trimmedText) && /(\*\*|__|~~|`|\[[^\]]+\]\([^ )]+\)|^\s{0,3}[-*+]\s|^\s{0,3}\d+\.\s|^>\s|\n>\s|^\s{0,3}#{1,6}\s|(?:https?|file):\/\/)/m.test(trimmedText);
  }

  function looksLikeMarkup(value: var): bool {
    return typeof value === "string" && /<\s*\/?\s*[a-zA-Z!][^>]*>/.test(value);
  }

  function markdownToHtml(value: var): string {
    if (!value)
      return "";

    const codeBlocks = [];
    const inlineCodeBlocks = [];
    const links = [];
    let html = String(value).replace(/```[\s\S]*?```/g, match => {
      const code = match.slice(3, -3).replace(/^\n+|\n+$/g, "");
      return storePlaceholder(codeBlocks, "CODEBLOCK", `<pre><code>${escapeHtml(code)}</code></pre>`);
    });

    html = html.replace(/`([^`]+)`/g, (match, code) => storePlaceholder(inlineCodeBlocks, "INLINECODE", `<code>${escapeHtml(code)}</code>`));
    html = escapeHtml(html);
    html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (match, label, href) => {
      const url = safeUrl(href);
      return url ? storePlaceholder(links, "MDLINK", `<a href="${escapeAttribute(url)}">${label}</a>`) : label;
    });
    html = html.replace(/(^|[\s([*_`\-])((?:https?|file):\/\/[^\s<>'"]*)/gi, (match, prefix, url) => {
      const href = safeUrl(url);
      return href ? prefix + storePlaceholder(links, "MDLINK", `<a href="${escapeAttribute(href)}">${url}</a>`) : match;
    });

    const rules = [[/^### (.*?)$/gm, "<h3>$1</h3>"], [/^## (.*?)$/gm, "<h2>$1</h2>"], [/^# (.*?)$/gm, "<h1>$1</h1>"], [/\*\*\*(.*?)\*\*\*/g, "<b><i>$1</i></b>"], [/\*\*(.*?)\*\*/g, "<b>$1</b>"], [/\*(.*?)\*/g, "<i>$1</i>"], [/___(.*?)___/g, "<b><i>$1</i></b>"], [/__(.*?)__/g, "<b>$1</b>"], [/_(.*?)_/g, "<i>$1</i>"], [/^\s*[-*]\s+(.*?)$/gm, "<li>$1</li>"], [/^\s*\d+\.\s+(.*?)$/gm, "<li>$1</li>"], [/(?:<li>[\s\S]*?<\/li>\s*)+/g, match => `<ul>${match}</ul>`], [/\x00MDLINK(\d+)\x00/g, (match, index) => links[parseInt(index, 10)] ?? ""], [/\x00CODEBLOCK(\d+)\x00/g, (match, index) => codeBlocks[parseInt(index, 10)] ?? ""], [/\x00INLINECODE(\d+)\x00/g, (match, index) => inlineCodeBlocks[parseInt(index, 10)] ?? ""], [/\n\n/g, "</p><p>"], [/\n/g, "<br/>"]];
    for (const rule of rules)
      html = html.replace(rule[0], rule[1]);

    if (!/^\s*</.test(html))
      html = `<p>${html}</p>`;

    return html.replace(/<br\/>\s*<pre>/g, "<pre>").replace(/<br\/>\s*<ul>/g, "<ul>").replace(/<br\/>\s*<(h[1-6])>/g, "<$1>").replace(/<p>\s*(<br\/>)?\s*<\/p>/g, "").replace(/(<br\/>){3,}/g, "<br/><br/>").replace(/(<\/p>)\s*(<p>)/g, "$1$2").trim();
  }

  function plainBody(value: var): string {
    const text = decodeEntities(value);
    return looksLikeMarkup(text) ? text.replace(/<\s*br\s*\/?\s*>/gi, "\n").replace(/<[^>]*>/g, "") : text;
  }

  function result(text: string, format: int, plain: string): var {
    return {
      text: text,
      format: format,
      plain: plain
    };
  }

  function safeUrl(value: var): string {
    const url = decodeEntities(value).trim();
    return safeUrlPattern.test(url) ? url : "";
  }

  function sanitizeMarkup(value: var): string {
    const source = String(value ?? "");
    const tagPattern = /<[^>]*>/g;
    let output = "";
    let textStart = 0;
    let tagMatch = tagPattern.exec(source);

    while (tagMatch) {
      output += escapeHtml(decodeEntities(source.slice(textStart, tagMatch.index)));
      output += sanitizeTag(tagMatch[0]);
      textStart = tagMatch.index + tagMatch[0].length;
      tagMatch = tagPattern.exec(source);
    }

    return output + escapeHtml(decodeEntities(source.slice(textStart)));
  }

  function sanitizeTag(tag: string): string {
    const parsedTag = tag.match(/^<\s*(\/?)\s*([a-zA-Z][\w:-]*)\b([^>]*)\/?\s*>$/);
    if (!parsedTag)
      return "";

    const isClosing = parsedTag[1] === "/";
    const tagName = parsedTag[2].toLowerCase();
    if (["b", "i", "u"].includes(tagName))
      return isClosing ? `</${tagName}>` : `<${tagName}>`;
    if (tagName === "br")
      return isClosing ? "" : "<br/>";
    if (tagName !== "a")
      return "";
    if (isClosing)
      return "</a>";

    const hrefMatch = parsedTag[3].match(/\bhref\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/i);
    const href = hrefMatch ? safeUrl(hrefMatch[1] ?? hrefMatch[2] ?? hrefMatch[3] ?? "") : "";
    return href ? `<a href="${escapeAttribute(href)}">` : "";
  }

  function storePlaceholder(values: var, prefix: string, html: string): string {
    const index = values.length;
    values.push(html);
    return `\x00${prefix}${index}\x00`;
  }

  function summary(value: var): var {
    const text = typeof value === "string" && value.length > 0 ? decodeEntities(value) : "(No title)";
    return result(text, Qt.PlainText, text);
  }
}
