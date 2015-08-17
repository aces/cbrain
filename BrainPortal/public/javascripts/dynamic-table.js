
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

/*
 * Dynamic tables client-side behavior
 * Event namespace: .dyn-tbl
 */

(function () {
  "use strict";

  /* polyfill for startsWith */
  if (typeof(String.prototype.startsWith) != 'function') {
    String.prototype.startsWith = function (str) {
      return this.substring(0, str.length) === str;
    };
  }

  /* jQuery UI icons */
  var icons = {
    column_show: "ui-icon-radio-off",
    column_hide: "ui-icon-radio-on"
  };

  /* localStorage column visibility module */
  var column_visibility = undefined;
  if (typeof localStorage !== 'undefined')
    column_visibility = cache_module(function (dyntbl_id) {
      return {
        /* current column visibility status for this table */
        columns: {},

        /* column visibility status for all tables */
        all: undefined,

        /* save visibility status to localStorage */
        save: function () {
          if (!this.all) this.load();

          this.all[dyntbl_id] = this.columns;
          localStorage.setItem('dyntbl_column_visibility', JSON.stringify(this.all));
        },

        /* load visibility status from localStorage */
        load: function () {
          if (!this.all) {
            try {
              this.all = JSON.parse(localStorage.getItem('dyntbl_column_visibility') || '{}');

            } catch (exception) {
              console.log(exception);

              localStorage.removeItem('dyntbl_column_visibility');
              this.all = {};
            }
          }

          if (!this.columns || $.isEmptyObject(this.columns))
            this.columns = this.all[dyntbl_id] || {};

          return this.columns;
        }
      };
    });

  /*
   * +refresh+ event
   * Present on .dynamic-table nodes, refreshes the dynamic table's UI elements.
   * Trigger this event if the table's dynamic elements (rows, column visibility,
   * filters, etc.) have changed.
   */
  $(document).delegate('.dynamic-table', 'refresh.dyn-tbl', function () {

    var dyntbl    = $(this),
        dyntbl_id = dyntbl.attr('id'),
        table     = dyntbl.find('.dt-table');

    /* unstick the selection state of pre-selected rows */
    table
      .find('.dt-sel-check[checked]')
      .removeAttr('checked')
      .prop('checked', true);

    /* restore previous column visibility status */
    if (column_visibility) {
      var visibility = column_visibility(dyntbl_id).load();

      table.find('.dt-head > tr > th').each(function () {
        var column  = $(this).data('column'),
            visible = visibility[column];

        if (!visibility.hasOwnProperty(column)) return;

        table.find(".dt-cpop-col[data-column='" + column + "'] > .dt-cpop-icon")
          .toggleClass(icons.column_show, visible)
          .toggleClass(icons.column_hide, !visible);

        table.find(['td.' + column, 'th.' + column].join(','))
          .toggleClass('dt-hidden', !visible);
      });
    }

    /* make sure that each cell's visibility is consistent with it's column */
    table.find('.dt-head > tr > th').each(function () {
      var column = $(this).data('column'),
          hidden = $(this).hasClass('dt-hidden');

      if (!column) return;

      table
        .find('td.' + column)
        .toggleClass('dt-hidden', hidden);
    });

    adjust_empty(table);

  });

  /*
   * +reload+ event
   * Present on .dynamic-table nodes, reload the dynamic table's state and
   * event bindings. Trigger this event if the table's static elements (headers,
   * pagination, columns, etc.) have changed and the current state is no longer
   * valid.
   */
  $(document).delegate('.dynamic-table', 'reload.dyn-tbl', function () {

    var dyntbl         = $(this),
        dyntbl_id      = dyntbl.attr('id'),
        table          = dyntbl.find('.dt-table'),
        request_type   = dyntbl.data('request-type'),
        selection_mode = dyntbl.data('selection-mode'),
        selected       = undefined;

    /* Requests */

    /* trigger a sorting request when the header of a sortable column is clicked */
    dyntbl
      .undelegate('.dt-sort > .dt-hdr', 'click.dyn-tbl')
      .delegate(  '.dt-sort > .dt-hdr', 'click.dyn-tbl', function () {
        $(this)
          .siblings('.dt-sort-btn')
          .first()
          .click();
      });

    /* sorting, filtering and pagination requests */
    dyntbl
      .undelegate('.dt-sort-btn, .dt-fpop-txt, .dt-pag-pages > a', 'click.dyn-tbl')
      .delegate(  '.dt-sort-btn, .dt-fpop-txt, .dt-pag-pages > a', 'click.dyn-tbl', function (event) {
        event.preventDefault();

        var url = $(this).attr('href') || $(this).data('url');
        if (!url || !request_type) return;

        var loading = $('#loading_image');

        switch (request_type) {
        case 'html_link':
          window.location.href = url;
          break;

        case 'ajax_replace':
          loading.show();

          $.get(url, function (data) {
            dyntbl.replaceWith(data);
            $('.dynamic-table').trigger('reload.dyn-tbl');

            loading.hide();
          });
          break;

        case 'server_javascript':
          loading.show();

          $.get(url, function () { loading.hide(); }, 'script');
          break;

        default:
          return;
        }
      });

    /* Popups */

    /* show/hide popups on filter/columns display button clicks */
    dyntbl
      .undelegate('.dt-filter-btn, .dt-col-btn', 'click.dyn-tbl')
      .delegate(  '.dt-filter-btn, .dt-col-btn', 'click.dyn-tbl', function () {
        table
          .find('.dt-filter-btn, .dt-col-btn')
          .not(this)
          .removeClass('dt-shown')
          .siblings('.dt-popup')
          .hide();

        var popup = $(this)
          .siblings('.dt-popup')
          .toggle();

        $(this).toggleClass('dt-shown');

        popup.trigger(popup.is(':visible') ? 'show.dyn-tbl' : 'hide.dyn-tbl');
      });

    /* hide popups when their close buttons are clicked */
    dyntbl
      .undelegate('.dt-pop-close-btn', 'click.dyn-tbl')
      .delegate(  '.dt-pop-close-btn', 'click.dyn-tbl', function () {
        var popup = $(this)
          .parent()
          .hide();

        popup
          .siblings('.dt-filter-btn, .dt-col-btn')
          .removeClass('dt-shown');

        popup.trigger('hide.dyn-tbl');
      });

    /* stick the columns display popup in place when shown */
    dyntbl
      .undelegate('.dt-col-csp > .dt-popup', 'show.dyn-tbl')
      .delegate(  '.dt-col-csp > .dt-popup', 'show.dyn-tbl', function () {
        var popup    = $(this),
            width    = popup.outerWidth(),
            edge_gap = 10,
            position = popup.offset();

        popup.parent().css({ position: 'static' });
        popup.offset({
          top:  position.top,
          left: Math.min(position.left, $(window).width() - width - edge_gap)
        });
      })
      .undelegate('.dt-col-csp > .dt-popup', 'hide.dyn-tbl')
      .delegate(  '.dt-col-csp > .dt-popup', 'hide.dyn-tbl', function () {
        $(this)
          .css({ left: '', top: '' })
          .parent()
          .css({ position: 'relative' });
      });

    /* Selection */

    /* show rows as selected if their respective checkbox is checked */
    dyntbl
      .undelegate('td.dt-sel > .dt-sel-check', 'change.dyn-tbl')
      .delegate(  'td.dt-sel > .dt-sel-check', 'change.dyn-tbl', function () {
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
    dyntbl
      .undelegate('.dt-body > .dt-sel-row', 'click.dyn-tbl')
      .delegate(  '.dt-body > .dt-sel-row', 'click.dyn-tbl', function (event) {
        if (!$(this).children('td').is(event.target)) return;

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
    dyntbl
      .undelegate('th.dt-sel > .dt-sel-check', 'change.dyn-tbl')
      .delegate(  'th.dt-sel > .dt-sel-check', 'change.dyn-tbl', function () {
        var checked = $(this).prop('checked');

        if (selection_mode == 'single') return;

        /*
         * FIXME: while triggering 'change' for every checkbox is the correct
         * behavior to implement, it is also extremely slow...
         */
        table
          .find('td.dt-sel > .dt-sel-check')
          .prop('checked', checked)
          .closest('tr')
          .toggleClass('dt-selected', checked);
      });

    /* Column visibility */

    /* toggle columns when the column is clicked in the column display popup */
    dyntbl
      .undelegate('.dt-cpop-col', 'click.dyn-tbl')
      .delegate(  '.dt-cpop-col', 'click.dyn-tbl', function () {
        $(this)
          .find('.dt-cpop-icon')
          .toggleClass(icons.column_show)
          .toggleClass(icons.column_hide);

        var column = $(this).data('column');
        if (!column) return;

        table
          .find(['td.' + column, 'th.' + column].join(','))
          .toggleClass('dt-hidden');

        adjust_empty(table);

        /* update the column's visibility status */
        if (column_visibility) {
          column_visibility(dyntbl_id).columns[column] = table.find('th.' + column).is(':visible');
          column_visibility(dyntbl_id).save();
        }
      });

    /* Misc */

    /* filter out filter options if they dont begin with the search input */
    dyntbl
      .undelegate('.dt-fpop-find > input', 'input.dyn-tbl')
      .delegate(  '.dt-fpop-find > input', 'input.dyn-tbl', function () {
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

    dyntbl.trigger('refresh.dyn-tbl');

  });

  /* adjust the width of table-wide cells for +table+ */
  function adjust_empty(table) {
    var empty = table.find('.dt-body > tr > .dt-table-wide');
    if (!empty.length) return;

    empty.attr('colspan',
      table
        .find('.dt-head > tr > th:not(.dt-col-csp):not(.dt-hidden)')
        .length
    );
  };

  /* cache a table-specific (one per dynamic table) +module+ */
  function cache_module(module) {
    var tables = {};

    return function (id) {
      return tables[id] || (tables[id] = module(id));
    };
  };

  /* load the table at initial page load */
  $('.dynamic-table').trigger('reload.dyn-tbl');

  /* and when new content is loaded */
  $(document).bind('new_content', function () {
    $('.dynamic-table').trigger('reload.dyn-tbl');
  });
})();
