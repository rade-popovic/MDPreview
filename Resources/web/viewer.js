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
  };

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
