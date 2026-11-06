<#-- $This file is distributed under the terms of the license in LICENSE$ -->
<#--
  FONDA 2026-11-03: the Traces page (/traces): "All traces" in the class box and a "Field" box below it, like the
  Publications and Workflows pages.
  Data:     fondaTraceRows, from display:fondaTracesBoxesDataGetter
            (/opt/vivo/vivo/rdf/display/everytime/fonda-traces-boxes.n3): one row per trace (rm:RunTrace,
            rm:TraceCollection) and research field of its workflow, with its name, download link, where it ran and
            who ran or provided it. Traces of runs that are not public are left out.
  Included: by menupage-scripts.ftl, only on the browse page whose class box has rm:RunTrace or rm:TraceCollection.
  The class box gets "All traces" at the top (the page opens with it). Below it, "Field": all fields and every field
  that has traces, "Other" for traces without one. Each entry: "Run trace · FONDA Cluster · <who> · Download".
  The letters, the page numbers and "Search this list" work on the chosen class and field; the field is kept in the
  address (?field=...).
  It needs VIVO's browse script (js/menupage/browseByVClass.js). If that script is missing or different, nothing
  is shown and the page shows VIVO's own list.
-->
<#if fondaTraceRows?? && (fondaTraceRows?size > 0)>
<div id="fonda-trace-boxes" style="display:none">
    <div class="fpb-box" id="ftb-field-box" role="navigation" aria-labelledby="ftb-field-title" style="display:none">
        <h3 id="ftb-field-title">Field</h3>
        <ul id="ftb-field" class="fpb-list" role="list"></ul>
    </div>
</div>
<style>
    #ftb-column { float: left; }
    #fonda-trace-boxes { float: left; clear: left; width: 255px; margin: 0 0 20px 15px; }
    #fonda-trace-boxes .fpb-box { margin: 0 0 16px 0; }
    #fonda-trace-boxes h3 { margin: 0; padding: 6px 0 4px 10px; font-size: 1.1em; }
    #fonda-trace-boxes .fpb-list { margin: 0; padding: 0; list-style: none; border: 0; background: transparent; }
    #fonda-trace-boxes .fpb-list li { display: block; width: 235px; margin: 0 10px; padding: 6px 0; font-size: 1em;
        border-bottom: 1px solid #dde4e3; border-left: 4px solid transparent; }
    #fonda-trace-boxes .fpb-list li:last-child { border-bottom: 0; }
    #fonda-trace-boxes .fpb-list li.fpb-selected { border-left-color: #8cb843; }
    #fonda-trace-boxes .fpb-list a { display: block; width: 225px; padding-left: 20px; }
    #fonda-trace-boxes .fpb-list a:hover, #fonda-trace-boxes .fpb-list a.selected { background: url(${urls.theme}/images/arrow.gif) 4px 5px no-repeat; color: #2ea0cf; }
    html:not(.dark-mode) body #fonda-trace-boxes .fpb-list a.selected, html:not(.dark-mode) body #fonda-trace-boxes .fpb-list a:hover { color: #064d68; }
    #fonda-trace-boxes .count-classes { font-size: 12px; }
    #individuals-in-class .ftb-meta a { color: inherit; text-decoration: none; border-bottom: 1px dotted currentColor; }
    #individuals-in-class .ftb-meta a:hover { border-bottom-style: solid; }
    @media (max-width: 1200px) {
        #ftb-column, #fonda-trace-boxes { float: none; width: auto; margin-left: 0; }
    }
