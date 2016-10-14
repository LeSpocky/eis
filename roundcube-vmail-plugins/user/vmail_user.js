/******************************************************************************
 * Vmail user Roundcube Plugin (RC0.4 and above)
 * This software distributed under the terms of the GNU General Public License
 * as published by the Free Software Foundation
 * Further details on the GPL license can be found at 
 * http://www.gnu.org/licenses/gpl.html
 * By contributing authors release their contributed work under this license
 * For more information see README.md file 
 *****************************************************************************/

if (window.rcmail) {
	rcmail.addEventListener('init', function(evt) {
		if (rcmail.env.action == 'plugin.vmail_user'
				|| rcmail.env.action == 'plugin.vmail_user.save'
				|| rcmail.env.action == 'plugin.vmail_user.toall'
				|| rcmail.env.action == 'plugin.vmail_user.notall'        
				|| rcmail.env.action == 'plugin.vmail_user.enable'
				|| rcmail.env.action == 'plugin.vmail_user.disable')
			var tab = $('<span>').attr('recid', 'settingstabplugin.vmail_user')
					.addClass('tablink selected');
		else
			var tab = $('<span>').attr('recid', 'settingstabplugin.vmail_user')
					.addClass('tablink');
		var button = $('<a>').attr('href',
				rcmail.env.comm_path + '&_action=plugin.vmail_user').html(
				rcmail.gettext('vmail_user', 'vmail_user')).appendTo(tab);
		button.bind('click', function(e) {
			return rcmail.command('plugin.vmail_user', this)
		});

		rcmail.add_element(tab, 'tabs');
		rcmail.register_command('plugin.vmail_user', function() {
			rcmail.goto_url('plugin.vmail_user')
		}, true);

		rcmail.register_command('plugin.vmail_user.save', function() {
      var input_login = rcube_find_object('_vmail_userlogin');
			var input_pass  = rcube_find_object('_vmail_userpass');
			var input_pass2 = rcube_find_object('_vmail_userpass2');
      
      var input_datetod = rcube_find_object('_vmail_userday');
      var input_datetom = rcube_find_object('_vmail_usermon');
      var input_datetoy = rcube_find_object('_vmail_useryear');     

      var day   = parseInt(input_datetod.value);			
      var month = parseInt(input_datetom.value);
      var year  = parseInt(input_datetoy.value);
      
      if (input_login.value == "") {
        alert('Missing login name!');
				input_login.focus();
			} 
      else if (input_pass && input_pass.value == '') {
          alert('Missing password!');
          input_pass.focus();
      }
      else if (input_pass2 && input_pass2.value == '') {
          alert('Missing retype password!');
          input_pass2.focus();
      }
      else if (input_pass && input_pass2 && input_pass.value != input_pass2.value) {
          alert('Password input not equal!');
          input_pass.focus();
      }
      else if ( month > 12){
          alert('Month > 12!');
          input_datetom.focus();
	    } 
      else if ( day > 31 ){
          alert('Day not correct, use 0 or 1 - 31 !');
          input_datetod.focus();
	    } 
      else if ( year > 1 && year < 1970 ){
          alert('Year not correct! Use 0 or greater 1970.');      
          input_datetoy.focus();
      }
      else
  			document.forms.vmail_userform.submit();
		}, true);

	})
}


function vmail_user_edit(recid) {
	window.location.href = '?_task=settings&_action=plugin.vmail_user&_id=' + recid;
}


function row_toall(recid, active) {
	if (recid == "") {
		parent.rcmail.display_message(rcmail.gettext('textempty', 'vmail_user'),
				'error');
	} else {
		if (active == 1) {
			var active = 0;
			document.getElementById('tda_' + recid).setAttribute('onclick',
					'row_toall(' + recid + ',' + active + ');');
			document.getElementById('imga_' + recid).src = 'plugins/vmail_user/skins/default/disabled.png';
			rcmail.http_request('plugin.vmail_user.notall', '_id=' + recid, true);
			parent.rcmail.display_message(rcmail.gettext(
					'successfullydisabled', 'vmail_user'), 'confirmation');
		} else {
			var active = 1;
			document.getElementById('tda_' + recid).setAttribute('onclick',
					'row_toall(' + recid + ',' + active + ');');
			document.getElementById('imga_' + recid).src = 'plugins/vmail_user/skins/default/enabled.png';
			rcmail.http_request('plugin.vmail_user.toall', '_id=' + recid, true);
			parent.rcmail.display_message(rcmail.gettext('successfullyenabled',
					'vmail_user'), 'confirmation');
		}
	}
}


function row_edit(recid, active) {
	if (recid == "") {
		parent.rcmail.display_message(rcmail.gettext('textempty', 'vmail_user'),
				'error');
	} else {
		if (active == 1) {
			var active = 0;
			document.getElementById('tde_' + recid).setAttribute('onclick',
					'row_edit(' + recid + ',' + active + ');');
			document.getElementById('imge_' + recid).src = 'plugins/vmail_user/skins/default/disabled.png';
			rcmail.http_request('plugin.vmail_user.disable', '_id=' + recid, true);
			parent.rcmail.display_message(rcmail.gettext(
					'successfullydisabled', 'vmail_user'), 'confirmation');
		} else {
			var active = 1;
			document.getElementById('tde_' + recid).setAttribute('onclick',
					'row_edit(' + recid + ',' + active + ');');
			document.getElementById('imge_' + recid).src = 'plugins/vmail_user/skins/default/enabled.png';
			rcmail.http_request('plugin.vmail_user.enable', '_id=' + recid, true);
			parent.rcmail.display_message(rcmail.gettext('successfullyenabled',
					'vmail_user'), 'confirmation');
		}
	}
}
