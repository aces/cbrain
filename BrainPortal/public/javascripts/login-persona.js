function simpleXhrSentinel(xhr) {
    return function() {
        if (xhr.readyState === 4) {
            if (xhr.status === 200){
                // reload page to reflect new login state
                window.location.reload();
            }
            else {
		window.location.replace("https://portal.cbrain.mcgill.ca:444");
            } 
        } 
    } 
}

function verifyAssertion(assertion) {
    // Your backend must return HTTP status code 200 to indicate successful
    // verification of user's email address and it must arrange for the binding
    // of currentUser to said address when the page is reloaded
    var xhr = new XMLHttpRequest();
    xhr.open("POST", "/session/mozilla_persona_auth", true);
    // see http://www.openjs.com/articles/ajax_xmlhttp_using_post.php
    var param = "assertion="+assertion;
    xhr.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
    xhr.send(param); // for verification by your backend    
    xhr.onreadystatechange = simpleXhrSentinel(xhr); 
}

function loginPersona(){
    navigator.id.get(verifyAssertion, {backgroundColor: "#05A3D6", siteName: "CBRAIN"});
}
