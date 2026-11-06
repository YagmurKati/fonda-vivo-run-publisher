<#-- $This file is distributed under the terms of the license in LICENSE$ -->

<#-- Template to setup and call scripts for menupages -->



<#list vClassGroup as vClass>
    <#if (vClass.entityCount > 0)>
        <#assign firstNonEmptyVClass = vClass.URI />
        <#break>
    </#if>
    <#-- test if we're at the last class. If we've gotten this far, none of the classes have any individuals -->
    <#if !vClass_has_next>
        <#assign firstNonEmptyVClass = "false">
    </#if>
</#list>

<script type="text/javascript">
    var firstBrowseClass = $("ul#browse-classes li:first").find("a").attr("data-uri");
    if ( !firstBrowseClass || firstBrowseClass.length == 0 ) {
        firstBrowseClass = '${firstNonEmptyVClass}';
    }
    var menupageData = {
        baseUrl: '${urls.base}',
        <#if internalClass?has_content>
            dataServiceUrl: '${dataServiceUrlIndividualsByVClass}${internalClass}&vclassId=',
        <#else>
            dataServiceUrl: '${dataServiceUrlIndividualsByVClass}',
        </#if>
        defaultBrowseVClassUri: firstBrowseClass //'${firstNonEmptyVClass}'
    };
    var i18nStrings = {
        pageString: '${i18n().page?js_string}',
        viewPageString: '${i18n().view_page?js_string}',
        ofTheResults: '${i18n().of_the_results?js_string}',
        thereAreNoEntriesStartingWith: '${i18n().there_are_no_entries_starting_with?js_string}',
        tryAnotherLetter: '${i18n().try_another_letter?js_string}',
        indsInSystem: '${i18n().individuals_in_system?js_string}',
        selectAnotherClass: '${i18n().select_another_class?js_string}'
    };
</script>




<#-- Script to enable browsing individuals within a class -->
${scripts.add('<script type="text/javascript" src="${urls.base}/js/jquery_plugins/jquery.scrollTo-min.js"></script>',
              '<script type="text/javascript" src="${urls.base}/js/menupage/browseByVClass.js"></script>')}

<#-- FONDA 2026-10-13: the "Sort" and "Year" boxes of the Publications page (fonda-publications-boxes.ftl), only
     on the browse page whose class box has the publication classes. Added at the end of VIVO's file; the lines
     above are unchanged. If the boxes fail, they are left out and the page is as before. -->
<#assign fondaPubsPage = false />
<#if vClassGroup??>
    <#list vClassGroup as fondaClass>
        <#if ["http://vivoweb.org/ontology/core#ConferencePaper", "https://fonda.hu-berlin.de/vocab#JournalArticle",
              "http://purl.org/ontology/bibo/AcademicArticle", "http://purl.org/ontology/bibo/Chapter"]?seq_contains(fondaClass.URI!"")>
            <#assign fondaPubsPage = true />
        </#if>
    </#list>
</#if>
<#if fondaPubsPage>
    <#attempt>
        <#include "fonda-publications-boxes.ftl">
    <#recover>
    </#attempt>
</#if>

<#-- FONDA 2026-11-02: application domains on the Workflows page (fonda-workflow-domains.ftl), only on the browse
     page whose class box has rm:Workflow. Placed before the look of all browse pages (which brings "Search this
     list"), so that the search box sees the workflows of the chosen domain. If it fails, the page is as before. -->
<#assign fondaWorkflowsPage = false />
<#if vClassGroup??>
    <#list vClassGroup as fondaClass>
        <#if (fondaClass.URI!"") == "http://example.org/ontology/run-metadata#Workflow">
            <#assign fondaWorkflowsPage = true />
        </#if>
    </#list>
</#if>
<#if fondaWorkflowsPage>
    <#attempt>
        <#include "fonda-workflow-domains.ftl">
    <#recover>
    </#attempt>
</#if>

<#-- FONDA 2026-11-03: the Traces page (fonda-traces-boxes.ftl), only on the browse page whose class box has
     rm:RunTrace or rm:TraceCollection. Placed before the look of all browse pages, like the Workflows block. -->
<#assign fondaTracesPage = false />
<#if vClassGroup??>
    <#list vClassGroup as fondaClass>
        <#if ["http://example.org/ontology/run-metadata#RunTrace", "http://example.org/ontology/run-metadata#TraceCollection"]?seq_contains(fondaClass.URI!"")>
            <#assign fondaTracesPage = true />
        </#if>
    </#list>
</#if>
<#if fondaTracesPage>
    <#attempt>
        <#include "fonda-traces-boxes.ftl">
    <#recover>
    </#attempt>
</#if>

<#-- FONDA 2026-10-15: one look for all browse pages (fonda-browse-look.ftl, styles only). Added at the end; the
     lines above are unchanged. If it fails, the pages look as before. -->
<#attempt>
    <#include "fonda-browse-look.ftl">
<#recover>
</#attempt>
