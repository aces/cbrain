// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

//The following code from: http://wiki.github.com/mislav/will_paginate/ajax-pagination
document.observe("dom:loaded", function() {
  // the element in which we will observe all clicks and capture
  // ones originating from pagination links
  var container = $(document.body)

  if (container) {
    container.observe('click', function(e) {
      var el = e.element()
      if (el.match('.pagination a')) {
        el.up('.pagination').replace(' Loading... <BR>')
        new Ajax.Request(el.href, { method: 'get' })
        e.stop()
      }
    })
  }
  
  $$("table.resource_list").invoke("observe", "mouseout", function() {highlightTableRowVersionA(0); });
  $$(".row_highlight").invoke("observe", "mouseover", function() {highlightTableRowVersionA(this, '#FFEBE5') });
  
})
