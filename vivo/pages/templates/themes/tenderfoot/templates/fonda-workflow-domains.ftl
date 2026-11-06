<#-- $This file is distributed under the terms of the license in LICENSE$ -->
<#--
  FONDA 2026-11-02: "Field" and "Purpose" boxes on the Workflows page (/workflows), list "Workflow Name" only,
  like the Year box of the Publications page.
  Data:     fondaWfDomainRows, from display:fondaWorkflowDomainsDataGetter
            (/opt/vivo/vivo/rdf/display/everytime/fonda-workflow-domains.n3): one row per workflow, research field
            (rm:researchField, DFG subject classification) and purpose (rm:workflowPurpose). The query runs on every
            view of the page, so new workflows, fields and purposes appear by themselves.
  Included: by menupage-scripts.ftl, only on the browse page whose class box has rm:Workflow.
  The boxes stand below VIVO's class box and are shown while "Workflow Name" is chosen:
    Field    "All fields" and every field that has workflows, with its number; "Other" for workflows without a field.
    Purpose  "All" and every purpose that has workflows; "Not set" for workflows without a purpose.
             Shown when the workflows have more than one purpose.
  Under each workflow: "Workflow · <field>" in grey, the field linking to its page. The letters, the page numbers
  and "Search this list" work on the chosen field and purpose; the choice is kept in the address (?field=, ?purpose=).
  The other classes of the page (Workflow Scheduling, Tools, Environments) are VIVO's own lists, unchanged.
  It needs VIVO's browse script (js/menupage/browseByVClass.js). If that script is missing or different, nothing
  is shown and the page shows VIVO's own list.
  (The file name is from the first version of 2026-11-02, a "Domain" row above the letters.)
-->
<#if fondaWfDomainRows?? && (fondaWfDomainRows?size > 0)>
<div id="fonda-wf-boxes" style="display:none">
    <div class="fpb-box" id="fwb-field-box" role="navigation" aria-labelledby="fwb-field-title">
        <h3 id="fwb-field-title">Field</h3>
        <ul id="fwb-field" class="fpb-list" role="list"></ul>
    </div>
    <div class="fpb-box" id="fwb-purpose-box" role="navigation" aria-labelledby="fwb-purpose-title" style="display:none">
        <h3 id="fwb-purpose-title">Purpose</h3>
        <ul id="fwb-purpose" class="fpb-list" role="list"></ul>
    </div>
</div>
<style>
    /* left column: VIVO's class box with the Field and Purpose boxes below it, in the look of the Year box of the
       Publications page (spacing as in fonda-browse-look.ftl) */
    #fwb-column { float: left; }
    #fonda-wf-boxes { float: left; clear: left; width: 255px; margin: 0 0 20px 15px; }
    #fonda-wf-boxes .fpb-box { margin: 0 0 16px 0; }
    #fonda-wf-boxes .fpb-box:last-child { margin-bottom: 0; }
    #fonda-wf-boxes h3 { margin: 0; padding: 6px 0 4px 10px; font-size: 1.1em; }
    #fonda-wf-boxes .fpb-list { margin: 0; padding: 0; list-style: none; border: 0; background: transparent; }
    #fonda-wf-boxes .fpb-list li { display: block; width: 235px; margin: 0 10px; padding: 6px 0; font-size: 1em;
        border-bottom: 1px solid #dde4e3; border-left: 4px solid transparent; }
    #fonda-wf-boxes .fpb-list li:last-child { border-bottom: 0; }
    #fonda-wf-boxes .fpb-list li.fpb-selected { border-left-color: #8cb843; }
    #fonda-wf-boxes .fpb-list a { display: block; width: 225px; padding-left: 20px; }
    #fonda-wf-boxes .fpb-list a:hover, #fonda-wf-boxes .fpb-list a.selected { background: url(${urls.theme}/images/arrow.gif) 4px 5px no-repeat; color: #2ea0cf; }
    html:not(.dark-mode) body #fonda-wf-boxes .fpb-list a.selected, html:not(.dark-mode) body #fonda-wf-boxes .fpb-list a:hover { color: #064d68; }
    #fonda-wf-boxes .count-classes { font-size: 12px; }
    #individuals-in-class .fwb-meta a { color: inherit; text-decoration: none; border-bottom: 1px dotted currentColor; }
    #individuals-in-class .fwb-meta a:hover { border-bottom-style: solid; }
    @media (max-width: 1200px) {
        #fwb-column, #fonda-wf-boxes { float: none; width: auto; margin-left: 0; }
    }
