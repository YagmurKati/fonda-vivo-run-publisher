<#-- $This file is distributed under the terms of the license in /doc/license.txt$ -->
<footer role="contentinfo">
    <div class="row">
        <div class="col-md-12">
            <div class="container">
                <div class="row">
                    <div class="col-md-8">
                        <p class="copyright">
                        <#if copyright??>
                            <small>&copy; ${copyright.year?c}
                                <#if copyright.url??>
                                    <a href="${copyright.url}" title="${i18n().menu_copyright}">${copyright.text}</a>
                                <#else>
                                ${copyright.text}
                                </#if>
                                | <a class="terms" href="${urls.termsOfUse}" title="${i18n().menu_termuse}">${i18n().menu_termuse}</a></small> |
                        </#if>
                        ${i18n().menu_powered} <a class="powered-by-vivo" href="http://vivoweb.org" target="_blank" title="${i18n().menu_powered} VIVO"><strong>VIVO</strong></a>
                        <#if user.hasRevisionInfoAccess>
                            | ${i18n().menu_version} <a href="${version.moreInfoUrl}" title="${i18n().menu_version}">${version.label}</a>
                        </#if>
                        </p>
                    </div>
                    <div class="col-md-4">
                        <nav role="navigation">
                            <ul id="footer-nav" role="list">
                                <#-- FONDA 2026-10-15: "About" opens the FONDA website (no About page on this portal) -->
                                <li role="listitem"><a class="fonda-about" href="https://fonda.hu-berlin.de/" target="_blank" rel="noopener" title="FONDA website (opens in a new tab)">About FONDA<svg viewBox="0 0 12 12" aria-hidden="true"><path d="M4.5 2.5h5v5M9.5 2.5L3 9" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg></a></li>
                            <#if urls.contact??>
                                <li role="listitem"><a href="${urls.contact}" title="${i18n().menu_contactus}">${i18n().menu_contactus}</a></li>
                            </#if>
                                <li role="listitem"><a href="https://github.com/YagmurKati/fonda-vivo-run-publisher" target="_blank" rel="noopener" title="Help: how to publish workflow runs to FONDA VIVO">Help</a></li>
                            </ul>
                        </nav>
                    </div>
                </div>
                <#-- FONDA 2026-10-15: official DFG funding line (same wording as fonda.hu-berlin.de) -->
                <p class="fonda-funding">Funded by the Deutsche Forschungsgemeinschaft (DFG, German Research Foundation) &ndash; Project-ID 414984028 &ndash; SFB 1404 FONDA</p>
            </div>
        </div>
    </div>
</footer>
<#-- FONDA 2026-10-15: footer layout. "(c) 2026 FONDA | Terms of Use | Powered by VIVO" starts on the same line as
     About FONDA / Contact Us / Support (it was 55px lower); "FONDA" readable; the funding line under both. -->
<style>
    footer p.copyright { padding-top: 12px !important; margin: 0 !important; line-height: 20px; color: #fff; }
    footer #footer-nav li { line-height: 20px; }
    footer p.copyright a:not(.terms):not(.powered-by-vivo) { color: #c8cfd8 !important; text-decoration: none; }
    footer #footer-nav a.fonda-about svg { width: 9px; height: 9px; margin-left: 4px; vertical-align: 0; }
    footer p.fonda-funding { clear: both; margin: 0 !important; padding: 6px 0 14px; font-size: .93em; line-height: 1.5; color: #a3acb8; }
    @media (max-width: 1200px) {
        footer p.copyright { padding: 12px 0 0 !important; float: none !important; }
        footer .col-md-8, footer .col-md-4 { width: 100% !important; }
        footer p.fonda-funding { padding-top: 2px; }
    }
</style>

<#include "scripts.ftl">
