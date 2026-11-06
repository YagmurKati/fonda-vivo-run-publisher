<#-- $This file is distributed under the terms of the license in LICENSE$ -->
<#--
  FONDA 2026-10-04: the Runs page (/runs) in the layout of VIVO's other browse pages (People, Publications,
  Workflows): the class box on the left, the list on the right. It is VIVO's page-classgroup.ftl plus the
  "Sort" and "Cluster" boxes (fonda-runs-boxes.ftl).
  Used for the Runs page only: /opt/vivo/vivo/rdf/display/everytime/fondaRunsPageTemplate.n3 names this
  template as the body template of that page (http://vitro.mannlib.cornell.edu/ns/default#n5899). No other
  page uses it.
  If the boxes fail, they are left out and the page shows VIVO's own alphabetical list.
  Before 2026-10-04 this file held a page-specific list of the runs (newest first, without the class box);
  that version is kept next to this file as page-runs-chronological.ftl.bak-before-runs-boxes-<date-time>.
-->

<#include "menupage-checkForData.ftl">

<#if !noData>
    <section id="menupage-intro" role="region">
        <h2>${page.title}</h2>
    </section>

    <#include "menupage-browse.ftl">

    <#attempt>
        <#include "fonda-runs-boxes.ftl">
    <#recover>
    </#attempt>

    ${stylesheets.add('<link rel="stylesheet" href="${urls.base}/css/menupage/menupage.css" />')}

    <#include "menupage-scripts.ftl">
<#else>
    ${noDataNotification}
</#if>
