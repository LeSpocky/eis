<?php

/******************************************************************************
 * Vmail user Roundcube Plugin (RC0.4 and above)
 * This software distributed under the terms of the GNU General Public License
 * as published by the Free Software Foundation
 * Further details on the GPL license can be found at 
 * http://www.gnu.org/licenses/gpl.html
 * By contributing authors release their contributed work under this license
 * For more information see README.md file 
 *****************************************************************************/

class vmail_user extends rcube_plugin {

  public $task = 'settings';
  private $db;
  private $editlevel;
  private $domainid;
  private $rcmail_inst = null;

  function init() {
    $this->rcmail_inst = rcmail::get_instance();
    $this->load_config();

    if (!strstr($this->rcmail_inst->config->get ('vmail_useredit'), $this->rcmail_inst->user->data['username'] ))
      return;   
    
    $this->add_texts ( 'localization/', true );
    $this->register_action ( 'plugin.vmail_user',         array ( $this, 'init_html' ) );
    $this->register_action ( 'plugin.vmail_user.save',    array ( $this, 'save' ) );
    $this->register_action ( 'plugin.vmail_user.toall',   array ( $this, 'toall' ) );
    $this->register_action ( 'plugin.vmail_user.notall',  array ( $this, 'notall' ) );
    $this->register_action ( 'plugin.vmail_user.enable',  array ( $this, 'enable' ) );
    $this->register_action ( 'plugin.vmail_user.disable', array ( $this, 'disable' ) );
    $this->api->output->add_handler ( 'vmail_user_form',  array ( $this, 'gen_form' ) );
    $this->api->output->add_handler ( 'vmail_user_table', array ( $this, 'gen_table' ) );
    $this->include_script ( 'vmail_user.js' );
    $this->domainid  = $this->get_domain_id ();
    $this->editlevel = $this->get_editlevel ();
  }


  function init_html() {
    // set firefox tab title:
    $this->rcmail_inst->output->set_pagetitle($this->gettext('vmail_user'));
    $this->rcmail_inst->output->send('vmail_user.vmail_user');
  }


  function toall() {
    $recid =  rcube_utils::get_input_value ( '_id', rcube_utils::INPUT_GET );
    if ($recid != 0 || $recid != '') {
      $sql = "UPDATE virtual_users SET toall = '1' WHERE id = '$recid'";
      $dbh = $this->get_dbh ();
      $update = $dbh->query ( $sql ); 
    }
  }


  function notall() {
    $recid =  rcube_utils::get_input_value ( '_id', rcube_utils::INPUT_GET );
    if ($recid != 0 || $recid != '') {
      $sql = "UPDATE virtual_users SET toall = '0' WHERE id = '$recid'";
      $dbh = $this->get_dbh ();
      $update = $dbh->query ( $sql );
    }
  }


  function disable() {
    $recid =  rcube_utils::get_input_value ( '_id', rcube_utils::INPUT_GET );
    if ($recid != 0 || $recid != '') {
      $sql = "UPDATE virtual_users SET active = '0' WHERE id = '$recid'";
      $dbh = $this->get_dbh ();
      $update = $dbh->query ( $sql );
    }
  }


  function enable() {
    $recid =  rcube_utils::get_input_value ( '_id', rcube_utils::INPUT_GET );
    if ($recid != 0 || $recid != '') {
      $sql = "UPDATE virtual_users SET active = '1' WHERE id = '$recid'";
      $dbh = $this->get_dbh ();
      $update = $dbh->query ( $sql );
    }
  }


