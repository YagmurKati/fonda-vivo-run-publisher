/* FONDA: collapse over-long single-value property fields behind a "... more"
   toggle.  (2026-08-21, v3)

   VIVO's own moreLessController.js already does this, but it triggers on the
   number of <li> in a list against the property's displayLimit. An abstract or
   a workflow "purpose" is a single <li> holding a long passage, so it never
   qualifies. This applies the same control on rendered height instead, reusing
   class="more-less" and the i18nStrings labels so the toggle is the control
   users already see on multi-value fields.

   v2 pinned max-height to LINES * line-height. That is only correct when every
   line box is the same height. Rich-text values are not: propStatement-
   dataDefault.ftl rewrites <p> as <p style='margin-bottom:.6em'>, so a value
   with two paragraphs is eight lines PLUS a paragraph gap, and a height
   computed from line-height alone cut through the middle of a line.

   v3 measures instead of calculating. A Range over the value's contents yields
   one rect per rendered line box, across paragraphs and margins alike, so the
   bottom edge of the LINES-th rect is the true cut point whatever the content
   is made of. That also makes it correct after a window resize, when the line
   breaks move -- see remeasure(). */
(function () {
    "use strict";

    var LINES = 8;

    function previewLines(li) {
        var id = li.parentNode.id;
        return id === "nodeConditionsMethod-noRangeClass-List" ||
               id === "energyCalculationMethod-noRangeClass-List" ? 3 : LINES;
    }

    function label(key, fallback) {
        return (window.i18nStrings && window.i18nStrings[key]) || fallback;
    }

    /* One rect per rendered line box. getClientRects can also emit a rect for a
       whole block child, which would be counted as a line; those are filtered
       by height, and any remaining duplicates by vertical position. */
    function lineRects(el, lineHeight) {
        var range = document.createRange();
        range.selectNodeContents(el);
        var all = range.getClientRects();
        var out = [], seen = {}, i, r, key;
        for (i = 0; i < all.length; i++) {
            r = all[i];
            if (r.height <= 0 || r.width <= 0) continue;
            if (lineHeight && r.height > lineHeight * 1.6) continue;  // block rect
            key = Math.round(r.top);
            if (seen[key]) continue;
            seen[key] = 1;
            out.push(r);
        }
        return out;
    }

    /* Height at which to cut, or null if the value is short enough already. */
    function cutHeight(li) {
        var lines = previewLines(li);
        var cs = window.getComputedStyle(li);
        var lh = parseFloat(cs.lineHeight) || 0;
        var rects = lineRects(li, lh);
        if (rects.length <= lines) return null;
        var cut = rects[lines - 1].bottom - li.getBoundingClientRect().top;
        if (cs.boxSizing !== "border-box") {
            cut -= parseFloat(cs.paddingTop) || 0;
        }
        return cut > 0 ? cut : null;
    }

    function clamp(ul) {
        var items = ul.querySelectorAll(":scope > li");
        if (items.length !== 1) return;             // multi-value: VIVO handles it
        var li = items[0];
        if (li.classList.contains("f-clamped")) return;
        if (li.querySelector("ul, ol")) return;     // nested lists, leave alone

        li.classList.add("f-clamped");              // applies padding-bottom:0
        var cut = cutHeight(li);
        if (cut === null) {                         // short enough after all
            li.classList.remove("f-clamped");
            return;
        }
        li.style.setProperty("--f-clamp-lines", String(previewLines(li)));
        li.style.maxHeight = cut + "px";

        var a = document.createElement("a");
        a.className = "more-less f-clamp-toggle";
        a.href = "#show more content";
        a.title = label("showMoreContent", "Show more content");
        a.textContent = label("displayMoreEllipsis", "... more");
        a.addEventListener("click", function (e) {
            e.preventDefault();
            var open = li.classList.toggle("f-clamp-open");
            if (open) {
                li.style.maxHeight = "";
            } else {
                li.style.maxHeight = "";            // release before measuring
                var h = cutHeight(li);
                li.style.maxHeight = h === null ? "" : h + "px";
            }
            a.textContent = open ? label("displayLess", "less")
                                 : label("displayMoreEllipsis", "... more");
            a.title = open ? label("showLessContent", "Show less content")
                           : label("showMoreContent", "Show more content");
        });
        ul.appendChild(a);
    }

    function init() {
        var lists = document.querySelectorAll("article.property > ul.property-list");
        Array.prototype.forEach.call(lists, clamp);
    }

    /* Line breaks move when the window is resized, so a height measured at one
       width is wrong at another. Re-measure the collapsed ones; expanded ones
       have no pinned height to correct. */
    function remeasure() {
        var done = document.querySelectorAll("li.f-clamped:not(.f-clamp-open)");
        Array.prototype.forEach.call(done, function (li) {
            li.style.maxHeight = "";
            var h = cutHeight(li);
            li.style.maxHeight = h === null ? "" : h + "px";
        });
    }

    /* Panes in unselected tabs are display:none and measure zero height, so
       they cannot be judged on load. init() is idempotent. */
    function watch() {
        // The theme's delegated tab handler stops bubbling at body.
        document.addEventListener("click", function (e) {
            if (e.target && e.target.closest && e.target.closest(".nav-tabs")) {
                window.setTimeout(init, 0);
            }
        }, true);
        var t;
        window.addEventListener("resize", function () {
            window.clearTimeout(t);
            t = window.setTimeout(remeasure, 150);
        });
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", function () { init(); watch(); });
    } else {
        init();
        watch();
    }
})();
