<#-- FONDA: a yearly graph of the person's recorded presentations, independent of authorship. -->
<#function fondaPresentationDate raw precision>
    <#local day = raw?keep_before("T")>
    <#local text = "">
    <#local machine = "">
    <#if day?matches("[0-9]{4}-[0-9]{2}-[0-9]{2}")>
        <#attempt>
            <#local parsed = day?date("yyyy-MM-dd")>
            <#if precision?ends_with("yearPrecision")>
                <#local text = parsed?string("yyyy")>
                <#local machine = parsed?string("yyyy")>
            <#elseif precision?ends_with("yearMonthPrecision")>
                <#local text = parsed?string("MMMM yyyy")>
                <#local machine = parsed?string("yyyy-MM")>
            <#else>
                <#local text = parsed?string("d MMMM yyyy")>
                <#local machine = day>
            </#if>
        <#recover>
            <#local text = "">
            <#local machine = "">
        </#attempt>
    <#elseif day?matches("[0-9]{4}")>
        <#local text = day>
        <#local machine = day>
    </#if>
    <#return {"text": text, "machine": machine}>
</#function>

<#function fondaRecentPresentations propertyGroups>
    <#local prop = propertyGroups.getProperty("http://purl.obolibrary.org/obo/RO_0000053", "http://vivoweb.org/ontology/core#PresenterRole")!>
    <#if !prop?has_content><#return []></#if>
    <#local groups = []>
    <#if prop.collatedBySubclass!false>
        <#local groups = prop.subclasses>
    <#else>
        <#local groups = [{"name": "Presentation", "statements": prop.statements![]}]>
    </#if>
    <#local records = {}>
    <#list groups as presentationGroup>
        <#list presentationGroup.statements as statement>
            <#local uri = statement.uri("presentation")!"">
            <#if uri?has_content>
                <#local date = (statement.presentationDate!"")?trim>
                <#local precision = statement.presentationDatePrecision!"">
                <#if !date?has_content>
                    <#local date = (statement.dateTime!"")?trim>
                    <#local precision = statement.roleDatePrecision!"">
                </#if>
                <#local formatted = fondaPresentationDate(date, precision)>
                <#local title = (statement.presentationLabel!statement.presentationName!"Untitled presentation")?trim>
                <#if !title?has_content><#local title = "Untitled presentation"></#if>
                <#local format = (presentationGroup.name!"")?trim>
                <#if !format?has_content><#local format = "Presentation"></#if>
                <#local eventUri = "">
                <#local eventLabel = "">
                <#if (statement.conferenceLabel!"")?has_content>
                    <#local eventUri = statement.uri("conference")!"">
                    <#local eventLabel = statement.conferenceLabel>
                <#elseif (statement.seriesLabel!"")?has_content>
                    <#local eventUri = statement.uri("series")!"">
                    <#local eventLabel = statement.seriesLabel>
                </#if>
                <#local dateRank = 0>
                <#if formatted.machine?has_content><#local dateRank = formatted.machine?replace("-", "")?right_pad(8, "0")?number></#if>
                <#local record = {"uri": uri, "title": title, "format": format?cap_first,
                    "dateText": formatted.text, "machineDate": formatted.machine,
                    "sortDate": formatted.machine, "dateRank": dateRank, "eventUri": eventUri, "eventLabel": eventLabel}>
                <#-- One graph record per presentation, even if it has multiple presenter roles. -->
                <#if !records[uri]?? || record.dateRank gt records[uri].dateRank>
                    <#local records = records + {uri: record}>
                </#if>
            </#if>
        </#list>
    </#list>
    <#return records?values?sort_by("title")?sort_by("sortDate")?reverse>
</#function>

