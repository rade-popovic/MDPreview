(function () {
  "use strict";

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

  function post(message) {
    const handlers = window.webkit && window.webkit.messageHandlers;
    if (handlers && handlers.viewer) handlers.viewer.postMessage(message);
  }

  // Outline: the app's sidebar lists `headings` and highlights the one being read.
  let headings = [];
  let current = null;
  let ignoreScrollUntil = 0;

  function reportCurrent(index) {
    if (index === current) return;
    current = index;
    post({ type: "current", index: index });
  }

  function updateCurrent() {
    if (performance.now() < ignoreScrollUntil) return;
    let index = headings.length ? 0 : null;
    for (let i = 0; i < headings.length; i++) {
      if (headings[i].getBoundingClientRect().top > 24) break;
      index = i;
    }
    reportCurrent(index);
  }

  // Keeps the clicked heading selected even when it can't scroll to the very top.
  function scrollToElement(element) {
    ignoreScrollUntil = performance.now() + 300;
    element.scrollIntoView();
    const index = headings.indexOf(element);
    if (index >= 0) reportCurrent(index);
  }

  window.scrollToHeading = function (index) {
    if (headings[index]) scrollToElement(headings[index]);
  };

  window.render = function (markdown, keepScroll) {
    const scrollY = window.scrollY;
    const root = document.getElementById("content");
    root.innerHTML = DOMPurify.sanitize(MDPreviewCore.render(markdown));

    const used = {};
    headings = Array.from(root.querySelectorAll("h1, h2, h3, h4, h5, h6"));
    headings.forEach(function (h) {
      if (!h.id) h.id = slugify(h.textContent, used);
    });
    post({
      type: "outline",
      items: headings.map(function (h) {
        return { level: Number(h.tagName[1]), title: h.textContent.trim() };
      }),
    });

    if (keepScroll) window.scrollTo(0, scrollY);
    current = null;
    updateCurrent();
    if (query) search(query, true);
  };

  // Search: highlights every match; the app's find bar steps through them.
  const BLOCKS = "p, li, h1, h2, h3, h4, h5, h6, td, th, pre, blockquote, dt, dd, figcaption, summary";
  let query = "";
  let matches = [];
  let currentMatch = -1;

  // All text in the document, with a line break between blocks so matches
  // can span inline formatting but not jump from one paragraph to the next.
  function textIndex() {
    const walker = document.createTreeWalker(document.getElementById("content"), NodeFilter.SHOW_TEXT);
    const nodes = [];
    let text = "";
    let lastBlock = null;
    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
      const block = node.parentElement.closest(BLOCKS);
      if (nodes.length && block !== lastBlock) text += "\n";
      lastBlock = block;
      nodes.push({ node: node, start: text.length });
      text += node.data;
    }
    return { nodes: nodes, text: text };
  }

  // Case-insensitive, keeping offsets identical to the original text.
  function fold(text) {
    let out = "";
    for (let i = 0; i < text.length; i++) {
      const lower = text[i].toLowerCase();
      out += lower.length === 1 ? lower : text[i];
    }
    return out;
  }

  function nodeAt(nodes, offset) {
    let lo = 0;
    let hi = nodes.length - 1;
    while (lo < hi) {
      const mid = (lo + hi + 1) >> 1;
      if (nodes[mid].start <= offset) lo = mid; else hi = mid - 1;
    }
    return nodes[lo];
  }

  window.search = function (text, keepPosition) {
    const previous = currentMatch;
    query = text;
    matches = [];
    if (text) {
      const index = textIndex();
      const haystack = fold(index.text);
      const needle = fold(text);
      for (let from = 0; matches.length < 5000; ) {
        const start = haystack.indexOf(needle, from);
        if (start < 0) break;
        const end = start + needle.length;
        const first = nodeAt(index.nodes, start);
        const last = nodeAt(index.nodes, end - 1);
        const range = document.createRange();
        range.setStart(first.node, start - first.start);
        range.setEnd(last.node, end - last.start);
        matches.push(range);
        from = end;
      }
    }
    if (window.CSS && CSS.highlights) CSS.highlights.set("search", new Highlight(...matches));
    post({ type: "search", count: matches.length });
    currentMatch = -1;
    selectMatch(keepPosition && previous >= 0 ? Math.min(previous, matches.length - 1) : 0, !keepPosition);
  };

  function selectMatch(index, scroll) {
    if (!matches.length) {
      if (window.CSS && CSS.highlights) CSS.highlights.delete("search-current");
      post({ type: "match", index: null });
      return;
    }
    currentMatch = (index % matches.length + matches.length) % matches.length;
    const range = matches[currentMatch];
    if (window.CSS && CSS.highlights) {
      const highlight = new Highlight(range);
      highlight.priority = 1;
      CSS.highlights.set("search-current", highlight);
    }
    if (scroll) {
      const rect = range.getBoundingClientRect();
      if (rect.top < 60 || rect.bottom > window.innerHeight - 60) {
        window.scrollTo(0, window.scrollY + rect.top - window.innerHeight / 3);
      }
    }
    post({ type: "match", index: currentMatch });
  }

  window.stepMatch = function (delta) {
    selectMatch(currentMatch + delta, true);
  };

  // Reading position: restored on open, reported to the app as the reader scrolls.
  let userScrolled = false;
  ["wheel", "keydown", "mousedown"].forEach(function (type) {
    window.addEventListener(type, function () { userScrolled = true; }, { passive: true });
  });

  window.restoreScroll = function (y) {
    if (!y) return;
    window.scrollTo(0, y);
    // Images that load later can shift the layout; settle again unless the reader already moved.
    window.addEventListener("load", function () {
      if (!userScrolled) window.scrollTo(0, y);
    });
  };

  let positionTimer = null;
  window.addEventListener("scroll", function () {
    clearTimeout(positionTimer);
    positionTimer = setTimeout(function () {
      post({ type: "scroll", y: Math.round(window.scrollY) });
    }, 250);
  }, { passive: true });

  let updateScheduled = false;
  function scheduleUpdate() {
    if (updateScheduled) return;
    updateScheduled = true;
    requestAnimationFrame(function () {
      updateScheduled = false;
      updateCurrent();
    });
  }
  window.addEventListener("scroll", scheduleUpdate, { passive: true });
  window.addEventListener("resize", scheduleUpdate);

  // In-page links (#section) scroll here; everything else is handled by the app.
  document.addEventListener("click", function (event) {
    const link = event.target.closest('a[href^="#"]');
    if (!link) return;
    event.preventDefault();
    const id = decodeURIComponent(link.getAttribute("href").slice(1));
    const target = document.getElementById(id) || document.getElementsByName(id)[0];
    if (target) scrollToElement(target);
  });
})();
