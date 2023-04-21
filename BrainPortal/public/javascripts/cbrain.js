
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

  // This function assigns 'data' to a 'target' in the DOM and is used mainly after
  // an ajax request returns successfully.
  // The options argument may contain values for 'width', 'height';
  // 'replace' and 'scroll_bottom' are evaluated as boolean.
  function modify_target(data, target, options) {
    options = options || {};

    var current_target, new_content;
    var width, height;

    if (target) {
      new_content = $(data);
      if (target === "__OVERLAY__") {
        width = parseInt(options["width"], 10); // || 800;
        height = parseInt(options["height"], 10); // || 500;
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
    // Enable chosen functionality for select boxes.
    // From chosen JavaScript library
    //
    /////////////////////////////////////////////////////////////////////

    loaded_element.find("select").each(function(){
      var select = $(this);

      var defined_width = (select.context.style.width);
      if ( defined_width !== '' ){
        select.chosen({ width: defined_width });
      } else {
        select.chosen({ width: '25em' });
      }
    });

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

    loaded_element.find(".inline_text_field").each(function() {
      var inline_text_field = $(this);
      var data_type = inline_text_field.data("type") || "script";
      var target = inline_text_field.data("target");
      var method = inline_text_field.data("method") || "POST";

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
      var trigger = inline_text_field.find(inline_text_field.data("trigger"));

      var data_type = inline_text_field.data("type") || "script";
      var target = inline_text_field.data("target");
      var method = inline_text_field.data("method") || "POST";

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
      var keep_open = button.data("open");
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

    // This create a switch to have one or two panels (side by side)
    // when performiming QC
    loaded_element.find(".hide_qc_panel").click(function(event) {
      var qc_right  = loaded_element.find(".qc_right_panel");
      var qc_button = $(this)[0];
      if (qc_right.is(":visible")) {
        qc_button.innerHTML = "2 panels";
        qc_right.hide();
      } else {
        qc_button.innerHTML = "1 panel";
        qc_right.show();
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
    }).click(function(event) {
      if (event.target.nodeName === "A") {
        return true;
      }

      var project_button = $(this);
      var url = project_button.data("href");
      var method = project_button.data("method");
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
          if (replace) {
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
          if (replace) {
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
      var method          = current_element.data("method") || "GET";
      var url             = current_element.data("url");
      var error_message   = current_element.data("error");
      var replace         = current_element.data("replace");
      var data            = current_element.data("data");
      var interval        = current_element.data("interval");
      var scroll_bottom   = current_element.data("scroll-bottom");

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
      var target = $(button.data("target"));
      update_ajax_element(target);

      return false;
    });

    //Overlay dialogs
    //See overlay_dialog_with_button()
    loaded_element.find(".overlay_dialog").each( function(index,element) {
      var enclosing_div = $(this);
      var dialog_link = enclosing_div.children('.overlay_content_link');
      var dialog = enclosing_div.children(".overlay_content")
      var content_width = parseInt(dialog_link.data("width"), 10);
      var content_height = parseInt(dialog_link.data("height"), 10);

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
      var target_element = $(checkbox.data("target"));
      var slide_effect = checkbox.data("slide-effect");
      var slide_duration = checkbox.data("slide-duration") || "fast";
      var invert = checkbox.data("invert");

      if (slide_duration !== "slow" && slide_duration !== "fast") {
        slide_duration = parseInt(slide_duration, 10);
      }

      if (invert) {
        show = !show;
      }

      if (show) {
        target_element.show();
      } else {
        target_element.hide();
      }

      checkbox.change(function() {
        show = checkbox.is(":checked");
        if (invert) {
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

    $(document).delegate(".hover_open", "mouseenter", function() {
      var header = $(this);
      var target = $(header.data("target"));

      target.show();
      header.mouseleave(function() {
        target.hide();
        return false;
      });

      return false;
     });

    $(document).delegate(".show_toggle", "click", function() {
      var current_element = $(this);
      var target_element = $(current_element.data("target"));
      var alternate_text = current_element.data("alternate-text");
      var slide_effect   = current_element.data("slide-effect");
      var slide_duration   = current_element.data("slide-duration");
      var current_text;

      if (slide_duration !== 'slow' && slide_duration !== 'fast') {
        slide_duration = parseInt(slide_duration, 10);
      }

      if (alternate_text) {
        current_text = current_element.html();
        current_element.data("alternate-text", current_text);
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

      group.find(".inline_edit_field_default_text").toggle(visible);
      group.find(".inline_edit_field_input").toggle(!visible);

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

    // This is a jquery_ujs event
    $(".ajax_link").on("ajax:success", function(event, data, status, xhr) {
      var link          = $(this);
      var target        = link.data("target");
      var datatype      = link.data("type");
      var remove_target = link.data("remove-target");
      var other_options = {};

      if (link.data("width"))   other_options["width"]   = link.data("width");
      if (link.data("height"))  other_options["height"]  = link.data("height");
      if (link.data("replace")) other_options["replace"] = link.data("replace");

      if (remove_target) {
         $(remove_target).remove();
      } else if (datatype !== "script") {
        modify_target(data, target, other_options);
      }
    });

    // This is a jquery_ujs event
    $(".ajax_link").on("ajax:beforeSend", function(event, xhr, settings) {
      var link            = $(this);
      var loading_message = link.data("loading-message");
      var target          = link.data("target");
      if (loading_message) {
        var loading_message_target = link.data("loading-message-target");
        if (!loading_message_target) loading_message_target = target;
        $(loading_message_target).html(loading_message);
      }
    });

    // Set the value of the hidden input field linked to the header_box
    var set_hidden_select_all = (header_box, value) => {
      var checkbox_class = header_box.attr('data-checkbox-class');
      if (checkbox_class === undefined) {return};

      var hidden_box = $("input[type='hidden'][data-checkbox-class='"+checkbox_class+"']");
      if (hidden_box.length !== 1) {return};
      hidden_box = hidden_box[0];

      $(hidden_box).val( value );
    };

    // Value of the header box is used to set
    // the checked status of child boxes
    var click_select_all = (header_box) => {
      var checkbox_class = header_box.data("checkbox-class");

      set_hidden_select_all(header_box, header_box.prop('checked') ? "all" : "none");

      $('.' + checkbox_class).each(function(index, element) {
        element.checked = header_box.prop('checked');
      });
    };

    $(document).delegate(".select_all", "click", function() {
      var header_box = $(this);
      click_select_all(header_box);
    });

    // Define on click event for each child of a `select_all` element.
    $(".select_all").each( (index,input) => {
      if ($(input).data("persistant-name")) {
        var checkbox_class = $(input).data("checkbox-class");
        $(input).load(click_select_all($(input)));
        var checkbox_class_elements = $('.' + checkbox_class);
        checkbox_class_elements.each(function(index, element) {
          $(element).on("click", () => {
            var number_of_checkbox = checkbox_class_elements.filter((i,e) => e.checked).length;
            if (number_of_checkbox === 0) {
              set_hidden_select_all($(input), "none");
              input.checked = false;
            } else if (checkbox_class_elements.length === number_of_checkbox) {
              set_hidden_select_all($(input), "all");
              input.checked = true;
            } else {
              set_hidden_select_all($(input), "some");
              input.checked = false;
            }
          });
        });
      };
    });

    $(document).delegate(".select_master", "change", function() {
      var master_select = $(this);
      var select_class = master_select.data("select-class");
      var selection = master_select.find(":selected").text();

      $('.' + select_class).each(function(index, elem) {
        $(elem).find("option").attr("selected", false).each(function(index, elem) {
          var element = $(elem);
          if (element.html() === selection) element.attr("selected", "selected");
        });
      });
      $('.' + select_class).trigger("chosen:updated");
    });

    $(document).on("change", ".request_on_change", function() {
      var input_element        = $(this);
      var param_name           = input_element.attr("name");
      var current_value        = input_element.val(); // input_element.attr("value");
      var url                  = input_element.data("url");
      var method               = input_element.data("method");
      var target               = input_element.data("target");
      var data_type            = input_element.data("type");
      var update_text          = input_element.data("loading-message");
      var optgroup_change      = input_element.data("optgroup-change")
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
      var commit_value = select.data("commit");
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
      var tool_tip_id = trigger.data("tool-tip-id");
      var tool_tip = $("#" + tool_tip_id);
      var offset_x = trigger.data("offset-x");
      var offset_y = trigger.data("offset-y") || '0';
      if (typeof offset_x == 'undefined') {
        offset_x = '30';
      }

      var x = trigger.position().left + parseInt(offset_x, 10);
      var y = trigger.position().top  + parseInt(offset_y, 10);

      // Fixed position bug.
      tool_tip.remove().appendTo(trigger.parent());

      tool_tip.css('top',  y + 'px');
      tool_tip.css('left', x + 'px');

      tool_tip.show();
    }).delegate(".html_tool_tip_trigger", "mouseleave", function(event) {
      var trigger = $(this);
      var tool_tip_id = trigger.data("tool-tip-id");
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
      var current_form  =  $(this);
      var target        = current_form.data("target");
      var reset_form    = current_form.data("reset-form");
      var scroll_bottom = current_form.data("scroll-bottom")

      if (reset_form) {
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
      var data_type = text_field.data("type") || "script";
      var url = text_field.data("url");
      var method = text_field.data("method") || "GET";
      var target = text_field.data("target");

      var parameters = {};
      parameters[text_field.attr("name")] = text_field.val();

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
      var submit_value  = button.val();
      var data_type = button.data("type");
      var url = button.data("url");
      var method = button.data("method");
      var target = button.data("target");
      var ajax_submit = button.data("ajax-submit");
      var confirm_message = button.data("confirm");
      var enclosing_form = button.closest("form");
      var other_options = {};
      var data = {};

      data_type = data_type || enclosing_form.data("type") || "html";
      url = url || enclosing_form.attr("action");
      method = method || enclosing_form.data("method") || "POST";

      if (button.data("width")) other_options["width"] = button.data("width");
      if (button.data("height")) other_options["height"] = button.data("height");

      data[submit_name] = submit_value;

      if (ajax_submit) {
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
        return true; // let the browser do the submit and send the form with the button info
        //enclosing_form.submit();
      }

      return false;
    });

    $(document).delegate('.external_submit_button', 'click', function(e) {
      var button = $(this);
      var submit_name   = button.attr("name");
      var submit_value  = button.val();
      var form = $("#" + button.data("associated-form"));
      var confirm_message = button.data("confirm");
      var hidden_field  = $("<input type=\'hidden\' name=\'"+submit_name+"\' value=\'"+submit_value+"\'>");
      var submit_button = $("<input type=\'submit\'>");
      submit_button.attr('style', 'display: none');
      if (confirm_message) {
        submit_button.data('confirm', confirm_message);
      }

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
      var before_content = onclick_elem.data("before");
      var replace_selector = onclick_elem.data("replace");
      var replace_position = onclick_elem.data("position");
      var parents = onclick_elem.data("parents");
      var replace_elem;

      var sub_viewable_links = document.getElementsByClassName('sub_viewable_link') || [];
      for (var i = 0; i < sub_viewable_links.length; i++) {
          var link         = $(sub_viewable_links[i]);
          var url_link     = $(sub_viewable_links[i].parentElement).attr("data-url");
          var onclick_link = $(onclick_elem).data("url");
          if (url_link == onclick_link) {
              link.css("color", "#4682B4");
          } else {
              link.css("color", "blue");
          }
      }

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
        url: $(onclick_elem).data("url"),
        dataType: 'html',
        success: function(data) {
          var new_data = $(data);

          new_data.data("parents", parents);
          new_data.addClass(parents);
          before_content.replaceWith(new_data);
          new_data.trigger("new_content");
          onclick_elem.find(".ajax_onclick_show_child").hide();
          onclick_elem.find(".ajax_onclick_hide_child").show();
        },
        error:function(e) {
          var new_data = $("Error occurred while processing this request");

          new_data.data("parents", parents);
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
      var url = current_element.data("url");
      var error_message = current_element.data("error");
      var replace_elem = $("#" + current_element.data("replace"));

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
          var type  = datepicker.data("datefieldtype");
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
            if ($(this).data("datefieldtype") !== type) {
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

  // Enable chosen functionality for select boxes.
  // From chosen JavaScript library
  $('select').each(function(){
    var select = $(this);

    var defined_width = (select.context.style.width);
    if ( defined_width !== '' ){
      select.chosen({ width: defined_width });
    } else {
      select.chosen({ width: '25em' });
    }
  });

  // Credit to Jeff Hays (GitHub: @jphase) for the select/deselect toggle.
  // (http://jsfiddle.net/jphase/A6LBv/)
  // Add select/deselect all toggle to optgroups in chosen
  $(document).on("click", ".group-result", function () {
    // Get unselected items in this group
    var unselected = $(this).nextUntil(".group-result").not(".result-selected");
    if (unselected.length) {
      // Select all items in this group
      unselected.trigger("mouseup");
    } else {
      $(this)
        .nextUntil(".group-result")
        .each(function () {
          // Deselect all items in this group
          $(
            'a.search-choice-close[data-option-array-index="' +
              $(this).data("option-array-index") +
              '"]'
          ).trigger("click");
        });
    }
  });

  // Set a timer to update the "Last Updated" indicator
  (function () {
    "use strict";

    var last_update = new Date();
    setInterval(function () {
      var diff = Math.floor((new Date() - last_update) / (60 * 1000)),
          part = undefined,
          text = [];

      part = Math.round(diff % 60);
      diff = Math.floor(diff / 60);
      text.unshift(part + 'm');

      part = Math.round(diff % 24);
      diff = Math.floor(diff / 24);
      if (part) text.unshift(part + 'h');

      if (diff) text.unshift(diff + 'd');

      $('span.last_updated > span.elapsed').text(text.join(' '));
    }, 5 * 1000);

    // The only times we need to reset it is when AJAX request are made.
    $( document ).ajaxStart(function() {
      last_update = new Date();
    });
  })();

})();

