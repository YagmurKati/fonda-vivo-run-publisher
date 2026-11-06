<#-- $This file is distributed under the terms of the license in /doc/license.txt$ -->

<meta charset="utf-8" />


<meta name="description" content="FONDA VIVO, the research portal of FONDA at Humboldt-Universität zu Berlin: researchers, publications and projects on reproducible, sustainable and energy-efficient scientific data analysis workflows." />
<meta name="keywords" content="FONDA, VIVO, workflow, scientific workflows, sustainability, energy efficiency, data analysis, reproducibility, HU Berlin" />
<meta property="og:site_name" content="FONDA VIVO" />
<meta property="og:title" content="${(title?html)!siteName!}" />
<meta property="og:description" content="Researchers, publications and projects on reproducible, sustainable and energy-efficient data analysis workflows." />
<meta property="og:type" content="website" />




<meta http-equiv="X-UA-Compatible" content="IE=edge" />
<meta name="viewport" content="width=device-width, initial-scale=1">

<!-- Google Chrome Frame open source plug-in brings Google Chrome's open web technologies and speedy JavaScript engine to Internet Explorer-->
<!-- <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1"> -->

<title>${(title?html)!siteName!}</title>

<#-- VIVO OpenSocial Extension by UCSF -->
<#if openSocial??>
    <#if openSocial.visible>
        <#-- Required to add these BEFORE stylesheets.flt and headScripts.ftl are processed -->
        ${stylesheets.add('<link rel="stylesheet" href="${urls.theme}/css/openSocial/gadgets.css" />')}			
        ${headScripts.add('<script type="text/javascript" src="${openSocial.containerJavascriptSrc}"></script>',
                          '<script type="text/javascript" language="javascript">${openSocial.gadgetJavascript}</script>',
                          '<script type="text/javascript" src="${urls.base}/js/openSocial/orng.js"></script>')}
    </#if>	
</#if>	

<#include "stylesheets.ftl">
<#-- <link rel="stylesheet" href="${urls.theme}/css/screen.css" /> -->

<#include "headScripts.ftl">

<!--[if (gte IE 6)&(lte IE 8)]>
<script type="text/javascript" src="${urls.base}/js/selectivizr.js"></script>
<![endif]-->

<#-- Inject head content specified in the controller. Currently this is used only to generate an rdf link on 
an individual profile page. -->
${headContent!}

<link rel="shortcut icon" type="image/x-icon" href="${urls.base}/favicon.ico">