  function save() {
    $recid     = rcube_utils::get_input_value ( '_id', RCUBE_INPUT_POST, FALSE, NULL );
    $loginname = rcube_utils::get_input_value ( '_vmail_userlogin', RCUBE_INPUT_POST, FALSE, NULL );
    $username  = rcube_utils::get_input_value ( '_vmail_username', RCUBE_INPUT_POST, FALSE, NULL );
    $pass      = rcube_utils::get_input_value ( '_vmail_userpass', RCUBE_INPUT_POST, FALSE, NULL );
    $pass2     = rcube_utils::get_input_value ( '_vmail_userpass2', RCUBE_INPUT_POST, FALSE, NULL );
    $signat    = rcube_utils::get_input_value ( '_vmail_usersignat', RCUBE_INPUT_POST, FALSE, NULL );
    $toall     = rcube_utils::get_input_value ( '_vmail_usertoall', RCUBE_INPUT_POST, FALSE, NULL );
    $enabled   = rcube_utils::get_input_value ( '_vmail_userenabled', RCUBE_INPUT_POST, FALSE, NULL );
    $uday      = rcube_utils::get_input_value ( '_vmail_userday', RCUBE_INPUT_POST, FALSE, NULL );
    $umon      = rcube_utils::get_input_value ( '_vmail_usermon', RCUBE_INPUT_POST, FALSE, NULL );
    $uyear     = rcube_utils::get_input_value ( '_vmail_useryear', RCUBE_INPUT_POST, FALSE, NULL );
    $newentry  = rcube_utils::get_input_value ( '_vmail_usernewentry', RCUBE_INPUT_POST, FALSE, NULL );
    $editlevel = rcube_utils::get_input_value ( '_vmail_usereditlevel', RCUBE_INPUT_POST, FALSE, NULL );

    $expireds = 0;
    if ($uyear > 0  ) {
      if (checkdate ( $umon, $uday, $uyear )) { 
        $expireds = $uyear.'-'.$umon.'-'.$uday.' 00:00:00'; 
      }
    } 
    if (! $enabled) {
      $enabled = 0;
    } else {
      $enabled = 1;
    }
    if (! $toall) {
      $toall = 0;
    } else {
      $toall = 1;
    }
    $comment = str_replace("eiche", "e", $pass );
    if ($editlevel=='' ) {
      $editlevel = $this->editlevel;
    }
    if ($this->editlevel == 0 ) {
      $editlevel = 5;
    }

    $dbh = $this->get_dbh ();
    if ($newentry or $recid == '') {
      if ( $pass == 'xxxxxxxxxx') {
        $pass = 'eiche500';
        $comment = 'e500';
      }
      $sql = 'INSERT INTO virtual_users ( domain_id, active, expired, loginuser, username, password, datacomment, toall, signature, editlevel ) VALUES ( ' 
                      . '"' . $this->domainid . '", '
                      . '"' . $enabled          . '", '
                      . '"' . $expireds         . '", '
                      . '"' . $loginname        . '", '
                      . '"' . $username         . '", '
                      . 'AES_ENCRYPT("' . $pass . '", "' . $this->rcmail_inst->config->get ('vmail_sql_encrypt_key') . '"), '
                      . '"' . $comment          . '", '
                      . '"' . $toall            . '", '
                      . '"' . $signat           . '", '
                      . '"' . $editlevel        . '")';
    } else {
      if ( $pass == 'xxxxxxxxxx') {
        $sql = 'UPDATE virtual_users SET active = %ac, expired = %de, loginuser = %ul, username = %un, toall = %ta, signature = %sn, editlevel = %el WHERE id  = "'. $recid  .'"';
      } else {
        $sql = 'UPDATE virtual_users SET active = %ac, expired = %de, loginuser = %ul, username = %un, password = AES_ENCRYPT(%pw, %pk), datacomment = %dc, toall = %ta, signature = %sn, editlevel = %el WHERE id = "'. $recid .'"';
      }
    }
    $sql = str_replace('%ac', $dbh->quote($enabled, 'text'), $sql); 
    $sql = str_replace('%de', $dbh->quote($expireds, 'text'), $sql);
    $sql = str_replace('%ul', $dbh->quote($loginname, 'text'), $sql);
    $sql = str_replace('%un', $dbh->quote($username, 'text'), $sql);
    $sql = str_replace('%pw', $dbh->quote($pass, 'text'), $sql);    
    $sql = str_replace('%pk', $dbh->quote($this->rcmail_inst->config->get ('vmail_sql_encrypt_key'), 'text'), $sql); 
    $sql = str_replace('%dc', $dbh->quote($comment, 'text'), $sql);
    $sql = str_replace('%ta', $dbh->quote($toall, 'text'), $sql);
    $sql = str_replace('%sn', $dbh->quote($signat, 'text'), $sql);
    $sql = str_replace('%el', $dbh->quote($editlevel, 'text'), $sql);

    $res = $dbh->query ( $sql );
    if ($err = $dbh->is_error ()) {
      $this->rcmail_inst->output->command('display_message', 'MySQL '. $res . '<br>' . $sql , 'error'); 
    } else {   
      $this->rcmail_inst->output->command ( 'display_message', $this->gettext ( 'successfullysaved' ), 'confirmation' );
    }
    $this->init_html ();
  }


