<#-- $This file is distributed under the terms of the license in /doc/license.txt$ -->

<div id="nav-wrapper">
    <div id="nav">
        <div class="container">
            <nav class="navbar navbar-default">
                <#-- FONDA 2026-10-15: the site search moved to the top row of the page (identity.ftl). -->

                <button class="navbar-toggle pull-left" type="button" data-toggle="collapse" data-target="#navbarContent" aria-controls="navbarContent" aria-expanded="false" aria-label="Toggle navigation">
                    <span class="button-label">${i18n().collapsed_menu_name}</span>
                    <div class="button-bars">
                        <span class="icon-bar"></span>
                        <span class="icon-bar"></span>
                        <span class="icon-bar"></span>
                    </div>
                </button>

                <div class="collapse navbar-collapse" id="navbarContent">
                    <ul id="main-nav" role="list" class="nav navbar-nav">
                    <#assign hiddenMenuLabels = ["events", "capability map"]>
                    <#list menu.items as item>
                        <#if !hiddenMenuLabels?seq_contains(item.linkText?lower_case)>
                            <li role="listitem" class="nav-item<#if item.active> active</#if>"><a href="${item.url}" title="${item.linkText} ${i18n().menu_item}" class="nav-link">${item.linkText}</a></li>
                        </#if>
                    </#list>
                    </ul>
                </div>

            </nav>
        </div>
    </div>
</div>
