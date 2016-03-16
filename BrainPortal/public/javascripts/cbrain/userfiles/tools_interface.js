
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

$(document).ready(function() {

  var selected_tags = {}; // this object has the list of currently selected tags

  $("#toolsDialog").dialog({
    autoOpen:    false,
    resizable:   false,
    modal:       true,
    show:        "blind",
    hide:        "blind",
    width:       600,
    height:      600,
    dialogClass: 'toolsDialogClass'
  });

  // This get executed when the dialog is invoked/opened
  $("#toolsDialog").bind('open.uf', function () {

    $(".tag_checkbox").removeAttr('checked');
    $("#showAllTools").attr('checked', true);
    $('#tool_version_selector').empty();
    $("#searchToolSelectionBox").val("");
    $('#toolSelectTable tr').show();
    $("#toolsDialog").dialog( "open");

    return false;
  });

  // Handles the search box; is called after each key stroke
  $("#searchToolSelectionBox").keyup(function(){
    applyTagsAndSearch();
  });

  // This function is called when the all tools checkbox changes state
  $("#showAllTools").change(function() {
    $(".tag_checkbox").not("#showAllTools").attr("checked",false);
    selected_tags = {};
    $('#toolSelectTable tr').toggle($(this).is(":checked"));
  });

  // This function is called when a tag checkbox changes state
  $(".tag_checkbox:not(#showAllTools)").change(function() {
    var selectedCheckBox = $(this);
    var tagname          = selectedCheckBox.data('tagname');

    if (selectedCheckBox.is(":checked")){
      $("#showAllTools").attr('checked', false);
      selected_tags[tagname]=true;
    } else {
      delete selected_tags[tagname];
    }
    applyTagsAndSearch();
  });

  // This function applies the tags and search word that are currently in the tools table
  function applyTagsAndSearch(){

    var searchval   = $("#searchToolSelectionBox").val().trim().toLowerCase()

    $('#tool_version_selector').empty();

    // Filter by active tags
    applyTags();

    // Filter further by what's in the search box
    if (searchval.length > 0) {
      $('#toolSelectTable tr:visible').each(function () {
        if ($(this).find('.toolsLink').text().toLowerCase().indexOf(searchval) == -1)
          $(this).hide();
      });
    }

  }

  // This function applies the tags that are currently selected in the table
  // If no tags are selected, shows all the tools.
  function applyTags(){
    if (jQuery.isEmptyObject(selected_tags)) { // if there are no selected tags...
      $('#toolSelectTable tr').show();
      $("#showAllTools").attr('checked', true);
      return;
    }
    $('#toolSelectTable tr').hide();
    $('#toolSelectTable tr[data-taglist]').filter(function() {
      var tr_element = $(this);
      var taglist    = tr_element.data('taglist').split(',');
      for (var i = 0; i < taglist.length; i++) {
        if (selected_tags[taglist[i]]) {
          tr_element.show();
          break;
        }
      }
    });
  }

  // This is executed when a tool link is clicked
  // It performs an ajax request to the server to get the tool versions currently available
  $('#toolSelectTable td').click(function(e) {
    var link = $(this).find('.toolsLink');

    if (e.target != this && e.target != link[0]) return;

    $("#tool_version_selector")
      .html('<span class="loading_message">Loading...</span>')
      .appendTo("#tool_" + link.data("toolId"));

    $.ajax({
      type: "GET",
      url: "/tools/tool_config_select",
      data : { tool_id: link.data("toolId") },
      dataType: "html",
      success: function (data) {
        $("#tool_version_selector")
          .html(data)
          .trigger('new_content');
      }
    });

    return false;
  });

  $('#tool_version_selector').delegate('input.launch_tool', 'click', function (event) {
    event.preventDefault();

    $('#userfiles_menus_and_filelist').children('form')
      .append($('#tool_version_selector').hide())
      .attr('action', $(this).data('url'))
      .attr('method', 'POST')
      .submit();
  });

  $("#tool_version_selector").delegate("#showAdditionalToolInfo", 'click', function (e) {
    $(".additionalToolInfo").show();
    return false;
  });


});





