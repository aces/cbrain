// This call will override the rails allowAction method to allow us to present a custom dialog for
// a link with data-confirm attribute

(function () {

// The custom dialog box actually gets created in the function below
function myCustomConfirmBox(message, callback) {

	if ($('.cbrain-dialog-confirm').length == 0){
		$(document.body).append('<div class="cbrain-dialog-confirm"></div>');
	}

	$(".cbrain-dialog-confirm").html(message);


	// Define the Dialog and its properties.
	$(".cbrain-dialog-confirm").dialog({
		resizable: false,
		modal: true,
		dialogClass: "no-close",
		title: "Confirmation",
		width: 400,
		buttons: {
			"Yes": function () {
				$(this).dialog('close');
				callback();
			},
			"No": function () {
				$(this).dialog('close');
			}
		}
	});
}

// The function below overrides the allowAction to create a custom dialog box
$.rails.allowAction = function(element) {
	var message = element.data('confirm'), callback;
	if (!message) { return true; } // if there is no message, proceed with action

	if ($.rails.fire(element, 'confirm')) {
		myCustomConfirmBox(message, function() {
			callback = $.rails.fire(element,'confirm:complete', [false]);
			if(callback) {
				var oldAllowAction = $.rails.allowAction;
				$.rails.allowAction = function() { return true; };
				element.trigger('click');
				$.rails.allowAction = oldAllowAction;
			}
		});
	}
	return false;
}

}());

