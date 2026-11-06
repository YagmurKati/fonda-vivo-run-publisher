<#-- $This file is distributed under the terms of the license in LICENSE$ -->
<#--
  FONDA 2026-10-15: "Find on this page" on the page of a person, publication, subproject, workflow, ...
  Included at the end of individual-property-group-tabs.ftl. A search box at the right end of the tabs
  (Overview / ... / View All). While you type, the lists of all tabs show only the entries that contain the words
  typed (all words, any order, each at the beginning of a word; upper/lower case and accents do not matter),
  also entries hidden behind "... more";
  the words are marked, lists and tabs without a match are hidden, and the box shows how many entries were found.
  "x" or Esc brings the page back as it was. Below the lists a link opens the site search for the same words.
  Only the lists of the tabs are searched; the parts above the tabs stay as they are. Nothing is stored or sent.
-->
<style>
    .nav-tabs > li.fpf-item { float: right; margin-left: auto; padding: 4px 0 4px 12px; border: 0; }
    .fpf-box { display: flex; align-items: center; width: 270px; max-width: 100%; height: 32px; box-sizing: border-box;
        background: #ffffff; border: 1px solid #c9d2d9; border-radius: 8px; transition: border-color .15s, box-shadow .15s; }
    .fpf-box:focus-within { border-color: #1f3a5f; box-shadow: 0 0 0 3px rgba(31, 58, 95, .16); }
    .fpf-box svg { flex: 0 0 15px; width: 15px; height: 15px; margin: 0 7px 0 10px; stroke: #4a5d75; }
    .fpf-box input[type="text"] { flex: 1 1 auto; min-width: 0; width: auto; height: 30px; margin: 0; padding: 0; border: 0; outline: 0;
        box-shadow: none; background: transparent; font-family: inherit; font-size: 14px; line-height: 30px; color: #1f3a5f; }
    .fpf-box input[type="text"]::placeholder { color: #7b8794; opacity: 1; }
    .fpf-box .fpf-count { flex: 0 0 auto; margin: 0 2px 0 6px; font-size: 12px; color: #6b7785; white-space: nowrap; }
    .fpf-box .fpf-clear { flex: 0 0 26px; width: 26px; height: 26px; margin: 0 2px 0 0; padding: 0; border: 0; border-radius: 6px;
        background: transparent; color: #6b7785; font-size: 17px; line-height: 26px; cursor: pointer; }
    .fpf-box .fpf-clear:hover, .fpf-box .fpf-clear:focus { background: #eef2f6; }
    .fpf-box .fpf-clear[hidden] { display: none; }
    @media (max-width: 640px) {
        .nav-tabs > li.fpf-item { float: none; width: 100%; padding: 6px 0; }
        .fpf-box { width: 100%; }
    }

    /* while searching (class fpf-on on the tab content) */
    html body .tab-content.fpf-on > .tab-pane { display: block !important; }
    html body .tab-content.fpf-on > .tab-pane.fpf-miss,
    html body .tab-content.fpf-on article.property.fpf-miss,
    html body .tab-content.fpf-on li.fpf-miss { display: none !important; }
    html body .tab-content.fpf-on li.fpf-hit { display: list-item !important; }
    html body .tab-content.fpf-on .additionalItems.fpf-open { display: block !important; }
    html body .tab-content.fpf-on a.more-less,
    html body .tab-content.fpf-on li.fonda-publication-toggle { display: none !important; }
    html body .tab-content.fpf-on li.fpf-hit.f-clamped,
    html body .tab-content.fpf-on li.fpf-hit .f-clamped { max-height: none !important; -webkit-line-clamp: unset !important; overflow: visible !important; }
    mark.fpf-mark { background: #dcebf0; color: inherit; padding: 0 1px; border-radius: 2px; }
    p.fpf-note { margin: 14px 0 6px; font-size: 14px; color: #6b7785; }
    p.fpf-note a { color: #064d68; }

    html.dark-mode .fpf-box { background: #1a2334; border-color: #2c3a52; }
    html.dark-mode .fpf-box:focus-within { border-color: #5d7aa5; box-shadow: 0 0 0 3px rgba(93, 140, 205, .25); }
    html.dark-mode .fpf-box svg { stroke: #aab6c6; }
    html.dark-mode .fpf-box input[type="text"] { color: #d5dde7; }
    html.dark-mode .fpf-box input[type="text"]::placeholder { color: #8d96a6; }
    html.dark-mode .fpf-box .fpf-count, html.dark-mode .fpf-box .fpf-clear { color: #8d96a6; }
    html.dark-mode .fpf-box .fpf-clear:hover, html.dark-mode .fpf-box .fpf-clear:focus { background: rgba(127, 192, 221, .14); }
    html.dark-mode mark.fpf-mark { background: rgba(127, 192, 221, .28); color: inherit; }
    html.dark-mode p.fpf-note { color: #8d96a6; }
    html.dark-mode p.fpf-note a { color: #7fc0dd; }
</style>
<script>
(function () {
    'use strict';
    var BASE = "${urls.base?js_string}";

    function fold(text) {
        var t = String(text).toLowerCase();
        t = t.normalize ? t.normalize('NFD').replace(/[\u0300-\u036f]/g, '') : t;
        return t.replace(/\u00df/g, 'ss');
    }
    function words(query) { return fold(query).split(/\s+/).filter(function (w) { return w !== ''; }); }
    // a typed word must match the beginning of a word of the text ("rna" finds "RNA-seq", not "Journal")
    var WORDCHAR = (function () { try { return new RegExp('[\\p{L}\\p{N}]', 'u'); } catch (e) { return /[a-z0-9]/; } })();
    function nextStart(f, w, from) {
        var at = f.indexOf(w, from);
        while (at > 0 && WORDCHAR.test(f.charAt(at - 1))) { at = f.indexOf(w, at + 1); }
        return at;
    }
    function hasAll(text, list) {
        var f = fold(text);
        for (var i = 0; i < list.length; i++) { if (nextStart(f, list[i], 0) === -1) { return false; } }
        return true;
    }
    // ranges [start, end) in the original text where one of the words occurs
    function ranges(text, list) {
        var f = '', map = [], i, k, out = [];
        for (i = 0; i < text.length; i++) {
            var c = fold(text.charAt(i));
            for (k = 0; k < c.length; k++) { f += c.charAt(k); map.push(i); }
        }
        list.forEach(function (w) {
            var at = nextStart(f, w, 0);
            while (at !== -1) { out.push([map[at], map[at + w.length - 1] + 1]); at = nextStart(f, w, at + w.length); }
        });
        out.sort(function (a, b) { return a[0] - b[0]; });
        var merged = [];
        out.forEach(function (r) {
            var last = merged[merged.length - 1];
            if (last && r[0] <= last[1]) { last[1] = Math.max(last[1], r[1]); } else { merged.push([r[0], r[1]]); }
        });
        return merged;
    }
    function markIn(element, list) {
        var walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT, null, false), nodes = [], node;
        while ((node = walker.nextNode())) {
            var p = node.parentNode;
            if (p && !/^(SCRIPT|STYLE|MARK)$/.test(p.nodeName) && node.nodeValue.trim() !== '') { nodes.push(node); }
        }
        nodes.forEach(function (textNode) {
            var found = ranges(textNode.nodeValue, list);
            for (var i = found.length - 1; i >= 0; i--) {
                var after = textNode.splitText(found[i][0]);
                after.splitText(found[i][1] - found[i][0]);
                var mark = document.createElement('mark');
                mark.className = 'fpf-mark';
                after.parentNode.replaceChild(mark, after);
                mark.appendChild(after);
            }
        });
    }
    function unmarkIn(element) {
        Array.prototype.slice.call(element.querySelectorAll('mark.fpf-mark')).forEach(function (mark) {
            var parent = mark.parentNode;
            while (mark.firstChild) { parent.insertBefore(mark.firstChild, mark); }
            parent.removeChild(mark);
            parent.normalize();
        });
    }

    function start() {
        // the tab content with the lists, and its tabs (the tabs list that has the tab of a group)
        var content = document.querySelector('#property-tabs .tab-content') || document.querySelector('.tab-content');
        if (!content || !content.querySelector('article.property')) { return; }
        var tabs = null;
        Array.prototype.slice.call(document.querySelectorAll('ul.nav-tabs')).forEach(function (ul) {
            if (!tabs && ul.querySelector('li[data-toggle="tab"]')) { tabs = ul; }
        });
        if (!tabs || tabs.querySelector('li.fpf-item')) { return; }

        var item = document.createElement('li');
        item.className = 'fpf-item';
        item.setAttribute('role', 'presentation');
        item.innerHTML = '<div class="fpf-box" role="search">' +
            '<svg viewBox="0 0 24 24" fill="none" stroke-width="2.2" stroke-linecap="round" aria-hidden="true">' +
            '<circle cx="10.5" cy="10.5" r="6.5"/><line x1="15.5" y1="15.5" x2="21" y2="21"/></svg>' +
            '<input type="text" autocomplete="off" placeholder="Find on this page" aria-label="Find on this page" />' +
            '<span class="fpf-count" aria-live="polite"></span>' +
            '<button type="button" class="fpf-clear" title="Clear" aria-label="Clear" hidden>\u00d7</button></div>';
        tabs.appendChild(item);
        var input = item.querySelector('input'), count = item.querySelector('.fpf-count'), clear = item.querySelector('.fpf-clear');
        var opened = [], timer = null;

        function entries() {
            // the entries of the lists: list items that are not a group heading of a list (li.subclass), not the
            // "... more" row and not inside another entry
            return Array.prototype.slice.call(content.querySelectorAll('article.property ul.property-list li')).filter(function (li) {
                if (li.classList.contains('subclass') || li.classList.contains('fonda-publication-toggle')) { return false; }
                var up = li.parentNode ? li.parentNode.closest('li') : null;
                return !up || up.classList.contains('subclass');
            });
        }
        function reset() {
            unmarkIn(content);
            Array.prototype.slice.call(content.querySelectorAll('.fpf-hit, .fpf-miss, .fpf-open')).forEach(function (el) {
                el.classList.remove('fpf-hit', 'fpf-miss', 'fpf-open');
            });
            opened.forEach(function (el) {
                if (el.nodeName === 'DETAILS') { el.open = false; } else { el.classList.remove('f-clamp-open'); }
            });
            opened = [];
            Array.prototype.slice.call(content.querySelectorAll('p.fpf-note')).forEach(function (p) { p.parentNode.removeChild(p); });
        }
        function note(html) {
            var p = document.createElement('p');
            p.className = 'fpf-note';
            p.innerHTML = html;
            content.appendChild(p);
        }
        function esc(text) {
            return String(text).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
        }
        function find() {
            var query = input.value, list = words(query);
            reset();
            clear.hidden = query === '';
            if (!list.length) { content.classList.remove('fpf-on'); count.textContent = ''; return; }
            content.classList.add('fpf-on');
            var hits = 0;
            entries().forEach(function (li) {
                if (hasAll(li.textContent, list)) {
                    hits++;
                    li.classList.add('fpf-hit');
                    markIn(li, list);
                    var box = li.closest('.additionalItems');
                    if (box) { box.classList.add('fpf-open'); }
                    if (li.classList.contains('f-clamped') && !li.classList.contains('f-clamp-open')) { li.classList.add('f-clamp-open'); opened.push(li); }
                    var details = li.closest('details');
                    if (details && !details.open) { details.open = true; opened.push(details); }
                    var group = li.parentNode.closest('li.subclass');
                    if (group) { group.classList.add('fpf-hit'); }
                } else {
                    li.classList.add('fpf-miss');
                }
            });
            Array.prototype.slice.call(content.querySelectorAll('li.subclass')).forEach(function (group) {
                if (!group.classList.contains('fpf-hit')) { group.classList.add('fpf-miss'); }
            });
            Array.prototype.slice.call(content.querySelectorAll('article.property')).forEach(function (article) {
                if (!article.querySelector('li.fpf-hit')) { article.classList.add('fpf-miss'); }
            });
            Array.prototype.slice.call(content.children).forEach(function (pane) {
                if (pane.classList.contains('tab-pane') && !pane.querySelector('li.fpf-hit')) { pane.classList.add('fpf-miss'); }
            });
            count.textContent = hits + ' found';
            var url = BASE + '/search?querytext=' + encodeURIComponent(query.trim());
            var words_ = '\u201c' + esc(query.trim()) + '\u201d';
            note((hits ? '' : 'Nothing on this page contains ' + words_ + '. ') +
                 '<a href="' + esc(url) + '">Search the whole site for ' + words_ + ' \u2192</a>');
        }
        function stop() { input.value = ''; find(); }

        input.addEventListener('input', function () { clearTimeout(timer); timer = setTimeout(find, 120); });
        input.addEventListener('keydown', function (e) {
            if (e.key === 'Escape' || e.keyCode === 27) { clearTimeout(timer); stop(); }
            if (e.key === 'Enter' || e.keyCode === 13) { e.preventDefault(); clearTimeout(timer); find(); }
        });
        clear.addEventListener('click', function () { clearTimeout(timer); stop(); input.focus(); });
        // a tab clicked while searching: the search ends, so that the chosen tab is shown as usual
        tabs.addEventListener('click', function (e) {
            if (input.value && !item.contains(e.target)) { clearTimeout(timer); stop(); }
        }, true);
    }
    if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', start); } else { start(); }
})();
</script>
