<#-- $This file is distributed under the terms of the license in /doc/license.txt$ -->

<div class="container">
	<div class="row">
		<div class="col-md-12">
<h1 class="vivo-logo"><a title="${i18n().identity_title}" href="${urls.home}"><span class="displace">${siteName}</span></a></h1>
<#-- FONDA 2026-10-15: full name of FONDA next to the logo, on every page (look and hiding: see the end of this file) -->
<div class="fonda-fullname"><span>Foundations of Workflows for<br>Large-Scale Scientific Data Analysis</span></div>
<#-- Since we are using a graphic text for the tagline, we won't render ${siteTagline}
<#if siteTagline?has_content>
	<em>${siteTagline}</em>
</#if>-->

<nav role="navigation">
	<ul id="header-nav" role="list">
		<#-- FONDA 2026-10-15: the site search in this top row (moved here from the menu bar, see menu.ftl); it always
		     searches the whole site. Same form as VIVO's search.ftl (the search results page relies on its names). -->
		<li role="listitem" class="fonda-site-search">
			<section id="search" role="region">
				<fieldset>
					<legend>${i18n().search_form}</legend>
					<form id="search-form" action="${urls.search}" name="search" role="search" accept-charset="UTF-8" method="GET">
						<div id="search-field">
							<input type="text" id="filter_input_querytext" name="querytext" class="search-vivo" value="${querytext!?html}" placeholder="Search the site" aria-label="Search the site" autocapitalize="off" />
							<input type="submit" value="${i18n().search_button}" class="search" title="Search the site" />
						</div>
					</form>
				</fieldset>
			</section>
		</li>
		<#include "languageSelector.ftl">
		<#-- FONDA: light/dark mode toggle. Label & behavior are set by the script in head.ftl. -->
		<li role="listitem"><a href="#" id="theme-toggle" title="Switch to dark mode">&#127769; Dark</a></li>
		<li role="listitem"><a href="${urls.index}" title="${i18n().identity_index}">${i18n().identity_index}</a></li>
		<#if user.loggedIn>
			<#-- COMMENTING OUT THE EDIT PAGE LINK FOR RELEASE 1.5. WE NEED TO IMPLEMENT THIS IN A MORE
				 USER FRIENDLY WAY. PERHAPS INCLUDE A LINK ON THE PAGES THEMSELVES AND DISPLAY IF THE
				 USER IS A SITE ADMIN. tlw72

				 <#if (page??) && (page?is_hash || page?is_hash_ex) && (page.URLToEditPage??) >
					<li role="listitem"><a href="${page.URLToEditPage}" title="${i18n().identity_edit}">${i18n().identity_edit}</a></li>
				 </#if>
			-->
			<#if user.hasSiteAdminAccess>
				<li role="listitem"><a href="${urls.siteAdmin}" title="${i18n().identity_admin}">${i18n().identity_admin}</a></li>
			</#if>
				<li>
					<ul class="dropdown">
						<li id="user-menu"><a href="#" title="${i18n().identity_user}">${user.loginName}</a>
							<ul class="sub_menu">
								 <#if user.hasProfile>
									 <li role="listitem"><a href="${user.profileUrl}" title="${i18n().identity_myprofile}">${i18n().identity_myprofile}</a></li>
								 </#if>
								 <#if urls.myAccount??>
									 <li role="listitem"><a href="${urls.myAccount}" title="${i18n().identity_myaccount}">${i18n().identity_myaccount}</a></li>
								 </#if>
								 <li role="listitem"><a href="${urls.logout}" title="${i18n().menu_logout}">${i18n().menu_logout}</a></li>
							</ul>
						</li>
					 </ul>
				 </li>



			${scripts.add('<script type="text/javascript" src="${urls.base}/js/userMenu/userMenuUtils.js"></script>')}

		<#else>
			<li role="listitem"><a class="log-out" title="${i18n().menu_loginfull}" href="${urls.login}">${i18n().menu_login}</a></li>
		</#if>
	</ul>
</nav>
<#-- FONDA 2026-10-15: look of the site search in the top row (light and dark mode). 2nd version: the search field is
     on its own line under Dark / Index / Log in, right-aligned with them (the links keep their place). -->
