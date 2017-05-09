
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
(function() {
  "use strict";

  /* Generic AJAX error handler */
  $(document).ajaxError(function (event, xhr, settings, error) {
    var flash = $('.flash_error'),
        xml   = $(xhr.responseXML);

    if (xhr.status === 0) return true;

    if (!flash.length)
      flash = $('<div class="flash_error">')
        .prependTo('#main');

    if (xhr.responseXML && xml.find('errors > error').length)
      flash.html(
        'Error performing request: <br />' +
        xml.find('errors > error')
          .map(function () { return $(this).text(); })
          .get()
          .join('<br />')
      );
    else
      flash.html(
        'Error sending background request: <br />' +
        'HTTP ' + xhr.status + ' ' + xhr.statusText + '<br />' +
        'The CBRAIN administrators have been alerted about this problem.'
      );

    return true;
  });

  /* Generic AJAX loading indicator */
  $(document)
    .ajaxStart(function () { $('#loading_image').show(); })
    .ajaxStop( function () { $('#loading_image').hide(); });

  function modify_target(data, target, options) {
    options = options || {};

    var current_target, new_content;
    var width, height;

    if (target) {
      new_content = $(data);
      if (target === "__OVERLAY__") {
        width = parseInt(options["width"], 10); // || 800);
        height = parseInt(options["height"], 10); // || 500);
        $("<div class='overlay_content'></div>").html(new_content).appendTo($("body")).dialog({
          position: 'center',
          width:  width  || 'auto',
          height: height || 'auto',
          close: function() {
            $(this).remove();
          }
        });
      } else {
        current_target = $(target);

        if (options["replace"]) {
          current_target.replaceWith(new_content);
        } else {
          current_target.html(new_content);
        }

        if (options["scroll_bottom"]) {
          current_target.scrollTop(current_target[0].scrollHeight);
        }
      }
      new_content.trigger("new_content");
    }
  }

  //Behaviours for newly loaded content that isn't triggered
  //by the user.
  //
  //This is for behaviours that can not be bound to live.
  //
  //NOTE: DO NOT USE .live() or .delegate() in here.
  function load_behaviour(event) {
    var loaded_element = $(event.target);

    /////////////////////////////////////////////////////////////////////
    //
    // UI Helper Methods see application_helper.rb for corresponding
    // helpers.
    //
    /////////////////////////////////////////////////////////////////////

    loaded_element.find(".scroll_bottom").each(function() {
      $(this).scrollTop(this.scrollHeight);
    });

    //All elements with the accordion class will be changed to accordions.
    loaded_element.find(".accordion").each(function() {
      $(this).accordion({
        active: false,
        collapsible: true,
        autoHeight: false
      });
    });


    //Sortable list of elements
    loaded_element.find(".sortable_list").each(function() {
      $(this).sortable();
    })
    loaded_element.find(".sortable_list").each(function() {
      $(this).disableSelection();
    });

    loaded_element.find(".slider_field").each( function() {
      var slider_text_field = $(this).children().filter("input");
      $(this).children().filter(".slider").slider({
        change: function(event, ui) {
          $(slider_text_field).val(ui.value);
        }
      });
    });

    loaded_element.find(".draggable_element").each( function() {
      $(this).draggable({
        connectToSortable: '#sortable',
        helper: 'clone',
        revert: 'invalid'
      });
    });

    loaded_element.find(".sortable_list ul, sortable_list li").each( function() {
      $(this).disableSelection();
    });

    // Tab Bar, div's of type tabs become tab_bars
    // See TabBar class
    loaded_element.find(".tabs").each( function() {
      $(this).tabs();
    });


    // //Prevent forms where submit buttons decide behaviour
    // //from submitting on 'enter'.
    // loaded_element.find("form").each(function() {
    //   var form = $(this);
    //   if (form.find("input[type=submit]").length > 1) {
    //     form.keypress(function(event) {
    //       if (event.keyCode == 13) event.preventDefault();
    //     });
    //   }
    // });

    loaded_element.find(".inline_text_field").each(function() {
      var inline_text_field = $(this);
      var data_type = inline_text_field.attr("data-type") || "script";
      var target = inline_text_field.attr("data-target");
      var method = inline_text_field.attr("data-method") || "POST";

      var form = inline_text_field.children("form")
      .hide()
      .ajaxForm({
        type: method,
        dataType: data_type,
        success: function(data) {
          modify_target(data, target);
        }
      });

      var input_field = form.find(".inline_text_input");
      var text = inline_text_field.find(".current_text");
      var trigger = inline_text_field.find(inline_text_field.attr("data-trigger"));

      var data_type = inline_text_field.attr("data-type") || "script";
      var target = inline_text_field.attr("data-target");
      var method = inline_text_field.attr("data-method") || "POST";

      trigger.click(function(event) {
        text.hide();
        form.show();
        input_field.focus();

        return false;
      });

      form.focusout(function(event) {
        text.show();
        form.hide();
      });

    });

    //Turns the element into a button looking thing
    loaded_element.find(".button").each( function() {
      $(this).button();
    });

    //Makes a button set, buttons that are glued together
    loaded_element.find(".button_set").each( function() {
      $(this).buttonset();
    });


    loaded_element.find(".button_with_drop_down > div.drop_down_menu").each(function(e) {
      var menu    = $(this);
      var button  = menu.closest(".button_with_drop_down");
      var keep_open = button.attr("data-open");
      if (keep_open !== "true") {
        menu.hide();
      }
    });

    loaded_element.find(".button_with_drop_down > div.drop_down_menu").find(".hijacker_submit_button").click(function(e) {
      loaded_element.find(".drop_down_menu:visible").siblings(".button_menu").click();
    });


    loaded_element.find(".button_with_drop_down").children(".button_menu").button({
      icons: {
        secondary: 'ui-icon-triangle-1-s'
      }
    }).click(function(event) {
      var menu = $(this).siblings(".drop_down_menu");
      if (menu.is(":visible")) {
        menu.hide();
      } else {
        loaded_element.find(".drop_down_menu:visible").hide();
        menu.show();
      }
    });


    /////////////////////////////////////////////////////////////////////
    //
    // Project button behaviour
    //
    /////////////////////////////////////////////////////////////////////

    loaded_element.find(".project_button").each(function(event) {
      var project_button = $(this);
      var project_details = project_button.find(".project_button_details");

      project_details.hide();

      project_button.mouseenter(function() {
        project_details.show();
      }).mouseleave(function() {
        project_details.hide();
      });

    }).mouseenter(function() {
      var project_button = $(this);

      project_button.css("-webkit-transform", "scale(1.3)");
      project_button.css("-moz-transform", "scale(1.3)");
      project_button.css("-o-transform", "scale(1.3)");
      project_button.css("-ms-transform", "scale(1.3)");
    }).mouseleave(function() {
      var project_button = $(this);

      project_button.css("-webkit-transform", "scale(1)");
      project_button.css("-moz-transform", "scale(1)");
      project_button.css("-o-transform", "scale(1)");
      project_button.css("-ms-transform", "scale(1)");
    }).mousedown(function(event) {
      if (event.target.nodeName === "A") {
        return true;
      }

      var project_button = $(this);

      project_button.css("-webkit-transform", "scale(1.2)");
      project_button.css("-moz-transform", "scale(1.2)");
      project_button.css("-o-transform", "scale(1.2)");
      project_button.css("-ms-transform", "scale(1.2)");
    }).mouseup(function() {
      var project_button = $(this);

      project_button.css("-webkit-transform", "scale(1.1)");
      project_button.css("-moz-transform", "scale(1.1)");
      project_button.css("-o-transform", "scale(1.1)");
      project_button.css("-ms-transform", "scale(1.1)");
    }).click(function(event) {
      if (event.target.nodeName === "A") {
        return true;
      }

      var project_button = $(this);
      var url = project_button.attr("data-href");
      var method = project_button.attr("data-method");
      var link = $("<a href=\"" + url + "\" data-method=\"" + method + "\"></a>");

      link.appendTo("body");
      link.click();
    });


    /////////////////////////////////////////////////////////////////////
    //
    // Delayed loading of content
    //
    /////////////////////////////////////////////////////////////////////

    function fetch_update(current_element, method, url, error_message, replace, data, scroll_bottom) {
      jQuery.ajax({
        type: method,
        url: url,
        dataType: 'html',
        data: data,
        success: function(data) {
          var new_content = $(data);
          if (replace === "true") {
            current_element.replaceWith(new_content);
          } else {
            current_element.html(new_content);
          }
          new_content.trigger("new_content");
          if (scroll_bottom) {
            current_element.scrollTop(current_element[0].scrollHeight);
          }
        },
        error: function(e) {
          if (!error_message) {
            error_message = "<span class='loading_message'>Error loading element</span>";
          }
          if (replace === "true") {
            current_element.replaceWith(error_message);
          } else {
            current_element.html(error_message);
          }
        },
        timeout: 50000
      });
    }

    function update_ajax_element(element) {
      var current_element = $(element);
      var method = current_element.attr("data-method") || "GET";
      var url = current_element.attr("data-url");
      var error_message = current_element.attr("data-error");
      var replace = current_element.attr("data-replace");
      var data = current_element.attr("data-data");
      var interval = current_element.attr("data-interval");
      var scroll_bottom = current_element.attr("data-scroll-bottom");

      if (data) data = jQuery.parseJSON(data);
      if (scroll_bottom === "false") scroll_bottom = false;

      if (interval) {
        interval = parseInt(interval, 10) * 1000;
        setInterval(function() {
          fetch_update(current_element, method, url, error_message, replace, data, scroll_bottom);
        }, interval);
      } else {
        fetch_update(current_element, method, url, error_message, replace, data, scroll_bottom);
      }
    }


    //See ajax_element() in application_helper.rb
    //The ajax element will have its contents loaded by the response from an
    //ajax request (so the element's conents will be loaded later with respect
    //to the rest of the page). If the "data-replace" attribute is set to "true"
    //the entire element will be replace an not just its contents.
    loaded_element.find(".ajax_element").each(function(index, element) {
      update_ajax_element(element);
    });

    loaded_element.find(".ajax_element_refresh_button").click(function() {
      var button = $(this);
      var target = $(button.attr("data-target"));
      update_ajax_element(target);

      return false;
    });

    //See script_loader() in application_helper.rb
    //Similar to above except that instead of loading html
    //it fetches javascript from the server that will be executed
    //update the page.
    loaded_element.find(".script_loader").each(function (index,element) {
      var current_element = $(element);
      current_element.css("display", "none");
      var url = current_element.attr("data-url");
      jQuery.ajax({
        dataType: 'script',
        url: url,
        timeout: 50000
      });
    });

    //Overlay dialogs
    //See overlay_dialog_with_button()
    loaded_element.find(".overlay_dialog").each( function(index,element) {
      var enclosing_div = $(this);
      var dialog_link = enclosing_div.children('.overlay_content_link');
      var dialog = enclosing_div.children(".overlay_content")
      var content_width = parseInt(dialog_link.attr('data-width'), 10);
      var content_height = parseInt(dialog_link.attr('data-height'), 10);

      dialog.dialog({
        autoOpen: false,
        position: "center",
        width:  content_width  || 'auto',
        height: content_height || 'auto'
      });

      dialog_link.click(function() {
        dialog.dialog('open');
        return false;
      });
    });

    loaded_element.find(".show_toggle_checkbox").each(function() {
      var checkbox = $(this);
      var show = checkbox.is(":checked");
      var target_element = $(checkbox.attr("data-target"));
      var slide_effect = checkbox.attr("data-slide-effect");
      var slide_duration = checkbox.attr("data-slide-duration") || "fast";
      var invert = checkbox.attr("data-invert");

      if (slide_duration !== "slow" && slide_duration !== "fast") {
        slide_duration = parseInt(slide_duration, 10);
      }

      if (invert === "true") {
        show = !show;
      }

      if (show) {
        target_element.show();
      } else {
        target_element.hide();
      }

      checkbox.change(function() {
        show = checkbox.is(":checked");
        if (invert === "true") {
          show = !show;
        }

        if (show) {
          if (slide_effect) {
            target_element.slideDown(slide_duration);
          } else {
            target_element.show();
          }
        } else {
          if (slide_effect) {
            target_element.slideUp(slide_duration);
          } else {
            target_element.hide();
          }
        }
      });

    });
  }

  $(function() {
    $("body").bind("new_content", load_behaviour);
    $("body").trigger("new_content");


    /////////////////////////////////////////////////////////////////////
    //
    // Ajax Pagination
    //
    /////////////////////////////////////////////////////////////////////

    function get_page_parameter(query_string) {
      if (!query_string) query_string = "";
      var page = query_string.match(/(\?|\&)(page\=\d+)(\&)?/);
      if (page) page = page[2];
      if (!page) page = "";

      return page;
    }

    $(document).delegate(".page_links > a", "click", function() {
      var link = $(this);
      var url = link.attr("href");
      var page_param = get_page_parameter(url);
      var pagination_div = link.closest(".pagination");

      url = window.location.protocol + "//" + window.location.host + window.location.pathname + "?" + page_param;

      var title  = "";
      if (page_param) {
        var page_num = page_param.match(/\d+/);
        if (page_num) title = "Page: " + page_num[0];
      }

      history.pushState({"paginating" : true}, "", url);
      $.ajax({
        url: url,
        dataType: "script"
      });

      return false;
    });

    $(window).bind("popstate", function(evt) {
      var state = evt.originalEvent.state || {};

      if (state.paginating) {
        var url = location.href;
        var page_param = get_page_parameter(url);

        url = window.location.protocol + "//" + window.location.host + window.location.pathname + "?" + page_param;
        $.ajax({
          url: url,
          dataType: "script"
        });
      }
    });

    var filter_header_timeout = null;

    $(document).delegate(".filter_header", "mouseenter", function() {

      if (filter_header_timeout) {
        clearTimeout(filter_header_timeout);
        filter_header_timeout = null;
      }

      var header = $(this);
      var target = $(header.attr("data-target"));
      var search = target.find(".filter_search");

      filter_header_timeout = setTimeout(function() {
        target.show();
        search.focus();
      }, 500);

      header.closest("th").mouseleave(function() {
        if (filter_header_timeout) {
          clearTimeout(filter_header_timeout);
          filter_header_timeout = null;
        }
        target.hide();
        return false;
      });

      return false;
    });

    $(document).delegate(".hover_open", "mouseenter", function() {
      var header = $(this);
      var target = $(header.attr("data-target"));

      target.show();
      header.mouseleave(function() {
        target.hide();
        return false;
      });

      return false;
     });

    $(document).delegate(".filter_search", "input", function() {
      var text_field = $(this);
      var cur_value  = text_field.val();
      var filter_list = text_field.closest(".filter_list");

      filter_list.find(".filter_item").each(function() {
        var filter = $(this);
        var link   = $(filter).find("a");

        if (link.html().match(new RegExp("^" + cur_value, "i"))) {
          filter.show();
        } else {
          filter.hide();
        }
      });
    }).delegate(".filter_search", "keypress", function(event) {
      if (event.keyCode === 13) {
        var text_field = $(this);
        var filter_link = text_field.closest(".filter_list").find(".filter_item a:visible").first();
        filter_link.focus();
        return false;
      }
    });

    $(document).delegate(".show_toggle", "click", function() {
      var current_element = $(this);
      var target_element = $(current_element.attr("data-target"));
      var alternate_text = current_element.attr("data-alternate-text");
      var slide_effect   = current_element.attr("data-slide-effect");
      var slide_duration   = current_element.attr("data-slide-duration");
      var current_text;

      if (slide_duration !== 'slow' && slide_duration !== 'fast') {
        slide_duration = parseInt(slide_duration, 10);
      }

      if (alternate_text) {
        current_text = current_element.html();
        current_element.attr("data-alternate-text", current_text);
        current_element.html(alternate_text);
      }

      if (target_element.is(":visible")) {
        if (slide_effect) {
          target_element.slideUp(slide_duration);
        } else {
          target_element.hide();
        }
      } else {
        if (slide_effect) {
          target_element.slideDown(slide_duration);
        } else {
          target_element.show();
        }
      }

      return false;
    });

    $(document).delegate(".inline_edit_field_link", "click", function() {
      var link = $(this);
      var visible = link.data("visible");
      var current_text = link.html();
      var alternate_text = link.data("alternate-text");
      var group = link.closest(".inline_edit_field_group");

      link.data("visible", !visible);

      if (!alternate_text) alternate_text = "Cancel";

      if (visible) {
        group.find(".inline_edit_field_default_text").show();
        group.find(".inline_edit_field_input").hide();
      } else {
        group.find(".inline_edit_field_default_text").hide();
        group.find(".inline_edit_field_input").show();
      }

      link.html(alternate_text);
      link.data("alternate-text", current_text);

      return false;
    });

    //Highlighting on resource list tables.
    $(document).delegate(".row_highlight", "mouseenter", function() {
      var element = $(this);
      element.data("original-color", element.css("background-color"));
      element.css("background-color", "#FFFFE5");
    });

    $(document).delegate(".row_highlight", "mouseleave", function() {
      var element = $(this);
      element.css("background-color", element.data("original-color"));
    });

    $(document).delegate(".ajax_link", "ajax:success", function(event, data, status, xhr) {
      var link     = $(this);
      var target   = link.attr("data-target");
      var datatype = link.attr("data-type");
      var remove_target = link.attr("data-remove-target");
      var other_options = {};

      if (link.attr("data-width")) other_options["width"] = link.attr("data-width");
      if (link.attr("data-height")) other_options["height"] = link.attr("data-height");
      if (link.attr("data-replace")) other_options["replace"] = link.attr("data-replace");

      if (remove_target) {
         $(remove_target).remove();
      } else if (datatype !== "script") {
        modify_target(data, target, other_options);
      }
    }).delegate(".ajax_link", "ajax:beforeSend", function(event, data, status, xhr) {
      var link = $(this);
      var loading_message = link.attr("data-loading-message");
      var target = link.attr("data-target");
      if (loading_message) {
        var loading_message_target = link.attr("data-loading-message-target");
        if (!loading_message_target) loading_message_target = target;
        $(loading_message_target).html(loading_message);
      }
    });

    $(document).delegate(".select_all", "click", function() {
      var header_box = $(this);
      var checkbox_class = header_box.attr("data-checkbox-class");

      $('.' + checkbox_class).each(function(index, element) {
        element.checked = header_box.prop('checked');
      });
    });

    $(document).delegate(".select_master", "change", function() {
      var master_select = $(this);
      var select_class = master_select.attr("data-select-class");
      var selection = master_select.find(":selected").text();

      $('.' + select_class).each(function(index, elem) {
        $(elem).find("option").attr("selected", false).each(function(index, elem) {
          var element = $(elem);
          if (element.html() === selection) element.attr("selected", "selected");
        });
      });
    });

    $(document).delegate(".request_on_change", "change", function() {
      var input_element        = $(this);
      var param_name           = input_element.attr("name");
      var current_value        = input_element.attr("value");
      var url                  = input_element.attr("data-url");
      var method               = input_element.attr("data-method");
      var target               = input_element.attr("data-target");
      var data_type            = input_element.attr("data-type");
      var update_text          = input_element.attr("data-loading-message");
      var optgroup_change      = input_element.attr("data-optgroup-change")
      var old_onchange_value   = input_element.data("old-onchange-value");
      var selected             = input_element.find("option:selected").parent();
      var optgroup_label       = selected.attr("label");
      var parameters = {};

      method = method || "GET";
      data_type = data_type || "html";

      if (optgroup_change && optgroup_label && optgroup_label === old_onchange_value) {
        return false;
      } else {
        input_element.data("old-onchange-value",optgroup_label);
      }

      if (target && update_text) {
        $(target).html(update_text);
      }

      parameters[param_name] = current_value;

      $.ajax({
        url       : url,
        type      : method,
        dataType  : data_type,
        success: function(data) {
          modify_target(data, target);
        },
        data: parameters
      });

      return false;
    });

    $(document).delegate(".submit_onchange", "change", function() {
      var select = $(this);
      var commit_value = select.attr("data-commit");
      var form   = select.closest("form");

      if (commit_value) {
        $("<input name=\"commit\" type=\"hidden\" value=\"" + commit_value +  "\">").appendTo(form);
      }

      form.submit();
    });


    //html_tool_tip_code based on xstooltip provided by
    //http://www.texsoft.it/index.php?%20m=sw.js.htmltooltip&c=software&l=it
    $(document).delegate(".html_tool_tip_trigger", "mouseenter", function(event) {
      var trigger = $(this);
      var tool_tip_id = trigger.attr("data-tool-tip-id");
      var tool_tip = $("#" + tool_tip_id);
      var offset_x = trigger.attr("data-offset-x") || '30';
      var offset_y = trigger.attr("data-offset-y") || '0';

      var x = trigger.position().left + parseInt(offset_x, 10);
      var y = trigger.position().top  + parseInt(offset_y, 10);

      // Fixed position bug.
      tool_tip.remove().appendTo(trigger.parent());

      tool_tip.css('top',  y + 'px');
      tool_tip.css('left', x + 'px');

      tool_tip.show();
    }).delegate(".html_tool_tip_trigger", "mouseleave", function(event) {
      var trigger = $(this);
      var tool_tip_id = trigger.attr("data-tool-tip-id");
      var tool_tip = $("#" + tool_tip_id);

      tool_tip.hide();
    });

    /////////////////////////////////////////////////////////////////////
    //
    // Form hijacking helpers
    //
    /////////////////////////////////////////////////////////////////////

    //Forms with the class "ajax_form" will be submitted as ajax requests.
    //Datatype and target can be set with appropriate "data" attributes.
    $(document).delegate(".ajax_form", "ajax:success", function(event, data, status, xhr) {
      var current_form =  $(this);
      var target = current_form.attr("data-target");
      var reset_form = current_form.attr("data-reset-form");
      var scroll_bottom = current_form.attr("data-scroll-bottom")

      if (reset_form !== "false") {
        current_form.resetForm();
      }

      modify_target(data, target, {scroll_bottom : scroll_bottom});

     });

    //Allows a textfield to submit an ajax request independently of
    //the surrounding form. Submission is triggered when the ENTER
    //key is pressed.
    $(document).delegate(".search_box", "keypress", function(event) {
      if (event.keyCode !== 13) return true;

      var text_field = $(this);
      var data_type = text_field.attr("data-type") || "script";
      var url = text_field.attr("data-url");
      var method = text_field.attr("data-method") || "GET";
      var target = text_field.attr("data-target");

      var parameters = {};
      parameters[text_field.attr("name")] = text_field.attr("value");

      jQuery.ajax({
        type: method,
        url: url,
        dataType: data_type,
        success: function(data) {
          modify_target(data, target);
        },
        data: parameters
      });

      return false;
    });

    //Allows for the creation of form submit buttons that can hijack
    //the form and send its contents elsewhere, changing the datatype,
    //target, http method as needed.
    $(document).delegate(".hijacker_submit_button", "click", function() {
      var button = $(this);
      var submit_name   = button.attr("name");
      var submit_value  = button.attr("value");
      var data_type = button.attr("data-type");
      var url = button.attr("data-url");
      var method = button.attr("data-method");
      var target = button.attr("data-target");
      var ajax_submit = button.attr("data-ajax-submit");
      var confirm_message = button.attr('data-confirm');
      var enclosing_form = button.closest("form");
      var other_options = {};
      var data = {};

      data_type = data_type || enclosing_form.attr("data-type") || "html";
      url = url || enclosing_form.attr("action");
      method = method || enclosing_form.attr("data-method") || "POST";

      if (button.attr("data-width")) other_options["width"] = button.attr("data-width");
      if (button.attr("data-height")) other_options["height"] = button.attr("data-height");

      data[submit_name] = submit_value;

      if (ajax_submit !== "false") {
        enclosing_form.ajaxSubmit({
          url: url,
          type: method,
          dataType: data_type,
          success: function(data) {
            modify_target(data, target, other_options);
          },
          data: data,
          resetForm: false
          }
        );
      } else {
        enclosing_form.attr("action", url);
        enclosing_form.attr("method", method);
        enclosing_form.submit();
      }

      return false;
    });

    $(document).delegate('.external_submit_button', 'click', function(e) {
      var button = $(this);
      var submit_name   = button.attr("name");
      var submit_value  = button.attr("value");
      var form = $("#" + button.attr('data-associated-form'));
      var confirm_message = button.attr('data-confirm');
      var hidden_field  = $("<input type=\'hidden\' name=\'"+submit_name+"\' value=\'"+submit_value+"\'>");
      var submit_button = $("<input type=\'submit\'>");

      form.append(hidden_field);
      form.append(submit_button)

      submit_button.click();

      hidden_field.remove();
      submit_button.remove();

      return false;
    });

    //For loading content into an element after it is clicked.
    //See on_click_ajax_replace() in application_helper.rb
    function ajax_onclick_show(event) {
      var onclick_elem = $(this);
      var before_content = onclick_elem.attr("data-before");
      var replace_selector = onclick_elem.attr("data-replace");
      var replace_position = onclick_elem.attr("data-position");
      var parents = onclick_elem.attr("data-parents");
      var replace_elem;

      if (!parents) {
        parents = ""
      }

      parents += " __cbrain_parent_" + onclick_elem.attr("id");

      if (!replace_selector) {
        replace_elem = onclick_elem;
      } else {
        replace_elem = $("#" + replace_selector);
      }

      if (!before_content) {
        before_content = "<span class='loading_message'>Loading...</span>";
      }

      before_content = $(before_content);

      if (replace_position === "after") {
        replace_elem.after(before_content);
      } else if (replace_position === "replace") {
        replace_elem.replaceWith(before_content);
      } else {
        replace_elem.html(before_content);
      }

      onclick_elem.removeClass("ajax_onclick_show_element");
      onclick_elem.unbind('click');
      onclick_elem.addClass("ajax_onclick_hide_element");
      $.ajax({
        type: 'GET',
        url: $(onclick_elem).attr("data-url"),
        dataType: 'html',
        success: function(data) {
          var new_data = $(data);

          new_data.attr("data-parents", parents);
          new_data.addClass(parents);
          before_content.replaceWith(new_data);
          new_data.trigger("new_content");
          onclick_elem.find(".ajax_onclick_show_child").hide();
          onclick_elem.find(".ajax_onclick_hide_child").show();
        },
        error:function(e) {
          var new_data = $("Error occured while processing this request");

          new_data.attr("data-parents", parents);
          new_data.addClass(parents);
          before_content.replaceWith(new_data);
          new_data.trigger("new_content");
          onclick_elem.find(".ajax_onclick_show_child").hide();
          onclick_elem.find(".ajax_onclick_hide_child").show();
        },
        async: true,
        timeout: 50000
      });

    };

    //For loading content into an element after it is clicked.
    //See on_click_ajax_replace() in application_helper.rb
    function ajax_onclick_hide(event) {
      var onclick_elem = $(this);
      var parental_id = "__cbrain_parent_" + onclick_elem.attr("id");

      $("." + parental_id).remove();
      onclick_elem.removeClass("ajax_onclick_hide_element");
      onclick_elem.unbind('click');
      onclick_elem.addClass("ajax_onclick_show_element");
      onclick_elem.find(".ajax_onclick_hide_child").hide();
      onclick_elem.find(".ajax_onclick_show_child").show();
    }

    $(document).delegate(".ajax_onclick_show_element", "click", ajax_onclick_show);
    $(document).delegate(".ajax_onclick_hide_element", "click", ajax_onclick_hide);

    // For checking the alive status of all DataProviders
    // The sequential_loading function is called recursively
    // with the id of each DataProvider that is online
    // The url and DataProvider id are stored in the button
    $(document).delegate(".check_all_dp", "click", function (event) {
      var dp_check_btns = $("body").find(".dp_alive_btn");

      sequential_loading(0, dp_check_btns);

      event.preventDefault();
    });

    function sequential_loading(index, element_array) {
      if (index >= element_array.length) return;

      var current_element = $(element_array[index]);
      var url = current_element.attr("data-url");
      var error_message = current_element.attr("data-error");
      var replace_elem = $("#" + current_element.attr("data-replace"));

      jQuery.ajax({
        dataType: 'html',
        url: url,
        timeout: 50000,
        success: function(data) {
          replace_elem.html(data);
        },
        error: function(e) {
          if (!error_message) {
            error_message = "<span class='loading_message'>???</span>";
          }
          replace_elem.html(error_message);
        },
        complete: function(e) {
          sequential_loading(index+1, element_array);
        }
      });
    }

    // Allows to submit an interval of two dates, uses
    // datepicker of jquery-ui, see:
    // http://jqueryui.com/demos/datepicker/#date-range
    $(document).delegate('.daterangepicker', 'click', function (event) {
      var datepicker = $(this);

      $(".daterangepicker").not(".hasDatepicker").datepicker({
        defaultDate: "+1w",
        changeMonth: true,
        dateFormat: "dd/mm/yy",
        onSelect: function( selectedDate ) {
          var type  = datepicker.attr("data-datefieldtype");
          var option = type === "from" ? "minDate" : "maxDate";
          var dates;

          instance = datepicker.data( "datepicker" ),
          date = $.datepicker.parseDate(
            instance.settings.dateFormat || $.datepicker._defaults.dateFormat,
            selectedDate,
            instance.settings
          );

          dates = datepicker.parent().children(".daterangepicker");

          $(dates).each(function(n) {
            if ($(this).attr("data-datefieldtype") !== type) {
              $(this).datepicker("option",option,date);
            }
          });
        }
      });

      datepicker.focus();
    });

    $(document).delegate('.datepicker', 'click', function (event) {
      $(".datepicker").not(".hasDatepicker").datepicker({
        defaultDate: "+1w",
        changeMonth: true,
        dateFormat: "dd/mm/yy",
      });

      $(this).focus();
    });

  });

})();

