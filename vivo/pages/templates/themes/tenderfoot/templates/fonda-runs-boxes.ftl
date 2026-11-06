<#-- $This file is distributed under the terms of the license in LICENSE$ -->
<#--
  FONDA 2026-10-04: "Sort" and "Cluster" boxes on the Runs page (/runs).
  Data:     fondaRunsRows, from display:fondaRunsBoxesDataGetter
            (/opt/vivo/vivo/rdf/display/everytime/fonda-runs-boxes.n3): one row per run and compute cluster,
            with the name and the start time of the run. The query runs on every view of the page, so new
            runs and new clusters appear by themselves.
  Included: by page-runs-chronological.ftl, the template of the Runs page.
  The boxes stand below VIVO's class box ("Workflow Run") and look like it (2026-10-04: no grey background):
    Sort     "Newest first" (by start time; this is how the page opens) or "Name A-Z" (as VIVO's own list).
    Cluster  "All clusters" and every cluster that has runs, each with its number of runs. Shown only when the
             runs are on more than one cluster.
  The list of runs is written by this script from the rows of the query, in the markup of VIVO's own list;
  the letters and the page numbers work on the chosen cluster and order.
  It needs VIVO's browse script (js/menupage/browseByVClass.js). If that script is missing or different, the
  boxes are not shown and the page shows VIVO's own alphabetical list.
-->
<#if fondaRunsRows?? && (fondaRunsRows?size > 0)>
<div id="fonda-runs-boxes" style="display:none">
    <div class="frb-box" role="navigation" aria-labelledby="frb-sort-title">
        <h3 id="frb-sort-title">Sort</h3>
        <ul id="frb-sort" class="frb-list" role="list">
            <li role="listitem"><a href="#" data-sort="new" title="Newest run first, by start time">Newest first</a></li>
            <li role="listitem"><a href="#" data-sort="name" title="By name, A to Z">Name A&ndash;Z</a></li>
        </ul>
    </div>
    <div class="frb-box" id="frb-cluster-box" role="navigation" aria-labelledby="frb-cluster-title" style="display:none">
        <h3 id="frb-cluster-title">Cluster</h3>
        <ul id="frb-cluster" class="frb-list" role="list"></ul>
    </div>
</div>
<style>
    /* left column: VIVO's class box with the Sort and Cluster boxes below it. The two lists look like the class
       box of this site: no background, no frame, a line between the entries, a green bar beside the chosen one. */
    #frb-column { float: left; }
    #fonda-runs-boxes { float: left; clear: left; width: 255px; margin: 0 0 20px 15px; }
    #fonda-runs-boxes .frb-box { margin: 0 0 20px 0; }
    #fonda-runs-boxes h3 { margin: 0; padding: 0 0 4px 10px; font-size: 1.1em; }
    #fonda-runs-boxes .frb-list { margin: 0; padding: 0; list-style: none; border: 0; background: transparent; }
    #fonda-runs-boxes .frb-list li { display: block; width: 235px; margin: 0 10px; padding: 10px 0; font-size: 1em;
        border-bottom: 1px solid #dde4e3; border-left: 4px solid transparent; }
    #fonda-runs-boxes .frb-list li:last-child { border-bottom: 0; }
    #fonda-runs-boxes .frb-list li.frb-selected { border-left-color: #8cb843; }
    #fonda-runs-boxes .frb-list a { display: block; width: 225px; padding-left: 20px; }
    #fonda-runs-boxes .frb-list a:hover, #fonda-runs-boxes .frb-list a.selected { background: url(${urls.theme}/images/arrow.gif) 4px 5px no-repeat; color: #2ea0cf; }
    #fonda-runs-boxes .count-classes { font-size: 12px; }
    /* narrow window: the site stacks the class box above the list; the two boxes follow the class box */
    @media (max-width: 1200px) {
        #frb-column, #fonda-runs-boxes { float: none; width: auto; margin-left: 0; }
    }
</style>
<script type="text/javascript">
(function ($) {
    'use strict';
    var RUN_CLASS = 'http://example.org/ontology/run-metadata#RunMetadata';
    var PER_PAGE = 30;   // as in VIVO's own list
    var BASE = "${urls.base?js_string}";
    var VIEW = "${i18n().view_profile_page_for?js_string}";
    var NONE_STARTING = "${i18n().there_are_no_entries_starting_with?js_string}";
    var TRY_ANOTHER = "${i18n().try_another_letter?js_string}";
    // one entry per run and cluster: r = run, l = name of the run, s = start time, c = cluster, n = name of the cluster
    var ROWS = [
<#list fondaRunsRows as row>
        {r: "${(row.fondaRun!"")?js_string}", l: "${(row.fondaRunName!"")?js_string}", s: "${(row.fondaStart!"")?js_string}", c: "${(row.fondaCluster!"")?js_string}", n: "${(row.fondaClusterName!"")?js_string}"}<#if row_has_next>,</#if>
</#list>
    ];

    function esc(text) {
        return String(text).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }
    // last part of an address: ".../cluster/hpc-hu-cluster" -> "hpc-hu-cluster"
    function tail(uri) { return String(uri).replace(/[\/#]+$/, '').replace(/^.*[\/#]/, ''); }
    function decoded(text) { try { return decodeURIComponent(text); } catch (e) { return text; } }
    // start of a run as a number that sorts by time, "YYYYMMDDhhmmss" in Berlin time. Start times are stored as
    // local time without a zone; one with a zone is converted. Without a start time, the date in the name of the
    // run is used ("... run 2026-10-03 17:22-17:24 CEST"). 0 = unknown, listed last.
    function startKey(start, name) {
        var m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?/.exec(start || '');
        if (m && /(Z|[+-]\d{2}:?\d{2})$/.test(start) && window.Intl) {
            try {
                var date = new Date(start), part = {};
                if (!isNaN(date.getTime())) {
                    new Intl.DateTimeFormat('en-GB', { timeZone: 'Europe/Berlin', year: 'numeric', month: '2-digit', day: '2-digit',
                        hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23' })
                        .formatToParts(date).forEach(function (x) { part[x.type] = x.value; });
                    m = [null, part.year, part.month, part.day, part.hour, part.minute, part.second];
                }
            } catch (e) { /* keep the time as written */ }
        }
        if (!m) { m = /(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})/.exec(name || ''); }
        return m ? Number(m[1] + m[2] + m[3] + m[4] + m[5] + (m[6] || '00')) : 0;
    }

    // runs[address] = one run; clusters[key]: key = address of the cluster, '' = runs without a cluster
    var runs = {}, runList = [], clusters = {}, keys = [];
    $.each(ROWS, function (i, row) {
        if (!row.r) { return; }
        var run = runs[row.r], key = row.c || '';
        if (!run) {
            var name = row.l || tail(row.r);
            run = runs[row.r] = { uri: row.r, name: name, sort: name.toLowerCase(), start: startKey(row.s, name), on: {} };
            runList.push(run);
        }
        if (!clusters[key]) { clusters[key] = { name: '', count: 0 }; keys.push(key); }
        if (row.n && !clusters[key].name) { clusters[key].name = row.n; }
        if (!run.on[key]) { run.on[key] = true; clusters[key].count++; }
    });
    $.each(keys, function (i, key) {
        clusters[key].label = key === '' ? 'Cluster not recorded' : (clusters[key].name || tail(key));
    });
    // named clusters in alphabetical order, runs without a cluster last
    keys.sort(function (a, b) {
        if (a === '' || b === '') { return a === b ? 0 : a === '' ? 1 : -1; }
        var x = clusters[a].label.toLowerCase(), y = clusters[b].label.toLowerCase();
        return x < y ? -1 : x > y ? 1 : 0;
    });
    function byName(a, b) { return a.sort < b.sort ? -1 : a.sort > b.sort ? 1 : a.uri < b.uri ? -1 : a.uri > b.uri ? 1 : 0; }
    function newestFirst(a, b) { return b.start - a.start || byName(a, b); }

    $(document).ready(function () {
        var bv = window.browseByVClass, boxes = $('#fonda-runs-boxes'), sortList = $('#frb-sort'), clusterList = $('#frb-cluster');
        var classLink = $('#browse-classes a').filter(function () { return $(this).attr('data-uri') === RUN_CLASS; });
        // without VIVO's browse script or without the class of the runs: no boxes, VIVO's own list
        if (!bv || !$.isFunction(bv.getIndividuals) || !$.isFunction(bv.wipeSlate) || !$.isFunction(bv.selectedAlpha) ||
                !$.isFunction(bv.selectedVClass) || !classLink.length || !runList.length) { return; }
        var className = $.trim(classLink.clone().children().remove().end().text());
        var cluster = null;                 // null = all clusters, otherwise a key of clusters
        var order = 'new';                  // 'new' = newest first, 'name' = name A-Z
        var lastAlpha = 'all', lastPage = 1;

        if (keys.length > 1) {
            var entries = '<li role="listitem"><a href="#" data-cluster="*" title="Show the runs of all clusters">All clusters ' +
                          '<span class="count-classes">(' + runList.length + ')</span></a></li>';
            $.each(keys, function (i, key) {
                entries += '<li role="listitem"><a href="#" data-cluster="' + esc(key) + '" title="' +
                    esc(key === '' ? 'Show only the runs without a cluster' : 'Show only the runs on ' + clusters[key].label) + '">' +
                    esc(clusters[key].label) + ' <span class="count-classes">(' + clusters[key].count + ')</span></a></li>';
            });
            clusterList.html(entries);
            $('#frb-cluster-box').show();
        }

        function mark() {
            var value = cluster === null ? '*' : cluster;
            clusterList.find('a').removeClass('selected').removeAttr('aria-current')
                .filter(function () { return $(this).attr('data-cluster') === value; }).addClass('selected').attr('aria-current', 'true');
            sortList.find('a').removeClass('selected').removeAttr('aria-current')
                .filter(function () { return $(this).attr('data-sort') === order; }).addClass('selected').attr('aria-current', 'true');
            // the green bar beside the chosen entry, as on the class box
            boxes.find('.frb-list li').removeClass('frb-selected').has('a.selected').addClass('frb-selected');
        }
        // keep the choice in the address, so that the Back button returns to the same list
        function remember() {
            try {
                var address = new URL(window.location.href);
                if (cluster === null) { address.searchParams['delete']('cluster'); }
                else { address.searchParams.set('cluster', cluster === '' ? 'none' : tail(cluster)); }
                if (order === 'new') { address.searchParams['delete']('sort'); } else { address.searchParams.set('sort', order); }
                window.history.replaceState(null, '', address.toString());
            } catch (e) { /* older browser: the choice is simply not kept */ }
        }
        function fromAddress() {
            try {
                var wanted = new URL(window.location.href).searchParams;
                if (wanted.get('sort') === 'name') { order = 'name'; }
                var name = wanted.get('cluster');
                if (name === 'none' && clusters['']) { cluster = ''; }
                else if (name) {
                    for (var i = 0; i < keys.length; i++) {
                        if (keys[i] !== '' && (tail(keys[i]) === name || keys[i] === name)) { cluster = keys[i]; break; }
                    }
                }
            } catch (e) { /* no choice in the address */ }
        }

        // the list: the runs of the chosen cluster in the chosen order; letters, page size and markup as in VIVO's own list
        function render(alpha, page, scroll) {
            var shown = [], i;
            alpha = alpha || 'all';
            for (i = 0; i < runList.length; i++) {
                if ((cluster === null || runList[i].on[cluster]) && (alpha === 'all' || runList[i].sort.charAt(0) === alpha)) { shown.push(runList[i]); }
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
                $('#individuals-in-class').prepend('<p class="no-individuals">' + esc(NONE_STARTING) + ' <em>' + esc(alpha.toUpperCase()) +
                    '</em>.</p> <p class="no-individuals">' + esc(TRY_ANOTHER) + '</p>');
            } else {
                var items = '';
                for (i = (page - 1) * PER_PAGE; i < Math.min(page * PER_PAGE, shown.length); i++) {
                    items += '<li class="individual" role="listitem"><h1><a href="' +
                        esc(BASE + '/individual?uri=' + encodeURIComponent(shown[i].uri)) + '" title="' + esc(VIEW + ' ' + shown[i].name) +
                        '">' + esc(shown[i].name) + '</a></h1></li>';
                }
                $('#individuals-in-class ul').first().append(items);
                if (pageCount > 1 && $.isFunction(bv.pagination)) {
                    var pages = [];
                    for (i = 1; i <= pageCount; i++) { pages.push({ text: String(i), index: String(i) }); }
                    bv.pagination(pages, page);
                }
            }
            $('h3.selected-class').text(cluster === null ? className : className + ' · ' + clusters[cluster].label);
            bv.selectedVClass(RUN_CLASS);
            bv.selectedAlpha(alpha);
        }

        // VIVO's script asks for the list through getIndividuals (first load, letters, pages, class).
        // For the class of the runs the list is written here; any other class of the page is left to VIVO.
        // 2026-10-15: the search box above the list (fonda-list-search.ftl) asks here for the runs of the chosen cluster,
        // in the chosen order
        window.fondaListProviders = window.fondaListProviders || [];
        window.fondaListProviders.push(function (classUri) {
            if (classUri !== RUN_CLASS && decoded(classUri) !== RUN_CLASS) { return null; }
            var shown = [], i;
            for (i = 0; i < runList.length; i++) { if (cluster === null || runList[i].on[cluster]) { shown.push(runList[i]); } }
            shown.sort(order === 'name' ? byName : newestFirst);
            return $.map(shown, function (run) {
                return { href: BASE + '/individual?uri=' + encodeURIComponent(run.uri), name: run.name, meta: '' };
            });
        });
        var vivoList = bv.getIndividuals;
        bv.getIndividuals = function (vclassUri, alpha, page, scroll) {
            if (vclassUri !== RUN_CLASS && decoded(vclassUri) !== RUN_CLASS) {
                boxes.hide();
                return vivoList.apply(bv, arguments);
            }
            boxes.show();
            render(alpha, page, scroll);
        };
        // if VIVO's own list of the runs was already requested (its script started first), it must not replace this list
        $(document).ajaxComplete(function (event, request, settings) {
            if (boxes.is(':visible') && settings && String(settings.url).indexOf('getRenderedSearchIndividualsByVClass') !== -1 &&
                    decoded(String(settings.url)).indexOf(RUN_CLASS) !== -1) {
                render(lastAlpha, lastPage, false);
            }
        });

        clusterList.on('click', 'a', function () {
            var value = $(this).attr('data-cluster');
            cluster = value === '*' ? null : value;
            mark(); remember();
            render('all', 1, false);
            return false;
        });
        sortList.on('click', 'a', function () {
            order = $(this).attr('data-sort') === 'name' ? 'name' : 'new';
            mark(); remember();
            render(lastAlpha, 1, false);
            return false;
        });

        fromAddress();
        mark();
        // put the boxes below VIVO's class box, in one column with it, so that they stay beside (or, in a narrow
        // window, above) the list
        $('#browse-classes').wrap('<div id="frb-column"></div>');
        $('#frb-column').append(boxes);
        boxes.show();
        // VIVO's script normally starts after this one and then asks for the list; if it started first, write the list now
        if (bv.individualsInVClass) { render('all', 1, false); }
    });
})(jQuery);
</script>
</#if>
