<#-- $This file is distributed under the terms of the license in LICENSE$ -->
<#-- FONDA 2026-10-16: Subprojects page (/subprojects) - the Phase I subprojects (their name ends with "(Phase I)") are
     shown at the end of the list, under a small heading "PHASE I (completed)", in grey and without the "(Phase I)" at
     the end of the name. Nothing in the data changes; the count in the box stays the total.
     Works with the letters, the page numbers and "Search this list" (the list is tidied every time it is written).
     Included from fonda-browse-look.ftl. To undo: remove the include line there (or use its backup). -->
<style>
    #individuals-in-class li.fonda-phase-head { list-style: none; margin: 10px 0 0 0; padding: 18px 0 4px 0; border-top: 1px solid #e3e8ee;
        font-size: 14px; font-weight: 600; letter-spacing: .03em; color: #5b6b80; }
    #individuals-in-class li.fonda-phase-old a { color: #5b6b80 !important; }
    html.dark-mode #individuals-in-class li.fonda-phase-head { border-top-color: #2c3a52; color: #8d96a6; }
    html.dark-mode #individuals-in-class li.fonda-phase-old a { color: #9aa8ba !important; }
</style>
<script>
(function () {
    'use strict';
    if (!/\/subprojects\/?$/.test(window.location.pathname)) { return; }
    var SUFFIX = /\s*\(Phase I\)\s*$/;

    function nameLink(li) { return li.querySelector('h1 a') || li.querySelector('a'); }

    // remove "(Phase I)" at the end of the visible name, also when "Search this list" marked words in it
    function strip(a) {
        var text = a.textContent, m = text.match(SUFFIX);
        if (!m) { return; }
        var cut = m[0].length;
        var walker = document.createTreeWalker(a, NodeFilter.SHOW_TEXT, null), nodes = [], n;
        while ((n = walker.nextNode())) { nodes.push(n); }
        for (var i = nodes.length - 1; i >= 0 && cut > 0; i--) {
            var len = nodes[i].nodeValue.length;
            if (len <= cut) { cut -= len; nodes[i].nodeValue = ''; }
            else { nodes[i].nodeValue = nodes[i].nodeValue.slice(0, len - cut); cut = 0; }
        }
    }

    function tidy(ul) {
        var head = null, current = [], old = [], i, li, a;
        for (i = 0; i < ul.children.length; i++) {
            li = ul.children[i];
            if (li.classList.contains('fonda-phase-head')) { head = li; continue; }
            a = nameLink(li);
            if (li.classList.contains('fonda-phase-old') || (a && SUFFIX.test(a.textContent))) { old.push(li); } else { current.push(li); }
        }
        if (!old.length) { if (head) { ul.removeChild(head); } return; }
        if (!head) {
            head = document.createElement('li');
            head.className = 'fonda-phase-head';
            head.setAttribute('role', 'presentation');
            head.textContent = 'PHASE I (completed)';
        }
        ul.appendChild(head);
        for (i = 0; i < old.length; i++) {
            li = old[i];
            li.classList.add('fonda-phase-old');
            a = nameLink(li);
            if (a) { strip(a); }
            ul.appendChild(li);
        }
    }

    function start() {
        var box = document.getElementById('individuals-in-class');
        if (!box || !window.MutationObserver) { return; }
        var observer;
        function run() {
            observer.disconnect();
            var ul = box.querySelector(':scope > ul');
            if (ul) { tidy(ul); }
            observer.takeRecords();
            observer.observe(box, { childList: true, subtree: true });
        }
        observer = new MutationObserver(run);
        run();
    }
    if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', start); } else { start(); }
})();
</script>
