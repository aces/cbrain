
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
 * Userfiles client-side behavior
 * Event namespace: .uf
 */

$(function() {
  "use strict";

  /* Main top-level userfiles interface */
  var userfiles = $('#userfiles_menus_and_filelist');

  /* URLs to perform actions/operations requests on */
  var urls = {
    refresh: '/userfiles',
    upload:  $('#upload-dialog > form').attr('action'),
    copy:    $('#cpmv-dialog > form').attr('action'),
    move:    $('#cpmv-dialog > form').attr('action'),
    rename:  '/userfiles/:id',
    update:  $('#prop-dialog > form').attr('action'),
    tags:    '/tags/:id',
    create_collection: $('#collection-dialog > form').attr('action')
  };

  /* Userfiles actions/operations */
  var operations = {
    /*
     * All operations return a jQuery Promise object to allow callbacks once the
     * operation completes or fails. Note that the returned promise often
     * directly corresponds to the operation's request.
     */

    /*
     * FIXME some operations take JS objects as entity values while others
     * directly take HTML forms. Ideally they should all be able to take both,
     * but it is impractical in some cases (notably tags and filters) and XML
     * serializing/nested structures add extra unwanted complexity.
     */

    /*
     * Send a request to the server, attaching the provided form and selected
     * files if necessary. The request's parameters are to be specified in the
     * +settings+ argument using the same parameters as jQuery's ajax()
     * settings argument, with the notable addition of:
     *
     * [ajax]
     *  whether the request should be made using AJAX or using a regular
     *  HTML request (defaults to false).
     *
     * [withSelection]
     *  whether or not the currently selected files should be added to the
     *  request (defaults to true for everything but GET requests).
     *
     * [emptySelection]
     *  whether or not the current selection should be cleared once the
     *  request completes. Typically used alongside +withSelection+ above
     *  (same default as +withSelection+; true for everything but GET
     *  requests).
     *
     * This function is mainly a rather thin wrapper around jQuery's ajax()
     * function, to add the currently selected files and allow non-AJAX
     * requests.
     */
    request: function (settings) {
      var ajax   = settings.ajax,
          url    = settings.url,
          method = settings.method || settings.type || 'GET',
          data   = settings.data;

      if (!url) return;
      settings.type = settings.method = method;

      var truthy = /^(t|true|1|y|yes)$/i;

      var withSelection = typeof settings.withSelection !== 'undefined'
        ? truthy.test(settings.withSelection)
        : method !== 'GET';

      var emptySelection = typeof settings.emptySelection !== 'undefined'
        ? truthy.test(settings.emptySelection)
        : withSelection;

      var form = withSelection
        ? userfiles.children('form')
        : $('<form>');

      if (ajax) {
        return (
          (method === 'GET')
            ? $.ajax(settings)
            : ajax_submit(form, settings)
        ).then(function () {
          if (emptySelection) clear_selection(false);
        });

      } else {
        if (data)
          form.append($.map($.params(data, false).split('&'), function (value) {
            var pair = value.split('=');
            return $('<input type="hidden" />')
              .attr('name', pair[0])
              .val(pair[1]);
          }));

        if (method === 'GET')
          form.attr('method', 'GET');
        else
          form.attr('method', 'POST')
            .append(
              $('<input type="hidden" name="_method" />')
                .val(method)
            );

        if (emptySelection) clear_selection(true);

        form.attr('action', url);
        return defer(function () { form.submit(); }).promise();
      }
    },

    /*
     * Refresh the current userfiles view using CBRAIN's server-generated
     * javascript mechanism via an AJAX request.
     */
    refresh: function () {
      return $.get(urls.refresh, null, $.noop, 'script');
    },

    /*
     * Upload a given file to CBRAIN (using an AJAX upload and a nice progress
     * bar if possible). Upload parameters (file itself, project/group, type,
     * tags, etc.) are to be specified in the HTML form argument +form+.
     */
    upload: function (form) {
      form = $(form);
      form.attr('action', urls.upload);

      var mode    = undefined,
          extract = form.find('#up-ex');

      /* convert the extraction mode to the one the server expects */
      if (!extract.is(':checked') || !extract.is(':visible'))
        mode = 'save';
      else if (form.find('#up-mul').is(':checked'))
        mode = 'extract';
      else
        mode = 'collection';

      form
        .append(
          $('<input type="hidden" name="archive" />')
            .val(mode)
        )
        .append(
          $('<input type="hidden">')
            .attr('name', $('#csrf-param').attr('content'))
            .val($('#csrf-token').attr('content'))
        );

      return userfiles.tags.add_selected(form.find('#up-tag')[0])
        .pipe(function () {
          /* are AJAX uploads supported? */
          var xhr = new XMLHttpRequest();
          if (('upload' in xhr) && ('onprogress' in xhr))
            return ajax_upload(form[0]);

          form.submit();
        });
    },

    /*
     * Copy the currently selected files to another data provider. Which data
     * provider to copy to (and whether or not to overwrite existing files) is
     * to be specified in the HTML form argument +form+.
     */
    copy: function (form) {
      var uform = userfiles.children('form');

      uform
        .attr('action', urls.copy)
        .attr('method', 'POST')
        .append($(form).find(':input'))
        .append($('<input type="hidden" name="_method" value="POST" />'))
        .append($('<input type="hidden" name="copy"    value="1"    />'));

      clear_selection(true);

      return defer(function () { uform.submit(); }).promise();
    },

    /*
     * Move the currently selected files to another data provider. Behaves
     * similarly to +copy+ (and requires a similar HTML form argument +form+).
     */
    move: function (form) {
      var uform = userfiles.children('form');

      uform
        .attr('action', urls.move)
        .attr('method', 'POST')
        .append($(form).find(':input'))
        .append($('<input type="hidden" name="_method" value="POST" />'))
        .append($('<input type="hidden" name="move"    value="1"    />'));

      clear_selection(true);

      return defer(function () { uform.submit(); }).promise();
    },

    /*
     * Rename the currently selected file with ID +id+ to +name+ using an AJAX
     * request.
     */
    rename: function (id, name) {
      return $.ajax({
        url:         urls.rename.replace(':id', id.toString()),
        type:        'PUT',
        method:      'PUT',
        data:        to_XML({ userfile: { name: name }}),
        headers:     {
          'Accept':       'application/xml, text/xml, text/plain, */*',
          'Content-Type': 'application/xml'
        }
      });
    },

    /*
     * Update the properties/metadata of the currently selected files. Which
     * properties to update (and associated values) are to be specified in the
     * HTML form argument +form+.
     */
    update: function (form) {
      var uform = userfiles.children('form');

      $(form).find('select').each(function () {
        var select = $(this);

        /*
         * disabled select boxes correspond to an explicitly empty field; send
         * an empty value.
         */
        if (select.prop('disabled')) {
          $(form).append(
            $('<input type="hidden" value="" />')
              .attr('name', select.attr('name'))
          );

          select.removeAttr('name');

        /*
         * empty select boxes correspond to 'keep current value'; do not send
         * anything.
         */
        } else if (!select.val()) {
          select.removeAttr('name');
        }
      });

      $(form).find('.dlg-chk[name]').each(function () {
        var check = $(this);

        /* named but unchecked checkboxes should still be sent */
        if (!check.prop('checked'))
          check.prop('checked', true).val('');
      });

      uform
        .attr('action', urls.update)
        .attr('method', 'POST')
        .append($(form).find(':input'))
        .append($('<input type="hidden" name="_method" value="PUT" />'));

      clear_selection(true);

      return userfiles.tags.add_selected(uform.find('#pp-tag')[0])
        .pipe(function () { uform.submit() });
    },

    /*
     * Create a new FileCollection containing the currently selected files.
     * The new collection's name and target data provider are to be specified
     * in the HTML form argument +form.
     */
    create_collection: function (form) {
      var uform = userfiles.children('form');

      uform
        .attr('action', urls.create_collection)
        .attr('method', 'POST')
        .append($(form).find(':input'));

      clear_selection(true);

      return defer(function () { uform.submit(); }).promise();
    },

    /*
     * Custom filter operations; generic CRUD for custom filters using the
     * corresponding custom filter form (+form+ argument). Note that these
     * operations are rather bare and inflexible as they rely on +form+ to do
     * most of their work.
     */
    filters: {
      add: function (form) {
        return ajax_submit($(form));
      },

      update: function (form) {
        return ajax_submit($(form));
      },

      /*
       * Note that this function expects the custom filter's 'edit' form, which
       * contains, in particular, the filter's proper URL
       */
      remove: function (form) {
        return $.ajax({
          url:         $(form).attr('action'),
          type:        'DELETE',
          method:      'DELETE',
          headers:     {
            'Accept':       'application/xml, text/xml, text/plain, */*',
            'Content-Type': 'application/xml'
          }
        });
      }
    },

    /*
     * Tag-related operations; generic CRUD with parameters +id+ (tag ID) and
     * +data+ (tag attributes as a JS object)
     */
    tags: {
      add: function (data) {
        return $.ajax({
          url:         urls.tags.replace(/\/?:id$/, ''),
          type:        'POST',
          method:      'POST',
          data:        to_XML({ tag: data }),
          headers:     {
            'Accept':       'application/xml, text/xml, text/plain, */*',
            'Content-Type': 'application/xml'
          }
        });
      },

      update: function (id, data) {
        return $.ajax({
          url:         urls.tags.replace(':id', id.toString()),
          type:        'PUT',
          method:      'PUT',
          data:        to_XML({ tag: data }),
          headers:     {
            'Accept':       'application/xml, text/xml, text/plain, */*',
            'Content-Type': 'application/xml'
          }
        });
      },

      remove: function (id) {
        return $.ajax({
          url:         urls.tags.replace(':id', id.toString()),
          type:        'DELETE',
          method:      'DELETE',
          headers:     {
            'Accept':       'application/xml, text/xml, text/plain, */*',
            'Content-Type': 'application/xml'
          }
        });
      },

      /*
       * Specialized version of +add+ to add tags described in an HTML select
       * box (+select+). This method is designed to go in tandem with the
       * snippet allowing new tags to be added to Chosen select boxes; it will
       * make the necessary requests (returning a promise) for the new tags
       * to be created. Note that a 'default-project' data attribute is
       * required on +select+ for the new tags' project.
       */
      add_selected: function (select) {
        return $.when.apply($,
          $(select).find('option[value="-1"]').map(function () {
            var option = $(this);

            /*
             * once the request is complete, set the appropriate tag
             * option's id.
             */
            return userfiles.tags.add({
              name:     $(this).text(),
              group_id: $(select).data('default-project')
            }).done(function (data) {
              option.val($(data).find('id').text());
            });
          }).get()
        );
      },
    }
  };

  /* Allow access to the operations above outside this immediate scope */
  $.extend(userfiles, operations);
  userfiles.data('operations', operations);

  /* Menus (context menu and menu bar) */
  userfiles.delegate('#menu_bar', 'new_content', function () {
    /* Style up action buttons */
    $('.act-btn').each(function () {
      $(this).button({ icons: { primary: $(this).data('icon') } });
    });

    /* Style up the dropdown menu */
    $('#menu-list').menu({
      position: { my: 'right top', at: 'left top' }
    });

    $('#menu-list .ui-icon-carat-1-e')
      .removeClass('ui-icon-carat-1-e')
      .addClass('ui-icon-carat-1-w');

    /* Style up the context menu */
    $('#userfiles_context_menu').menu();

    /* Show/Hide dynamic actions/menu elements according to current selection */
    (function () {
      function toggle(checked, persistent) {
        if (typeof checked === 'undefined')
          checked = $('input[name="file_ids[]"]:checked').length;

        if (typeof persistent === 'undefined')
          persistent = parseInt($('.psel-count').text());

        $('#dynamic-actions, #menu-list .dyn-item')
          .toggleClass('hidden', !checked && !persistent);

        $('#ren-btn, #ren-ctx').toggle(checked == 1);
      };

      $('#userfiles_table')
        .undelegate('input[name="file_ids[]"]', 'change.uf.chk-dynamic')
        .delegate(  'input[name="file_ids[]"]', 'change.uf.chk-dynamic', function () {
          toggle();
        })
        .undelegate('th.dt-sel > .dt-sel-check', 'change.uf.mchk-dynamic')
        .delegate(  'th.dt-sel > .dt-sel-check', 'change.uf.mchk-dynamic', function () {
          toggle($(this).prop('checked') ? $('input[name="file_ids[]"]').length : 0);
        });

      userfiles
        .undelegate('.persistent-selection', 'ready.psel.uf.psel-ready-dynamic')
        .delegate(  '.persistent-selection', 'ready.psel.uf.psel-ready-dynamic', function () {
          toggle();
        })
        .undelegate('.persistent-selection', 'clear.psel.uf.psel-clear-dynamic')
        .delegate(  '.persistent-selection', 'clear.psel.uf.psel-clear-dynamic', function () {
          toggle(0, 0);
        });

      toggle(0);
    })();

    /* Open/Close menu handlers */
    (function () {
      function toggle(menu, ehide, event) {
        var body = $('body');

        menu.toggle();
        body.unbind(ehide);
        event.stopPropagation();

        if (menu.is(':visible'))
          body.bind(ehide, function (event) {
            menu.hide();
            body.unbind(ehide);
            event.stopPropagation();
          });
      };

      /* top bar menu button */
      $('#menu-btn')
        .unbind('click.uf.toggle-menu')
        .bind(  'click.uf.toggle-menu', function (event) {
          toggle($('#menu-list'), 'click.uf.hide-menu', event);
        });

      /* context menu (right-click) */
      $('#userfiles_table')
        .undelegate('.dt-sel-row', 'contextmenu.uf.toggle-context')
        .delegate(  '.dt-sel-row', 'contextmenu.uf.toggle-context', function (event) {
          /* keep the browser's context menu on links (anchors) */
          if (event.target.tagName.toLowerCase() == 'a') return;

          var menu     = $('#userfiles_context_menu'),
              checkbox = $(this).find('.dt-sel-check').first();

          toggle(menu, 'context.uf.hide-context, click.uf.hide-context', event);
          menu.offset({ top: event.pageY, left: event.pageX });

          event.preventDefault();

          /* select the right-clicked element */
          if (!checkbox.prop('checked'))
            checkbox
              .prop('checked', true)
              .trigger('change');
        });
    })();

    $('#userfiles_context_menu, #static-actions, #dynamic-actions, #menu-actions')
      /* Dialog-bound buttons/items */
      .undelegate('.act-btn[data-dialog], .act-item[data-dialog]', 'click.uf.dlg-bound')
      .delegate(  '.act-btn[data-dialog], .act-item[data-dialog]', 'click.uf.dlg-bound', function () {
        var dialog = $(this).data('dialog');

        if (dialog) $('#' + dialog).trigger('open.uf', [this]);
      })
      /* Link-bound buttons/items */
      .undelegate('.act-btn[data-url], .act-item[data-url]', 'click.uf.url-bound')
      .delegate(  '.act-btn[data-url], .act-item[data-url]', 'click.uf.url-bound', function () {
        var elem = $(this),
            cfrm = elem.data('confirm-dlg');

        var params = {
          url:      elem.data('url'),
          method:   elem.data('method')    || 'GET',
          dataType: elem.data('data-type') || 'script',
          ajax:     elem.data('ajax')      || false,
          withSelection:  elem.data('with-selection'),
          emptySelection: elem.data('empty-selection')
        };

        if (cfrm)
          $('#' + cfrm).trigger('open.uf', [this, {
            action: elem.data('confirm-act') || null,
            accept: function () { userfiles.request(params); },
          }]);
        else
          userfiles.request(params);
      });

    /* Rename action button/context menu item */
    $('#ren-btn, #ren-ctx')
      .unbind('click.uf.start-rename')
      .bind(  'click.uf.start-rename', function () {
        userfiles.trigger('rename-start.uf-ren');
      });

    /* Edit custom filter button */
    $('#filters-menu')
      .undelegate('.filter-edit', 'click.uf.dlg-filter-edit')
      .delegate(  '.filter-edit', 'click.uf.dlg-filter-edit', function (event) {
        event.stopPropagation();
        $('#filter-dialog').trigger('open.uf', [this]);
      });
  }).find('#menu_bar').trigger('new_content');

  /* Dialogs */
  userfiles.delegate('#userfiles_dialogs', 'new_content', function () {
    /* Dialog button icons */
    var icons = {
      'Done':    'ui-icon-check',
      'Apply':   'ui-icon-check',
      'Proceed': 'ui-icon-play',
      'Cancel':  'ui-icon-closethick',
      'Close':   'ui-icon-closethick',
      'Upload':  'ui-icon-arrowthick-1-n',
      'Copy':    'ui-icon-copy',
      'Move':    'ui-icon-arrowreturnthick-1-e',
      'Delete':  'ui-icon-trash',
      'Create':  'ui-icon-plusthick',
    };

    /* Generic dialog properties and handlers */
    $('.dlg-dialog').dialog({
      autoOpen:    false,
      resizable:   false,
      modal:       true,
      width:       'auto',
      height:      'auto',
      dialogClass: 'dlg-ovfl',
      open: function () {
        $(this)
          .siblings('.ui-dialog-buttonpane')
          .find('button')
          .each(function () {
            var icon = icons[$(this).text()];

            if (icon) $(this).button({ icons: { primary: icon } });
          });
      }
    });

    /* Open/close events */
    $('body')
      .undelegate('.dlg-dialog', 'open.uf.dlg-open')
      .delegate(  '.dlg-dialog', 'open.uf.dlg-open', function () {
        $(this).dialog('open');
      })
      .undelegate('.dlg-dialog', 'close.uf.dlg-close')
      .delegate(  '.dlg-dialog', 'close.uf.dlg-close', function () {
        if ($(this).data('close-state'))
          $(this).removeData('close-state');
        else
          $(this)
            .data('close-state', 1)
            .dialog('close');
      })
      .undelegate('.dlg-dialog', 'dialogclose.uf.dlg-close-chain')
      .delegate(  '.dlg-dialog', 'dialogclose.uf.dlg-close-chain', function () {
        if ($(this).data('close-state'))
          $(this).removeData('close-state');
        else
          $(this)
            .data('close-state', 1)
            .trigger('close.uf');
      });

    /* Chosen select box plugin */
    $('#up-tag, #pp-tag').chosen({
      no_results_text: "Press Enter to add: ",
      width: '200px'
    });

    /* Tri-state checkboxes (unset, unchecked, checked) */
    $('.dlg-dialog')
      .undelegate('.dlg-chk.dlg-tri-state', 'change.uf.switch-state')
      .delegate(  '.dlg-chk.dlg-tri-state', 'change.uf.switch-state', function (event) {
        event.preventDefault();

        if ($(this).hasClass('dlg-unset'))
          $(this)
            .attr('name', $(this).data('name'))
            .removeClass('dlg-unset')
            .prop('checked', true);

        else if (this.checked)
          $(this)
            .removeAttr('name')
            .addClass('dlg-unset')
            .prop('checked', false);
      });

    /* Disable 'Enter' key form submission in dialogs */
    $('.dlg-dialog')
      .undelegate('form', 'keypress.uf.enter-submit')
      .delegate(  'form', 'keypress.uf.enter-submit', function (event) {
        if (event.keyCode === 13) event.preventDefault();
      });

    /* Confirmation dialogs */
    $('.dlg-cfrm')
      .unbind('open.uf.cfrm-open')
      .bind(  'open.uf.cfrm-open', function (event, source, settings) {
        if (!settings) settings = {};

        var dialog  = $(this),
            accept  = settings.accept || $.noop,
            cancel  = settings.cancel || $.noop,
            action  = settings.action || dialog.data('action') || 'Accept',
            buttons = {};

        buttons['Cancel'] = function (event) {
          dialog.trigger('close.uf');
          dialog.dialog('option', 'buttons', {});

          cancel(event);
        };

        buttons[action] = function (event) {
          dialog.trigger('close.uf');
          dialog.dialog('option', 'buttons', {});

          accept(event);
        };

        dialog.dialog('option', 'buttons', buttons);
      });

    /* Upload dialog */
    (function () {
      var upload_button = undefined;

      $('#upload-dialog')
        .dialog('option', 'buttons', {
          'Cancel': function (event) {
            $(this).trigger('close.uf');
          },
          'Upload': function (event) {
            var dialog = $(this);

            dialog.trigger('close.uf');
            userfiles.upload(dialog.children('form')[0])
              .then(userfiles.refresh);
          }
        })
        .unbind('open.uf.up-open')
        .bind(  'open.uf.up-open', function () {
          if (!upload_button)
            upload_button = $('#upload-dialog')
              .parent()
              .find(':button:contains("Upload")');

          upload_button
            .toggleClass('ui-state-disabled', true)
            .prop('disabled', true);

          $('#up-file').trigger('click');
        });

      if (!$('#up-alt-help').length) {
        var helplink = $('#up-alt-help-link').data('link');
        if (helplink !== undefined) {
           helplink = $('<a>').attr('href',helplink).html('Large datasets?');
           $('#upload-dialog ~ .ui-dialog-buttonpane')
             .prepend( $('<span id="up-alt-help">').append(helplink) )
        }
      }

      if (window.FileReader && $('#upload-dialog').data('max-upload-size'))
        /* check selected files against upload limit */
        $('#upload-dialog')
          .undelegate('#up-file', 'change.uf.up-limit')
          .delegate(  '#up-file', 'change.uf.up-limit', function () {
            var max = parseInt($('#upload-dialog').data('max-upload-size'));

            var visible = (
              this.files && this.files[0] &&
              max && this.files[0].size > max
            );

            $('#up-file-warn').css({
              visibility: visible ? 'visible' : 'hidden'
            });

            upload_button
              .toggleClass('ui-state-disabled', visible)
              .prop('disabled', visible);
          });

      $('#upload-dialog')
        /* file type auto-detection */
        .undelegate('#up-type', 'change.uf.up-arch-detect')
        .delegate(  '#up-type', 'change.uf.up-arch-detect', function (event) {
          if (!event.namespace) {
            $('#up-type-auto').hide();
            $('#up-type-unknown').css({ visibility: 'hidden' });
          }

          /* FIXME not exactly a solid check for an archive-like file type... */
          $('#up-ex-container').toggle(/Archive$/.test($(this).val()));
        })
        .undelegate('#up-file', 'change.uf.up-type-detect')
        .delegate(  '#up-file', 'change.uf.up-type-detect', function (event) {
          var url = $('#upload-dialog').data('type-detect-url');
          if (!url) return;

          $.post(url, { file_name: $(this).val() }, function (data) {
            /* FIXME SingleFile is hopefully the correct fallback... */
            var known = (data != 'SingleFile');
            if (!known) $('#up-opt-toggle').prop('checked', true);

            $('#up-type-auto').toggle(known);
            $('#up-type-unknown').css({
              visibility: known ? 'hidden' : 'visible'
            });

            $('#up-type').val(data).trigger('change.uf');
          });
        })
        /* only activate the upload button if a file is selected */
        .undelegate('#up-file', 'change.uf.toggle-up-btn')
        .delegate(  '#up-file', 'change.uf.toggle-up-btn', function () {
          var selected = !!$(this).val();

          upload_button
            .toggleClass('ui-state-disabled', !selected)
            .prop('disabled', !selected);
        });
    })();

    /* Copy/Move dialog */
    $('#cpmv-dialog')
      .unbind('open.uf.cpmv-open')
      .bind(  'open.uf.cpmv-open', function (event, source) {
        /* FIXME not exactly a clean way to detect if moving or copying... */
        var move    = $(source).is('#move-btn') || $(source).is('#move-ctx'),
            dialog  = $(this),
            buttons = {},
            title   = undefined;

        title = (move ? 'Move' : 'Copy') + ' - ' + formatted_selection();

        buttons['Cancel'] = function (event) {
          dialog.trigger('close.uf');
        };

        buttons[(move ? 'Move' : 'Copy')] = function (event) {
            userfiles[move ? 'move' : 'copy'](dialog.children('form')[0]);
            dialog.trigger('close.uf');
          };

        dialog
          .dialog('option', 'title', title)
          .dialog('option', 'buttons', buttons);
      });

    /* Custom filters dialog */
    $('#filter-dialog')
      .unbind('open.uf.filter-open')
      .bind(  'open.uf.filter-open', function (event, source) {
        var edit    = !$(source).is('#filter-new'),
            dialog  = $(this),
            buttons = {},
            title   = undefined;

        /* fetch the matching custom filters form */
        $.get($(source).data('overlay-url'), function (html) {
          var contents = $(html);
          contents.find('input[type="submit"]').remove();

          dialog
            .html(contents)
            .dialog('option', 'position', {
              my: 'center', at: 'center center+15%', of: window
            });
        });

        title = (edit ? 'Edit custom filter' : 'New custom filter');

        buttons['Cancel'] = function () {
          dialog.trigger('close.uf');
        };

        /* generic filter action handler generator */
        var handle = function (action) {
          return function (event) {
            var form = action === 'add'
              ? 'form#new_custom_filter'
              : 'form#edit_custom_filter';

            dialog.trigger('close.uf');
            userfiles.filters[action]($(form)[0])
              .then(userfiles.refresh);
          }
        };

        if (edit) {
          buttons['Apply']  = handle('update');
          buttons['Delete'] = {
            text:    'Delete',
            'class': 'dlg-left-button',
            click: handle('remove')
          };
        } else {
          buttons['Create'] = handle('add');
        }

        dialog
          .dialog('option', 'title', title)
          .dialog('option', 'buttons', buttons);
      });

    /* Tags dialog */
    $('#tag-dialog')
      .dialog('option', 'buttons', {
        'Done': function (event) {
          $(this).trigger('close.uf');
        }
      })
      /* remove the initial button focus */
      .unbind('open.uf.tag-button-focus')
      .bind(  'open.uf.tag-button-focus', function () {
        $(this).find('button').blur();
      })
      /* refresh the main index if tags changed (dirty flag) */
      .unbind('close.uf.tag-refresh')
      .bind(  'close.uf.tag-refresh', function () {
        var dialog = $(this);

        if (dialog.data('dirty'))
          userfiles.refresh().then(function () {
            dialog.removeData('dirty');
          });
      })
      /* swap a tag's name label for an input textbox on click */
      .undelegate('.tag-body .tag-txt-name', 'click.uf.tag-swap-iname')
      .delegate(  '.tag-body .tag-txt-name', 'click.uf.tag-swap-iname', function () {
        var input = $('<input type="text" />')
          .addClass('tag-in-name')
          .data('old-value', $(this).text())
          .val($(this).text());

        $('#tag-dialog').find('.tag-body .tag-in-name').blur();

        $(this).replaceWith(input);
        input.focus();
      })
      /* swap the name label back when done editing */
      .undelegate('.tag-body .tag-in-name', 'blur.uf.tag-swap-lname, keyup.uf.tag-swap-lname')
      .delegate(  '.tag-body .tag-in-name', 'blur.uf.tag-swap-lname, keyup.uf.tag-swap-lname', function (event) {
        if (typeof event.keyCode !== 'undefined' && event.keyCode !== 13)
          return;

        var id   = $(this).closest('.tag-row').data('id'),
            name = $(this).val(),
            old  = $(this).data('old-value');

        $(this)
          .removeData('old-value')
          .replaceWith(
            $('<span class="tag-txt-name">')
              .text(name)
          );

        if (name === old) return;

        userfiles.tags.update(id, { name: name })
          .done(function () { $('#tag-dialog').data('dirty', 1);    })
          .fail(function () { $('#tag-dialog').trigger('close.uf'); });
      })
      /* swap a tag's project label for a drop-down menu on click */
      .undelegate('.tag-body .tag-txt-prj', 'click.uf.tag-swap-iprj')
      .delegate(  '.tag-body .tag-txt-prj', 'click.uf.tag-swap-iprj', function () {
        $(this).replaceWith(
          $('#tag-mov-prj')
            .trigger('blur.uf')
            .data('old-value', $(this).data('value'))
            .val($(this).data('value'))
            .show()
        );
      })
      /* swap the project label back when done editing */
      .undelegate('.tag-body .tag-in-prj', 'blur.uf.tag-swap-lprj')
      .delegate(  '.tag-body .tag-in-prj', 'blur.uf.tag-swap-lprj', function () {
        var id    = $(this).closest('.tag-row').data('id'),
            group = $(this).val(),
            old   = $(this).data('old-value');

        $(this)
          .removeData('old-value')
          .replaceWith(
            $('<span class="tag-txt-prj">')
              .text($(this).find(':selected').text())
              .data('value', group)
          )
          .appendTo('#tag-dialog > form')
          .hide();

        if (group === old) return;

        userfiles.tags.update(id, { group_id: group })
          .done(function () { $('#tag-dialog').data('dirty', 1);    })
          .fail(function () { $('#tag-dialog').trigger('close.uf'); });
      })
      /* remove an existing tag */
      .undelegate('.tag-body .tag-act', 'click.uf.tag-remove')
      .delegate(  '.tag-body .tag-act', 'click.uf.tag-remove', function (event) {
        var row = $(this).closest('.tag-row');
        event.preventDefault();

        $('#tag-del-confirm').trigger('open.uf', [this, {
          name:   row.find('.tag-name').text().trim(),
          accept: function (event) {
            userfiles.tags.remove(row.data('id'))
              .done(function () {
                $('#tag-dialog').data('dirty', 1);
                row.remove();
              })
              .fail(function () {
                $('#tag-dialog').trigger('close.uf');
              });
          }
        }]);
      })
      /* validate the tag name to activate the add-tag button */
      .undelegate('.tag-add .tag-in-name', 'input.uf.tag-name-check')
      .delegate(  '.tag-add .tag-in-name', 'input.uf.tag-name-check', function (event) {
        var valid = /^\w+$/.test($(this).val());

        $(this)
          .toggleClass('tag-invalid', !valid && !!$(this).val())
          .closest('.tag-row')
          .find('.tag-act > .ui-icon')
          .removeAttr('disabled')
          .prop('disabled', !valid);
      })
      /* add a new tag */
      .undelegate('.tag-add .tag-act', 'click.uf.tag-add')
      .delegate(  '.tag-add .tag-act', 'click.uf.tag-add', function (event) {
        var form      = $(this).closest('form'),
            indicator = $(this).siblings('.tag-ind').find('.ui-icon');
        event.preventDefault();

        indicator.css({ visibility: 'visible' });
        userfiles.tags.add({
          name:     form.find('.tag-add .tag-in-name').val(),
          group_id: form.find('.tag-add .tag-in-prj').val()
        })
          .done(function () {
            userfiles.refresh().then(function () {
              indicator.css({ visibility: 'hidden' });
            });
          })
          .fail(function () {
            $('#tag-dialog').trigger('close.uf');
            indicator.css({ visibility: 'hidden' });
          });
      });

    /* Properties dialog */
    $('#prop-dialog')
      .dialog('option', 'buttons', {
        'Cancel': function (event) {
          $(this).trigger('close.uf');
        },
        'Apply': function (event) {
          var dialog = $(this);

          dialog.trigger('close.uf');
          userfiles.update(dialog.children('form')[0]);
        }
      })
      .unbind('open.uf.prop-open')
      .bind(  'open.uf.prop-open', function () {
        $(this).dialog('option', 'title',
          'File properties - ' + formatted_selection()
        );
      })
      .undelegate('#pp-tag-clr', 'change.uf.prop-tag-clear')
      .delegate(  '#pp-tag-clr', 'change.uf.prop-tag-clear', function () {
        var checked = $(this).prop('checked');

        $('#pp-tag')
          .val('')
          .prop('disabled', checked)
          .attr('data-placeholder', checked ? "No tags" : "Keep current tags")
          .trigger('chosen:updated');
      });

    /* New collection dialog */
    $('#collection-dialog')
      .dialog('option', 'buttons', {
        'Cancel': function (event) {
          $(this).trigger('close.uf');
        },
        'Create': function (event) {
          var dialog = $(this);

          dialog.trigger('close.uf');
          userfiles.create_collection(dialog.children('form')[0]);
        }
      })
      .unbind('open.uf.col-open')
      .bind(  'open.uf.col-open', function () {
        $(this).dialog('option', 'title',
          'New collection - ' + formatted_selection()
        );
      })
      .undelegate('#co-name', 'input.uf.co-name-check')
      .delegate(  '#co-name', 'input.uf.co-name-check', function () {
        var valid = /^\w[\w~!@#%^&*()-+=:[\]{}|<>,.?]*$/.test($(this).val());

        $('#co-invalid-name').css({
          visibility: valid ? 'hidden' : 'visible'
        });

        $('#collection-dialog')
          .parent()
          .find(':button:contains("Create")')
          .prop('disabled', !valid)
          .toggleClass('ui-state-disabled', !valid);
      });

    /* Delete files confirmation dialog */
    $('#delete-confirm')
      .unbind('open.uf.del-cfrm-open')
      .bind(  'open.uf.del-cfrm-open', function (event) {
        $(this).find('.dlg-cfrm-cnt').text(count_selection().toString());
      });

    /* Delete tag confirmation dialog */
    $('#tag-del-confirm')
      .unbind('open.uf.tdel-cfrm-open')
      .bind(  'open.uf.tdel-cfrm-open', function (event, source, settings) {
        $(this).find('.dlg-cfrm-obj').text((settings && settings.name) || '?');
      });

    /*
     * Allow adding new tags in Chosen select boxes. Note that this snippet only
     * deals with adding them to the select box; the tags are actually added
     * just before the form is sent in the corresponding action.
     */
    $('#up-tag, #pp-tag')
      .each(function () {
        var select = $(this),
            chosen = select.data('chosen');

        chosen.search_field
          .unbind('keyup.uf.chosen-tag-add')
          .bind(  'keyup.uf.chosen-tag-add', function (event) {
            if (event.which != 13 || !chosen.dropdown.find('li.no-results').length)
              return;

            select
              .append($('<option value="-1" selected>').text($(this).val()))
              .trigger('chosen:updated');
          });
      });
  }).find('#userfiles_dialogs').trigger('new_content');

  /* Rename action (special event + UI) */
  (function () {
    /*
     * +rename-start+ event (namespace: uf-ren)
     * Present on the main userfiles interface, start editing (renaming) the
     * currently selected userfile. Only a single userfile must be selected.
     */
    userfiles.bind('rename-start.uf-ren', function (event) {
      var checked = $('input[name="file_ids[]"]:checked');
      if (checked.length !== 1) return;

      var cell = checked.parent().siblings('.name'),
          link = cell.find('a');

      $('.rename-fld').trigger('done.uf-ren');

      $('#userfiles_table').bind('click.uf-ren', function (event) {
        if ($(event.target).hasClass('rename-fld')) return;

        $('.rename-fld').trigger('done.uf-ren');
      });

      var input = $('<input class="rename-fld" />')
        .data('id', cell.closest('tr').data('id'))
        .data('old-value', link.text())
        .val(link.text());

      cell
        .wrapInner('<div class="rename-hid" style="display:none">')
        .append(input);

      input.focus();
    });

    /* Remove the rename textbox and send off an update once done editing */
    userfiles.delegate('.rename-fld', 'done.uf-ren keyup.uf-ren', function (event) {
      if (typeof event.keyCode !== 'undefined' && event.keyCode !== 13)
        return;

      var input  = $(this),
          hidden = input.siblings('.rename-hid'),
          link   = hidden.find('a');

      if (input.val() !== input.data('old-value'))
        userfiles.rename(input.data('id'), input.val());

      $('#userfiles_table').unbind('click.uf-ren');

      link.text(input.val());
      input.parent().html(hidden.html());
    });
  })();

  /* Fetch the current selection count */
  function count_selection() {
    var checked = $('input[name="file_ids[]"]:checked').length,
        persistent = parseInt($('.psel-count').text());

    return persistent || checked || 0;
  };

  /* Current selection count as a nice descriptive line */
  function formatted_selection() {
    var count = count_selection();

    if (!count) return '(no files)';

    return '(' + count + ' file' + (count == 1 ? '' : 's') + ')';
  };

  /*
   * Clear the current (persistent) selection. Also updates the UI and form
   * elements accordingly if +bare+ is specified as false (defaults to true;
   * UI and form elements stay as-is). See the +clear+ event of the persistent
   * selection module for more information.
   *
   * FIXME could cause issues if the IndexedDB transaction is cancelled by a
   * page refresh...
   */
  function clear_selection(bare) {
    if (typeof bare === 'undefined') bare = true;

    $('.persistent-selection').trigger('clear.psel', [bare]);
  };

  /* Attach a jQuery Deferred object on a call to +fcn+ */
  function defer(fcn) {
    var deferred = jQuery.Deferred();

    setTimeout(function () {
      fcn();
      deferred.resolve();
    }, 0);

    return deferred;
  };

  /*
   * Submit an HTML form +form+ (as a jQuery object) using AJAX, returning
   * a jQuery Deferred object. This function is mainly a thin wrapper around
   * the jQuery Form plugin's own ajaxSubmit to bind a jQuery Deferred object
   * to the request to have a consistent interface to binding request callbacks.
   * Note that arrays of callbacks are not supported in +settings+.
   */
  function ajax_submit(form, settings) {
    var deferred = jQuery.Deferred();
    settings = settings || {};

    if (settings.success)
      deferred.done(settings.success);

    if (settings.error)
      deferred.fail(settings.error);

    if (settings.complete)
      deferred.then(settings.complete);

    form.ajaxSubmit($.extend(settings, {
      success: function (data, status, xhr) {
        deferred.resolve(data, status, xhr);
      },
      error: function (xhr, status, error) {
        deferred.reject(xhr, status, error);
      },
      complete: $.noop
    }));

    return deferred;
  };

  /* Extremely crude and simplistic XML serializer */
  function to_XML(obj) {
    /* Escape an XML value +s+ */
    function escape_xml(s) {
      return s.replace(/[<>&'"]/g, function (c) {
        switch (c) {
        case '<': return '&lt;';
        case '>': return '&gt;';
        case '&': return '&amp;';
        case "'": return '&apos;';
        case '"': return '&quot;';
        }
      });
    };

    /* Recursively serialize a JS object +o+ */
    function serialize_xml(o) {
      if ($.isArray(o))
        return $.map(o, function (v) {
          if ($.isArray(v) || $.isPlainObject(v))
            return serialize_xml(v);

          return '<value>' + escape_xml(v.toString()) + '</value>';
        }).join('');

      if ($.isPlainObject(o))
        return $.map(o, function (v, k) {
          return '<' + k + '>' + serialize_xml(v) + '</' + k + '>';
        }).join('');

      return escape_xml(o.toString());
    };

    return '<?xml version="1.0" encoding="UTF-8"?>' + serialize_xml(obj);
  };

  /*
   * Upload the given file-containing HTML +form+ via AJAX, showing a nice
   * dialog with progress bar as the file is uploaded.
   */
  function ajax_upload(form) {
    var dialog, progress, label, start_time;

    /* Send the upload */
    return $.ajax({
      url:         form.action,
      type:        form.method,
      data:        new FormData(form),
      cache:       false,
      contentType: false,
      processData: false,
      headers:     { 'Accept': 'application/json' },
      xhr: function () {
        var xhr = $.ajaxSettings.xhr();
        xhr.upload.onloadstart = onloadstart;
        xhr.upload.onprogress  = onprogress;
        xhr.upload.onloadend   = onloadend;
        return xhr;
      }
    });

    /* The upload started; show a nice progress bar. */
    function onloadstart(event) {
      label    = $('<div class="label"></div>');
      progress = $('<div class="bar">').append(label);
      dialog   = $('<div class="progress-dialog">').append(progress);

      progress.progressbar({ value: false });
      dialog.dialog({
        title:         'Uploading...',
        modal:         true,
        resizable:     false,
        draggable:     false,
        closeOnEscape: false,
        width:         400,
        dialogClass:   'no-close'
      });

      start_time = new Date();
      onprogress(event);
    };

    /* Some progress has been made on the upload; update the progress bar. */
    function onprogress(event) {
      if (!event.lengthComputable) return;

      var elapsed = (new Date() - start_time) / 1000,
          loaded  = human_readable(event.loaded),
          total   = human_readable(event.total),
          speed   = elapsed ? human_readable(event.loaded / elapsed) + "/s" : "?";

      progress.progressbar('value', event.loaded / event.total * 100);
      label.text(loaded + " / " + total + " (" + speed + ")");
    };

    /* The upload is done; remove the progress bar. */
    function onloadend(event) {
      dialog.dialog('close');
      dialog.remove();
    };

    /* Format a byte size into something easier to read (65536 -> 64K) */
    function human_readable(byte_size) {
      var sizes = [ 1,   1 << 10, 1 << 20, 1 << 30 ],
          names = [ 'B', 'KB',    'MB',    'GB' ];

      for (var i = sizes.length - 1; i > 0; --i)
        if (10 * sizes[i] < byte_size)
          return (byte_size / sizes[i] | 0) + names[i];

      return byte_size + names[0];
    };
  };
});
