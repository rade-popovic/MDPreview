// Markdown -> HTML, shared by the app (in a web view) and the Quick Look
// extension (in JavaScriptCore, no DOM). Needs marked and highlight.js loaded first.
(function (root) {
  "use strict";

  const base = new marked.Renderer();
  let rewriteImage = null;

  // Show YAML front matter as a code block instead of a stray <hr> and paragraph.
  function frontMatterAsCode(markdown) {
    const match = markdown.match(/^---\r?\n([\s\S]*?)\r?\n(?:---|\.\.\.)[ \t]*(?:\r?\n|$)/);
    if (!match) return markdown;
    return "```yaml\n" + match[1] + "\n```\n\n" + markdown.slice(match[0].length);
  }

  function escapeAttribute(text) {
    return text.replace(/[&"<>]/g, function (c) {
      return { "&": "&amp;", '"': "&quot;", "<": "&lt;", ">": "&gt;" }[c];
    });
  }

  marked.use({
    gfm: true,
    renderer: {
      code(token) {
        const lang = (token.lang || "").match(/^\S*/)[0];
        if (!lang || !hljs.getLanguage(lang)) return false;
        const highlighted = hljs.highlight(token.text, { language: lang, ignoreIllegals: true }).value;
        return '<pre><code class="hljs language-' + escapeAttribute(lang) + '">' + highlighted + "</code></pre>\n";
      },

      // Classes the GitHub stylesheet uses to drop bullets from checkbox lists.
      list(token) {
        const html = base.list.call(this, token);
        return token.items.some(function (item) { return item.task; })
          ? html.replace(/^<(ul|ol)/, '<$1 class="contains-task-list"')
          : html;
      },
      listitem(item) {
        const html = base.listitem.call(this, item);
        return item.task ? html.replace(/^<li>/, '<li class="task-list-item">') : html;
      },
      checkbox(token) {
        return '<input class="task-list-item-checkbox" type="checkbox" disabled' + (token.checked ? " checked" : "") + ">";
      },

      image(token) {
        const href = rewriteImage && rewriteImage(token.href);
        return href ? base.image.call(this, Object.assign({}, token, { href: href })) : false;
      },
    },
  });

  function render(markdown) {
    return marked.parse(frontMatterAsCode(markdown));
  }

  function isLocal(href) {
    return !/^(?:[a-z][a-z0-9+.-]*:|\/\/|#)/i.test(href);
  }

  // For Quick Look: local images become cid:imgN references, and their
  // paths (relative to the document) are returned so the caller can attach them.
  function renderWithLocalImages(markdown) {
    const images = [];
    rewriteImage = function (href) {
      if (!isLocal(href)) return null;
      let path = href.split(/[?#]/)[0];
      try { path = decodeURI(path); } catch (e) {}
      images.push(path);
      return "cid:img" + (images.length - 1);
    };
    try {
      return { html: render(markdown), images: images };
    } finally {
      rewriteImage = null;
    }
  }

  root.MDPreviewCore = { render: render, renderWithLocalImages: renderWithLocalImages };
})(globalThis);
