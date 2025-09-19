// Markdown to HTML converter
// Copied from https://github.com/anasgets111/DankMaterialShell/blob/master/Common/markdown2html.js
// This exists only beacause I haven't been able to get linkColor to work with MarkdownText
// May not be necessary if that's possible tbh.
pragma Singleton
import QtQuick

QtObject {
  function markdownToHtml(text) {
    // paste the fixed JS body here, return html string
    return (function (text) {
        if (!text)
          return "";
        const codeBlocks = [], inlineCode = [], linkPlaceholders = [];
        let blockIndex = 0, inlineIndex = 0, linkIndex = 0;
        let html = text.replace(/``````/g, (m, code) => {
          const trimmedCode = code.replace(/^\n+|\n+$/g, '');
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
        html = html.replace(/(^|[\s(])((?:https?|file):\/\/[^\s<)]+)/g, (m, pre, url) => {
          const ph = `\x00MDLINK${linkIndex++}\x00`;
          linkPlaceholders.push(`<a href="${url}">${url}</a>`);
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
      })(text);
  }
}
