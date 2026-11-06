<#-- $This file is distributed under the terms of the license in LICENSE$ -->

<meta charset="utf-8" />




<#-- FONDA 2026-10-15: description for search engines and shared links (full name of FONDA, no university) -->
<meta name="description" content="Research portal of FONDA (Foundations of Workflows for Large-Scale Scientific Data Analysis, DFG CRC 1404): people, publications, workflows and their energy use." />


<meta name="google-site-verification" content="ugc_wUpDJ5pg6yaktZwWD2dq4jekj82aPY3fugcx2eY" />


<meta name="keywords" content="FONDA, VIVO, workflow, scientific workflows, sustainability, energy efficiency, data analysis, reproducibility, HU Berlin" />
<meta property="og:site_name" content="FONDA VIVO" />
<meta property="og:title" content="${(title?html)!siteName!}" />
<meta property="og:description" content="Research portal of FONDA (Foundations of Workflows for Large-Scale Scientific Data Analysis, DFG CRC 1404): people, publications, workflows and their energy use." />
<meta property="og:type" content="website" />







<meta name="viewport" content="width=device-width, initial-scale=1">
<!-- Google Chrome Frame open source plug-in brings Google Chrome's open web technologies and speedy JavaScript engine to Internet Explorer-->
<meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
<meta name="generator" content="VIVO ${version.label}" />

<#-- FONDA 2026-10-15: browser tab = "<page name> · FONDA"; the home page (title = site name) shows the full name of FONDA -->
<#assign fondaPageTitle = (title?html)!siteName!>
<title><#if fondaPageTitle == "" || fondaPageTitle == (siteName!"")>FONDA &ndash; Foundations of Workflows for Large-Scale Scientific Data Analysis<#else>${fondaPageTitle} &middot; FONDA</#if></title>

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

<#-- Modern typography: Inter via Google Fonts. Optional — remove these three lines
     if you don't want web fonts loaded on every page. -->
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap">

<#include "stylesheets.ftl">
<link rel="stylesheet" href="${urls.theme}/css/screen.css?v=30" />

<#include "headScripts.ftl">

<#if metaTags??>
    ${metaTags.list()}
</#if>

<!--[if (gte IE 6)&(lte IE 8)]>
<script type="text/javascript" src="${urls.base}/js/selectivizr.js"></script>
<![endif]-->

<#-- Inject head content specified in the controller. Currently this is used only to generate an rdf link on
an individual profile page. -->
${headContent!}

<link rel="shortcut icon" type="image/x-icon" href="${urls.base}/favicon.ico">

<#-- FONDA: dark mode. Loads the override stylesheet, applies the saved preference
     before first paint (class on <html>), and wires up the #theme-toggle link
     rendered in identity.ftl. Preference persists in localStorage ("fonda-theme");
     default is light — the site exactly as before. -->
<link rel="stylesheet" href="${urls.theme}/css/dark-mode.css?v=9" />
<script>
    (function() {
        // Explicit toggle choice (localStorage "fonda-theme") wins.
        // With no stored choice, follow the OS setting (prefers-color-scheme),
        // including live OS switches.
        var mq = null;
        try { mq = window.matchMedia('(prefers-color-scheme: dark)'); } catch (e) {}
        function stored() {
            try { return localStorage.getItem('fonda-theme'); } catch (e) { return null; }
        }
        function apply(dark) {
            document.documentElement.classList.toggle('dark-mode', dark);
        }
        var pref = stored();
        if (pref === 'dark') { apply(true); }
        else if (pref === 'light') { apply(false); }
        else if (mq) { apply(mq.matches); }
        function syncThemeToggle() {
            var btn = document.getElementById('theme-toggle');
            if (!btn) return;
            var dark = document.documentElement.classList.contains('dark-mode');
            btn.innerHTML = dark ? '&#9728;&#65039; Light' : '&#127769; Dark';
            btn.setAttribute('title', dark ? 'Switch to light mode' : 'Switch to dark mode');
        }
        if (mq && mq.addEventListener) {
            mq.addEventListener('change', function(ev) {
                if (!stored()) { apply(ev.matches); syncThemeToggle(); }
            });
        }
        document.addEventListener('DOMContentLoaded', function() {
            syncThemeToggle();
            var btn = document.getElementById('theme-toggle');
            if (!btn) return;
            btn.addEventListener('click', function(ev) {
                ev.preventDefault();
                var dark = document.documentElement.classList.toggle('dark-mode');
                try { localStorage.setItem('fonda-theme', dark ? 'dark' : 'light'); } catch (e) {}
                syncThemeToggle();
            });
        });
    })();
</script>
