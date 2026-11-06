/* $This file is distributed under the terms of the license in LICENSE$ */

$(document).ready(function(){
    // This function creates and styles the "qTip" tooltip that displays the bubble text when the user hovers
    // over the research area "group" icon.

    $.extend(this, i18nStrings);

    // Use a flexible text bubble instead of the fixed-size background image.
    $('head').append('<style id="researchAreaCSS">.qtip.researchAreaTip { background: #334b5b; color: #fff; border: 0; border-radius: 6px; font-size: 14px; line-height: 1.5; width: 260px; max-width: calc(100vw - 32px) !important; height: auto; box-shadow: 0 3px 12px rgba(0,0,0,.18); } .researchAreaTip .qtip-content, .researchAreaTip .qtip-content span { color: #fff !important; } .researchAreaTip .qtip-content { padding: 10px 14px; overflow: visible; white-space: normal; }</style>');

    $('#researchAreaIcon').each(function()
    {
        $(this).qtip({
            prerender: true,
            content: {
                text: $('<span>').text(i18nStrings.researchAreaTooltipOne + ' ' + i18nStrings.researchAreaTooltipTwo)
            },
            position: {
                my: 'top center',
                at: 'bottom center',
                viewport: $(window),
                adjust: { x: 0, y: 8, method: 'flipinvert shift' }
            },
            style: {
                classes: 'researchAreaTip',
                tip: false
            }
        });
    });

    $('head').append('<style id="bubbleCSS">.qtip { font-size: 14px; max-width: none !important; } .bubbleTip { url(' + imagesPath + '/individual/toolTipBubble.png) no-repeat; } </style>');

    $('#fullViewIcon').each(function()
    {
        $(this).qtip(
        {
            content: {
                text: '<div style="padding-top:0.5em;color:white">' + i18nStrings.quickviewTooltip + '</div>'
            },
            position: {
                my: 'top left',
                at: 'bottom center',
                adjust: {
                    x:27,
                    y:30
                }
            },
            style: {
                classes: 'bubbleTip',
                height: 56,
                width: 140,

            }
        });
    });

    $('#quickViewIcon').each(function()
    {
        $(this).qtip(
        {
            content: {
                text: '<div style="padding-top:0.5em;color:white">' + i18nStrings.standardviewTooltipOne + '</div><div style="color:white">' + i18nStrings.standardviewTooltipTwo + '</div>'
            },
            position: {
                my: 'top left',
                at: 'bottom center',
                adjust: {
                    x:28,
                    y:30
                }
            },
            style: {
                classes: 'bubbleTip',
                height: 56,
                width: 144,
            }
        });
    });
});
