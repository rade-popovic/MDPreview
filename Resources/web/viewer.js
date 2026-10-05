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

  window.render = function (markdown, keepScroll) {
    const scrollY = window.scrollY;
    const root = document.getElementById("content");
    root.innerHTML = DOMPurify.sanitize(MDPreviewCore.render(markdown));

    const used = {};
    root.querySelectorAll("h1, h2, h3, h4, h5, h6").forEach(function (h) {
      if (!h.id) h.id = slugify(h.textContent, used);
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
