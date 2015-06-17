
/*
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.  
#
*/

/* Dynamic tables behavior */

(function () {
  "use strict";

  /* polyfill for startsWith */
  if (typeof(String.prototype.startsWith) != 'function') {
    String.prototype.startsWith = function (str) {
      return this.substring(0, str.length) === str;
    };
  }

  $(function bind() {
    var container      = $('.dynamic-table'),
        table          = container.find('.dt-table'),
        request_type   = container.data('request-type'),
        selection_mode = container.data('selection-mode'),
        selected       = undefined,
        icons          = {
          column_show: "ui-icon-radio-off",
          column_hide: "ui-icon-radio-on"
        };

    /* Requests */

    /* sorting and filtering requests */
    table.find('.dt-sort-btn, .dt-fpop-txt:not(.dt-zero)').click(function () {
      var url = $(this).data('url');
      if (!url || !request_type) return;

      if (request_type == 'html_link')
        window.location.href = url;
      else
        $.get(url, function (data) {
          container.replaceWith(data);
          bind();
        });
    });

    /* re-bind when the table is reloaded (new_content event) */
    container.parent()
      .unbind('new_content', bind)
      .bind('new_content', bind);

    /* UI */

    /* show/hide popups on filter/columns display button clicks */
    var popup_buttons = table.find('.dt-filter-btn, .dt-col-btn');
    popup_buttons.click(function () {
      popup_buttons
        .not(this)
        .removeClass('dt-shown')
        .siblings('.dt-popup')
        .hide();

      var popup = $(this)
        .siblings('.dt-popup')
        .toggle();

      $(this).toggleClass('dt-shown');

      popup.trigger(popup.is(':visible') ? 'show' : 'hide');
    });

    /* hide popups when their close buttons are clicked */
    table.find('.dt-pop-close-btn').click(function () {
      var popup = $(this)
        .parent()
        .hide();

      popup
        .siblings('.dt-filter-btn, .dt-col-btn')
        .removeClass('dt-shown');

      popup.trigger('hide');
    });

    /* stick the columns display popup in place when shown */
    table.find('.dt-col-csp > .dt-popup')
      .bind('show', function () {
        var popup    = $(this),
            position = popup.offset();

        popup.parent().css({ position: 'static' });
        popup.offset(position);
      })
      .bind('hide', function () {
        $(this)
          .css({ left: '', top: '' })
          .parent()
          .css({ position: 'relative' });
      });

    /* show rows as selected if their respective checkbox is checked */
    var checkboxes = table.find('td.dt-sel > .dt-sel-check');
    checkboxes.change(function () {
      $(this)
        .closest('tr')
        .toggleClass('dt-selected', $(this).prop('checked'));

      if (selection_mode != 'single') return;

      /* in single select mode, when a checkbox is checked, the last one gets unchecked */
      if (selected && selected != this)
        $(selected)
          .prop('checked', false)
          .closest('tr')
          .removeClass('dt-selected');

      selected = (selected == this ? undefined : this);
    });

    /* trigger selection checkboxes when the row is clicked */
    table.find('.dt-body > .dt-sel-row').click(function () {
      var checkbox = $(this)
        .find('.dt-sel-check')
        .first();

      checkbox
        .prop('checked', !checkbox.prop('checked'))
        .trigger('change');
    });

    /* in single select mode, there is no need for a header checkbox */
    if (selection_mode == 'single')
      table.find('th.dt-sel')
        .css({ visibility: 'hidden' });

    /* toggle all checkboxes when the header checkbox is clicked */
    table.find('th.dt-sel > .dt-sel-check').change(function () {
      var checked = $(this).prop('checked');

      checkboxes
        .prop('checked', checked)
        .closest('tr')
        .toggleClass('dt-selected', checked);
    });

    /* toggle columns when the column is clicked in the column display popup */
    table.find('.dt-cpop-col').click(function () {
      $(this)
        .find('.dt-cpop-icon')
        .toggleClass(icons.column_show)
        .toggleClass(icons.column_hide);

      var column = $(this).data('column');
      if (!column) return;

      table
        .find(['td.' + column, 'th.' + column].join(','))
        .toggleClass('dt-hidden');

      adjust_empty();
    });

    /* filter out filter options if they dont begin with the search input */
    table.find('.dt-fpop-find > input').bind('input', function () {
      var key = $.trim($(this).val()).toLowerCase();

      $(this)
        .closest('table')
        .find('tbody > tr')
        .each(function () {
          var text = $.trim(
            $(this)
              .find('.dt-fpop-txt')
              .first()
              .text()
          ).toLowerCase();

          $(this).toggle(text.startsWith(key));
        });
    });

    /* adjust the width of the empty-table cell, if the table is empty */
    function adjust_empty() {
      var empty = table.find('.dt-body > tr > .dt-table-empty');
      if (!empty.length) return;

      empty.attr('colspan',
        table
          .find('.dt-head > tr > th:not(.dt-col-csp):not(.dt-hidden)')
          .length
      );
    };

    adjust_empty();
  });
})();
