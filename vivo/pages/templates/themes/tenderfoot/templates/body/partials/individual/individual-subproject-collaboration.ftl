<#-- $This file is distributed under the terms of the license in LICENSE$ -->
<#--
  FONDA 2026-09-29: "Collaboration with other subprojects" chord on fonda:Subproject pages.
  Data:     subprojectCollabRows, from display:fondaSubprojectCollabDataGetter
            (/opt/vivo/vivo/rdf/display/everytime/fonda-subproject-collaboration.n3),
            one row per (publication of this subproject, subproject of that publication).
  Included: by individual--fonda-subproject.ftl, the custom display view of fonda:Subproject.
            The script moves the section to the end of the Overview tab (#overviewGroup),
            or below the page header when a subproject has no Overview tab.
  v2 2026-09-29: smaller chart drawn at 1:1 (larger labels), text colours set explicitly
            (a third-party stylesheet greyed out plain <div> text in dark mode), placed after Overview.
  A pair of subprojects is linked by the publications of THIS subproject that are tagged
  (vivo:hasSubjectArea) with both. Publications tagged with more than 8 subprojects
  (e.g. the FONDA overview paper) are consortium-wide and left out unless the viewer opts in.
-->
<#if subprojectCollabRows?? && subprojectCollabRows?has_content>
<section id="subproject-collaboration" class="subproject-collaboration" aria-labelledby="sp-collab-heading">
    <h2 id="sp-collab-heading">Collaboration with other subprojects</h2>
    <p class="sp-collab-note">Joint publications of this subproject with other FONDA subprojects.
       Hover over a subproject or a band for details, click a subproject to open its page.</p>
    <div class="sp-collab-legend" aria-hidden="true"></div>
    <div class="sp-collab-wide"></div>
    <div class="sp-chord"></div>
    <div class="sp-collab-table-wrap"></div>
    <div class="sp-collab-tip" role="tooltip" hidden></div>
</section>

<style>
#subproject-collaboration { --sp-a: #2a78d6; --sp-b: #eb6834; --sp-c: #1baf7a; --sp-x: #7a7974;
    --sp-line: #e3e7ec; --sp-muted: #5e6363; color: #595b5b; clear: both; margin: 1.5em 0 2em; }
html.dark-mode #subproject-collaboration { --sp-a: #3987e5; --sp-b: #d95926; --sp-c: #199e70; --sp-x: #9a9993;
    --sp-line: #273349; --sp-muted: #9aa7b8; color: #d5dde7; }
#subproject-collaboration :not(a) { color: inherit; }
#subproject-collaboration h2 { margin-top: 0; }
#subproject-collaboration .sp-collab-note { color: var(--sp-muted); margin: .25em 0 .75em; }
#subproject-collaboration .sp-collab-legend { display: flex; flex-wrap: wrap; gap: .4em 1.4em; font-size: 13px; margin-bottom: .5em; }
#subproject-collaboration .sp-collab-legend span { display: inline-flex; align-items: center; gap: .45em; }
#subproject-collaboration .sp-collab-legend i { width: 12px; height: 12px; border-radius: 3px; display: inline-block; }
#subproject-collaboration .sp-collab-wide { font-size: 13px; color: var(--sp-muted); margin-bottom: .5em; }
#subproject-collaboration .sp-collab-wide label { cursor: pointer; }
#subproject-collaboration .sp-chord svg { display: block; margin: 0 auto; overflow: visible; }
#subproject-collaboration .sp-chord text { fill: currentColor; font-size: 15px; font-weight: 600; cursor: pointer; }
#subproject-collaboration .sp-chord text.ego { font-weight: 700; font-size: 17px; }
#subproject-collaboration .sp-chord .grp { cursor: pointer; }
#subproject-collaboration .sp-chord .grp.ego { stroke: currentColor; stroke-width: 1.5px; cursor: default; }
#subproject-collaboration .sp-chord .ribbon { fill-opacity: .7; stroke: none; transition: fill-opacity .15s; }
#subproject-collaboration .sp-chord .ribbon.faded { fill-opacity: .07; }
#subproject-collaboration .area-a { fill: var(--sp-a); background: var(--sp-a); }
#subproject-collaboration .area-b { fill: var(--sp-b); background: var(--sp-b); }
#subproject-collaboration .area-c { fill: var(--sp-c); background: var(--sp-c); }
#subproject-collaboration .area-x { fill: var(--sp-x); background: var(--sp-x); }
#subproject-collaboration .sp-collab-tip { position: fixed; z-index: 1000; pointer-events: none; max-width: 340px;
    padding: 6px 9px; border-radius: 4px; font-size: 13px; line-height: 1.35;
    background: #ffffff; color: #222222; border: 1px solid #cfd6de; box-shadow: 0 2px 8px rgba(0,0,0,.15); }
html.dark-mode #subproject-collaboration .sp-collab-tip { background: #151d2b; color: #d5dde7; border-color: #273349; }
#subproject-collaboration table { border-collapse: collapse; width: 100%; max-width: 820px; margin-top: 1em; font-size: 14px; }
#subproject-collaboration caption { text-align: left; font-weight: 600; padding-bottom: .4em; }
#subproject-collaboration th, #subproject-collaboration td { text-align: left; vertical-align: top;
    padding: 5px 8px; border-bottom: 1px solid var(--sp-line); }
