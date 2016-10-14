/* Autoresponder plugin script */
if (window.rcmail) {
  rcmail.addEventListener('init', function(evt) {
    // register command handler
    rcmail.register_command('plugin.vmail_autoanswer-save', function() { 
      var input_datefromd = rcube_find_object('_autoresponderdatefromd');
      var input_datefromm = rcube_find_object('_autoresponderdatefromm');
      var input_datefromy = rcube_find_object('_autoresponderdatefromy');    
      var input_datetod = rcube_find_object('_autoresponderdatetod');
      var input_datetom = rcube_find_object('_autoresponderdatetom');
      var input_datetoy = rcube_find_object('_autoresponderdatetoy');
      var fday   = parseInt(input_datefromd.value);			
      var fmonth = parseInt(input_datefromm.value);
      var fyear  = parseInt(input_datefromy.value);
      var tday   = parseInt(input_datetod.value);			
      var tmonth = parseInt(input_datetom.value);
      var tyear  = parseInt(input_datetoy.value);
      if ( fmonth > 12){
          alert('Month > 12!');
          input_datefromm.focus();
	    } 
      else if ( fday > 31 ){
          alert('Day not correct, use 0 or 1 - 31 !');
          input_datefromd.focus();
	    } 
      else if ( fyear > 1 && fyear < 1970 ){
          alert('Year not correct! Use 0 or greater 1970.');      
          input_datefromy.focus();
      }
      else if ( tmonth > 12){
          alert('Month > 12!');
          input_datetom.focus();
	    } 
      else if ( tday > 31 ){
          alert('Day not correct, use 0 or 1 - 31 !');
          input_datetod.focus();
	    } 
      else if ( tyear > 1 && tyear < 1970 ){
          alert('Year not correct! Use 0 or greater 1970.');      
          input_datetoy.focus();
      }
      else {       
        document.forms.autoresponderform.submit();
      }
    }, true);
  })
}
