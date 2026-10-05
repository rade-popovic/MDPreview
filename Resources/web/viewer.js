(function () {
  "use strict";

  marked.setOptions({ gfm: true });

  // GitHub-style heading anchors: "Getting Started" -> "getting-started", duplicates get "-1", "-2".
  function slugify(text, used) {
    let slug = text.trim().toLowerCase()
      .replace(/[^\p{L}\p{N}\s_-]/gu, "")
      .replace(/\s/g, "-");
    if (slug in used) {
      used[slug] += 1;
      slug = slug + "-" + used[slug];
    } else {
      used[slug] = 0;
    }
    return slug;
  }

  // Show YAML front matter as a code block instead of a stray <hr> and paragraph.
  function frontMatterAsCode(markdown) {
    const match = markdown.match(/^---\r?\n([\s\S]*?)\r?\n(?:---|\.\.\.)[ \t]*(?:\r?\n|$)/);
    if (!match) return markdown;
    return "```yaml\n" + match[1] + "\n```\n\n" + markdown.slice(match[0].length);
  }

  window.render = function (markdown, keepScroll) {
    const scrollY = window.scrollY;
    const root = document.getElementById("content");
    root.innerHTML = DOMPurify.sanitize(marked.parse(frontMatterAsCode(markdown)));

    const used = {};
    root.querySelectorAll("h1, h2, h3, h4, h5, h6").forEach(function (h) {
      if (!h.id) h.id = slugify(h.textContent, used);
    });

    // Classes the GitHub stylesheet uses to drop bullets from checkbox lists.
    root.querySelectorAll('li > input[type="checkbox"]:first-child').forEach(function (box) {
      box.classList.add("task-list-item-checkbox");
      box.parentElement.classList.add("task-list-item");
      box.parentElement.parentElement.classList.add("contains-task-list");
    });

    root.querySelectorAll("pre code").forEach(function (code) {
      const lang = Array.from(code.classList).find(function (c) { return c.startsWith("language-"); });
      if (lang && hljs.getLanguage(lang.slice(9))) hljs.highlightElement(code);
    });

    if (keepScroll) window.scrollTo(0, scrollY);
  };

  // In-page links (#section) scroll here; everything else is handled by the app.
  document.addEventListener("click", function (event) {
    const link = event.target.closest('a[href^="#"]');
    if (!link) return;
    event.preventDefault();
    const id = decodeURIComponent(link.getAttribute("href").slice(1));
    const target = document.getElementById(id) || document.getElementsByName(id)[0];
    if (target) target.scrollIntoView();
  });
})();
