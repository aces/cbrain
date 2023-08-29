
/*
#
# CBRAIN Project
#
# a modification of w3schools.com snippet
#
*/

function copy_text_to_clipboard() {
    // Get the text field
    var copyText = $("copiable");

    // Select the text field
    copyText.select();
    copyText.setSelectionRange(0, 99999); // For mobile devices

    // Copy the text inside the text field
    navigator.clipboard.writeText(copyText.value);
}
