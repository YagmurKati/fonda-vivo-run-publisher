<#-- $This file is distributed under the terms of the license in /doc/license.txt$ -->

<#-- Template for sparkline visualization on individual profile page -->

<#-- Determine whether this person is an author -->
<#assign isAuthor = p.hasVisualizationStatements(propertyGroups, "${core}relatedBy", "${core}Authorship") />

<#-- Determine whether this person is involved in any grants -->
<#assign obo_RO53 = "http://purl.obolibrary.org/obo/RO_0000053">

<#assign isInvestigator = ( p.hasVisualizationStatements(propertyGroups, "${obo_RO53}", "${core}InvestigatorRole") ||
                            p.hasVisualizationStatements(propertyGroups, "${obo_RO53}", "${core}PrincipalInvestigatorRole") ||
                            p.hasVisualizationStatements(propertyGroups, "${obo_RO53}", "${core}CoPrincipalInvestigatorRole") ) >

<#if (isAuthor || isInvestigator)>

    ${stylesheets.add('<link rel="stylesheet" href="${urls.base}/css/visualization/visualization.css" />')}
    <#assign standardVisualizationURLRoot ="/visualization">

        <#if isAuthor>
            ${scripts.add('<script type="text/javascript" src="${urls.base}/js/d3.min.js"></script>')}

            <#assign coAuthorIcon = "${urls.images}/visualization/coauthorship/co_author_icon.png">
            <#assign coAuthorVisUrl = individual.coAuthorVisUrl()>

            <#if mapOfScienceVisualizationEnabled>
                <#assign mapOfScienceIcon = "${urls.images}/visualization/mapofscience/scimap_icon.png">
                <#assign mapOfScienceVisUrl = individual.mapOfScienceUrl()>
            </#if>

            <style>
                .fonda-publications-panel { box-sizing: border-box; width: 100%; margin: 0 0 20px; padding: 16px; border: 1px solid #e2e9ef; border-radius: 12px; background: #fafcfd; }
                .fonda-publications-panel #publicationsHeading { display: block; margin: 0; color: #23395d; font-size: 15px; font-weight: 600; line-height: 1.4; }
                .fonda-publications-caption { margin: 4px 0 14px; color: #647487; font-size: 12px; line-height: 1.5; }
                .fonda-publications-legend { display: flex; flex-wrap: wrap; gap: 8px 16px; margin: 0 0 8px; font-size: 12px; color: #526476; }
                .fonda-publications-legend > span { display: inline-flex; align-items: center; gap: 6px; }
                .fonda-publications-legend span { color: inherit !important; }
                .fonda-publications-legend i { width: 9px; height: 9px; display: inline-block; border-radius: 3px; }
                .fonda-series-JournalArticles { fill: #286a91; background: #286a91; }
                .fonda-series-ConferencePapers { fill: #7375bd; background: #7375bd; }
                .fonda-series-Preprints { fill: #b65b6b; background: #b65b6b; }
                .fonda-series-Books { fill: #ba8740; background: #ba8740; }
                .fonda-series-Other { fill: #52a9b8; background: #52a9b8; }
                .fonda-publications-scroll { overflow-x: auto; width: 100%; }
                .fonda-publications-panel #publicationsChart { display: block; max-width: none; overflow: visible; font-family: inherit; }
                #publicationsChart .fonda-grid line { stroke: #dce6ee; stroke-dasharray: 3 4; }
                #publicationsChart .fonda-grid .domain, #publicationsChart .fonda-y-axis .domain { display: none; }
                #publicationsChart .tick text { fill: #647487; font-family: inherit; font-size: 11px; }
                #publicationsChart .fonda-x-axis .domain { stroke: #dce6ee; }
                #publicationsChart .fonda-year-bar { outline: none; }
                #publicationsChart .fonda-year-bar:hover rect.fonda-bar, #publicationsChart .fonda-year-bar:focus rect.fonda-bar { stroke: #23395d; stroke-width: 1.5px; }
                .fonda-publications-detail { min-height: 36px; margin: 6px 0 0; color: #526476; font-size: 12px; line-height: 1.5; }
                .fonda-publications-panel .visualization-buttons { text-align: left; border-top: 1px solid #dce6ee; margin-top: 8px; padding-top: 12px; }
                .fonda-publications-panel .collaboratorship-link-container { margin: 0 0 8px; }
                .fonda-publications-panel .collaboratorship-link-container:last-child { margin-bottom: 0; }
                .fonda-publications-panel .collaboratorship-link-container a.btn { display: flex; align-items: center; justify-content: center; gap: 8px; width: 100%; min-width: 0; padding: 9px 10px; border: 1px solid #d2dfe9; border-radius: 7px; background: #fff; box-shadow: none; text-shadow: none; color: #23395d; font-size: 13px; }
                .fonda-publications-panel .collaboratorship-link-container a.btn:hover { background: #eaf2f7; }
                html.dark-mode .fonda-publications-panel { background: #151f2d; border-color: #2b3b50; }
                html.dark-mode .fonda-publications-panel #publicationsHeading { color: #e4edf6; }
                html.dark-mode .fonda-publications-caption, html.dark-mode .fonda-publications-legend, html.dark-mode .fonda-publications-detail { color: #a8b9cb; }
                html.dark-mode .fonda-series-JournalArticles { fill: #76b1de; background: #76b1de; }
                html.dark-mode .fonda-series-ConferencePapers { fill: #b2a7ec; background: #b2a7ec; }
                html.dark-mode .fonda-series-Preprints { fill: #e99aab; background: #e99aab; }
                html.dark-mode .fonda-series-Books { fill: #dfb671; background: #dfb671; }
                html.dark-mode .fonda-series-Other { fill: #55c1c3; background: #55c1c3; }
                html.dark-mode #publicationsChart .fonda-grid line, html.dark-mode #publicationsChart .fonda-x-axis .domain { stroke: #33445b; }
                html.dark-mode #publicationsChart .fonda-year-bar:hover rect.fonda-bar, html.dark-mode #publicationsChart .fonda-year-bar:focus rect.fonda-bar { stroke: #e4edf6; }
                html.dark-mode .fonda-publications-panel .visualization-buttons { border-color: #2b3b50; }
                html.dark-mode .fonda-publications-panel .collaboratorship-link-container a.btn { background: #1c2a3c; border-color: #33445b; color: #e4edf6; }
                html.dark-mode .fonda-publications-panel .collaboratorship-link-container a.btn:hover { background: #25364b; }
            </style>
            <section class="fonda-publications-panel" aria-labelledby="publicationsHeading">
                <span id="publicationsHeading">Publications in FONDA</span>
                <p class="fonda-publications-caption">Publications by year</p>
                <div class="fonda-publications-legend" aria-label="Publication types"></div>
                <div class="fonda-publications-scroll">
                    <svg id="publicationsChart" role="img" aria-label="Publications by year"></svg>
                </div>
                <p class="fonda-publications-detail" aria-live="polite"></p>
            <script>
                $(document).ready(function () {
                    var panel = document.querySelector('.fonda-publications-panel');
                    var chart = panel.querySelector('#publicationsChart');
                    var detail = panel.querySelector('.fonda-publications-detail');
                    var rawData, keys, defaultDetail;
                    var dataUrl = '${urls.base}/visualizationAjax?vis=cumulative_pub_count&publication_categories=fonda&uri=${individual.uri?url}';
                    var categoryLabels = {
                        JournalArticles: 'Journal articles',
                        ConferencePapers: 'Conference papers',
                        Preprints: 'Preprints',
                        Books: 'Books and chapters',
                        Other: 'Other outputs'
                    };
                    var categorySingular = {
                        JournalArticles: 'journal article',
                        ConferencePapers: 'conference paper',
                        Preprints: 'preprint',
                        Books: 'book or chapter',
                        Other: 'other output'
                    };

                    function separatePreprints(row) {
                        // The existing endpoint includes precise type counts in OtherDetails.
                        // Move preprints into a dedicated series, retaining the yearly total
                        // and all remaining software, dataset and other output descriptions.
                        if (Object.prototype.hasOwnProperty.call(row, 'Preprints')) return row;
                        var preprints = 0, remaining = [];
                        (row.OtherDetails || '').split(/\s*·\s*/).forEach(function (part) {
                            var match = part.trim().match(/^(\d+)\s+preprints?$/i);
                            if (match) preprints += +match[1];
                            else if (part.trim()) remaining.push(part.trim());
                        });
                        var other = Math.max(0, +row.Other || 0);
                        row.Preprints = Math.min(other, preprints);
                        row.Other = other - row.Preprints;
                        row.OtherDetails = remaining.join(' · ');
                        return row;
                    }

                    function annualRows(data, types) {
                        // Each type is already a yearly count. "Previous" is the carry-over.
                        return data.map(function (row) {
                            var result = {Year: row.Year, total: 0, otherDetails: row.OtherDetails || ''};
                            types.forEach(function (key) {
                                result[key] = Math.max(0, +row[key] || 0);
                                result.total += result[key];
                            });
                            return result;
                        });
                    }

                    function renderPublicationsChart() {
                        if (!rawData) return;
                        var annual = annualRows(rawData, keys);
                        var first = 0;
                        while (first < annual.length - 1 && annual[first].total === 0) first++;
                        annual = annual.slice(first);
                        var available = panel.querySelector('.fonda-publications-scroll').clientWidth;
                        if (!available) return;
                        var chartWidth = Math.max(available, annual.length * 34 + 42);
                        var margin = {top: 12, right: 10, bottom: 32, left: 30};
                        var width = chartWidth - margin.left - margin.right, height = 132;
                        var svg = d3.select(chart);
                        svg.selectAll('*').remove();
                        svg.attr('width', chartWidth).attr('height', height + margin.top + margin.bottom);
                        svg.append('title').text('Publications by year. Focus a bar for its publication details.');
                        var g = svg.append('g').attr('transform', 'translate(' + margin.left + ',' + margin.top + ')');
                        var x = d3.scaleBand().domain(annual.map(function (d) { return d.Year; }))
                            .range([0, width]).padding(0.38);
                        var max = d3.max(annual, function (d) { return d.total; }) || 1;
                        var y = d3.scaleLinear().domain([0, max]).range([height, 0]).nice();
                        var ticks = y.ticks(4).filter(function (value) { return value % 1 === 0; });
                        g.append('g').attr('class', 'fonda-grid').call(d3.axisLeft(y).tickValues(ticks).tickSize(-width).tickFormat(''));
                        g.append('g').attr('class', 'fonda-y-axis').call(d3.axisLeft(y).tickValues(ticks).tickFormat(d3.format('d')).tickSize(0).tickPadding(8));
                        g.append('g').attr('class', 'fonda-x-axis').attr('transform', 'translate(0,' + height + ')')
                            .call(d3.axisBottom(x).tickSize(0).tickPadding(12));
                        annual.forEach(function (row) {
                            var barWidth = Math.min(52, x.bandwidth());
                            var barX = x(row.Year) + (x.bandwidth() - barWidth) / 2;
                            var breakdown = keys.filter(function (key) { return row[key] > 0; })
                                .map(function (key) { return row[key] + ' ' + (row[key] === 1 ? categorySingular[key] : categoryLabels[key].toLowerCase()) + (key === 'Other' && row.otherDetails ? ' (' + row.otherDetails + ')' : ''); }).join(' · ');
                            var description = row.Year + ' · ' + row.total + ' publication' + (row.total === 1 ? '' : 's')
                                + (breakdown ? ' · ' + breakdown : '');
                            var bar = g.append('g').attr('class', 'fonda-year-bar').attr('tabindex', 0)
                                .attr('role', 'group').attr('aria-label', description)
                                .attr('data-year', row.Year).attr('data-total', row.total);
                            bar.append('title').text(description);
                            bar.append('rect').attr('x', x(row.Year)).attr('y', -20)
                                .attr('width', x.bandwidth()).attr('height', height + 20).attr('fill', 'transparent');
                            var previous = 0;
                            keys.forEach(function (key) {
                                if (row[key] > 0) {
                                    var segment = bar.append('rect').attr('class', 'fonda-bar fonda-series-' + key)
                                        .attr('x', barX).attr('y', y(previous + row[key]))
                                        .attr('width', barWidth).attr('height', Math.max(0, y(previous) - y(previous + row[key]) - 1))
                                        .attr('rx', 3);
                                    if (key === 'Other' || key === 'Preprints') {
                                        var segmentDescription = row.Year + ' · ' + row[key] + ' '
                                            + (row[key] === 1 ? categorySingular[key] : categoryLabels[key].toLowerCase())
                                            + (key === 'Other' && row.otherDetails ? ' · ' + row.otherDetails : '');
                                        segment.attr('tabindex', 0).attr('role', 'img').attr('aria-label', segmentDescription);
                                        segment.append('title').text(segmentDescription.replace(/ · /g, '\n'));
                                        segment.on('mouseenter', function () { detail.textContent = segmentDescription; })
                                            .on('focus', function () { detail.textContent = segmentDescription; })
                                            .on('mouseleave', function () {
                                                var target = d3.event.relatedTarget;
                                                detail.textContent = target && this.parentNode.contains(target) ? description : defaultDetail;
                                            })
                                            .on('blur', function () { detail.textContent = defaultDetail; });
                                    }
                                }
                                previous += row[key];
                            });
                            bar.on('mouseenter', function () { detail.textContent = description; })
                                .on('focus', function () { detail.textContent = description; })
                                .on('mouseleave', function () { detail.textContent = defaultDetail; })
                                .on('blur', function () { detail.textContent = defaultDetail; });
                        });
                        detail.textContent = defaultDetail;
                    }

                    d3.csv(dataUrl, function (row, index, columns) {
                        columns.slice(1).forEach(function (key) { if (key !== 'OtherDetails') row[key] = +row[key] || 0; });
                        return separatePreprints(row);
                    }, function (error, data) {
                        if (error) {
                            detail.textContent = 'Publication counts are currently unavailable.';
                            return;
                        }
                        rawData = data;
                        keys = ['JournalArticles', 'ConferencePapers', 'Preprints', 'Books', 'Other'].filter(function (key) {
                            return data.some(function (row) { return row[key] > 0; });
                        });
                        var legend = d3.select(panel.querySelector('.fonda-publications-legend'));
                        keys.forEach(function (key) {
                            var item = legend.append('span');
                            item.append('i').attr('class', 'fonda-series-' + key).attr('aria-hidden', 'true');
                            item.append('span').text(categoryLabels[key]);
                        });
                        defaultDetail = 'Yearly counts · hover or focus a bar for details';
                        if (data.length && data[0].Previous > 0) {
                            panel.querySelector('.fonda-publications-caption').textContent = 'Publications by year · recent years shown';
                        }
                        renderPublicationsChart();
                        if (window.ResizeObserver) {
                            new ResizeObserver(renderPublicationsChart).observe(panel.querySelector('.fonda-publications-scroll'));
                        } else {
                            window.addEventListener('resize', renderPublicationsChart);
                        }
                    });
                });
            </script>

            <div class="visualization-buttons">
                <div id="coauthorship_link_container" class="collaboratorship-link-container">
                    <a href="${coAuthorVisUrl}" title="Co-authors with profiles and linked publications in FONDA VIVO" class="btn btn-info" role="button">
                        <img src="${coAuthorIcon}" alt="${i18n().co_author}" width="25px" height="25px" />
                        FONDA co-author network
                    </a>
                </div>

                <#if mapOfScienceVisualizationEnabled>
                    <div id="mapofscience_link_container" class="collaboratorship-link-container">
                        <a href="${mapOfScienceVisUrl}" title="${i18n().map_of_science}" class="btn btn-info" role="button">
                            <img src="${mapOfScienceIcon}" alt="${i18n().map_of_science}" width="25px" height="25px" />
                            ${i18n().map_of_science_capitalized}
                        </a>
                    </div>
                </#if>

                <#if isInvestigator>
                    <#assign coInvestigatorVisUrl = individual.coInvestigatorVisUrl()>
                    <#assign coInvestigatorIcon = "${urls.images}/visualization/coauthorship/co_investigator_icon.png">

                    <div id="coinvestigator_link_container" class="collaboratorship-link-container">
                        <a href="${coInvestigatorVisUrl}" title="${i18n().co_investigator_network}" class="btn btn-info" role="button">
                            <img src="${coInvestigatorIcon}" alt="${i18n().co_investigator_network}" width="25px" height="25px" />
                        ${i18n().co_investigator_network_capitalized}
                        </a>
                    </div>
                </#if>
            </div>
            </section>
        </#if>
</#if>
