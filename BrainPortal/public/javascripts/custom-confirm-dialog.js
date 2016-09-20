// This call will override the rails allowAction method to allow us to present a custom dialog for
// a link with data-confirm attribute

(function () {

// Finds the Bootstrap Modal and sets the message, running the confirm callback when user clicks OK
function myCustomConfirmBox(message, callback) {

  $('#confirm-message').html(message);

  $('#cbrain-dialog-confirm').modal('show');

  $('.modal-confirm').on('click', function(event){
    callback();
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

