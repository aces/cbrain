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
					var input_field = jQuery(this).children().filter("input").hide();
					var text = jQuery(this).children().filter(".current_text");
					input_field.change(function(event) {
							     text.html(input_field.val());
							     input_field.hide();
							     text.show();
							   });
				        jQuery(this).click(function(event){
						     input_field.val(text.html());
						     text.hide();
						     input_field.show();
						   });

				      });

}

);

