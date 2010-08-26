var macacc;
var brainbrowser;


jQuery(
 function() {

   /////////////////////////////////////////////////////////////////////
    //
    // Ajax Pagination
    //
    /////////////////////////////////////////////////////////////////////

    jQuery(".pagination a").live("click", function(){
      link = jQuery(this);
      url = link.attr("href");
      pagination_div = link.closest(".pagination");
      pagination_div.html(" Loading... <BR>");
      jQuery.ajax({
        url: url,
        dataType: "script"
      });
      return false;
    });

   /////////////////////////////////////////////////////////////////////
   //
   // UI Helper Methods see application_helper.rb for corresponding
   // helpers.
   //
   /////////////////////////////////////////////////////////////////////

   //All elements with the accordion class will be changed to accordions.
   jQuery(".accordion").accordion({
     active: false,
     collapsible: true,
     autoHeight: false}
   );


   //Sortable list of elements
   jQuery(".sortable_list").sortable();
   jQuery(".sortable_list").disableSelection();

   jQuery(".slider_field").each( function() {
     var slider_text_field = jQuery(this).children().filter("input");
     jQuery(this).children().filter(".slider").slider({ change: function(event,ui) {
       jQuery(slider_text_field).val(ui.value);
     }});
   });

   jQuery(".draggable_element").draggable({
     connectToSortable: '#sortable',
     helper: 'clone',
     revert: 'invalid'
   });

   jQuery(".sortable_list ul, sortable_list li").disableSelection();

   //Tab Bar, div's of type tabs become tab_bars
   // See TabBar class
   jQuery(".tabs").tabs();

   //Overlay dialogs
   //See overlay_dialog_with_button()
   jQuery(".overlay_dialog").each( function(index,element){
     var content_width = parseInt(jQuery(element).children('.dialog').attr('data-width'));
     var dialog = jQuery(this).children(".dialog")
     dialog.remove().appendTo("body");

     dialog.dialog({ autoOpen: false,
         modal: true,
         position: "center",
         resizable: false,
         width: content_width
     });

     var button = jQuery(this).children(".dialog_button").click(function(){dialog.dialog('open')});
   });

   //Links with class "overlay_link" will create an overlay with content loaded
   //from "data-url".
   jQuery(".overlay_link").click( function() {
     var url=jQuery(this).attr('data-url');
     var dialog = jQuery("<div></div>").load(url).appendTo(jQuery("body")).dialog({
     	show: "puff",
     	modal: true,
      position: 'center',
     	width: 800,
     	height: 600
     });

   });

   jQuery(".inline_edit_field").each(function() {
     var input_field = jQuery(this).children().filter("span").children().filter("input").hide();
     var save_link = jQuery(this).children().filter(".inplace_edit_field_save").hide();
     var text = jQuery(this).children().filter("span").children().filter(".current_text");
     var save_function = function(event) {
       text.html(input_field.val());
       input_field.hide();
       save_link.hide();
       text.show();
     };
     input_field.change(save_function);

     jQuery(save_link).click(save_function);


     jQuery(this).children().filter("span").click(function(event){
       input_field.val(text.html());
       text.hide();
       input_field.show();
       save_link.show();
     });

   });

   //Turns the element into a button looking thing
   jQuery(".button").button();

   //Makes a button set, buttons that are glued together
   jQuery(".button_set").buttonset();


   jQuery(".button_with_drop_down").children(".button_menu").button({
     icons: {
       secondary: 'ui-icon-triangle-1-s'
     }
   }).toggle(function(event){
               var menu = jQuery(this).siblings(".drop_down_menu");
               jQuery(".drop_down_menu:visible").siblings(".button_menu").click();
     	        menu.show();
             },
             function(event){
     	        var menu = jQuery(this).siblings(".drop_down_menu");
     	        menu.hide();
   });

   jQuery(".show_toggle").live("click", function(){
     var current_element = jQuery(this);
     var target_element = jQuery(current_element.attr("data-target"));
     var alternate_text = current_element.attr("data-alternate-text");
     var slide_effect   = current_element.attr("data-slide-effect");
     var slide_duration   = current_element.attr("data-slide-duration");  
     if(slide_duration != 'slow' && slide_duration != 'fast'){
       slide_duration = parseInt(slide_duration);
     }
     
     if(alternate_text){
       current_text = current_element.html();
       current_element.attr("data-alternate-text", current_text);
       current_element.html(alternate_text);
     }
     if(target_element.is(":visible")){
       if(slide_effect){
         target_element.slideUp(slide_duration);
       }else{
         target_element.hide();
       }
     }else{
       if(slide_effect){
          target_element.slideDown(slide_duration);
        }else{
          target_element.show();
        }
     }
     return false;  
   });

   jQuery(".button_with_drop_down > div.drop_down_menu").hide();

   //Highlighting on ressource list tables.
   jQuery("table.resource_list").live("mouseout", function() {highlightTableRowVersionA(0); });
   jQuery(".row_highlight").live("hover", function() {highlightTableRowVersionA(this, '#FFEBE5');});

   jQuery(".ajax_link").live("click", function(element){
     var link = jQuery(this);
     var data_type = link.attr("data-datatype");
     var url = link.attr("href");
     var method = link.attr("data-method");
     var target = link.attr("data-target");
     if(!data_type) data_type = "html";
     if(!method) method = "GET";

     jQuery.ajax({
        type: method,
        url: url,
        dataType: data_type,
        target: target,
      });

      return false;
   });
   
   //Allows for the creation of form submit buttons that can highjack
   //the form and send its contents elsewhere, changing the datatype,
   //target, http method as needed.
   jQuery(".delete_button").live("click", function(){
     var button = jQuery(this);
     var data_type = button.attr("data-datatype");
     var url = button.attr("href");
     var target = button.attr("data-target");
     var confirm_message = button.attr('data-confirm');
     var delete_selector = button.attr("data-delete-selector");
     var delete_text = button.attr("data-delete-text");
     var data_method = button.attr("data-method");
     if(!data_type) data_type = "script";
     if(!data_method) data_method = "DELETE";
     
     if(confirm_message){
        if(!confirm(confirm_message)){
          return false;
        };
     }
    
     if(delete_selector){
       if(!delete_text){
         delete_text = "";
       }
       jQuery(delete_selector).html(delete_text);
     }
      
     jQuery.ajax({
       url: url,
       type: data_method,
       dataType: data_type,
       target: target,
       resetForm: false
       }
     );
     return false;
   }); 
   

   jQuery(".select_all").live("click", function(){
     var header_box = jQuery(this);
     var checkbox_class = header_box.attr("data-checkbox-class");

     jQuery('.' + checkbox_class).each(function(index, element) {
        element.checked = header_box.attr("checked");
      });
   });
   
   jQuery(".select_master").live("change", function(){
     var master_select = jQuery(this);
     var select_class = master_select.attr("data-select-class");
     var selection = master_select.find(":selected").text();

     jQuery('.' + select_class).each(function(index, elem){
       jQuery(elem).find("option").attr("selected", false).each(function(index, elem){
         var element = jQuery(elem);
         if(element.html() == selection) element.attr("selected", "selected");
       });
     });
   });
   
   jQuery(".request_on_change").live("change", function(){
     var input_element = jQuery(this);
     var current_value = input_element.attr("value");
     var url = input_element.attr("data-url");
     var method = input_element.attr("data-method");
     var target = input_element.attr("data-target");
     var data_type = input_element.attr("data-datatype");
     var update_text = input_element.attr("data-update-text");
     if(!method) method = "GET";
     if(!data_type) data_type = "html";
     
     if(target && update_text){
       jQuery(target).html(update_text);
     }
      
     jQuery.ajax({
       url : url,
       type : method,
       dataType : data_type,
       success: function(data){
          if(target){
            jQuery(target).html(data);
          }       
        },
       data : {current_value : current_value}
     });
     
     return false;
   });

   /////////////////////////////////////////////////////////////////////
   //
   // Form hijacking helpers
   //
   /////////////////////////////////////////////////////////////////////

   //Forms with the class "ajax_form" will be submitted as ajax requests.
   //Datatype and target can be set with appropriate "data" attributes.
   jQuery(".ajax_form").live("submit", function(){
     var current_form = jQuery(this);
     var data_type = current_form.attr("data-datatype");
     var target = current_form.attr("data-target");
     var method = current_form.attr("data-method");
     if(!method) method = "POST";
     if(!data_type) data_type = "html";
     
     current_form.ajaxSubmit({
       type: method,
       dataType: data_type,
       success: function(data){
         if(target){
           jQuery(target).html(data);
         }       
       },
       resetForm: true
     });
     return false;
   });

   //Allows a textfield to submit an ajax request independantly of
   //the surrounding form. Submission is triggered when the ENTER
   //key is pressed.
   jQuery(".search_box").live("keypress", function(event){
     if(event.keyCode == 13){
       var text_field = jQuery(this);
       var data_type = text_field.attr("data-datatype");
       if(!data_type) data_type = "script";
       var url = text_field.attr("data-url");
       var method = text_field.attr("data-method");
       if(!method) method = "GET";
       var target = text_field.attr("data-target");

       var parameters = {};
       parameters[text_field.attr("id")] = text_field.attr("value");

       jQuery.ajax({
         type: method,
         url: url,
         dataType: data_type,
         target: target,
         data: parameters
       });
       return false;
     }
   });

   //Allows for the creation of form submit buttons that can highjack
   //the form and send its contents elsewhere, changing the datatype,
   //target, http method as needed.
   jQuery(".ajax_submit_button").live("click", function(){
     var button = jQuery(this);
     var commit = button.attr("value");
     var data_type = button.attr("data-datatype");
     var url = button.attr("data-url");
     var method = button.attr("data-method");
     var target = button.attr("data-target");
     var confirm_message = button.attr('data-confirm');
     var enclosing_form = button.closest("form");
     if(!data_type) data_type = enclosing_form.attr("data-datatype");
     if(!data_type) data_type = "html";

     if(!url) url = enclosing_form.attr("action");

     if(!method) method = enclosing_form.attr("data-method");
     if(!method) method = "POST";
     
     if(confirm_message){
         if(!confirm(confirm_message)){
           return false;
         };
     }

     enclosing_form.ajaxSubmit({
       url: url,
       type: method,
       dataType: data_type,
       target: target,
       data: { commit : commit },
       resetForm: false
       }
     );
     return false;
   });

   jQuery('.external_submit_button').live('click', function(e) {
     var form=document.getElementById(jQuery(this).attr('data-associated-form'));
     var confirm_message = jQuery(this).attr('data-confirm');
     if(confirm_message) {
       if(confirm(confirm_message)) {
	       form.submit();
       }
     }
     else {
       form.submit();
     }
     return false;
   });
    
   //UNFINISHED: DO NOT USE
   //Attempting to create a form for the userfiles page that
   //can pull in inputs from elsewhere on the page (outside the
   //form).
   //Currently the problem is that the Prototype library is
   //interfering with some functionality that this function needs.
   //If we migrate away from Prototype, it should work.
   jQuery(".userfiles_partial_form").live("submit", function(){
     var current_form = jQuery(this);
     try{
       var data_type = current_form.attr("data-datatype");
       var target = current_form.attr("data-target");
       var method = current_form.attr("data-method");
       if(!data_type) data_type = "html";
       if(!method) method = "POST";

       var commit = this.commit.value;

          var post_data = { commit : commit, iamjs: "YES" };
           var file_ids = new Array();
           jQuery('.userfiles_checkbox:checked').each(function(index, element){
             file_ids.push(element.value);
           });
         }catch(e){
           alert(e.toString());
           return false;
         }
       post_data["filelist[]"] = file_ids;
       current_form.ajaxSubmit({
         type: method,
         data: post_data,
         dataType: data_type,
         target: target,
         resetForm: true
       });

       return false;
   });



   //Only used for jiv. Used to submit parameters and create an overlay with the response.
   jQuery("#jiv_submit").click(function(){
     var data_type = jQuery(this).attr("data-datatype");
     jQuery(this).closest("form").ajaxSubmit({
       url: "/jiv",
       type: "GET",
       resetForm: false,
       success: function(data){
         jQuery("<div id='jiv_option_div'></div>").html(data).appendTo(jQuery("body")).dialog({
         	show: "puff",
         	modal: true,
   	      position: 'center',
         	width: 800,
         	height: 500,
         	close: function(){
         	  jQuery(this).remove();
         	}
         });
       }
     });
     return false;
   });

   /////////////////////////////////////////////////////////////////////
   //
   // Delayed loading of content
   //
   /////////////////////////////////////////////////////////////////////

   //See ajax_element() in application_helper.rb
   //The ajax element will have its contents loaded by the response from an
   //ajax request (so the element's conents will be loaded later with respect
   //to the rest of the page). If the "data-replace" attribute is set to "true"
   //the entire element will be replace an not just its contents.
   jQuery(".ajax_element").each(function (index,element){
     var current_element = jQuery(element);
     var url = current_element.attr("data-url");
     var error_message = current_element.attr("data-error");
     var replace = current_element.attr("data-replace");
     jQuery.ajax({
       type: 'GET',
       url: url,
       dataType: 'html',
       success: function(data) {
           if(replace == "true"){
             current_element.replaceWith(data);
           }else{
             current_element.html(data);
           }
       },
       error: function(e) {
         if(!error_message){
           error_message = "Error loading element";
         }
         current_element.html("<span class='loading_message'>"+ error_message +"</span>");
       },
       timeout: 50000
 	   });
   });

   //See script_loader() in application_helper.rb
   //Similar to above except that instead of loading html
   //it fetches javascript from the server that will be executed
   //update the page.
   jQuery(".script_loader").each(function (index,element){
     var current_element = jQuery(element);
     current_element.css("display", "none");
     var url = current_element.attr("data-url");
     jQuery.ajax({
       dataType: 'script',
       url: url,
       timeout: 50000
     });
   });
   
   var staggered_load_elements = jQuery(".staggered_loader");
   staggered_loading(0, staggered_load_elements);
   
   function staggered_loading(index, element_array){
      if(index >= element_array.length) return;
      
      var current_element = jQuery(element_array[index]);
      var url = current_element.attr("data-url");
      var error_message = current_element.attr("data-error");
      var replace = current_element.attr("data-replace");
      jQuery.ajax({
        dataType: 'html',
        url: url,
        target: current_element,
        timeout: 50000,
        success: function(data) {
            if(replace == "true"){
              current_element.replaceWith(data);
            }else{
              current_element.html(data);
            }
        },
        error: function(e) {
          if(!error_message){
            error_message = "Error loading element";
          }
          current_element.html("<span class='loading_message'>"+ error_message +"</span>");
        },
        complete: function(e) {
          staggered_loading(index+1, element_array)
        }
      });
    }

   //For loading content into an element after it is clicked.
   //See on_click_ajax_replace() in application_helper.rb
   function ajax_onclick_show(event) {
     var onclick_elem = jQuery(this);
     var before_content = onclick_elem.attr("data-before");
     var replace_selector = onclick_elem.attr("data-replace");
     var replace_position = onclick_elem.attr("data-position");
     var parents = onclick_elem.attr("data-parents");
     if(!parents){
       parents = ""
     };
     parents += " __cbrain_parent_" + onclick_elem.attr("id");
     if(!replace_selector) {
       var replace_elem = onclick_elem;
     } else {
       var replace_elem=jQuery("#" + replace_selector);
     };
     if(!before_content) {
       before_content = "<span class='loading_message'>Loading...</span>";
     };
     before_content = jQuery(before_content);
     if(replace_position == "after") {
       replace_elem.after(before_content);
     }else if (replace_position == "replace"){
       replace_elem.replaceWith(before_content);
     }else{
       replace_elem.html(before_content);
     }

     onclick_elem.removeClass("ajax_onclick_show_element");
     onclick_elem.unbind('click');
     onclick_elem.addClass("ajax_onclick_hide_element");
     jQuery.ajax({ type: 'GET',
       url: jQuery(onclick_elem).attr("data-url"),
       dataType: 'html',
       success: function(data){
         var new_data = jQuery(data);
         new_data.attr("data-parents", parents);
         new_data.addClass(parents);
         before_content.replaceWith(new_data);
         onclick_elem.find(".ajax_onclick_show_child").hide();
         onclick_elem.find(".ajax_onclick_hide_child").show();
       },
       error:function(e) {
         var new_data = jQuery("Error occured while processing this request");
         new_data.attr("data-parents", parents);
         new_data.addClass(parents);
         before_content.replaceWith(new_data);
         onclick_elem.find(".ajax_onclick_show_child").hide();
         onclick_elem.find(".ajax_onclick_hide_child").show();
 	    },
       data: {},
       async: true,
       timeout: 50000
     });

   };

   //For loading content into an element after it is clicked.
   //See on_click_ajax_replace() in application_helper.rb
   function ajax_onclick_hide(event){
     var onclick_elem = jQuery(this);
     var parental_id = "__cbrain_parent_" + onclick_elem.attr("id");
     jQuery("." + parental_id).remove();
     onclick_elem.removeClass("ajax_onclick_hide_element");
     onclick_elem.unbind('click');
     onclick_elem.addClass("ajax_onclick_show_element");
     onclick_elem.find(".ajax_onclick_hide_child").hide();
     onclick_elem.find(".ajax_onclick_show_child").show();
   };

   jQuery(".ajax_onclick_show_element").live("click", ajax_onclick_show);
   jQuery(".ajax_onclick_hide_element").live("click", ajax_onclick_hide);


   /////////////////////////////////////////////////////////////////////
   //
   // Macacc stuff
   //
   /////////////////////////////////////////////////////////////////////

   jQuery(".o3d_link").live('click',o3DOverlay);

   jQuery(".macacc_link").live('click',macaccOverlay);

   function macaccOverlay(event) {
     var macacc=jQuery("<div id=\"macacc_viewer\"></div>").load(jQuery(this).attr('data-viewer')).appendTo(jQuery("body")).dialog({
       show: "puff",
     	modal: true,
       position: 'center',
     	width: 1024,
     	height:  768,
       async: false,
       close: function(){
     	  brainbrowser.uninit();
     	  jQuery("#macacc_viewer").remove();
     	}
     });
     jQuery(".macacc_button").button();
     brainbrowser = new BrainBrowser();
     brainbrowser.afterInit = function(bb) {
       macacc = new MacaccObject(bb,jQuery("#launch_macacc").attr("data-content-url"));
       jQuery('#fillmode').toggle(bb.set_fill_mode_wireframe,bb.set_fill_mode_solid);
       jQuery('#range_change').click(macacc.range_change);
       jQuery('.data_controls').change(macacc.data_control_change);
       macacc.pickInfoElem=jQuery("#vertex_info");
       jQuery('#screenshot').click(function(event) {jQuery(this).attr("href",bb.client.toDataURL());});
     };
     brainbrowser.setup(jQuery("#launch_macacc").attr("data-content-url")+"?model=normal");

     jQuery("#viewinfo > .button").button();
   }



   function o3DOverlay(event) {
     var macacc=jQuery("<div id=\"civet_viewer\"></div>").load(jQuery(this).attr('data-viewer')).appendTo(jQuery("body")).dialog({
    	show: "puff",
     	modal: true,
       position: 'center',
     	width: 1024,
     	height: 768,
     	close: function(){
     	  brainbrowser.uninit();
     	  jQuery("#civet_viewer").remove();
     	}
     });
     brainbrowser = new BrainBrowser();
     var civet;
     var obj_link = this;
     brainbrowser.afterInit = function(bb) {
       civet = new CivetObject(bb,jQuery(obj_link).attr("data-content"));
       jQuery('#fillmode').toggle(bb.set_fill_mode_wireframe,bb.set_fill_mode_solid);
       jQuery('#range_change').click(civet.range_change);
       civet.pickInfoElem=jQuery("#vertex_info");
       jQuery('#screenshot').click(function(event) {jQuery(this).attr("href",bb.client.toDataURL());});
     };
     brainbrowser.setup(jQuery(this).attr('data-content-url'));
     return false;
   };
});


