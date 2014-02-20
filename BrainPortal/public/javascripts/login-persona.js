//
// CBRAIN Project
//
// Copyright (C) 2008-2012
// The Royal Institution for the Advancement of Learning
// McGill University
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

// Just monitors the status of an XMLHttpRequest
function simpleXhrSentinel(xhr) {
    return function() {
        if (xhr.readyState === 4) {
            if (xhr.status === 200){
                // reload page to reflect new login state
                window.location.reload();
            }
	    // else do nothing, the server should print a message
        } 
    } 
}

// Posts a Mozilla Persona assertion to the session controller
function verifyAssertion(assertion) {
    var xhr = new XMLHttpRequest();
    xhr.open("POST", "/session/mozilla_persona_auth", true);
    // see http://www.openjs.com/articles/ajax_xmlhttp_using_post.php
    var param = "assertion="+assertion;
    xhr.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
    xhr.send(param); // for verification by your backend    
    xhr.onreadystatechange = simpleXhrSentinel(xhr); 
}

// Function called by button "Sign-in with your email" on the login page
function loginPersona(){
    navigator.id.get(verifyAssertion, {backgroundColor: "#05A3D6", siteName: "CBRAIN"});
}