<#assign fondaPresentationEntries = fondaRecentPresentations(propertyGroups)>
<#if fondaPresentationEntries?has_content>
    <style>
        .fonda-presentations-panel { box-sizing: border-box; width: 100%; margin: 0 0 20px; padding: 16px; border: 1px solid #e2e9ef; border-radius: 12px; background: #fafcfd; }
        .fonda-presentations-panel #fonda-presentations-heading { margin: 0; color: #23395d; font-size: 15px; font-weight: 600; line-height: 1.4; }
        .fonda-presentations-caption { margin: 4px 0 18px; color: #647487; font-size: 12px; line-height: 1.5; }
        .fonda-presentations-legend { display: flex; flex-wrap: wrap; gap: 10px 16px; margin-bottom: 16px; color: #526476; font-size: 12px; line-height: 1.5; }
        .fonda-presentations-legend > span { display: inline-flex; align-items: center; gap: 6px; }
        .fonda-presentations-legend span { color: inherit !important; }
        .fonda-presentations-legend i { width: 9px; height: 9px; border-radius: 3px; }
        .fonda-presentations-scroll { width: 100%; overflow-x: auto; }
        #presentationsChart { display: block; overflow: visible; }
        #presentationsChart text { fill: #647487; font-family: inherit; font-size: 11px; }
        #presentationsChart .fonda-presentation-grid { stroke: #dce6ee; stroke-dasharray: 3 4; }
        #presentationsChart .fonda-presentation-baseline { stroke: #dce6ee; }
        .fonda-presentation-year:focus { outline: none; }
        .fonda-presentation-year:hover .fonda-presentation-segment, .fonda-presentation-year:focus .fonda-presentation-segment { stroke: #23395d; stroke-width: 2px; }
        .fonda-presentation-year:focus .fonda-presentation-hit { stroke: #23395d; stroke-width: 1px; stroke-dasharray: 3 3; }
        .fonda-presentations-detail, .fonda-presentations-undated { margin: 12px 0; color: #526476; font-size: 12px; line-height: 1.5; }
        .fonda-presentations-undated[hidden] { display: none; }
        .fonda-presentations-panel a.fonda-presentations-view-all { display: inline-block; border-top: 1px solid #e2e9ef; padding-top: 12px; width: 100%; color: #205584; font-size: 12px; line-height: 1.5; }
        .fonda-presentations-panel a:hover { text-decoration: underline; }
        .fonda-presentation-color-0 { background: #286a91; fill: #286a91; }
        .fonda-presentation-color-1 { background: #7375bd; fill: #7375bd; }
        .fonda-presentation-color-2 { background: #52a9b8; fill: #52a9b8; }
        .fonda-presentation-color-3 { background: #ba8740; fill: #ba8740; }
        .fonda-presentation-color-4 { background: #9b6285; fill: #9b6285; }
        html.dark-mode .fonda-presentations-panel { background: #151f2d; border-color: #2b3b50; }
        html.dark-mode .fonda-presentations-panel #fonda-presentations-heading { color: #e4edf6; }
        html.dark-mode .fonda-presentations-caption, html.dark-mode .fonda-presentations-legend,
        html.dark-mode .fonda-presentations-detail, html.dark-mode .fonda-presentations-undated { color: #a8b9cb; }
        html.dark-mode #presentationsChart text { fill: #a8b9cb; }
        html.dark-mode #presentationsChart .fonda-presentation-grid, html.dark-mode #presentationsChart .fonda-presentation-baseline { stroke: #33445b; }
        html.dark-mode .fonda-presentation-year:hover .fonda-presentation-segment,
        html.dark-mode .fonda-presentation-year:focus .fonda-presentation-segment,
        html.dark-mode .fonda-presentation-year:focus .fonda-presentation-hit { stroke: #e4edf6; }
        html.dark-mode .fonda-presentations-panel a.fonda-presentations-view-all { color: #93c7eb; border-color: #2b3b50; }
        html.dark-mode .fonda-presentation-color-0 { background: #76b1de; fill: #76b1de; }
        html.dark-mode .fonda-presentation-color-1 { background: #b2a7ec; fill: #b2a7ec; }
        html.dark-mode .fonda-presentation-color-2 { background: #55c1c3; fill: #55c1c3; }
        html.dark-mode .fonda-presentation-color-3 { background: #dfb671; fill: #dfb671; }
        html.dark-mode .fonda-presentation-color-4 { background: #d598bb; fill: #d598bb; }
    </style>
    <section class="fonda-presentations-panel" aria-labelledby="fonda-presentations-heading">
        <h3 id="fonda-presentations-heading">Presentations in FONDA</h3>
        <p class="fonda-presentations-caption">Presentations by year</p>
        <div class="fonda-presentations-data" hidden>
            <#list fondaPresentationEntries as entry>
                <span data-date="${entry.machineDate}" data-format="${entry.format?html}"></span>
            </#list>
        </div>
        <div class="fonda-presentations-legend" aria-label="Presentation types"></div>
        <div class="fonda-presentations-scroll">
            <svg id="presentationsChart" role="group" aria-label="Presentations by year. Focus a bar for counts and presentation types."></svg>
        </div>
        <p class="fonda-presentations-detail" aria-live="polite">Yearly counts · hover or focus a bar for details</p>
        <p class="fonda-presentations-undated" hidden>Presentations without a recorded date are available in the full list.</p>
        <a id="fonda-view-presentations" class="fonda-presentations-view-all" href="#RO_0000053-PresenterRole-List">View all presentations</a>
    </section>
    <script>
        $(document).ready(function () {
            var panel = document.querySelector('.fonda-presentations-panel');
            var chart = panel.querySelector('#presentationsChart');
            var detail = panel.querySelector('.fonda-presentations-detail');
            var defaultDetail = 'Yearly counts · hover or focus a bar for details';

            function presentationAnnualRows(entries) {
                var byYear = Object.create(null), types = [], undated = 0;
                entries.forEach(function (entry) {
                    var year = /^\d{4}(?:-|$)/.test(entry.date) ? +entry.date.slice(0, 4) : 0;
                    if (!year) { undated++; return; }
                    var type = entry.format || 'Presentation';
                    if (types.indexOf(type) === -1) types.push(type);
                    if (!byYear[year]) byYear[year] = {year: year, total: 0, types: Object.create(null)};
                    byYear[year].total++;
                    byYear[year].types[type] = (byYear[year].types[type] || 0) + 1;
                });
                types.sort();
                var years = Object.keys(byYear).map(Number).sort(function (a, b) { return a - b; });
                var rows = [];
                if (years.length) {
                    for (var year = years[0]; year <= years[years.length - 1]; year++) {
                        rows.push(byYear[year] || {year: year, total: 0, types: Object.create(null)});
                    }
                }
                return {rows: rows, types: types, undated: undated};
            }

            function presentationTickScale(maximum) {
                var rough = Math.max(1, maximum / 4);
                var power = Math.pow(10, Math.floor(Math.log(rough) / Math.LN10));
                var step = [1, 2, 5, 10].map(function (factor) { return factor * power; })
                    .filter(function (value) { return value >= rough; })[0];
                return {step: step, maximum: Math.ceil(maximum / step) * step};
            }

            function presentationDescription(row, types) {
                return row.year + ' · ' + row.total + ' presentation' + (row.total === 1 ? '' : 's')
                    + types.filter(function (type) { return row.types[type] > 0; })
                        .map(function (type) { return ' · ' + type + ': ' + row.types[type]; }).join('');
            }

            var entries = Array.prototype.map.call(panel.querySelectorAll('.fonda-presentations-data span'), function (node) {
                return {date: node.getAttribute('data-date'), format: node.getAttribute('data-format')};
            });
            var annual = presentationAnnualRows(entries);
            panel.querySelector('.fonda-presentations-undated').hidden = !annual.undated;
            function colorClass(type) {
                var known = {Talk: 0, Poster: 1, Demo: 2, Presentation: 3};
                var index = Object.prototype.hasOwnProperty.call(known, type) ? known[type] : 4;
                return 'fonda-presentation-color-' + index;
            }
            var legend = panel.querySelector('.fonda-presentations-legend');
            annual.types.forEach(function (type) {
                var item = document.createElement('span');
                var swatch = document.createElement('i');
                swatch.className = colorClass(type);
                swatch.setAttribute('aria-hidden', 'true');
                item.appendChild(swatch);
                item.appendChild(document.createTextNode(type));
                legend.appendChild(item);
            });

            function svgElement(name, attributes, parent, text) {
                var element = document.createElementNS('http://www.w3.org/2000/svg', name);
                Object.keys(attributes).forEach(function (key) { element.setAttribute(key, attributes[key]); });
                if (text !== undefined) element.textContent = text;
                parent.appendChild(element);
                return element;
            }
            function renderPresentationsChart() {
                if (!annual.rows.length) {
                    panel.querySelector('.fonda-presentations-scroll').hidden = true;
                    detail.textContent = 'Dates have not been recorded for these presentations yet.';
                    panel.querySelector('.fonda-presentations-undated').hidden = true;
                    return;
                }
                var available = panel.querySelector('.fonda-presentations-scroll').clientWidth;
                if (!available) return;
                var chartWidth = Math.max(available, annual.rows.length * 34 + 42);
                var margin = {top: 12, right: 10, bottom: 32, left: 30};
                var width = chartWidth - margin.left - margin.right, height = 132;
                var scale = presentationTickScale(Math.max.apply(null, annual.rows.map(function (row) { return row.total; })));
                var y = function (count) { return margin.top + height * (1 - count / scale.maximum); };
                while (chart.firstChild) chart.removeChild(chart.firstChild);
                chart.setAttribute('width', chartWidth);
                chart.setAttribute('height', height + margin.top + margin.bottom);
                svgElement('title', {}, chart, 'Presentations by year. Focus a bar for its counts and presentation types.');
                for (var tick = 0; tick <= scale.maximum; tick += scale.step) {
                    svgElement('line', {x1: margin.left, x2: chartWidth - margin.right, y1: y(tick), y2: y(tick),
                        'class': tick === 0 ? 'fonda-presentation-baseline' : 'fonda-presentation-grid'}, chart);
                    svgElement('text', {x: margin.left - 8, y: y(tick), dy: '.32em', 'text-anchor': 'end'}, chart, String(tick));
                }
                var slotWidth = width / annual.rows.length;
                annual.rows.forEach(function (row, index) {
                    var barWidth = Math.min(52, slotWidth * 0.62);
                    var x = margin.left + slotWidth * (index + 0.5) - barWidth / 2;
                    var description = presentationDescription(row, annual.types);
                    var bar = svgElement('g', {'class': 'fonda-presentation-year', tabindex: 0, role: 'group',
                        'aria-label': description, 'data-year': row.year, 'data-total': row.total}, chart);
                    svgElement('title', {}, bar, description);
                    svgElement('rect', {x: x, y: margin.top, width: barWidth, height: height,
                        fill: 'transparent', 'class': 'fonda-presentation-hit'}, bar);
                    var previous = 0;
                    annual.types.forEach(function (type) {
                        var count = row.types[type] || 0;
                        if (count) {
                            svgElement('rect', {x: x, y: y(previous + count), width: barWidth,
                                height: Math.max(0, y(previous) - y(previous + count) - 1), rx: 3,
                                'class': 'fonda-presentation-segment ' + colorClass(type), 'data-format': type}, bar);
                        }
                        previous += count;
                    });
                    svgElement('text', {x: x + barWidth / 2, y: margin.top + height + 24, 'text-anchor': 'middle'}, chart, String(row.year));
                    function showDetail() { detail.textContent = description; }
                    function resetDetail() {
                        var focused = chart.querySelector('.fonda-presentation-year:focus');
                        detail.textContent = focused ? focused.getAttribute('aria-label') : defaultDetail;
                    }
                    bar.addEventListener('mouseenter', showDetail);
                    bar.addEventListener('focus', showDetail);
                    bar.addEventListener('mouseleave', resetDetail);
                    bar.addEventListener('blur', resetDetail);
                });
                detail.textContent = defaultDetail;
            }
            renderPresentationsChart();
            if (window.ResizeObserver) {
                new ResizeObserver(renderPresentationsChart).observe(panel.querySelector('.fonda-presentations-scroll'));
            } else {
                window.addEventListener('resize', renderPresentationsChart);
            }
            $('#fonda-view-presentations').on('click', function (event) {
                var list = document.getElementById('RO_0000053-PresenterRole-List');
                var pane = list && list.closest('.tab-pane');
                var tabs = document.querySelectorAll('#property-tabs li[data-toggle="tab"]');
                var tab = null;
                if (pane) {
                    for (var i = 0; i < tabs.length; i++) {
                        if (tabs[i].getAttribute('href') === '#' + pane.id) { tab = tabs[i]; break; }
                    }
                }
                if (!tab) { return; }
                event.preventDefault();
                $(tab).trigger('click');
                var heading = list.closest('article').querySelector('h3');
                heading.setAttribute('tabindex', '-1');
                heading.focus();
            });
        });
    </script>
</#if>