  function gen_form() {
    $recid =  rcube_utils::get_input_value ( '_id', rcube_utils::INPUT_GET );

    $pass    = 'xxxxxxxxxx';
    $pass2   = 'xxxxxxxxxx';
    $toall   = 1;
    $enabled = 1;
    if ($this->editlevel == 0 ) {
      $editlevel = 5;
    } else {
      $editlevel = $this->editlevel;
    }

    // auslesen start
    if ($recid != '' || $recid != 0) {
      $sql = 'SELECT active, UNIX_TIMESTAMP(`expired`) AS expired, loginuser, username, toall, signature, editlevel FROM  virtual_users WHERE id = "' . $recid . '" LIMIT 0 , 1'; 
      $dbh = $this->get_dbh ();
      $result = $dbh->query ( $sql );
      while ( $row = $this->db->fetch_assoc ( $result ) ) {
        $enabled     = $row ['active'];
        $expired     = $row ['expired'];
        $loginname   = $row ['loginuser'];
        $username    = $row ['username'];
        $toall       = $row ['toall'];
        $signat      = $row ['signature'];
        $editlevel   = $row ['editlevel'];
      }

      if ( $expired > 0) {
        $uday  = $this->rcmail_inst->format_date ($expired, "d"); 
        $umon  = $this->rcmail_inst->format_date ($expired, "m");
        $uyear = $this->rcmail_inst->format_date ($expired, "Y");
      } else {
        $uday  = '00';
        $umon  = '00';
        $uyear = '0000';
      }
    } else {
      $uyear   = $this->rcmail_inst->format_date (time() + (365 * 24 * 60 * 60), "Y" );
      $umon    = $this->rcmail_inst->format_date (time() + (395 * 24 * 60 * 60), "m" );
      $uday    = '01';
      $signat =  $this->rcmail_inst->config->get ('vmail_user_signature');      
    }
    $newentry = 0;
    
    $out .= '<fieldset><legend>' . $this->gettext ( 'vmail_user_to' ) . '</legend>' . "\n";
    $out .= '<br />' . "\n";
    $out .= '<table' . $attrib_str . ">\n\n";
    
    $hidden_id = new html_hiddenfield ( array (
				'name' => '_id',
				'value' => $recid 
      ) );
    $out .= $hidden_id->show ();

    $field_id = 'vmail_userlogin';
    $input_vmail_userlogin = new html_inputfield ( array (
				'name' => '_vmail_userlogin',
				'id' => $field_id,
				'maxlength' => 80,
				'size' => 40
      ) );
    $out .= sprintf ( "<tr><td class=\"title\"><label for=\"%s\">%s</label>:</td><td>%s</td></tr>\n", $field_id, rcube_utils::rep_specialchars_output ( $this->gettext ( 'vmail_userloginname' ),'','',true ), $input_vmail_userlogin->show ( $loginname ) );

    $field_id = 'vmail_username';
    $input_vmail_username = new html_inputfield ( array (
				'name' => '_vmail_username',
				'id' => $field_id,
				'maxlength' => 80,
				'size' => 40 
      ) );
    $out .= sprintf ( "<tr><td class=\"title\"><label for=\"%s\">%s</label>:</td><td>%s</td></tr>\n", $field_id, rcube_utils::rep_specialchars_output ( $this->gettext ( 'vmail_userusername' ),'','',true ), $input_vmail_username->show ( $username ) );
		
    $field_id = 'vmail_userpass';
    $input_vmail_userpass = new html_passwordfield ( array (
				'name' => '_vmail_userpass',
				'id' => $field_id,
				'maxlength' => 40,
				'size' => 40,
				'autocomplete' => 'off'
      ) );
    $out .= sprintf ( "<tr><td class=\"title\"><label for=\"%s\">%s</label>:</td><td>%s</td></tr>\n", $field_id, rcube_utils::rep_specialchars_output ( $this->gettext ( 'password' ),'','',true ), $input_vmail_userpass->show ( $pass ) );

    $field_id = 'vmail_userpass2';
    $input_vmail_userpass2 = new html_passwordfield ( array (
				'name' => '_vmail_userpass2',
				'id' => $field_id,
				'maxlength' => 40,
				'size' => 40,
				'autocomplete' => 'off'
      ) );
    $out .= sprintf ( "<tr><td class=\"title\"><label for=\"%s\">%s</label>:</td><td>%s</td></tr>\n", $field_id, rcube_utils::rep_specialchars_output ( $this->gettext ( 'password' ),'','',true ), $input_vmail_userpass2->show ( $pass2 ) );

    $field_id = 'vmail_usertoall';
    $input_vmail_usertoall = new html_checkbox ( array (
				'name' => '_vmail_usertoall',
				'id' => $field_id,
				'value' => '1'
      ) );
    $out .= sprintf ( "<tr><td class=\"title\"><label for=\"%s\">%s</label>:</td><td>%s</td></tr>\n", $field_id, rcube_utils::rep_specialchars_output ( $this->gettext ( 'vmail_usertoall' ),'','',true ), $input_vmail_usertoall->show ( $toall ) );

    $field_id = 'vmail_usersignat';
    $input_vmail_usersignat = new html_textarea ( array (
				'name' => '_vmail_usersignat',
				'id' => $field_id,
				'cols' => 51, 
				'rows' => 7 
      ) );
    $out .= sprintf ( "<tr><td class=\"title\"><label for=\"%s\">%s</label>:</td><td>%s</td></tr>\n", $field_id, rcube_utils::rep_specialchars_output ( $this->gettext ( 'vmail_usersignat' ) ,'','',true), $input_vmail_usersignat->show ( $signat ) );

    $field_id = 'vmail_userenabled';
    $input_vmail_userenabled = new html_checkbox ( array (
				'name' => '_vmail_userenabled',
				'id' => $field_id,
				'value' => '1' 
      ) );
    $out .= sprintf ( "<tr><td class=\"title\"><label for=\"%s\">%s</label>:</td><td>%s</td></tr>\n", $field_id, rcube_utils::rep_specialchars_output ( $this->gettext ( 'vmail_userenabled' ),'','',true ), $input_vmail_userenabled->show ( $enabled ) );

    $field_id = 'vmail_useryear';
    $input_vmail_useryear = new html_inputfield ( array (
				'name' => '_vmail_useryear',
				'id' => $field_id,
				'maxlength' => 4,
				'size' => 4 
      ) );
    $field_id = 'vmail_usermon';
    $input_vmail_usermon = new html_inputfield ( array (
				'name' => '_vmail_usermon',
				'id' => $field_id,
				'maxlength' => 2,
				'size' => 2 
      ) );
    $field_id = 'vmail_userday';
    $input_vmail_userday = new html_inputfield ( array (
				'name' => '_vmail_userday',
				'id' => $field_id,
				'maxlength' => 2,
				'size' => 2 
      ) );
    $out .= sprintf ( "<tr><td class=\"title\"><label for=\"%s\">%s</label>:</td><td>%s</td></tr>\n", $field_id, rcube_utils::rep_specialchars_output ( $this->gettext ( 'vmail_userexpired' ),'','',true ), $input_vmail_userday->show ( $uday ) . $input_vmail_usermon->show ( $umon )  . $input_vmail_useryear->show ( $uyear ) . ' ' . $this->gettext ( 'vmail_userymd' ),'','',true );

    if ( $this->editlevel == 0 ) {
      $field_id = 'vmail_usereditlevel';
      $input_vmail_usereditlevel = new html_inputfield ( array (
				'name' => '_vmail_usereditlevel',
				'id' => $field_id,
				'maxlength' => 2,
				'size' => 2 
        ) );
      $out .= sprintf ( "<tr><td class=\"title\"><label for=\"%s\">%s</label>:</td><td>%s</td></tr>\n", $field_id, rcube_utils::rep_specialchars_output ( $this->gettext ( 'vmail_usereditlevel' ),'','',true ), $input_vmail_usereditlevel->show ( $editlevel ) );
    } else {
      $hidden_editlevel = new html_hiddenfield ( array (
				'name' => '_vmail_usereditlevel',
				'value' => $editlevel
        ) );
      $out .= $hidden_editlevel->show ();
    }
/*
    if ($recid != '' || $recid != 0) {
      $field_id = 'vmail_usernewentry';
      $input_vmail_usernewentry = new html_checkbox ( array (
				'name' => '_vmail_usernewentry',
				'id' => $field_id,
				'value' => '1' 
        ) );
      $out .= sprintf ( "<tr><td class=\"title\"><label for=\"%s\">%s</label>:</td><td>%s</td></tr>\n", $field_id, rcube_utils::rep_specialchars_output ( $this->gettext ( 'vmail_usernewentry' ),'','',true ), $input_vmail_usernewentry->show ( $newentry ) );
    }
*/
    $out .= "\n</table>";
    $out .= '<br />' . "\n";
    $out .= "</fieldset>\n";
    
    $this->rcmail_inst->output->add_gui_object ( 'vmail_userform', 'vmail_user-form' );
    return $out;
  }