</style>
<script type="text/javascript">
(function ($) {
    'use strict';
    if (!$) { return; }
    var CLASSES = { 'http://example.org/ontology/run-metadata#RunTrace': 'Run trace',
                    'http://example.org/ontology/run-metadata#TraceCollection': 'Trace collection' };
    var ALL = 'fonda-all-traces';
    var PER_PAGE = 30;
    var BASE = "${urls.base?js_string}";
    var VIEW = "${i18n().view_profile_page_for?js_string}";
    var NONE_STARTING = "${i18n().there_are_no_entries_starting_with?js_string}";
    var TRY_ANOTHER = "${i18n().try_another_letter?js_string}";
    // t = trace, l = name, c = its class, k = download link, f/fn = field of its workflow, w = where it ran, b = who
    var ROWS = [
<#list fondaTraceRows as row>
        {t: "${(row.fondaTrace!"")?js_string}", l: "${(row.fondaTraceName!"")?js_string}", c: "${(row.fondaTraceClass!"")?js_string}", k: "${(row.fondaTraceLink!"")?js_string}", f: "${(row.fondaField!"")?js_string}", fn: "${(row.fondaFieldName!"")?js_string}", w: "${(row.fondaWhere!"")?js_string}", b: "${(row.fondaWho!"")?js_string}"}<#if row_has_next>,</#if>
</#list>
    ];

    function esc(text) {
        return String(text).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }
    function tail(uri) { return String(uri).replace(/[\/#]+$/, '').replace(/^.*[\/#]/, ''); }
    function decoded(text) { try { return decodeURIComponent(text); } catch (e) { return text; } }
    function slug(text) { return String(text).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, ''); }
    function profile(uri) { return BASE + '/individual?uri=' + encodeURIComponent(uri); }
    function classOf(uri) {
        var u = decoded(uri || '');
        if (u === ALL) { return ALL; }
        return CLASSES[u] ? u : null;
    }

    var traces = [], traceOf = {}, fields = [], fieldOf = {};
    $.each(ROWS, function (i, row) {
        if (!row.t || !CLASSES[row.c]) { return; }
        var tr = traceOf[row.t];
        if (!tr) {
            var name = row.l || tail(row.t);
            tr = traceOf[row.t] = { uri: row.t, name: name, sort: $.trim(name).toLowerCase(), cls: row.c, link: row.k,
                                    where: row.w, who: row.b, fields: [] };
            traces.push(tr);
        }
        if (row.f) {
            var f = fieldOf[row.f];
            if (!f) { f = fieldOf[row.f] = { uri: row.f, name: row.fn || tail(row.f), key: slug(row.fn || tail(row.f)) }; fields.push(f); }
            if ($.inArray(f, tr.fields) === -1) { tr.fields.push(f); }
        }
    });
    traces.sort(function (a, b) { return a.sort < b.sort ? -1 : a.sort > b.sort ? 1 : (a.uri < b.uri ? -1 : 1); });
    fields.sort(function (a, b) { return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1; });

    var NONE = 'none', field = null;
    function inClass(tr, cls) { return cls === ALL || tr.cls === cls; }
    function inField(tr) {
        if (field === null) { return true; }
        if (field === NONE) { return !tr.fields.length; }
        for (var i = 0; i < tr.fields.length; i++) { if (tr.fields[i].key === field) { return true; } }
        return false;
    }
    function fieldName() {
        if (field === null) { return ''; }
        if (field === NONE) { return 'Other'; }
        for (var i = 0; i < fields.length; i++) { if (fields[i].key === field) { return fields[i].name; } }
        return '';
    }

    $(document).ready(function () {
        var bv = window.browseByVClass, boxes = $('#fonda-trace-boxes'), fieldList = $('#ftb-field');
        var known = $('#browse-classes a').filter(function () { var c = classOf($(this).attr('data-uri')); return c && c !== ALL; });
        if (!bv || !$.isFunction(bv.getIndividuals) || !$.isFunction(bv.wipeSlate) || !$.isFunction(bv.selectedAlpha) ||
                !$.isFunction(bv.selectedVClass) || !known.length || !traces.length) { return; }
        var current = null, lastAlpha = 'all', lastPage = 1;

        // "All traces" at the top of the class box, when the box has more than one class of traces
        if (known.length > 1) {
            var allLink = $('<a href="#allTraces" title="Browse all traces" data-uri="' + ALL + '">All traces ' +
                            '<span class="count-classes">(' + traces.length + ')</span></a>');
            $('#browse-classes').prepend($('<li id="allTraces" role="listitem"></li>').append(allLink));
            if (window.menupageData) { window.menupageData.defaultBrowseVClassUri = ALL; }
            if (bv.browseVClassLinks) {
                allLink.on('click', function () { window.location.hash = ALL; bv.getIndividuals(ALL); return false; });
            }
        }
        function className(cls) {
            if (cls === ALL) { return 'All traces'; }
            var link = known.filter(function () { return classOf($(this).attr('data-uri')) === cls; }).first();
            return link.length ? $.trim(link.clone().children().remove().end().text()) : CLASSES[cls];
        }

        // the Field box for the chosen class: every field of its traces, "Other" for traces without one
        function fill(cls) {
            var counts = {}, none = 0, all = 0;
            $.each(traces, function (i, tr) {
                if (!inClass(tr, cls)) { return; }
                all++;
                if (!tr.fields.length) { none++; }
                $.each(tr.fields, function (j, f) { counts[f.key] = (counts[f.key] || 0) + 1; });
            });
            var entries = '<li role="listitem"><a href="#" data-value="*" title="Show the traces of all fields">All fields ' +
                          '<span class="count-classes">(' + all + ')</span></a></li>', shown = 0;
            $.each(fields, function (i, f) {
                if (!counts[f.key]) { return; }
                shown++;
                entries += '<li role="listitem"><a href="#" data-value="' + esc(f.key) + '" title="' + esc('Show only the traces of workflows in ' + f.name) + '">' +
                           esc(f.name) + ' <span class="count-classes">(' + counts[f.key] + ')</span></a></li>';
            });
            if (none) {
                shown++;
                entries += '<li role="listitem"><a href="#" data-value="' + NONE + '" title="Show only the traces of workflows without a field">Other ' +
                           '<span class="count-classes">(' + none + ')</span></a></li>';
            }
            if (field !== null && field !== NONE && !counts[field]) { field = null; }
            if (field === NONE && !none) { field = null; }
            fieldList.html(entries);
            $('#ftb-field-box').toggle(shown > 1);
            if (shown < 2) { field = null; }
        }
        function mark() {
            var value = field === null ? '*' : field;
            fieldList.find('a').removeClass('selected').removeAttr('aria-current')
                .filter(function () { return $(this).attr('data-value') === value; }).addClass('selected').attr('aria-current', 'true');
            boxes.find('.fpb-list li').removeClass('fpb-selected').has('a.selected').addClass('fpb-selected');
        }
        function remember() {
            try {
                var address = new URL(window.location.href);
                if (field === null) { address.searchParams['delete']('field'); } else { address.searchParams.set('field', field); }
                window.history.replaceState(null, '', address.toString());
            } catch (e) { /* older browser: the choice is simply not kept */ }
        }
        function fromAddress() {
            try {
                var wanted = new URL(window.location.href).searchParams.get('field');
                if (wanted === NONE) { field = NONE; }
                else if (wanted) { $.each(fields, function (i, f) { if (f.key === wanted) { field = wanted; } }); }
            } catch (e) { /* no choice in the address */ }
        }
        function metaParts(tr) {
            var parts = [CLASSES[tr.cls]];
            if (tr.where) { parts.push(tr.where); }
            if (tr.who) { parts.push(tr.who); }
            return parts;
        }
        function meta(tr) {
            var html = $.map(metaParts(tr), esc).join(' · ');
            if (tr.link) {
                html += ' · <a href="' + esc(tr.link) + '" target="_blank" rel="noopener" title="' + esc('Download: ' + tr.link) + '">Download</a>';
            }
            return '<span class="title ftb-meta">' + html + '</span>';
        }

        function render(cls, alpha, page, scroll) {
            var shown = [], i;
            alpha = alpha || 'all';
            if (cls !== current) { current = cls; fill(cls); mark(); remember(); }
            for (i = 0; i < traces.length; i++) {
                if (inClass(traces[i], cls) && inField(traces[i]) && (alpha === 'all' || traces[i].sort.charAt(0) === alpha)) { shown.push(traces[i]); }
            }
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
                    '<p class="no-individuals">No traces for this choice.</p>');
            } else {
                var items = '';
                for (i = (page - 1) * PER_PAGE; i < Math.min(page * PER_PAGE, shown.length); i++) {
                    items += '<li class="individual" role="listitem"><h1><a href="' + esc(profile(shown[i].uri)) + '" title="' +
                        esc(VIEW + ' ' + shown[i].name) + '">' + esc(shown[i].name) + '</a></h1>' + meta(shown[i]) + '</li>';
                }
                $('#individuals-in-class ul').first().append(items);
                if (pageCount > 1 && $.isFunction(bv.pagination)) {
                    var pages = [];
                    for (i = 1; i <= pageCount; i++) { pages.push({ text: String(i), index: String(i) }); }
                    bv.pagination(pages, page);
                }
            }
            var f = fieldName();
            $('h3.selected-class').text(f ? className(cls) + ' · ' + f : className(cls));
            bv.selectedVClass(cls);
            bv.selectedAlpha(alpha);
        }

        // "Search this list" (fonda-list-search.ftl) asks here for the traces of the chosen class and field
        window.fondaListProviders = window.fondaListProviders || [];
        window.fondaListProviders.push(function (classUri) {
            var cls = classOf(classUri);
            if (!cls) { return null; }
            return $.map($.grep(traces, function (tr) { return inClass(tr, cls) && inField(tr); }), function (tr) {
                return { href: profile(tr.uri), name: tr.name, meta: metaParts(tr).join(' · ') };
            });
        });

        var vivoList = bv.getIndividuals;
        bv.getIndividuals = function (vclassUri, alpha, page, scroll) {
            var cls = classOf(vclassUri);
            if (!cls) {
                current = null;
                boxes.hide();
                return vivoList.apply(bv, arguments);
            }
            boxes.show();
            render(cls, alpha, page, scroll);
        };
        // if VIVO's own list was already requested (its script started first), it must not replace this list
        $(document).ajaxComplete(function (event, request, settings) {
            var url = String((settings && settings.url) || '');
            if (current !== null && url.indexOf('getRenderedSearchIndividualsByVClass') !== -1 && url.indexOf('fondaListSearch=1') === -1) {
                render(current, lastAlpha, lastPage, false);
            }
        });

        fieldList.on('click', 'a', function () {
            var value = $(this).attr('data-value');
            field = value === '*' ? null : value;
            mark(); remember();
            if (current !== null) { render(current, 'all', 1, false); }
            var search = $('#fonda-list-search input');
            if (search.length && $.trim(search.val())) { search.trigger('input'); }
            return false;
        });

        fromAddress();
        $('#browse-classes').wrap('<div id="ftb-column"></div>');
        $('#ftb-column').append(boxes);
        if (bv.individualsInVClass) {
            var first = $('#browse-classes li a.selected').attr('data-uri') || (window.location.hash || '').substring(1) ||
                        $('#browse-classes li a').first().attr('data-uri');
            if (classOf(first)) { boxes.show(); render(classOf(first), 'all', 1, false); }
        }
    });
})(window.jQuery);
</script>
</#if>
