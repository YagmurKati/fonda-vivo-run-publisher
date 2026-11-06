<#-- $This file is distributed under the terms of the license in /doc/license.txt$ -->

<#include "menupage-checkForData.ftl">

<#if !noData>
    <section id="menupage-intro" role="region">
        <h2>${page.title}</h2>
    </section>
    
    <#assign fondaIsRuns = false>
    <#list vClassGroup as fondaVc>
        <#if fondaVc.URI == "http://example.org/ontology/run-metadata#RunMetadata">
            <#assign fondaIsRuns = true>
        </#if>
    </#list>
    <#if fondaIsRuns && runsByStartDG?? && runsByStartDG?has_content>
        <#include "menupage-runs-chronological.ftl">
    <#else>
        <#include "menupage-browse.ftl">
        <#include "menupage-scripts.ftl">
    </#if>
<#else>
    ${noDataNotification}
</#if>
