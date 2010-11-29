
// All xstooltip code from: http://www.texsoft.it/index.php?%20m=sw.js.htmltooltip&c=software&l=it     
// Heavily modified locally to invoke jQuery stuff
function xstooltip_show(tooltipId, parentId, posX, posY)
{
    it = document.getElementById(tooltipId);
    
    if ((it.style.top == '' || it.style.top == 0) 
        && (it.style.left == '' || it.style.left == 0))
    {
        img = document.getElementById(parentId); 
    
        x = jQuery(img).position().left + posX;
        y = jQuery(img).position().top  + posY;
        
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