#subproject-collaboration td.code { white-space: nowrap; width: 4.5em; }
#subproject-collaboration td.code i { width: 10px; height: 10px; border-radius: 2px; display: inline-block; margin-right: .4em; }
#subproject-collaboration th.n, #subproject-collaboration td.n { text-align: right; width: 9em; }
#subproject-collaboration th.n { white-space: nowrap; }
#subproject-collaboration details summary { cursor: pointer; }
#subproject-collaboration details ul { text-align: left; margin: .4em 0 .2em 1.2em; padding: 0; font-size: 13px; }
</style>

<script src="${urls.base}/js/d3.min.js"></script>
<script>
(function () {
    var MAX_SUBPROJECTS = 8;   // a publication tagged with more subprojects counts as consortium-wide

    function esc(s) {
        return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }
    function codeOf(label, uri) {
        var m = /^\s*([A-Z]\d+)\s*:/.exec(label || '') || /Subproject\s+([A-Z]\d+)/i.exec(label || '')
             || /subproject-([A-Z]\d+)/i.exec(uri) || /fonda-group-([a-z]\d+)-/i.exec(uri);
        return m ? m[1].toUpperCase() : (label || uri);
    }
    function nameOf(label) { return String(label || '').replace(/^\s*[A-Z]\d+\s*:\s*/, ''); }
    // one colour per subproject, fixed by its code on every page: the area letter gives the hue
    // (A blue, B orange, C green, S/other grey), the number gives the shade (1 = darkest)
    function colorOf(code) {
        var fam = { A: [214, 70], B: [19, 80], C: [158, 62] }[code.charAt(0)] || [40, 6];
        var d = parseInt(code.slice(1), 10); d = isFinite(d) ? Math.max(1, Math.min(8, d)) : 4;
        var dark = document.documentElement.classList.contains('dark-mode');
        var grey = fam[1] < 10, step = grey ? 22 : 7.5;          // S projects: few, so bigger steps
        var l = (dark ? 38 : 26) + (d - 1) * (dark ? step * 0.8 : step);
        var h = fam[0] + (grey ? 0 : (d - 4) * 6);               // small hue shift keeps neighbours apart
        return 'hsl(' + h + ',' + fam[1] + '%,' + Math.min(l, 80) + '%)';
    }
    function areaOf(code) { var l = code.charAt(0); return (l === 'A' || l === 'B' || l === 'C') ? l.toLowerCase() : 'x'; }
    function plural(n, one, many) { return n + ' ' + (n === 1 ? one : many); }

    window.fondaSubprojectCollab = function (root, egoUri, base, rows) {
        if (!root || typeof d3 === 'undefined' || !d3.chord) { return; }
        var link = function (uri) { return base + '/individual?uri=' + encodeURIComponent(uri); };

        // ---- publications of this subproject, with the subprojects each one is tagged with
        var pubs = {}, spLabel = {};
        rows.forEach(function (r) {
            var p = pubs[r.p] || (pubs[r.p] = { uri: r.p, title: '', sps: {} });
            if (r.pl && !p.title) { p.title = r.pl; }
            p.sps[r.s] = true;
            if (r.sl && !spLabel[r.s]) { spLabel[r.s] = r.sl; }
        });
        var pubList = Object.keys(pubs).map(function (u) {
            var p = pubs[u]; p.sps = Object.keys(p.sps); p.title = p.title || u; return p;
        });
        var sp = {};   // uri -> {uri, code, name, area}
        var spInfo = function (u) {
            if (!sp[u]) { var c = codeOf(spLabel[u], u); sp[u] = { uri: u, code: c, name: nameOf(spLabel[u]) || c, area: areaOf(c) }; }
            return sp[u];
        };
        spInfo(egoUri);
        var wide = pubList.filter(function (p) { return p.sps.length > MAX_SUBPROJECTS; });

        var legend = root.querySelector('.sp-collab-legend');
        var wideBox = root.querySelector('.sp-collab-wide');
        var chordBox = root.querySelector('.sp-chord');
        var tableBox = root.querySelector('.sp-collab-table-wrap');
        var tip = root.querySelector('.sp-collab-tip');

        function showTip(html) {
            tip.innerHTML = html; tip.hidden = false;
            var e = d3.event, w = tip.offsetWidth, h = tip.offsetHeight;
            var x = e.clientX + 14, y = e.clientY + 14;
            if (x + w > window.innerWidth - 8) { x = e.clientX - w - 14; }
            if (y + h > window.innerHeight - 8) { y = e.clientY - h - 14; }
            tip.style.left = x + 'px'; tip.style.top = y + 'px';
        }
        function hideTip() { tip.hidden = true; }

        function render(includeWide) {
            chordBox.innerHTML = ''; tableBox.innerHTML = ''; legend.innerHTML = ''; hideTip();

            // ---- pairs: subproject pair -> joint publications (all include this subproject)
            var used = pubList.filter(function (p) { return p.sps.length > 1 && (includeWide || p.sps.length <= MAX_SUBPROJECTS); });
            var pair = {}, inNet = {};
            inNet[egoUri] = true;
            used.forEach(function (p) {
                var s = p.sps.slice().sort();
                s.forEach(function (u) { inNet[u] = true; spInfo(u); });
                for (var i = 0; i < s.length; i++) {
                    for (var j = i + 1; j < s.length; j++) {
                        var k = s[i] + '\n' + s[j];
                        (pair[k] = pair[k] || []).push(p);
                    }
                }
            });
            var pairPubs = function (a, b) { return pair[a < b ? a + '\n' + b : b + '\n' + a] || []; };

            // ---- nodes: this subproject on top, then the others in code order, continuing after it
            var codes = Object.keys(inNet).map(function (u) { return sp[u]; })
                .sort(function (x, y) { return x.code.localeCompare(y.code, 'en', { numeric: true }); });
            var at = 0;
            codes.forEach(function (n, i) { if (n.uri === egoUri) { at = i; } });
            var nodes = codes.slice(at).concat(codes.slice(0, at));
            if (nodes.length < 2) {
                chordBox.innerHTML = '<p class="sp-collab-note">No joint publications with other subprojects yet.</p>';
                return;
            }
            var n = nodes.length, matrix = [];
            for (var i = 0; i < n; i++) {
                matrix.push([]);
                for (var j = 0; j < n; j++) { matrix[i].push(i === j ? 0 : pairPubs(nodes[i].uri, nodes[j].uri).length); }
            }

            // ---- legend: one entry per subproject on screen, in code order
            legend.innerHTML = nodes.slice().sort(function (x, y) { return x.code.localeCompare(y.code, 'en', { numeric: true }); })
                .map(function (d) {
                    return '<span title="' + esc(d.name) + '"><i style="background:' + colorOf(d.code) + '"></i>' + esc(d.code) + '</span>';
                }).join('');

            // ---- chord
            var size = Math.max(300, Math.min(chordBox.clientWidth || 440, 440));
            var outer = size / 2 - 40, inner = outer - 12;
            var chords = d3.chord().padAngle(0.04).sortSubgroups(d3.descending)(matrix);
            var svg = d3.select(chordBox).append('svg')
                .attr('viewBox', (-size / 2) + ' ' + (-size / 2) + ' ' + size + ' ' + size)
                .attr('width', size).attr('height', size)
                .attr('role', 'img')
                .attr('aria-label', 'Joint publications of ' + nodes[0].code + ' with ' + plural(n - 1, 'other subproject', 'other subprojects'));

            var ribbons = svg.append('g').selectAll('path').data(chords).enter().append('path')
                .attr('class', function (c) {
                    var k = c.source.index === 0 ? c.target.index : c.source.index;
                    return 'ribbon area-' + nodes[k].area;
                })
                .style('fill', function (c) { return colorOf(nodes[c.source.index === 0 ? c.target.index : c.source.index].code); })
                .attr('d', d3.ribbon().radius(inner))
                .on('mousemove', function (c) {
                    var a = nodes[c.source.index], b = nodes[c.target.index];
                    var cnt = pairPubs(a.uri, b.uri).length;
                    var extra = (c.source.index === 0 || c.target.index === 0) ? '' : ' (together with ' + esc(nodes[0].code) + ')';
                    showTip('<b>' + esc(a.code) + ' &amp; ' + esc(b.code) + '</b><br>' + plural(cnt, 'joint publication', 'joint publications') + extra);
                })
                .on('mouseout', hideTip);

            function focus(idx) {
                ribbons.classed('faded', function (c) { return idx !== null && c.source.index !== idx && c.target.index !== idx; });
            }

            var groups = svg.append('g').selectAll('g').data(chords.groups).enter().append('g');
            groups.append('path')
                .attr('class', function (g) { return 'grp area-' + nodes[g.index].area + (g.index === 0 ? ' ego' : ''); })
                .style('fill', function (g) { return colorOf(nodes[g.index].code); })
                .attr('d', d3.arc().innerRadius(inner).outerRadius(outer));
            groups.append('text')
                .attr('class', function (g) { return g.index === 0 ? 'ego' : null; })
                .attr('dy', '.35em')
                .attr('text-anchor', function (g) { return (g.startAngle + g.endAngle) / 2 > Math.PI ? 'end' : null; })
                .attr('transform', function (g) {
                    var a = (g.startAngle + g.endAngle) / 2;
                    return 'rotate(' + (a * 180 / Math.PI - 90) + ')translate(' + (outer + 7) + ')' + (a > Math.PI ? 'rotate(180)' : '');
                })
                .text(function (g) { return nodes[g.index].code; });
            groups
                .on('mousemove', function (g) {
                    focus(g.index);
                    var d = nodes[g.index];
                    var msg = '<b>' + esc(d.code) + '</b> ' + esc(d.name) + '<br>';
                    if (g.index === 0) {
                        var partners = nodes.length - 1;
                        msg += 'Joint publications with ' + plural(partners, 'other subproject', 'other subprojects');
                    } else {
                        msg += plural(matrix[0][g.index], 'joint publication', 'joint publications') + ' with ' + esc(nodes[0].code);
                    }
                    showTip(msg);
                })
                .on('mouseout', function () { focus(null); hideTip(); })
                .on('click', function (g) { if (g.index > 0) { window.location.href = link(nodes[g.index].uri); } });

            // ---- table view: every partner, with the joint publications behind the number
            var partnerRows = nodes.slice(1).map(function (d, i) { return { d: d, pubs: pairPubs(nodes[0].uri, d.uri) }; })
                .filter(function (r) { return r.pubs.length > 0; })
                .sort(function (x, y) { return y.pubs.length - x.pubs.length || x.d.code.localeCompare(y.d.code, 'en', { numeric: true }); });
            var html = '<table><caption>Joint publications of ' + esc(nodes[0].code) + ' by subproject</caption>'
                + '<thead><tr><th>Subproject</th><th></th><th class="n">Joint publications</th></tr></thead><tbody>';
            partnerRows.forEach(function (r) {
                var list = r.pubs.slice().sort(function (x, y) { return x.title.localeCompare(y.title); }).map(function (p) {
                    return '<li><a href="' + esc(link(p.uri)) + '">' + esc(p.title) + '</a></li>';
                }).join('');
                html += '<tr><td class="code"><i style="background:' + colorOf(r.d.code) + '"></i>' + esc(r.d.code) + '</td>'
                    + '<td><a href="' + esc(link(r.d.uri)) + '">' + esc(r.d.name) + '</a></td>'
                    + '<td class="n"><details><summary>' + r.pubs.length + '</summary><ul>' + list + '</ul></details></td></tr>';
            });
            tableBox.innerHTML = html + '</tbody></table>';
        }

        if (wide.length) {
            wideBox.innerHTML = '<label><input type="checkbox"> Include FONDA-wide publications ('
                + wide.length + ', tagged with more than ' + MAX_SUBPROJECTS + ' subprojects: '
                + wide.map(function (p) { return '&ldquo;' + esc(p.title) + '&rdquo;'; }).join(', ') + ')</label>';
            wideBox.querySelector('input').addEventListener('change', function () { render(this.checked); });
        }

        // Show the section at the end of the Overview tab; without one, below the page header.
        var overview = document.getElementById('overviewGroup');
        var intro = document.getElementById('individual-intro');
        if (overview) {
            overview.appendChild(root);
        } else if (intro && intro.parentNode && intro.contains(root)) {
            intro.parentNode.insertBefore(root, intro.nextSibling);
        }
        render(false);
    };

    var start = function () {
        window.fondaSubprojectCollab(document.getElementById('subproject-collaboration'),
            "${individual.uri?js_string}", "${urls.base?js_string}", [
<#list subprojectCollabRows as r>
            {p: "${r.pub?js_string}", pl: "${(r.pubLabel!"")?js_string}", s: "${r.sp?js_string}", sl: "${(r.spLabel!"")?js_string}"}<#sep>,</#sep>
</#list>
        ]);
    };
    if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', start); } else { start(); }
})();
</script>
</#if>