  function gen_table($attrib) {
    $recid   = rcube_utils::get_input_value ( '_id', rcube_utils::INPUT_GET );
    $sql = 'SELECT id, loginuser, username, datacomment, toall, active, DATE_FORMAT(`expired`, "%Y-%m-%d") AS expired FROM virtual_users WHERE domain_id = "' . $this->domainid . '" AND editlevel >= ' . $this->editlevel . ' ORDER by loginuser';
    $dbh = $this->get_dbh ();
    $result = $dbh->query ( $sql );
		$nrows = $dbh->num_rows ( $result );
		$out = '<fieldset><legend>' . $this->gettext ( 'vmail_user_entries' ) ." (<span id=\"vmail_user_items_number\">$nrows</span>)". '</legend>' . "\n";
		$out .= '<br />' . "\n";
		$mailuser_table = new html_table ( array (
				'id' => 'mailuser-table',
				'class' => 'records-table',
				'cellspacing' => '0',
				'cols' => 6 
		) );
		$mailuser_table->add_header ( array (
				'width' => '80px' 
		), $this->gettext ( 'vmail_userloginname' ) );
		$mailuser_table->add_header ( array (
				'width' => '100px' 
		), $this->gettext ( 'username' ) );
		$mailuser_table->add_header ( array (
				'width' => '30px' 
		), $this->gettext ( 'vmail_userdatacomment' ) );
		$mailuser_table->add_header ( array (
				'width' => '24px' 
		),  $this->gettext ( 'vmail_usertoall' )  );
		$mailuser_table->add_header ( array (
				'width' => '24px' 
		),  $this->gettext ( 'vmail_useractive' )  );
		$mailuser_table->add_header ( array (
				'width' => '40px' 
		),  $this->gettext ( 'vmail_userexpired' )  );

		while ( $row = $dbh->fetch_assoc ( $result ) ) {
			$class = ($class == 'odd' ? 'even' : 'odd');
			if ($row ['id'] == $recid) {
				$class = 'selected';
			}
			$mailuser_table->set_row_attribs ( array (
					'class' => $class,
					'id' => 'fetch_' . $row ['id'] 
			) );
			$this->_fetch_row ( $mailuser_table, $row ['id'], $row ['loginuser'], $row ['username'], $row ['datacomment'], $row ['toall'], $row ['active'], $row ['expired'], $attrib );
		} 
		if ($nrows == 0) {
			$mailuser_table->add ( array (
					'colspan' => '6' 
			), rcube_utils::rep_specialchars_output ( $this->gettext ( 'nofetch' ),'','',true ) );
			$mailuser_table->set_row_attribs ( array (
					'class' => 'odd' 
			) );
			$mailuser_table->add_row ();
		}
		$out .= "<div id=\"fetch-cont\">" . $mailuser_table->show () . "</div>\n";
		$out .= '<br />' . "\n";
		$out .= "</fieldset>\n";
		return $out;
  }


