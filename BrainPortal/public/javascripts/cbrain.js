jQuery(
  function() {
    
    
    //All elements with the accordion class will be changed to accordions.
    jQuery(".accordion").accordion({
      active: false,
      collapsible: true}
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
      jQuery(".tabs").tabs();

      //Overlay dialogs
    jQuery(".overlay_dialog").each( function(index,element){
      var content_width = parseInt(jQuery(element).children('.dialog').attr('data-width'));
      var dialog = jQuery(this).children(".dialog").dialog({ autoOpen: false,
          modal: true,
          position: "center",
	  resizable: false,
	  width: content_width
	 });

          var button = jQuery(this).children(".dialog_button").click(function(){dialog.dialog('open')});



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





        jQuery(".button").button();
        jQuery(".button_with_drop_down").children(".button").button({
          icons: {
            secondary: 'ui-icon-triangle-1-s'
          }



        }).toggle(function(event){
	        var menu = jQuery(this).siblings("div.drop_down_menu");
          jQuery(".drop_down_menu").hide();
          menu.show();
        },
        function(event){
      	  var menu = jQuery(this).siblings("div.drop_down_menu");
      	  menu.hide();
        });



        jQuery(".button_with_drop_down > div.drop_down_menu").hide();

        jQuery(".ajax_form").live("submit", function(){
          var data_type = jQuery(this).attr("data-datatype");
          var target = jQuery(this).attr("data-target");
          if(!data_type) data_type = "html";
          jQuery(this).ajaxSubmit({
            type: "POST",
            dataType: data_type,
            target: target,
            resetForm: true
          });
          return false;
        });
        
        jQuery(".ajax_element").each(function (index,element){
    	  //jQuery(element).load(jQuery(element).attr("data-url"));
    	  var url = jQuery(element).attr("data-url");
    	  var error_message = jQuery(element).attr("data-error");
    	  jQuery.ajax({
    	    type: 'GET',
    	    url: url,
    	    dataType: 'html',
    	    success: function(data) {
    	      jQuery(element).html(data);
    	    },
    	    error: function(e) {
    	      if(!error_message){
    		error_message = "Error loading element";
    	      }
    	      jQuery(element).html("<span>"+ error_message +"</span>");
    	    },
    	    timeout: 50000


	  });

        });


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

      jQuery("table.resource_list").live("mouseout", function() {highlightTableRowVersionA(0); });
      jQuery(".row_highlight").live("hover", function() {highlightTableRowVersionA(this, '#FFEBE5');});

      jQuery(".o3d_link").live('click',O3DOverlay);



    var brainbrowser;
    function O3DOverlay(event) {
      var dialog = jQuery("<div id=\"o3d\"></div>").appendTo(jQuery("body")).dialog({
      	show: "puff",
      	modal: true,
      	width: 800,
      	height: 600,
      	close: function(){
      	  brainbrowser.uninit();
      	  jQuery("#o3d").remove();
      	}
      });
      brainbrowser = new BrainBrowser(jQuery(this).attr('data-content-url'));
    }


});


