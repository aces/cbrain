
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

$(document).delegate('div#tool_version_selector', 'new_content', function (event) {
  "use strict";

  /* Only trigger when the main div is loaded */
  if (event.target != this) return;

  var launch_button       = $(this).find('input.launch_tool');
  if (launch_button.length === 0) return;

  var userfile_checkboxes = $("input[name='file_ids[]']");
  var tool_name           = launch_button.val().replace("Launch ", "");

  /* Do we have some files selected to launch the task on? */
  function have_selection() {
    return (
      userfile_checkboxes.is(':checked') ||
      parseInt($('.psel-count').text()) > 0
    );
  };

  launch_button
    .val((have_selection() ? "Launch " : "Prepare ") + tool_name)
    .unbind('click.launch_task')
    .bind('click.launch_task', function (event) {
      /* If we have userfiles selected, we can launch the task right away! */
      if (have_selection()) return;

      /* Otherwise, hide the dialog and show a nice bar to let the user pick files */
      $('#toolsDialog').dialog('close');

      event.preventDefault();
      event.stopPropagation();

      cbrain_userfile_launch_bar(tool_name, "No files selected", false, launch_button.data('url'));
    });

  cbrain_attach_userfile_checkboxes(userfile_checkboxes, tool_name, launch_button);
});