</style>
<script type="text/javascript">
(function ($) {
    'use strict';
    if (!$) { return; }
    var WORKFLOW = 'http://example.org/ontology/run-metadata#Workflow';
    var PER_PAGE = 30;
    var BASE = "${urls.base?js_string}";
    var VIEW = "${i18n().view_profile_page_for?js_string}";
    var NONE_STARTING = "${i18n().there_are_no_entries_starting_with?js_string}";
    var TRY_ANOTHER = "${i18n().try_another_letter?js_string}";
    // one row per workflow, field and purpose: w = workflow, l = its name, f/fn = field and its name, p/pn = purpose and its name
    var ROWS = [
<#list fondaWfDomainRows as row>
        {w: "${(row.fondaWf!"")?js_string}", l: "${(row.fondaWfName!"")?js_string}", f: "${(row.fondaField!"")?js_string}", fn: "${(row.fondaFieldName!"")?js_string}", p: "${(row.fondaPurpose!"")?js_string}", pn: "${(row.fondaPurposeName!"")?js_string}"}<#if row_has_next>,</#if>
</#list>
    ];

    function esc(text) {
        return String(text).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }
    function tail(uri) { return String(uri).replace(/[\/#]+$/, '').replace(/^.*[\/#]/, ''); }
    function decoded(text) { try { return decodeURIComponent(text); } catch (e) { return text; } }
    function isWorkflowClass(uri) { return uri === WORKFLOW || decoded(uri || '') === WORKFLOW; }
    function slug(text) { return String(text).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, ''); }
    function profile(uri) { return BASE + '/individual?uri=' + encodeURIComponent(uri); }

    // workflows (each once); fields and purposes (each once, with the number of their workflows)
    var workflows = [], wfOf = {};
    var facets = { field: { list: [], of: {}, key: 'fields', none: 0 }, purpose: { list: [], of: {}, key: 'purposes', none: 0 } };
    function add(facet, wf, uri, name) {
        if (!uri) { return; }
        var f = facets[facet], v = f.of[uri];
        if (!v) { v = f.of[uri] = { uri: uri, name: name || tail(uri), key: slug(name || tail(uri)), count: 0 }; f.list.push(v); }
        if ($.inArray(v, wf[f.key]) === -1) { wf[f.key].push(v); v.count++; }
    }
    $.each(ROWS, function (i, row) {
        if (!row.w) { return; }
        var wf = wfOf[row.w];
        if (!wf) {
            var name = row.l || tail(row.w);
            wf = wfOf[row.w] = { uri: row.w, name: name, sort: $.trim(name).toLowerCase(), fields: [], purposes: [] };
            workflows.push(wf);
        }
        add('field', wf, row.f, row.fn);
        add('purpose', wf, row.p, row.pn);
    });
    workflows.sort(function (a, b) { return a.sort < b.sort ? -1 : a.sort > b.sort ? 1 : (a.uri < b.uri ? -1 : 1); });
    $.each(facets, function (name, f) {
        f.list.sort(function (a, b) { return b.count - a.count || (a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1); });
        f.none = $.grep(workflows, function (wf) { return !wf[f.key].length; }).length;
    });
    // fields in alphabetical order (the order of the DFG list is not obvious to visitors); purposes by number
    facets.field.list.sort(function (a, b) { return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1; });

    var NONE = 'none';
    var chosen = { field: null, purpose: null };   // null = all, 'none' = without, otherwise a key
    function fits(wf, facet) {
        var value = chosen[facet], values = wf[facets[facet].key];
        if (value === null) { return true; }
        if (value === NONE) { return !values.length; }
        for (var i = 0; i < values.length; i++) { if (values[i].key === value) { return true; } }
        return false;
    }
    function inChoice(wf) { return fits(wf, 'field') && fits(wf, 'purpose'); }
    var NONE_LABEL = { field: 'Other', purpose: 'Not set' };
    function chosenName(facet) {
        var value = chosen[facet], list = facets[facet].list;
        if (value === null) { return ''; }
        if (value === NONE) { return NONE_LABEL[facet]; }
        for (var i = 0; i < list.length; i++) { if (list[i].key === value) { return list[i].name; } }
        return '';
    }

    $(document).ready(function () {
        var bv = window.browseByVClass, boxes = $('#fonda-wf-boxes');
        var lists = { field: $('#fwb-field'), purpose: $('#fwb-purpose') };
        var classLink = $('#browse-classes a').filter(function () { return isWorkflowClass($(this).attr('data-uri')); }).first();
        if (!bv || !$.isFunction(bv.getIndividuals) || !$.isFunction(bv.wipeSlate) || !$.isFunction(bv.selectedAlpha) ||
                !$.isFunction(bv.selectedVClass) || !classLink.length || !workflows.length) { return; }
        var className = $.trim(classLink.clone().children().remove().end().text()) || 'Workflow';
        var TYPE = 'Workflow';
        var lastAlpha = 'all', lastPage = 1, active = false;

        function fill(facet, allTitle) {
            var f = facets[facet], noun = facet === 'field' ? 'field' : 'purpose';
            var entries = '<li role="listitem"><a href="#" data-value="*" title="' + esc(allTitle) + '">' +
                          (facet === 'field' ? 'All fields' : 'All') + ' <span class="count-classes">(' + workflows.length + ')</span></a></li>';
            $.each(f.list, function (i, v) {
                entries += '<li role="listitem"><a href="#" data-value="' + esc(v.key) + '" title="' + esc('Show only the workflows with the ' + noun + ' ' + v.name) + '">' +
                           esc(v.name) + ' <span class="count-classes">(' + v.count + ')</span></a></li>';
            });
            if (f.none) {
                entries += '<li role="listitem"><a href="#" data-value="' + NONE + '" title="' + esc('Show only the workflows without a ' + noun) + '">' +
                           NONE_LABEL[facet] + ' <span class="count-classes">(' + f.none + ')</span></a></li>';
            }
            lists[facet].html(entries);
        }
        fill('field', 'Show the workflows of all fields');
        fill('purpose', 'Show the workflows of all purposes');
        // the Purpose box only when there is something to choose
        if (facets.purpose.list.length + (facets.purpose.none ? 1 : 0) > 1) { $('#fwb-purpose-box').show(); }

        function mark() {
            $.each(lists, function (facet, list) {
                var value = chosen[facet] === null ? '*' : chosen[facet];
                list.find('a').removeClass('selected').removeAttr('aria-current')
                    .filter(function () { return $(this).attr('data-value') === value; }).addClass('selected').attr('aria-current', 'true');
            });
            boxes.find('.fpb-list li').removeClass('fpb-selected').has('a.selected').addClass('fpb-selected');
        }
        function remember() {
            try {
                var address = new URL(window.location.href);
                $.each(chosen, function (facet, value) {
                    if (value === null) { address.searchParams['delete'](facet); } else { address.searchParams.set(facet, value); }
                });
                window.history.replaceState(null, '', address.toString());
            } catch (e) { /* older browser: the choice is simply not kept */ }
        }
        function fromAddress() {
            try {
                var wanted = new URL(window.location.href).searchParams;
                $.each(facets, function (facet, f) {
                    var value = wanted.get(facet);
                    if (value === NONE && f.none) { chosen[facet] = NONE; }
                    else if (value) { $.each(f.list, function (i, v) { if (v.key === value) { chosen[facet] = value; } }); }
                });
            } catch (e) { /* no choice in the address */ }
        }
        function meta(wf) {
            var parts = $.map(wf.fields, function (v) {
                return '<a href="' + esc(profile(v.uri)) + '" title="' + esc('All workflows of the field ' + v.name) + '">' + esc(v.name) + '</a>';
            });
            return '<span class="title fwb-meta">' + esc(TYPE) + (parts.length ? ' · ' + parts.join(', ') : '') + '</span>';
        }
        function heading() {
            var parts = [className], f = chosenName('field'), p = chosenName('purpose');
            if (f) { parts.push(f); }
            if (p) { parts.push(p); }
            return parts.join(' · ');
        }

        function render(alpha, page, scroll) {
            var shown = [], i;
            alpha = alpha || 'all';
            for (i = 0; i < workflows.length; i++) {
                if (inChoice(workflows[i]) && (alpha === 'all' || workflows[i].sort.charAt(0) === alpha)) { shown.push(workflows[i]); }
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
                    '<p class="no-individuals">No workflows for this choice.</p>');
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
            $('h3.selected-class').text(heading());
            bv.selectedVClass(classLink.attr('data-uri'));
            bv.selectedAlpha(alpha);
        }

        // "Search this list" (fonda-list-search.ftl) asks here for the workflows of the chosen field and purpose
        window.fondaListProviders = window.fondaListProviders || [];
        window.fondaListProviders.push(function (classUri) {
            if (!isWorkflowClass(classUri)) { return null; }
            return $.map($.grep(workflows, inChoice), function (wf) {
                var names = $.map(wf.fields, function (v) { return v.name; });
                return { href: profile(wf.uri), name: wf.name, meta: TYPE + (names.length ? ' · ' + names.join(', ') : '') };
            });
        });

        // VIVO's script asks for the list through getIndividuals (first load, class, letters, pages).
        // For "Workflow Name" the list is written here; the other classes are left to VIVO.
        var vivoList = bv.getIndividuals;
        bv.getIndividuals = function (vclassUri, alpha, page, scroll) {
            if (!isWorkflowClass(vclassUri)) {
                active = false;
                boxes.hide();
                return vivoList.apply(bv, arguments);
            }
            active = true;
            boxes.show();
            render(alpha, page, scroll);
        };
        // if VIVO's own list of the workflows was already requested (its script started first), it must not replace this list
        $(document).ajaxComplete(function (event, request, settings) {
            var url = String((settings && settings.url) || '');
            if (active && url.indexOf('getRenderedSearchIndividualsByVClass') !== -1 && url.indexOf('fondaListSearch=1') === -1 &&
                    decoded(url).indexOf(WORKFLOW) !== -1) {
                render(lastAlpha, lastPage, false);
            }
        });

        $.each(lists, function (facet, list) {
            list.on('click', 'a', function () {
                var value = $(this).attr('data-value');
                chosen[facet] = value === '*' ? null : value;
                mark(); remember();
                render('all', 1, false);
                // while "Search this list" has words in it, show its matches for the new choice
                var search = $('#fonda-list-search input');
                if (search.length && $.trim(search.val())) { search.trigger('input'); }
                return false;
            });
        });

        fromAddress();
        mark();
        // the boxes below VIVO's class box, in one column with it (as on the Publications page)
        $('#browse-classes').wrap('<div id="fwb-column"></div>');
        $('#fwb-column').append(boxes);
        // VIVO's script normally starts after this one and then asks for the list; if it started first, write it now
        if (bv.individualsInVClass) {
            var first = $('#browse-classes li a.selected').attr('data-uri') || (window.location.hash || '').substring(1) ||
                        $('#browse-classes li a').first().attr('data-uri');
            if (isWorkflowClass(first)) { active = true; boxes.show(); render('all', 1, false); }
        }
    });
})(window.jQuery);
</script>
</#if>
