
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

  document.addEventListener("DOMContentLoaded", function(event) {

    document.getElementById("upload_file").addEventListener('input', function (event) {
      var warning_text = "";
      var max          = parseInt(document.getElementById('upload-dialog').dataset["maxUploadSize"]);
      var select_file  = document.getElementById("upload_file").files[0]
      var filename     = select_file && select_file.name;
      var filesize     = select_file && select_file.size;
      var bad_file;

      var allowed_file_pattern = /^[a-zA-Z0-9][\w\~\!\@\#\%\^\&\*\(\)\-\+\=\:\[\]\{\}\|\<\>\,\.\?]*$/;
      var bad_chars = !allowed_file_pattern.test(filename);

      var spaces_in_name = filename.includes(" ");
            
      var file_too_big;
      if ( max > 0 ){
        file_too_big = filesize && max && filesize > max;
      } else {
        file_too_big = false;
      }

      bad_file = ( bad_chars || file_too_big || spaces_in_name );

      if ( bad_chars && spaces_in_name) {
        warning_text += "No spaces allowed in filename! ";
      }
      else if ( bad_chars ) {
        warning_text += "Illegal filename: must start with letter/digit, and no slashes, or ASCII nulls allowed. ";
      }
      if ( file_too_big ) {
        warning_text += "Too large! (> " + max/1048576 + " MB) ";
      }

      document.getElementById("up-file-warn").textContent      = warning_text;
      document.getElementById("up-file-warn").style.visibility = bad_file ? 'visible' : 'hidden';
    });


    document.getElementById("upload_file_btn").addEventListener('click', function (event) {
      
      // var progressBar = document.getElementById("progressBar");
      // var form        = $(document.getElementById("upload"));
      // var form        = form[0];  
      
      // var xhr         = new XMLHttpRequest();
      // if (('upload' in xhr) && ('onprogress' in xhr)){
        
      //   $.ajax({ 
      //     url:         form.action,
      //     type:        form.method,
      //     data:        new FormData(form),
      //     cache:       false,
      //     contentType: false,
      //     processData: false,
      //     headers:     { 'Accept': 'application/json' },
      //     xhr: function () {
      //       var xhr = $.ajaxSettings.xhr();
      //       xhr.upload.onloadstart = onloadstart;
      //       xhr.upload.onprogress  = onprogress;
      //       xhr.upload.onloadend   = onloadend;
      //       return xhr;
      //     }
      //   })

      //   /* The upload started; show a nice progress bar. */
      //   function onloadstart(event) {
      //     // alert("IN onloadstart");
      //     onprogress(event);
      //   };

      //   // Some progress has been made on the upload; update the progress bar. 
      //   function onprogress(event) {
      //     // alert("IN onprogress");
      //     alert(event.lengthComputable);

      //     if (!event.lengthComputable) return;

      //     // alert("loaded");
      //     // alert(event.loaded);
      //     // alert("total");
      //     // alert(event.total);
          
      //     progressBar.value = (event.loaded / event.total * 100);


      //     onloadend(event);
      //   };

      //   /* The upload is done; remove the progress bar. */
      //   function onloadend(event) {
      //     // alert("IN onloadend");
      //   };

      // }

      // form.submit();

    });
  });

})();
