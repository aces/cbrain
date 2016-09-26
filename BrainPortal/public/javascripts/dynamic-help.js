
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



$('.dynamic-help-btn').on('click', function(event){
  var help_doc_key = $(this).attr('data-key');

  alert(help_doc_key);
});

$('#dynamic_help_modal')


// $(document).delegate('div.help_document_popup', 'new_content', function () {
//   "use strict";

//   var popup = $(this);


//   /* Server-side info about the help document */
//   var server_doc = {
//     id:   <%= j (@doc.id || "null").to_s %>,
//     key: "<%= j  @doc.key  %>",
//     url: "<%= j (@doc.id ? doc_path(@doc) : docs_path()) %>"
//   };

//   /* Make sure we have Showdown (Markdown -> HTML) and CodeMirror (editor) */
//   if (typeof Showdown === 'undefined')
//     $('head').append("<%= j (javascript_include_tag "showdown") %>");

//   if (typeof CodeMirror === 'undefined')
//     $('head').append("<%= j (javascript_include_tag "codemirror") %>");

//   var base_content   = popup.find('script.raw').html().trim(),
//       converter      = new Showdown.converter(),
//       editor         = undefined,
//       action         = undefined,
//       divs           = {
//         editor:   popup.find('div.editor'),
//         empty:    popup.find('div.empty'),
//         content:  popup.find('div.contents')
//       },
//       buttons        = {
//         show:     popup.find('button.show'),
//         edit:     popup.find('button.edit'),
//         save:     popup.find('button.save'),
//         remove:   popup.find('button.remove')
//       };

//   buttons.show
//     .button({ icons: { primary: "ui-icon-search" } })
//     .unbind('click')
//     .click(show);

//   buttons.edit
//     .button({ icons: { primary: "ui-icon-pencil" } })
//     .unbind('click')
//     .click(edit);

//   buttons.save
//     .button({ icons: { primary: "ui-icon-check" } })
//     .unbind('click')
//     .click(save);

//   buttons.remove
//     .button({ icons: { primary: "ui-icon-closethick" } })
//     .unbind('click')
//     .click(remove);

//   if (server_doc.id) buttons.remove.show();
//   show();

//   /* Show the help document as HTML */
//   function show() {
//     var content = (editor ? editor.getValue() : base_content.trim());

//     divs.editor.hide();

//     if (content) {
//       divs.content.html(converter.makeHtml(content)).show();
//       divs.empty.hide();
//     } else {
//       divs.content.hide();
//       divs.empty.show();
//     }

//     popup.parent().dialog({ position: { my: 'center', at: 'center', of: window } });

//     $(this).hide();
//     buttons.edit.show();
//   };

//    Edit the document as Markdown
//   function edit() {
//     if (!editor) {
//       editor  = CodeMirror(divs.editor[0], {
//         mode:            'markdown',
//         tabMode:         'indent',
//         lineWrapping:    true,
//         lineNumbers:     true,
//         styleActiveLine: true,
//         theme:           'neo',
//       });

//       editor.setValue(base_content.trim());
//       editor.on('changes', function () { buttons.save.show(); });
//     }

//     divs.content.hide();
//     divs.empty.hide();
//     divs.editor.show();

//     editor.refresh();
//     editor.focus();

//     popup.parent().dialog({ position: { my: 'center', at: 'center', of: window } });

//     $(this).hide();
//     buttons.show.show();
//   };

//   /* Save the document on the server */
//   function save() {
//     toggle_button(buttons.save, "Saving...");

//     $.ajax({
//       url:      server_doc.url,
//       type:     server_doc.id ? 'PUT' : 'POST',
//       dataType: 'json',
//       data:     {
//         doc:      { key: server_doc.key },
//         contents: editor ? editor.getValue() : base_content
//       }
//     }).done(function (doc) {
//       if (!server_doc.id && doc.id)
//         server_doc.url += '/' + doc.id;
//       server_doc.id   = doc.id;

//       buttons.remove.show();
//       buttons.save.hide();
//     }).always(function () {
//       toggle_button(buttons.save, "Save");
//     });
//   };

//   /* Remove/delete the document */
//   function remove() {
//     toggle_button(buttons.remove, "Removing...");

//     $.ajax({
//       url:  server_doc.url,
//       type: 'DELETE'
//     }).done(function () {
//       var u          = server_doc.url;
//       server_doc.url = u.slice(0, u.lastIndexOf('/'));
//       server_doc.id  = null;

//       buttons.remove.hide();
//     }).always(function () {
//       toggle_button(buttons.remove, "Remove");
//     });
//   };

//   /* Enable/disable an UI button. Used to disable actions while making AJAX requests */
//   function toggle_button(button, label) {
//     var disabled = !button.prop('disabled');

//     button.button({
//       disabled: !disabled,
//       label:    label,
//       icons:    {
//         primary:   button.button('option').icons.primary,
//         secondary: !disabled ? "ui-icon-gear" : null
//       }
//     });
//   };
// });
