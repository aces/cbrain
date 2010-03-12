jQuery(
  function() {
    //All elements with the accordion class will be changed to accordions.
    jQuery(".accordion").accordion({
				     active: false,
				     collapsible: true});


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
    jQuery(".overlay_dialog").each(function(){
				     var dialog = jQuery(this).children().filter(".dialog").dialog({ autoOpen: false,
											modal: true,
											position: "center",
											resizable: false,
											show: "puff"});

				     var button = jQuery(this).children().filter(".dialog_button").click(function(){dialog.dialog('open')});



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
						            var menu = jQuery(this).siblings("div.drop_down_menu")
							    jQuery(".drop_down_menu").hide();
					            	    menu.show();
							  },
							  function(event){
						            var menu = jQuery(this).siblings("div.drop_down_menu")
					            	    menu.hide();
							  });



    jQuery(".button_with_drop_down > div.drop_down_menu").hide();


    jQuery(".ajax_element").each(function (index,element){
				    jQuery(element).load(jQuery(element).attr("href"));
				  });

});
