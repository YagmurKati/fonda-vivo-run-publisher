<#-- $This file is distributed under the terms of the license in LICENSE$ -->
<#--
  FONDA 2026-10-15: one look for all browse pages (People, Subprojects, Organizations, Publications, Workflows,
  Runs, Infrastructure, Domains, Sources, ...). Included by menupage-scripts.ftl, which every browse page with a
  class box uses, so the rules below apply to those pages only.
    - The page heading and the class box start at one left edge (the edge of the coloured bar), with less empty
      space at the top. #menupage-intro gets the width of #browse-by (90%, centred), so both start at the same
      place; 25px = left margin of the class box (15px) + margin of its entries (10px). Font and size of the
      heading as before.
    - Tighter entries in the class box and in the boxes below it (Sort, Year, Cluster).
    - The heading above the list is a small label.
    - List entries closer together; the line under a name (title, type or year) closer to the name.
    - The chosen entry (class box, boxes, letter) in the dark teal of the site's headings instead of light blue,
      in light mode only; the green bar and arrow stay. Dark mode keeps its colours.
  Only styles; nothing else on the pages changes. To go back: restore menupage-scripts.ftl from its backup.
-->
<style>
    body #wrapper-content #menupage-intro { width: 90%; margin: 6px auto 0; }
    body #wrapper-content #menupage-intro h2 { margin: 0; padding: 0 0 8px 25px; }

    body #wrapper-content ul#browse-classes li,
    body #fonda-pubs-boxes .fpb-list li, body #fonda-runs-boxes .frb-list li { padding: 6px 0; }
    body #fonda-pubs-boxes .fpb-box, body #fonda-runs-boxes .frb-box { margin-bottom: 16px; }
    body #fonda-pubs-boxes .fpb-box:last-child, body #fonda-runs-boxes .frb-box:last-child { margin-bottom: 0; }
    body #fonda-pubs-boxes h3, body #fonda-runs-boxes h3 { padding: 6px 0 4px 10px; }

    body #wrapper-content h3.selected-class { font-size: 15px; font-weight: 600; }
    html:not(.dark-mode) body #wrapper-content h3.selected-class { color: #5e6363; }

    body #wrapper-content #individuals-in-class li.individual { padding: 8px 0; }
    body #wrapper-content #individuals-in-class li.individual span.title { display: block; margin: 2px 0 0; font-size: 13px; line-height: 1.4; }
    html:not(.dark-mode) body #wrapper-content #individuals-in-class li.individual span.title { color: #6b7785; }

    html:not(.dark-mode) body #wrapper-content ul#browse-classes a.selected, html:not(.dark-mode) body #wrapper-content ul#browse-classes a:hover,
    html:not(.dark-mode) body #fonda-pubs-boxes .fpb-list a.selected, html:not(.dark-mode) body #fonda-pubs-boxes .fpb-list a:hover,
    html:not(.dark-mode) body #fonda-runs-boxes .frb-list a.selected, html:not(.dark-mode) body #fonda-runs-boxes .frb-list a:hover,
    html:not(.dark-mode) body #fpb-sources-box .fpb-list a:hover,
    html:not(.dark-mode) body #wrapper-content ul#alpha-browse-individuals a.selected,
    html:not(.dark-mode) body #wrapper-content ul#alpha-browse-individuals a:hover { color: #064d68; }

    /* narrow window: the class box loses its left margin, so the common edge moves to 10px */
    @media (max-width: 1200px) {
        body #wrapper-content #menupage-intro h2 { padding-left: 10px; }
    }
</style>
<#-- FONDA 2026-10-15: the search box above the list of every browse page -->
<#attempt><#include "fonda-list-search.ftl"><#recover></#attempt>
<#-- FONDA 2026-10-16: Subprojects page - the Phase I subprojects at the end of the list (fonda-subprojects-phase.ftl) -->
<#attempt><#include "fonda-subprojects-phase.ftl"><#recover></#attempt>
