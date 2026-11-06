<#-- $This file is distributed under the terms of the license in LICENSE$ -->
<#--
  FONDA 2026-10-15: a search box for the list of every browse page (People, Subprojects, Organizations,
  Publications, Workflows, Runs, Infrastructure, Domains, Sources, ...). Included by fonda-browse-look.ftl.
  Place (2026-10-15, 2nd version): 300px wide, in the row of the page heading, right edge = right edge of the list;
  in a narrow window (below 768px) under the heading, full width.
    - While you type, the list shows only the entries of the chosen class whose name contains the words typed
      (all words, any order, each at the beginning of a word; upper/lower case and accents do not matter), from all pages of the list, with the
      words marked. The letters and the page numbers are hidden while searching; "x" or Esc brings the list back.
    - Publications and Runs: the box asks the boxes of these pages (fonda-publications-boxes.ftl,
      fonda-runs-boxes.ftl, through window.fondaListProviders) for the entries of the chosen class, year or cluster,
      in the chosen order. Other classes: the entries come from VIVO's own list service (all its pages, once).
    - Below the matches a link opens the site search for the same words (in this page's category).
  Without VIVO's browse script nothing is shown and the page is as before.
-->
<style>
    #fonda-list-search { display: flex; align-items: center; height: 36px; box-sizing: border-box; margin: 0 0 14px 10px;
        background: #ffffff; border: 1px solid #c9d2d9; border-radius: 8px; transition: border-color .15s, box-shadow .15s; }
    #fonda-list-search:focus-within { border-color: #1f3a5f; box-shadow: 0 0 0 3px rgba(31, 58, 95, .16); }
    #fonda-list-search svg { flex: 0 0 16px; width: 16px; height: 16px; margin: 0 8px 0 12px; stroke: #4a5d75; }
    #fonda-list-search input[type="text"] { flex: 1 1 auto; min-width: 0; width: auto; height: 34px; margin: 0; padding: 0;
        border: 0; outline: 0; box-shadow: none; background: transparent; font-family: inherit; font-size: 15px; line-height: 34px; color: #1f3a5f; }
    #fonda-list-search input[type="text"]::placeholder { color: #7b8794; opacity: 1; }
    #fonda-list-search input[type="text"]::-ms-clear { display: none; }
    #fonda-list-search .fls-count { flex: 0 0 auto; margin: 0 4px 0 8px; font-size: 13px; color: #6b7785; white-space: nowrap; }
    #fonda-list-search .fls-clear { flex: 0 0 28px; width: 28px; height: 28px; margin: 0 4px 0 0; padding: 0; border: 0; border-radius: 6px;
        background: transparent; color: #6b7785; font-size: 18px; line-height: 28px; cursor: pointer; }
    #fonda-list-search .fls-clear:hover, #fonda-list-search .fls-clear:focus { background: #eef2f6; }
    #fonda-list-search .fls-clear[hidden] { display: none; }
    #browse-by.fonda-list-searching #alpha-browse-individuals,
    #browse-by.fonda-list-searching #individuals-in-class .pagination { display: none !important; }
    #individuals-in-class mark.fls-mark { background: #dcebf0; color: inherit; padding: 0 1px; border-radius: 2px; }
    #individuals-in-class p.fls-more { margin: 16px 0 0 0; font-size: 14px; }
    #individuals-in-class p.fls-more a { color: #064d68; }

    /* in the row of the page heading */
    #menupage-intro.fls-in-heading { position: relative; }
    #menupage-intro.fls-in-heading h2 { padding-right: 330px; }
    #menupage-intro.fls-in-heading #fonda-list-search { position: absolute; right: 0; bottom: 6px; width: 300px; margin: 0; }
    @media (max-width: 767px) {
        #menupage-intro.fls-in-heading h2 { padding-right: 0; }
        #menupage-intro.fls-in-heading #fonda-list-search { position: static; width: auto; margin: 6px 10px 10px; }
    }

    html.dark-mode #fonda-list-search { background: #1a2334; border-color: #2c3a52; }
    html.dark-mode #fonda-list-search:focus-within { border-color: #5d7aa5; box-shadow: 0 0 0 3px rgba(93, 140, 205, .25); }
    html.dark-mode #fonda-list-search svg { stroke: #aab6c6; }
    html.dark-mode #fonda-list-search input[type="text"] { color: #d5dde7; }
    html.dark-mode #fonda-list-search input[type="text"]::placeholder { color: #8d96a6; }
    html.dark-mode #fonda-list-search .fls-count, html.dark-mode #fonda-list-search .fls-clear { color: #8d96a6; }
    html.dark-mode #fonda-list-search .fls-clear:hover, html.dark-mode #fonda-list-search .fls-clear:focus { background: rgba(127, 192, 221, .14); }
    html.dark-mode #individuals-in-class mark.fls-mark { background: rgba(127, 192, 221, .28); color: inherit; }
    html.dark-mode #individuals-in-class p.fls-more a { color: #7fc0dd; }
    /* the message when nothing matches (and VIVO's own "no entries" message): readable in dark mode */
    html.dark-mode #individuals-in-class p.no-individuals { color: #c3ccd8; }
</style>
<script>
(function ($) {
    'use strict';
    if (!$) { return; }
    var BASE = "${urls.base?js_string}";
    // the category of the site search for each menu page (values as in the search box of the home page)
    var CATEGORY = {
        people: 'http://vivoweb.org/ontology#vitroClassGrouppeople',
        subprojects: 'http://172.28.33.178:8080/vivo/individual/vitroClassGroupSubprojects',
        organizations: 'http://vivoweb.org/ontology#vitroClassGrouporganizations',
        publications: 'http://vivoweb.org/ontology#vitroClassGrouppublications',
        workflows: 'http://172.28.33.178:8080/vivo/individual/vitroClassGroupWorkflows',
        runs: 'http://172.28.33.178:8080/vivo/individual/vitroClassGroupRuns',
        infrastructure: 'http://172.28.33.178:8080/vivo/individual/vitroClassGroupInfrastructure',
        domains: 'http://172.28.33.178:8080/vivo/individual/vitroClassGroupDomains',
        sources: 'http://172.28.33.178:8080/vivo/individual/vitroClassGroupPublicationSources'
    };
    var MARKER = 'fondaListSearch=1';   // added to the requests of this box, so that they can be told apart

    function esc(text) {
        return String(text).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }
    function fold(text) {
        var t = String(text).toLowerCase();
        t = t.normalize ? t.normalize('NFD').replace(/[\u0300-\u036f]/g, '') : t;
        return t.replace(/\u00df/g, 'ss');
    }
    function words(query) { return $.grep(fold(query).split(/\s+/), function (w) { return w !== ''; }); }
    // a typed word must match the beginning of a word of the text ("rna" finds "RNA-seq", not "Journal")
    var WORDCHAR = (function () { try { return new RegExp('[\\p{L}\\p{N}]', 'u'); } catch (e) { return /[a-z0-9]/; } })();
    function nextStart(f, w, from) {
        var at = f.indexOf(w, from);
        while (at > 0 && WORDCHAR.test(f.charAt(at - 1))) { at = f.indexOf(w, at + 1); }
        return at;
    }
    function matches(name, list) {
        var f = fold(name);
        for (var i = 0; i < list.length; i++) { if (nextStart(f, list[i], 0) === -1) { return false; } }
        return true;
    }
    // the name with the typed words marked (the folded text is mapped back to the letters of the name)
    function marked(name, list) {
        var text = String(name), f = '', map = [], hit = [], i, k, out = '';
        for (i = 0; i < text.length; i++) {
            var c = fold(text.charAt(i));
            for (k = 0; k < c.length; k++) { f += c.charAt(k); map.push(i); }
            hit.push(false);
        }
        $.each(list, function (n, w) {
            var at = nextStart(f, w, 0);
            while (at !== -1 && w.length) {
                for (k = map[at]; k <= map[at + w.length - 1]; k++) { hit[k] = true; }
                at = nextStart(f, w, at + w.length);
            }
        });
        for (i = 0; i < text.length; i++) {
            if (hit[i] && (i === 0 || !hit[i - 1])) { out += '<mark class="fls-mark">'; }
            out += esc(text.charAt(i));
            if (hit[i] && (i === text.length - 1 || !hit[i + 1])) { out += '</mark>'; }
        }
        return out;
    }

    $(document).ready(function () {
        var bv = window.browseByVClass, container = $('#alpha-browse-container'), browseBy = $('#browse-by');
        if (!bv || !$.isFunction(bv.getIndividuals) || !$.isFunction(bv.wipeSlate) || !container.length ||
                !$('#individuals-in-class').length) { return; }

        var path = window.location.pathname.replace(/\/+$/, '');
        var page = path.substring(path.lastIndexOf('/') + 1).toLowerCase();
        var box = $('<div id="fonda-list-search" role="search">' +
            '<svg viewBox="0 0 24 24" fill="none" stroke-width="2.2" stroke-linecap="round" aria-hidden="true">' +
            '<circle cx="10.5" cy="10.5" r="6.5"/><line x1="15.5" y1="15.5" x2="21" y2="21"/></svg>' +
            '<input type="text" autocomplete="off" placeholder="Search this list" aria-label="Search this list" />' +
            '<span class="fls-count" aria-live="polite"></span>' +
            '<button type="button" class="fls-clear" title="Clear" aria-label="Clear" hidden>\u00d7</button></div>');
        // in the row of the page heading, its right edge at the right edge of the list; without that heading above the list
        var intro = $('#menupage-intro').first();
        if (intro.length) {
            intro.addClass('fls-in-heading').append(box);
            var place = function () {
                var a = intro[0].getBoundingClientRect(), b = container[0].getBoundingClientRect();
                box.css('right', window.innerWidth >= 768 && b.width ? Math.max(0, Math.round(a.right - b.right)) + 'px' : '');
            };
            place();
            $(window).on('resize load', place);
        } else {
            container.prepend(box);
        }
        var input = box.find('input'), count = box.find('.fls-count'), clear = box.find('.fls-clear');

        var cache = {};          // class address -> entries from VIVO's list service (or the request in progress)
        var shownClass = null;   // the class of the list on the page
        var query = '', timer = null, turn = 0;

        function selectedClass() {
            return shownClass || $('#browse-classes a.selected').attr('data-uri') || null;
        }
        function searching() { return words(query).length > 0; }

        // entries of a class from VIVO's list service: all pages, once per class
        function fromService(classUri, done) {
            if (cache[classUri] && cache[classUri].entries) { done(cache[classUri].entries); return; }
            if (cache[classUri] && cache[classUri].waiting) { cache[classUri].waiting.push(done); return; }
            var entry = cache[classUri] = { waiting: [done] };
            var url = bv.dataServiceUrl + encodeURIComponent(classUri) + '&' + MARKER;
            function finish(list) {
                entry.entries = list;
                var waiting = entry.waiting; entry.waiting = null;
                $.each(waiting, function (i, f) { f(list); });
            }
            $.getJSON(url + '&page=1').done(function (first) {
                var list = [], pages = (first && first.pages) ? first.pages.length : 0, asked = [], i;
                function add(result) {
                    $.each((result && result.individuals) || [], function (j, ind) {
                        list.push({ name: ind.label || ind.name || '', html: ind.shortViewHtml || '', href: ind.profileUrl || '' });
                    });
                }
                add(first);
                for (i = 2; i <= pages; i++) { asked.push($.getJSON(url + '&page=' + i)); }
                if (!asked.length) { finish(list); return; }
                $.when.apply($, asked).done(function () {
                    var results = asked.length === 1 ? [arguments] : arguments;
                    $.each(results, function (j, r) { add(r[0]); });
                    finish(list);
                }).fail(function () { cache[classUri] = null; finish(null); });
            }).fail(function () { cache[classUri] = null; finish(null); });
        }

        function entriesFor(classUri, done) {
            var providers = window.fondaListProviders || [], i, list;
            for (i = 0; i < providers.length; i++) {
                try { list = providers[i](classUri); } catch (e) { list = null; }
                if (list) { done(list, false); return; }
            }
            fromService(classUri, function (entries) { done(entries, true); });
        }

        function moreLink(list) {
            var url = BASE + '/search?querytext=' + encodeURIComponent($.trim(query));
            var label = 'Search the whole site for \u201c' + $.trim(query) + '\u201d';
            if (CATEGORY[page]) {
                url += '&filters_category=' + encodeURIComponent('category:' + CATEGORY[page]);
                label = 'Search all ' + $.trim($('#menupage-intro h2, h2').first().text() || page).toLowerCase() +
                        ' for \u201c' + $.trim(query) + '\u201d with the site search';
            }
            return '<p class="fls-more"><a href="' + esc(url) + '">' + esc(label) + ' \u2192</a></p>';
        }

        function show() {
            var list = words(query), classUri = selectedClass(), mine = ++turn;
            clear.prop('hidden', query === '');
            if (!list.length) { count.text(''); return; }
            if (!classUri) { return; }
            browseBy.addClass('fonda-list-searching');
            count.text('\u2026');
            entriesFor(classUri, function (entries, fromVivo) {
                if (mine !== turn || !searching()) { return; }
                bv.wipeSlate();
                var target = $('#individuals-in-class');
                target.find('p.fls-more').remove();
                if (!entries) {
                    count.text('');
                    target.prepend('<p class="no-individuals">The list could not be searched. Please try again.</p>');
                    return;
                }
                var hits = $.grep(entries, function (e) { return matches(e.name, list); });
                count.text(hits.length + ' found');
                var items = '';
                $.each(hits, function (i, e) {
                    if (fromVivo && e.html) {
                        var li = $($.parseHTML($.trim(e.html)));
                        li.find('h1 a, a').first().html(marked(e.name, list));
                        items += $('<div>').append(li).html();
                    } else {
                        items += '<li class="individual" role="listitem"><h1><a href="' + esc(e.href) + '">' + marked(e.name, list) +
                                 '</a></h1>' + (e.meta ? '<span class="title">' + esc(e.meta) + '</span>' : '') + '</li>';
                    }
                });
                if (hits.length) {
                    target.find('ul').first().append(items);
                } else {
                    target.prepend('<p class="no-individuals">No entry of this list contains \u201c' + esc($.trim(query)) + '\u201d.</p>');
                }
                target.append(moreLink(list));
            });
        }

        function stop() {
            turn++;
            browseBy.removeClass('fonda-list-searching');
            count.text('');
            clear.prop('hidden', true);
            $('#individuals-in-class p.fls-more').remove();
            var classUri = selectedClass();
            if (classUri) { bv.getIndividuals(classUri, 'all', 1, false); }
        }

        input.on('input', function () {
            var was = searching();
            query = input.val();
            clearTimeout(timer);
            if (!searching()) { if (was) { stop(); } else { clear.prop('hidden', query === ''); } return; }
            timer = setTimeout(show, 150);
        });
        input.on('keydown', function (e) {
            if (e.key === 'Escape' || e.keyCode === 27) { input.val(''); query = ''; stop(); }
            if (e.key === 'Enter' || e.keyCode === 13) { e.preventDefault(); clearTimeout(timer); if (searching()) { show(); } }
        });
        clear.on('click', function () { input.val(''); query = ''; stop(); input.focus(); });

        // the list of a class (first load, another class, letters, pages): remember the class; while searching,
        // the matches of the new class are shown after the list was written
        var before = bv.getIndividuals;
        bv.getIndividuals = function (vclassUri) {
            shownClass = vclassUri;
            var result = before.apply(bv, arguments);
            if (searching()) { show(); }
            return result;
        };
        // VIVO's own list arrives later than the matches: show the matches again after it
        $(document).ajaxComplete(function (event, request, settings) {
            var url = String((settings && settings.url) || '');
            if (searching() && url.indexOf('getRenderedSearchIndividualsByVClass') !== -1 && url.indexOf(MARKER) === -1) { show(); }
        });
        // another year, cluster or order in the boxes of the Publications and Runs pages: their own click handlers
        // stop the click, so it is noticed on its way down (capture) and the matches are shown after their list
        if (document.addEventListener) {
            document.addEventListener('click', function (e) {
                if (searching() && $(e.target).closest('#fonda-pubs-boxes a, #fonda-runs-boxes a').length) { setTimeout(show, 0); }
            }, true);
        }
    });
})(window.jQuery);
</script>
