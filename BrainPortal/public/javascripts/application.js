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
  
})

//All xstooltip code from: http://www.texsoft.it/index.php?%20m=sw.js.htmltooltip&c=software&l=it
function xstooltip_findPosX(obj) 
{
  var curleft = 0;
  if (obj.offsetParent) 
  {
    while (obj.offsetParent) 
        {
            curleft += obj.offsetLeft
            obj = obj.offsetParent;
        }
    }
    else if (obj.x)
        curleft += obj.x;
    return curleft;
}

function xstooltip_findPosY(obj) 
{
    var curtop = 0;
    if (obj.offsetParent) 
    {
        while (obj.offsetParent) 
        {
            curtop += obj.offsetTop
            obj = obj.offsetParent;
        }
    }
    else if (obj.y)
        curtop += obj.y;
    return curtop;
}

function xstooltip_show(tooltipId, parentId, posX, posY)
{
    it = document.getElementById(tooltipId);
    
    if ((it.style.top == '' || it.style.top == 0) 
        && (it.style.left == '' || it.style.left == 0))
    {
        // need to fixate default size (MSIE problem)
        //it.style.width = it.offsetWidth + 'px';
        //it.style.height = it.offsetHeight + 'px';
        
        img = document.getElementById(parentId); 
    
        // if tooltip is too wide, shift left to be within parent 
        //if (posX + it.offsetWidth > img.offsetWidth) posX = img.offsetWidth - it.offsetWidth;
        //if (posX < 0 ) posX = 0; 
        
        x = xstooltip_findPosX(img) + posX;
        y = xstooltip_findPosY(img) + posY;
        
        it.style.top = y + 'px';
        it.style.left = x + 'px';
    }
    
    it.style.visibility = 'visible'; 
}

function xstooltip_hide(id)
{
    it = document.getElementById(id); 
    it.style.visibility = 'hidden'; 
}
