<#-- $This file is distributed under the terms of the license in LICENSE$ -->
<#--
  FONDA 2026-10-13: "Sort" and "Year" boxes on the Publications page (/publications), like the boxes of the
  Runs page.
  Data:     fondaPubsRows, from display:fondaPublicationsBoxesDataGetter
            (/opt/vivo/vivo/rdf/display/everytime/fonda-publications-boxes.n3): one row per publication with its
            title, its date and its types. The query runs on every view of the page, so new publications appear
            by themselves.
  Included: by menupage-scripts.ftl, only on the browse page whose class box has the publication classes
            (Conference Paper, Journal Article, Chapter, ...). All other browse pages are not changed.
  The boxes stand below VIVO's class box ("Journal Article", "Conference Paper", ...) and look like it:
    Sort  "Newest first" (by the publication date, the date/time value of the publication; this is how the
          page opens) or "Name A-Z" (as VIVO's own list). Within a year the newest date comes first;
          publications without a date come last.
    Year  "All years" and every year that has publications of the chosen class, newest year first, each with
          its number; "No date" last. Shown when the chosen class has publications in more than one year.
  Each entry shows the year under its title. The letters and the page numbers work on the chosen class, year
  and order.
  2026-10-13: an entry "All publications" at the top of the class box lists the publications of all classes of
  the box together (each publication once), and the page opens with it (newest first). A class chosen in the
  address (#...) still opens that class.
  2026-10-15: under "All publications" each entry shows "year · type"; the link "Browse publication sources"
  below the Year box (without the arrow); 50 per page. The look shared by all browse pages (left edge, spacing,
  colours) is in fonda-browse-look.ftl, included by menupage-scripts.ftl.
  It needs VIVO's browse script (js/menupage/browseByVClass.js). If that script is missing or different, or a
  class has no rows, the boxes are not shown and the page shows VIVO's own alphabetical list.
-->
<#if fondaPubsRows?? && (fondaPubsRows?size > 0)>
<div id="fonda-pubs-boxes" style="display:none">
    <div class="fpb-box" role="navigation" aria-labelledby="fpb-sort-title">
        <h3 id="fpb-sort-title">Sort</h3>
        <ul id="fpb-sort" class="fpb-list" role="list">
            <li role="listitem"><a href="#" data-sort="new" title="Newest first, by publication date">Newest first</a></li>
            <li role="listitem"><a href="#" data-sort="name" title="By title, A to Z">Name A&ndash;Z</a></li>
        </ul>
    </div>
    <div class="fpb-box" id="fpb-year-box" role="navigation" aria-labelledby="fpb-year-title" style="display:none">
        <h3 id="fpb-year-title">Year</h3>
        <ul id="fpb-year" class="fpb-list" role="list"></ul>
    </div>
</div>
<style>
    /* left column: VIVO's class box with the Sort and Year boxes below it. The two lists look like the class
       box of this site: no background, no frame, a line between the entries, a green bar beside the chosen one. */
    #fpb-column { float: left; }
    #fonda-pubs-boxes { float: left; clear: left; width: 255px; margin: 0 0 20px 15px; }
    #fonda-pubs-boxes .fpb-box { margin: 0 0 20px 0; }
    #fonda-pubs-boxes h3 { margin: 0; padding: 0 0 4px 10px; font-size: 1.1em; }
    #fonda-pubs-boxes .fpb-list { margin: 0; padding: 0; list-style: none; border: 0; background: transparent; }
    #fonda-pubs-boxes .fpb-list li { display: block; width: 235px; margin: 0 10px; padding: 10px 0; font-size: 1em;
        border-bottom: 1px solid #dde4e3; border-left: 4px solid transparent; }
    #fonda-pubs-boxes .fpb-list li:last-child { border-bottom: 0; }
    #fonda-pubs-boxes .fpb-list li.fpb-selected { border-left-color: #8cb843; }
    #fonda-pubs-boxes .fpb-list a { display: block; width: 225px; padding-left: 20px; }
    #fonda-pubs-boxes .fpb-list a:hover, #fonda-pubs-boxes .fpb-list a.selected { background: url(${urls.theme}/images/arrow.gif) 4px 5px no-repeat; color: #2ea0cf; }
    #fonda-pubs-boxes .count-classes { font-size: 12px; }
    /* narrow window: the site stacks the class box above the list; the two boxes follow the class box */
    @media (max-width: 1200px) {
        #fpb-column, #fonda-pubs-boxes { float: none; width: auto; margin-left: 0; }
    }

    /* FONDA 2026-10-15: Publications page only; the look shared by all browse pages is in fonda-browse-look.ftl.
       The link "Browse publication sources" is moved by the script below the Year box, without the arrow. */
    body #wrapper-content #browse-by > p { display: none; }
    #fpb-sources-box { float: left; clear: left; width: 255px; margin: 0 0 20px 15px; }
    #fpb-sources-box .fpb-list { margin: 0; padding: 0; list-style: none; border: 0; background: transparent; }
    #fpb-sources-box .fpb-list li { display: block; width: 235px; margin: 0 10px; padding: 6px 0; font-size: 1em; border-left: 4px solid transparent; }
    #fpb-sources-box .fpb-list a { display: block; padding-left: 20px; white-space: nowrap; }
    @media (max-width: 1200px) {
        #fpb-sources-box { float: none; width: auto; margin-left: 0; }
    }
</style>
<script type="text/javascript">
(function ($) {
    'use strict';
    var PER_PAGE = 50;   // 2026-10-15: 50 per page (VIVO's own list: 30)
    var BASE = "${urls.base?js_string}";
    var VIEW = "${i18n().view_profile_page_for?js_string}";
    var NONE_STARTING = "${i18n().there_are_no_entries_starting_with?js_string}";
    var TRY_ANOTHER = "${i18n().try_another_letter?js_string}";
    // one entry per publication: p = publication, l = title, d = publication date (date/time value),
    // s = start of its date/time interval (used when there is no date/time value), t = its types
    var ROWS = [
<#list fondaPubsRows as row>
        {p: "${(row.fondaPub!"")?js_string}", l: "${(row.fondaPubName!"")?js_string}", d: "${(row.fondaPubDate!"")?js_string}", s: "${(row.fondaPubStart!"")?js_string}", t: "${(row.fondaPubTypes!"")?js_string}"}<#if row_has_next>,</#if>
</#list>
    ];

    function esc(text) {
        return String(text).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }
    function tail(uri) { return String(uri).replace(/[\/#]+$/, '').replace(/^.*[\/#]/, ''); }
    function decoded(text) { try { return decodeURIComponent(text); } catch (e) { return text; } }
    // a date as a number that sorts by time, "YYYYMMDDhhmmss" as written (VIVO stores the date of a publication
    // without a time zone; a year alone counts as 1 January). 0 = no date, listed last.
    function dateKey(text) {
        var m = /^(\d{4})(?:-(\d{2}))?(?:-(\d{2}))?(?:T(\d{2}):(\d{2})(?::(\d{2}))?)?/.exec(text || '');
        return m ? Number(m[1] + (m[2] || '01') + (m[3] || '01') + (m[4] || '00') + (m[5] || '00') + (m[6] || '00')) : 0;
    }

    // pubs: one entry per publication; byClass[class address] = the publications of that type
    var pubs = {}, byClass = {};
    $.each(ROWS, function (i, row) {
        if (!row.p || pubs[row.p]) { return; }
        var name = row.l || tail(row.p), date = row.d || row.s || '';
        var pub = pubs[row.p] = { uri: row.p, name: name, sort: $.trim(name).toLowerCase(), date: dateKey(date) };
        pub.year = pub.date ? String(pub.date).substring(0, 4) : '';
        $.each(String(row.t || '').split(/\s+/), function (j, type) {
            if (type) { (byClass[type] = byClass[type] || []).push(pub); }
        });
    });
    function byName(a, b) { return a.sort < b.sort ? -1 : a.sort > b.sort ? 1 : a.uri < b.uri ? -1 : a.uri > b.uri ? 1 : 0; }
    function newestFirst(a, b) { return b.date - a.date || byName(a, b); }
    // "All publications": the publications of all classes of the class box together, each once (filled when the page is ready)
    var ALL = 'fonda-all-publications', allList = null;
    function listFor(classUri) {
        if (allList && (classUri === ALL || decoded(classUri) === ALL)) { return allList; }
        return byClass[classUri] || byClass[decoded(classUri)] || null;
    }

    $(document).ready(function () {
        var bv = window.browseByVClass, boxes = $('#fonda-pubs-boxes'), sortList = $('#fpb-sort'), yearList = $('#fpb-year');
        // without VIVO's browse script or without a class of this page in the rows: no boxes, VIVO's own list
        var known = $('#browse-classes a').filter(function () { return listFor($(this).attr('data-uri')) !== null; });
        if (!bv || !$.isFunction(bv.getIndividuals) || !$.isFunction(bv.wipeSlate) || !$.isFunction(bv.selectedAlpha) ||
                !$.isFunction(bv.selectedVClass) || !known.length) { $('#browse-by > p').css('display', 'block'); return; }
        // the entry "All publications" at the top of the class box, when the box has more than one class with rows
        if (known.length > 1) {
            var seen = {};
            allList = [];
            known.each(function () {
                $.each(listFor($(this).attr('data-uri')), function (i, pub) {
                    if (!seen[pub.uri]) { seen[pub.uri] = true; allList.push(pub); }
                });
            });
            var allLink = $('<a href="#allPublications" title="Browse all publications" data-uri="' + ALL + '">All publications ' +
                            '<span class="count-classes">(' + allList.length + ')</span></a>');
            $('#browse-classes').prepend($('<li id="allPublications" role="listitem"></li>').append(allLink));
            // the type shown under each title in "All publications": the first class of the box the publication has
            known.each(function () {
                var label = $.trim($(this).clone().children().remove().end().text());
                $.each(listFor($(this).attr('data-uri')), function (i, pub) { if (!pub.type) { pub.type = label; } });
            });
            // VIVO's script normally starts after this one: it then opens this entry first and gives it its click.
            // If it started first, the click is given here.
            if (window.menupageData) { window.menupageData.defaultBrowseVClassUri = ALL; }
            if (bv.browseVClassLinks) {
                allLink.on('click', function () { window.location.hash = ALL; bv.getIndividuals(ALL); return false; });
            }
        }
        var year = null;                    // null = all years, '' = no date, otherwise "YYYY"
        var order = 'new';                  // 'new' = newest first, 'name' = name A-Z
        var current = null, lastAlpha = 'all', lastPage = 1;

        function className(classUri) {
            var link = $('#browse-classes a').filter(function () {
                var uri = $(this).attr('data-uri'); return uri === classUri || uri === decoded(classUri);
            }).first();
            return link.length ? $.trim(link.clone().children().remove().end().text()) : tail(classUri);
        }
        function yearLabel(value) { return value === '' ? 'No date' : value; }
        // the Year box for the chosen class: all years, every year with publications (newest first), "No date" last
        function years(list) {
            var counts = {}, keys = [], i;
            for (i = 0; i < list.length; i++) {
                if (counts[list[i].year] === undefined) { counts[list[i].year] = 0; keys.push(list[i].year); }
                counts[list[i].year]++;
            }
            keys.sort(function (a, b) { return a === '' ? 1 : b === '' ? -1 : (a < b ? 1 : a > b ? -1 : 0); });
            if (year !== null && counts[year] === undefined) { year = null; }
            if (keys.length < 2) { $('#fpb-year-box').hide(); year = null; return; }
            var entries = '<li role="listitem"><a href="#" data-year="*" title="Show the publications of all years">All years ' +
                          '<span class="count-classes">(' + list.length + ')</span></a></li>';
            $.each(keys, function (j, key) {
                entries += '<li role="listitem"><a href="#" data-year="' + esc(key === '' ? 'none' : key) + '" title="' +
                    esc(key === '' ? 'Show only the publications without a date' : 'Show only the publications of ' + key) + '">' +
                    esc(yearLabel(key)) + ' <span class="count-classes">(' + counts[key] + ')</span></a></li>';
            });
            yearList.html(entries);
            $('#fpb-year-box').show();
        }
        function mark() {
            var value = year === null ? '*' : (year === '' ? 'none' : year);
            yearList.find('a').removeClass('selected').removeAttr('aria-current')
                .filter(function () { return $(this).attr('data-year') === value; }).addClass('selected').attr('aria-current', 'true');
            sortList.find('a').removeClass('selected').removeAttr('aria-current')
                .filter(function () { return $(this).attr('data-sort') === order; }).addClass('selected').attr('aria-current', 'true');
            // the green bar beside the chosen entry, as on the class box
            boxes.find('.fpb-list li').removeClass('fpb-selected').has('a.selected').addClass('fpb-selected');
        }
        // keep the choice in the address, so that the Back button returns to the same list
        function remember() {
            try {
                var address = new URL(window.location.href);
                if (year === null) { address.searchParams['delete']('year'); } else { address.searchParams.set('year', year === '' ? 'none' : year); }
                if (order === 'new') { address.searchParams['delete']('sort'); } else { address.searchParams.set('sort', order); }
                window.history.replaceState(null, '', address.toString());
            } catch (e) { /* older browser: the choice is simply not kept */ }
        }
        function fromAddress() {
            try {
                var wanted = new URL(window.location.href).searchParams;
                if (wanted.get('sort') === 'name') { order = 'name'; }
                var y = wanted.get('year');
                if (y === 'none') { year = ''; } else if (y && /^\d{4}$/.test(y)) { year = y; }
            } catch (e) { /* no choice in the address */ }
        }

        // the list: the publications of the chosen class and year in the chosen order; letters, page size and
        // markup as in VIVO's own list, with the year under the title
        function render(classUri, alpha, page, scroll) {
            var all = listFor(classUri), shown = [], i;
            alpha = alpha || 'all';
            if (classUri !== current) { current = classUri; years(all); mark(); remember(); }
            for (i = 0; i < all.length; i++) {
                if ((year === null || all[i].year === year) && (alpha === 'all' || all[i].sort.charAt(0) === alpha)) { shown.push(all[i]); }
            }
            shown.sort(order === 'name' ? byName : newestFirst);
            var pageCount = Math.ceil(shown.length / PER_PAGE);
            page = parseInt(page, 10) || 1;
            if (page > pageCount) { page = 1; }
            lastAlpha = alpha; lastPage = page;
            if (scroll !== false && $.isFunction(bv.getPageScroll) && $.isFunction($.scrollTo) && $('#browse-by').length &&
                    bv.getPageScroll()[1] > $('#browse-by').offset().top) {
                $.scrollTo('#menupage-intro', 500);
            }
            bv.wipeSlate();
            if (!shown.length) {
                $('#individuals-in-class').prepend(alpha !== 'all' ?
                    '<p class="no-individuals">' + esc(NONE_STARTING) + ' <em>' + esc(alpha.toUpperCase()) + '</em>.</p> <p class="no-individuals">' + esc(TRY_ANOTHER) + '</p>' :
                    '<p class="no-individuals">No publications for this choice.</p>');
            } else {
                var items = '';
                for (i = (page - 1) * PER_PAGE; i < Math.min(page * PER_PAGE, shown.length); i++) {
                    items += '<li class="individual" role="listitem"><h1><a href="' +
                        esc(BASE + '/individual?uri=' + encodeURIComponent(shown[i].uri)) + '" title="' + esc(VIEW + ' ' + shown[i].name) +
                        '">' + esc(shown[i].name) + '</a></h1>';
                    var meta = shown[i].year;
                    if (current === ALL && shown[i].type) { meta = (meta ? meta + ' \u00b7 ' : '') + shown[i].type; }
                    items += (meta ? '<span class="title">' + esc(meta) + '</span>' : '') + '</li>';
                }
                $('#individuals-in-class ul').first().append(items);
                if (pageCount > 1 && $.isFunction(bv.pagination)) {
                    var pages = [];
                    for (i = 1; i <= pageCount; i++) { pages.push({ text: String(i), index: String(i) }); }
                    bv.pagination(pages, page);
                }
            }
            $('h3.selected-class').text(year === null ? className(classUri) : className(classUri) + ' · ' + yearLabel(year));
            bv.selectedVClass(decoded(classUri));
            bv.selectedAlpha(alpha);
        }

        // VIVO's script asks for the list through getIndividuals (first load, class, letters, pages).
        // For a class with rows the list is written here; any other class is left to VIVO.
        // 2026-10-15: the search box above the list (fonda-list-search.ftl) asks here for the publications of the chosen
        // class and year, in the chosen order
        window.fondaListProviders = window.fondaListProviders || [];
        window.fondaListProviders.push(function (classUri) {
            var all = listFor(classUri), shown = [], i;
            if (!all) { return null; }
            for (i = 0; i < all.length; i++) { if (year === null || all[i].year === year) { shown.push(all[i]); } }
            shown.sort(order === 'name' ? byName : newestFirst);
            return $.map(shown, function (pub) {
                var meta = pub.year;
                if ((classUri === ALL || decoded(classUri) === ALL) && pub.type) { meta = (meta ? meta + ' \u00b7 ' : '') + pub.type; }
                return { href: BASE + '/individual?uri=' + encodeURIComponent(pub.uri), name: pub.name, meta: meta };
            });
        });
        var vivoList = bv.getIndividuals;
        bv.getIndividuals = function (vclassUri, alpha, page, scroll) {
            if (!listFor(vclassUri)) {
                current = null;
                boxes.hide();
                return vivoList.apply(bv, arguments);
            }
            boxes.show();
            render(vclassUri, alpha, page, scroll);
        };
        // if VIVO's own list was already requested (its script started first), it must not replace this list
        $(document).ajaxComplete(function (event, request, settings) {
            if (current !== null && boxes.is(':visible') && settings &&
                    String(settings.url).indexOf('getRenderedSearchIndividualsByVClass') !== -1) {
                render(current, lastAlpha, lastPage, false);
            }
        });

        yearList.on('click', 'a', function () {
            var value = $(this).attr('data-year');
            year = value === '*' ? null : (value === 'none' ? '' : value);
            mark(); remember();
            if (current !== null) { render(current, 'all', 1, false); }
            return false;
        });
        sortList.on('click', 'a', function () {
            order = $(this).attr('data-sort') === 'name' ? 'name' : 'new';
            mark(); remember();
            if (current !== null) { render(current, lastAlpha, 1, false); }
            return false;
        });

        fromAddress();
        mark();
        // put the boxes below VIVO's class box, in one column with it, so that they stay beside (or, in a narrow
        // window, above) the list
        $('#browse-classes').wrap('<div id="fpb-column"></div>');
        $('#fpb-column').append(boxes);
        // the link "Browse publication sources" (above the class box in VIVO's template) goes below the Year box,
        // without the arrow
        var sourcesLink = $('#browse-by > p a[href]').first();
        if (sourcesLink.length) {
            var sourcesBox = $('<div id="fpb-sources-box" role="navigation"><ul class="fpb-list" role="list"><li role="listitem"></li></ul></div>');
            sourcesBox.find('li').append($('<a></a>').attr('href', sourcesLink.attr('href'))
                .text($.trim(sourcesLink.text()).replace(/\s*\u2192\s*$/, '')));
            $('#fpb-column').append(sourcesBox);
        } else {
            $('#browse-by > p').css('display', 'block');
        }
        // VIVO's script normally starts after this one and then asks for the list; if it started first, write the
        // list of the chosen class now
        if (bv.individualsInVClass) {
            var chosen = $('#browse-classes li a.selected').attr('data-uri') || (window.location.hash || '').substring(1) ||
                         $('#browse-classes li a').first().attr('data-uri');
            if (chosen && listFor(chosen)) { boxes.show(); render(chosen, 'all', 1, false); }
        }
    });
})(jQuery);
</script>
</#if>