<style>
    ul#header-nav { display: flex !important; flex-wrap: wrap; justify-content: flex-end; align-items: center; height: auto !important; }
    ul#header-nav > li { float: none !important; }
    ul#header-nav li.fonda-site-search { order: 99; flex: 0 0 100%; display: flex !important; justify-content: flex-end;
        padding: 0 !important; margin: 9px 0 0 0 !important; border-right: 0 !important; font-size: 14px; }
    ul#header-nav li.fonda-site-search #search { position: static !important; left: auto !important; right: auto !important; width: auto !important;
        height: auto !important; padding: 0 !important; margin: 0 !important; display: block; }
    ul#header-nav li.fonda-site-search fieldset { margin: 0; padding: 0; border: 0; min-width: 0; }
    ul#header-nav li.fonda-site-search legend { display: none; }
    ul#header-nav li.fonda-site-search #search-field {
        display: flex !important; align-items: center !important; width: 220px !important; height: 30px !important; box-sizing: border-box;
        background: rgba(255, 255, 255, .92) !important; border: 1px solid rgba(255, 255, 255, .7) !important; border-radius: 6px !important;
        overflow: hidden; transition: border-color .15s, box-shadow .15s, background-color .15s; }
    ul#header-nav li.fonda-site-search #search-field:focus-within {
        background: #ffffff !important; border-color: #1f3a5f !important; box-shadow: 0 0 0 3px rgba(31, 58, 95, .2); }
    ul#header-nav li.fonda-site-search #search-field input.search-vivo {
        flex: 1 1 auto !important; float: none !important; width: auto !important; min-width: 0 !important; height: 28px !important;
        margin: 0 !important; padding: 0 10px 0 2px !important; border: 0 !important; outline: 0 !important; box-shadow: none !important;
        background: transparent !important; color: #1f3a5f !important; font-family: inherit !important; font-size: 14px !important; line-height: 28px !important; }
    ul#header-nav li.fonda-site-search #search-field input.search-vivo::placeholder { color: #5c6b7c; opacity: 1; }
    ul#header-nav li.fonda-site-search #search-field input.search-vivo:-webkit-autofill { transition: background-color 0s 600000s, color 0s 600000s !important; }
    ul#header-nav li.fonda-site-search #search-field input.search {
        order: -1; -webkit-appearance: none !important; appearance: none !important; flex: 0 0 32px !important; width: 32px !important;
        height: 28px !important; margin: 0 !important; padding: 0 !important; border: 0 !important; border-radius: 0 !important;
        font-size: 0 !important; color: transparent !important; text-shadow: none !important; box-shadow: none !important; cursor: pointer;
        background: transparent url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='%234a5d75' stroke-width='2.2' stroke-linecap='round'%3E%3Ccircle cx='10.5' cy='10.5' r='6.5'/%3E%3Cline x1='15.5' y1='15.5' x2='21' y2='21'/%3E%3C/svg%3E") no-repeat center / 15px 15px !important; }
    html.dark-mode ul#header-nav li.fonda-site-search #search-field { background: rgba(26, 35, 52, .92) !important; border-color: #2c3a52 !important; }
    html.dark-mode ul#header-nav li.fonda-site-search #search-field:focus-within { background: #1a2334 !important; border-color: #5d7aa5 !important; box-shadow: 0 0 0 3px rgba(93, 140, 205, .25); }
    html.dark-mode ul#header-nav li.fonda-site-search #search-field input.search-vivo { color: #d5dde7 !important; }
    html.dark-mode ul#header-nav li.fonda-site-search #search-field input.search-vivo::placeholder { color: #8d96a6; }
    html.dark-mode ul#header-nav li.fonda-site-search #search-field input.search {
        background: transparent url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='%23aab6c6' stroke-width='2.2' stroke-linecap='round'%3E%3Ccircle cx='10.5' cy='10.5' r='6.5'/%3E%3Cline x1='15.5' y1='15.5' x2='21' y2='21'/%3E%3C/svg%3E") no-repeat center / 15px 15px !important;
        border: 0 !important; color: transparent !important; }
    /* the home page has its own big search bar */
    body.home-page ul#header-nav li.fonda-site-search { display: none !important; }
    @media (max-width: 767px) {
        ul#header-nav li.fonda-site-search { margin: 6px 0 0 0 !important; }
        ul#header-nav li.fonda-site-search #search-field { width: 150px !important; }
    }
</style>
<#-- FONDA 2026-10-15: look of the full name next to the logo. It sits in the same box as the logo (same position rules),
     30px right of the FONDA wordmark, centred on the logo. It is hidden on narrow screens and whenever it would come
     closer than 40px to the search field or a link on the right (checked by the script below, also when the window is
     resized), so the two never crowd each other. -->
<style>
    div.fonda-fullname { position: absolute; left: 308px; top: 22px; height: 90px; display: flex; align-items: center; z-index: 1;
        margin: 0; padding: 0; white-space: nowrap; }
    /* on the span itself: the theme's reset.css gives every span its own grey colour and normal weight */
    div.fonda-fullname > span { font-size: 15px; font-weight: 500; line-height: 1.3; color: #2a4466; }
    html.dark-mode div.fonda-fullname > span { color: #c9d4e2; }
    div.fonda-fullname.fonda-fullname-off { visibility: hidden; }
    @media (max-width: 767px) { div.fonda-fullname { display: none; } }
</style>
<script>
(function () {
    var box = document.querySelector('div.fonda-fullname');
    if (!box) { return; }
    var text = box.querySelector('span');
    function fit() {
        box.classList.remove('fonda-fullname-off');
        var r = text.getBoundingClientRect();
        if (!r.width) { return; }
        var limit = document.documentElement.clientWidth - 16;
        var nav = document.getElementById('header-nav');
        if (nav) {
            for (var i = 0; i < nav.children.length; i++) {
                var li = nav.children[i];
                var el = li.querySelector('#search-field') || li;
                var o = el.getBoundingClientRect();
                if (o.width && o.height && o.bottom > r.top && o.top < r.bottom) { limit = Math.min(limit, o.left - 40); }
            }
        }
        if (r.right > limit) { box.classList.add('fonda-fullname-off'); }
    }
    fit();
    window.addEventListener('resize', fit);
    window.addEventListener('load', fit);
    if (document.fonts && document.fonts.ready) { document.fonts.ready.then(fit); }
})();
</script>
<#-- FONDA 2026-10-16: LIGHT MODE ONLY - the full name next to the logo in a quieter style (option A of the preview):
     smaller, normal weight, grey-blue; the two lines are about as tall as the FONDA letters. The header keeps its
     white-to-grey-blue fade. Dark mode keeps its own look (this rule starts with html:not(.dark-mode)). -->
<style>
    html:not(.dark-mode) div.fonda-fullname > span { font-size: 13px; line-height: 17px; font-weight: 400; color: #5b6b80; letter-spacing: .01em; }
</style>
		</div>
	</div>
</div>
