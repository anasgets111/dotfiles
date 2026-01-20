// Markdown to HTML converter
// Copied from https://github.com/anasgets111/DankMaterialShell/blob/master/Common/markdown2html.js
// This exists only beacause I haven't been able to get linkColor to work with MarkdownText
// May not be necessary if that's possible tbh.
pragma Singleton
import QtQuick

QtObject {
  function looksLikeHtml(text) {
    if (typeof text !== "string")
      return false;

    return text.search(/<\s*\/?\s*[a-zA-Z!][^>]*>/) !== -1;
  }

  function looksLikeMarkdown(text) {
    if (typeof text !== "string")
      return false;

    const trimmed = text.trim();
    if (trimmed.length === 0)
      return false;

    if (looksLikeHtml(trimmed))
      return false;

    return trimmed.search(/(\*\*|__|~~|`|\[[^\]]+\]\([^ )]+\)|^\s{0,3}[-*+]\s|^\s{0,3}\d+\.\s|^>\s|\n>\s|^\s{0,3}#{1,6}\s|(?:https?|file):\/\/)/m) !== -1;
  }

  function markdownToHtml(text) {
    // paste the fixed JS body here, return html string
    return (function (text) {
        if (!text)
          return "";

        const codeBlocks = [], inlineCode = [], linkPlaceholders = [];
        let blockIndex = 0, inlineIndex = 0, linkIndex = 0;
        let html = text.replace(/```[\s\S]*?```/g, m => {
          const trimmedCode = m.slice(3, -3).replace(/^\n+|\n+$/g, '');
          const escaped = trimmedCode.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
          codeBlocks.push(`<pre><code>${escaped}</code></pre>`);
          return `\x00CODEBLOCK${blockIndex++}\x00`;
        });
        html = html.replace(/`([^`]+)`/g, (m, code) => {
          const escaped = code.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
          inlineCode.push(`<code>${escaped}</code>`);
          return `\x00INLINECODE${inlineIndex++}\x00`;
        });
        html = html.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
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
        html = html.replace(/(?:<li>[\s\S]*?<\/li>\s*)+/g, m => {
          return '<ul>' + m + '</ul>';
        });
        html = html.replace(/\x00MDLINK(\d+)\x00/g, (m, i) => {
          return linkPlaceholders[parseInt(i, 10)];
        });
        html = html.replace(/\x00CODEBLOCK(\d+)\x00/g, (m, i) => {
          return codeBlocks[parseInt(i, 10)];
        });
        html = html.replace(/\x00INLINECODE(\d+)\x00/g, (m, i) => {
          return inlineCode[parseInt(i, 10)];
        });
        html = html.replace(/\n\n/g, '</p><p>').replace(/\n/g, '<br/>');
        if (!/^\s*</.test(html))
          html = '<p>' + html + '</p>';

        html = html.replace(/<br\/>\s*<pre>/g, '<pre>').replace(/<br\/>\s*<ul>/g, '<ul>').replace(/<br\/>\s*<(h[1-6])>/g, '<$1>').replace(/<p>\s*<\/p>/g, '').replace(/<p>\s*<br\/>\s*<\/p>/g, '').replace(/(<br\/>){3,}/g, '<br/><br/>').replace(/(<\/p>)\s*(<p>)/g, '$1$2');
        return html.trim();
      })(text);
  }

  function toDisplay(raw) {
    if (typeof raw !== "string" || raw.length === 0)
      return ({
          "text": "",
          "format": Qt.PlainText
        });

    if (looksLikeHtml(raw))
      return ({
          "text": raw,
          "format": Qt.RichText
        });

    if (looksLikeMarkdown(raw)) {
      try {
        return ({
            "text": markdownToHtml(raw),
            "format": Qt.RichText
          });
      } catch (err) {
        console.warn("Markdown2Html", "markdownToHtml failed", err);
      }
    }
    return ({
        "text": raw,
        "format": Qt.PlainText
      });
  }
}