	private function _fetch_row($mailuser_table, $recid, $col_loginuser, $col_username,  $col_datacomment, $col_toall, $col_active, $col_expired, $attrib) {
		$mailuser_table->add ( array (
				'onclick' => 'vmail_user_edit(' . $recid . ');' 
		), $col_loginuser );  
		$mailuser_table->add ( array (
				'onclick' => 'vmail_user_edit(' . $recid . ');' 
		), $col_username );  
		$mailuser_table->add ( array (
				'onclick' => 'vmail_user_edit(' . $recid . ');' 
		), $col_datacomment );

		$disable_button = html::img ( array (
				'src' => $attrib ['enableicon'],
				'alt' => $this->gettext ( 'enabled' ),
				'border' => 0,
				'id' => 'imga_' . $recid 
		) );
		$enable_button = html::img ( array (
				'src' => $attrib ['disableicon'],
				'alt' => $this->gettext ( 'disabled' ),
				'border' => 0,
				'id' => 'imga_' . $recid 
		) );
		if ($col_toall == 1) {
			$status_button = $disable_button;
		} else {
			$status_button = $enable_button;
		}
		$mailuser_table->add ( array (
				'id' => 'tda_' . $recid,
				'onclick' => 'row_toall(' . $recid . ',' . $col_toall . ');' 
		), $status_button );

		$disable_button = html::img ( array (
				'src' => $attrib ['enableicon'],
				'alt' => $this->gettext ( 'enabled' ),
				'border' => 0,
				'id' => 'imge_' . $recid 
		) );
		$enable_button = html::img ( array (
				'src' => $attrib ['disableicon'],
				'alt' => $this->gettext ( 'disabled' ),
				'border' => 0,
				'id' => 'imge_' . $recid 
		) ); 
 		if ($col_active == 1) {
			$status_button = $disable_button;
		} else {
			$status_button = $enable_button;
		}
		$mailuser_table->add ( array (
				'id' => 'tde_' . $recid,
				'onclick' => 'row_edit(' . $recid . ',' . $col_active . ');' 
		), $status_button );

		$mailuser_table->add ( array (
				'onclick' => 'vmail_user_edit(' . $recid . ');' 
		), $col_expired );

		return $mailuser_table;
	}


/**
  return the domain id from login user  */
  private function get_domain_id() {
    $dbh = $this->get_dbh ();
    if (strstr($this->rcmail_inst->user->data['username'],'@')){ 
      $sql = 'SELECT id FROM virtual_domains WHERE name = %u LIMIT 0 , 1';
      $usernamex = explode('@', $this->rcmail_inst->user->data['username']);
      $sql = str_replace('%u', $dbh->quote($usernamex[1],'text'), $sql);    
    } else {
      $sql = 'SELECT domain_id FROM virtual_users WHERE loginuser = %u LIMIT 0 , 1';
      $sql = str_replace('%u', $dbh->quote($this->rcmail_inst->user->data['username'],'text'), $sql);
    }
    $result = $dbh->query ( $sql );
    if ($row = $dbh->fetch_array ( $result )) {
      return $row[0];
    } else {
      die("FATAL ERROR ::: RoundCube Plugin ::: vmail_user SQL query error: " . $sql);
      return '0';
    }
  }

/**
  return the edit_level from login user  */
  private function get_editlevel() {
    $dbh = $this->get_dbh ();
    if (strstr($this->rcmail_inst->user->data['username'],'@')){ 
      $sql = 'SELECT editlevel FROM virtual_users WHERE loginuser = %u AND domain_id = ' . $this->get_domain_id () . ' LIMIT 0 , 1';
      $usernamex = explode('@', $this->rcmail_inst->user->data['username']);
      $sql = str_replace('%u', $dbh->quote($usernamex[0],'text'), $sql);
    } else {
      $sql = 'SELECT editlevel FROM virtual_users WHERE loginuser = %u LIMIT 0 , 1';
      $sql = str_replace('%u', $dbh->quote($this->rcmail_inst->user->data['username'],'text'), $sql);
    }
    $result = $dbh->query ( $sql );
    if ($row = $dbh->fetch_array ( $result )) {
      return $row[0];
    } else {
      die("FATAL ERROR ::: RoundCube Plugin ::: vmail_user SQL query error: " . $sql);
      return '0';
    }
  }


  /**
   * Initialize database handler  */
  private function get_dbh() {
    if (!$this->db) {
      if ($dsn = $this->rcmail_inst->config->get ('vmail_db_dsn')) {
        $this->db = rcube_db::factory ($dsn, '', false);
        $this->db->set_debug ((bool) $this->rcmail_inst->config->get ('sql_debug'));
        $this->db->db_connect ('r');
      } else {
        die("FATAL ERROR ::: RoundCube Plugin ::: vmail_user ::: \$config['db_vmail_dsn'] undefined !!! ==> die");
      }
    }
    return $this->db;
  }

}

?>
