function ThicknessData(path) {

  this.path = path;

  /*
   * Parses the text from the ajax request into an array of values
   */
  this.parse = function(data) {
    var string = data;
    string = string.replace(/\s+$/, '');
    string = string.replace(/^\s+/, '');
    this.data = string.split(/\s+/);
    this.min = this.data.min();
    this.max = this.data.max();
  };

  /*
   * Sends an ajax request to the server for the data, sends it to parse and then calls
   * the callback
   */
  this.get_data = function(filename,callback){

    var that = this;
    jQuery.ajax({
      type: 'GET',
      url: path,
      data: {
	collection_file: filename
      },
      dataType: 'text',
      success: function(data) {
	that.parse(data);
	callback(that);
      },
      error: function () {
	jQuery(g_pickInfoElem).html("Error loading map");
      }

    });

  };

};