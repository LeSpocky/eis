<?php

/**
 * Vmail Autoresponder
 * Plugin that gives access to aut-of-office responder using vmail database
 *
 * @version 1.1 - 22.07.2016
 * @author Jens Vehlhaber jens@eisfair.org
 *
 * Requirements: vmail (eisfair-ng 2.7.x ... 3.x)
 *
 **/
             

class vmail_autoanswer extends rcube_plugin
{
  public $task = 'settings';
  private $db;

  function init() {
		$rcmail = rcmail::get_instance();
		$this->load_config();		
		$this->rc = &$rcmail;
    $this->add_texts('localization/');
    $this->add_hook('settings_actions', array($this, 'settings_actions'));  
    $this->register_action('plugin.vmail_autoanswer', array($this, 'vmail_autoanswer_init'));
    $this->register_action('plugin.vmail_autoanswer-save', array($this, 'vmail_autoanswer_save'));
    $this->include_script('vmail_autoanswer.js');
  }


  function settings_actions($args) {
    // register as settings action
//    $args['actions'][] = array('action' => 'plugin.vmail_autoanswer', 'class' => 'vmail_autoanswer', 'label' => 'autoresponder', 'domain' => 'vmail_autoanswer');
		// add autoresponder tab
		$args['actions'][] = array('action' => 'plugin.vmail_autoanswer', 'class' => 'vmail_autoanswer', 'label' => 'autoresponder', 'domain' => 'vmail_autoanswer', 'role' => 'button', 'aria-disabled' => 'false', 'tabindex' => '0');
    return $args;
  }


  function vmail_autoanswer_init() {
    $this->add_texts('localization/');
    $this->register_handler('plugin.body', array($this, 'vmail_autoanswer_form'));

    $rcmail = rcmail::get_instance();
    $rcmail->output->set_pagetitle($this->gettext('autoresponder')); 
    $rcmail->output->send('plugin');
  }

  
  function vmail_autoanswer_save() {
    $rcmail = rcmail::get_instance();
    $recno            = rcube_utils::get_input_value('_autoresponderrecno', RCUBE_INPUT_POST, FALSE, NULL);
    $body             = rcube_utils::get_input_value('_autoresponderbody', RCUBE_INPUT_POST, FALSE, NULL);
    $vmvac_startday   = rcube_utils::get_input_value('_autoresponderdatefromd', RCUBE_INPUT_POST, FALSE, NULL);
    $vmvac_startmon   = rcube_utils::get_input_value('_autoresponderdatefromm', RCUBE_INPUT_POST, FALSE, NULL);
    $vmvac_startyear  = rcube_utils::get_input_value('_autoresponderdatefromy', RCUBE_INPUT_POST, FALSE, NULL);    
    $vmvac_endday     = rcube_utils::get_input_value('_autoresponderdatetod', RCUBE_INPUT_POST, FALSE, NULL);
    $vmvac_endmon     = rcube_utils::get_input_value('_autoresponderdatetom', RCUBE_INPUT_POST, FALSE, NULL);
    $vmvac_endyear    = rcube_utils::get_input_value('_autoresponderdatetoy', RCUBE_INPUT_POST, FALSE, NULL);
    $enabled          = rcube_utils::get_input_value('_autoresponderenabled', RCUBE_INPUT_POST, FALSE, NULL);

    if(!$recno) $recno = 0;
    if(!$enabled) $enabled = 0;

    $datefrom = 0;
    if ( $vmvac_startyear > 0 ) {
        if (checkdate( $vmvac_startmon, $vmvac_startday, $vmvac_startyear )) {
            $datefrom = mktime(0,0,0, $vmvac_startmon, $vmvac_startday, $vmvac_startyear);
        }
    }
    $dateend = 0;
    if ( $vmvac_endyear > 0 ) {
        if (checkdate( $vmvac_endmon, $vmvac_endday, $vmvac_endyear )) {
            $dateend = mktime(0,0,0, $vmvac_endmon, $vmvac_endday, $vmvac_endyear);
        }
    }

    if (!($res = $this->write_data($recno, $datefrom, $dateend, $body, $enabled))) {
      $rcmail->output->command('display_message', $this->gettext('successfullysaved'), 'confirmation');
    } else {
      $rcmail->output->command('display_message', "DUPA.".$res, 'error');
    }
    $this->vmail_autoanswer_init();
  }


  function vmail_autoanswer_form() {
    $rcmail = rcmail::get_instance();

    // add some labels to client
    $rcmail->output->add_label(
      'vmail_autoanswer.autoresponder',
      'vmail_autoanswer.dateformatinconsistency',
      'vmail_autoanswer.dateformat',
      'vmail_autoanswer.entervalidmonth',
      'vmail_autoanswer.entervalidday',
      'vmail_autoanswer.enterfordigityear',
      'vmail_autoanswer.entervaliddate',
      'vmail_autoanswer.dateinpast',
      'vmail_autoanswer.subjectempty',
      'vmail_autoanswer.and'
    );
    
    $rcmail->output->add_script("var settings_account=true;");  

    $settings      = $this->get_data ();
    $recnoid       = $settings['id'];
    $body          = $settings['body'];
    $datefrom      = $settings['datefrom'];
    $dateend       = $settings['dateend'];
    $enabled       = $settings['active'];

    $vmvac_startday    = '00';
    $vmvac_startmon    = '00';
    $vmvac_startyear   = '0000';
    $vmvac_endday      = '00'; 
    $vmvac_endmon      = '00';
    $vmvac_endyear     = '0000';
    
    if ( $datefrom > 0 ){
      $vmvac_startday    = $rcmail->format_date ($datefrom, "d");
      $vmvac_startmon    = $rcmail->format_date ($datefrom, "m");
      $vmvac_startyear   = $rcmail->format_date ($datefrom, "Y");
    }
    if ( $dateend > 0 ){
      $vmvac_endday      = $rcmail->format_date ($dateend, "d");
      $vmvac_endmon      = $rcmail->format_date ($dateend, "m");
      $vmvac_endyear     = $rcmail->format_date ($dateend, "Y");
    }       
    
    $rcmail->output->set_env('product_name', $rcmail->config->get('product_name'));

    // allow the following attributes to be added to the <table> tag
    $attrib_str = html::attrib_string($attrib, array('style', 'class', 'id', 'cellpadding', 'cellspacing', 'border', 'summary'));

    // return the complete edit form as table
    $table = new html_table(array('cols' => 2));

    $input_autoresponderrecno = new html_hiddenfield(array('name' => '_autoresponderrecno', 'value' => $recnoid));
    $out = $input_autoresponderrecno->show();

    $input_autoresponderrecno = new html_hiddenfield(array('name' => '_autoresponderownerid', 'value' => $this->ownerid));
    $out .= $input_autoresponderrecno->show();
     
    $field_id = 'autoresponderbody';
    $input_autoresponderbody = new html_textarea(array('name' => '_autoresponderbody', 'id' => $field_id, 'cols' => 79, 'rows' => 20));

    $table->add('title', html::label($field_id, rcube_utils::rep_specialchars_output($this->gettext('autorespondermessage'),'' , true)));
    $table->add(null, $input_autoresponderbody->show($body));

    $field_id = 'autoresponderdatefrom';
    $input_autoresponderfromd = new html_inputfield(array('name' => '_autoresponderdatefromd', 'id' => $field_id, 'value' => $date, 'maxlength' => 2, 'size' => 2));
    $input_autoresponderfromm = new html_inputfield(array('name' => '_autoresponderdatefromm', 'id' => $field_id, 'value' => $date, 'maxlength' => 2, 'size' => 2));
    $input_autoresponderfromy = new html_inputfield(array('name' => '_autoresponderdatefromy', 'id' => $field_id, 'value' => $date, 'maxlength' => 4, 'size' => 4));     

    $table->add('title', html::label($field_id, rcube_utils::rep_specialchars_output($this->gettext('autoresponderdatefrom'),'', true)));
    $table->add(null, $input_autoresponderfromd->show($vmvac_startday) . " " .  
      $input_autoresponderfromm->show($vmvac_startmon) . " " . 
      $input_autoresponderfromy->show($vmvac_startyear) . " " .
      $this->gettext('dateformat'));

    $field_id = 'autoresponderdateto';
    $input_autorespondertod = new html_inputfield(array('name' => '_autoresponderdatetod', 'id' => $field_id, 'value' => $date, 'maxlength' => 2, 'size' => 2));
    $input_autorespondertom = new html_inputfield(array('name' => '_autoresponderdatetom', 'id' => $field_id, 'value' => $date, 'maxlength' => 2, 'size' => 2));
    $input_autorespondertoy = new html_inputfield(array('name' => '_autoresponderdatetoy', 'id' => $field_id, 'value' => $date, 'maxlength' => 4, 'size' => 4));

    $table->add('title', html::label($field_id, rcube_utils::rep_specialchars_output($this->gettext('autoresponderdateto'),'' , true)));
    $table->add(null, $input_autorespondertod->show($vmvac_endday) . " ". 
      $input_autorespondertom->show($vmvac_endmon) . " " . 
      $input_autorespondertoy->show($vmvac_endyear) . " " .
      $this->gettext('dateformat'));    

    $field_id = 'autoresponderenabled';
    $input_autoresponderenabled = new html_checkbox(array('name' => '_autoresponderenabled', 'id' => $field_id, 'value' => 1));

    $table->add('title', html::label($field_id, rcube_utils::rep_specialchars_output($this->gettext('autoresponderenabled'),'' , true)));
    $table->add(null, $input_autoresponderenabled->show($enabled));


    $out .= html::div(array('class' => 'box'),
	    html::div(array('id' => 'prefs-title', 'class' => 'boxtitle'), $this->gettext('autoresponder')) .
	    html::div(array('class' => 'boxcontent'), $table->show() .
	    html::p(null,
		  $rcmail->output->button(array(
			'command' => 'plugin.vmail_autoanswer-save',
			'type' => 'input',
			'class' => 'button mainaction',
			'label' => 'save'
    	)))));
 
    $rcmail->output->add_gui_object('autoresponderform', 'autoresponder-form');

    return $rcmail->output->form_tag(array(
    	'id' => 'autoresponderform',
	    'name' => 'autoresponderform',
	    'method' => 'post',
	    'action' => './?_task=settings&_action=plugin.vmail_autoanswer-save',
    ), $out);
  }


  private function get_ownerid() {
    $rcmail = rcmail::get_instance ();
    $dbh = $this->get_dbh ();
    /* login with username@domain.tld or only username */
    if (strstr($rcmail->user->data['username'],'@')){
        $sql = 'SELECT id FROM view_users WHERE email = %u LIMIT 0, 1';      
    } else {
        $sql = 'SELECT id FROM view_users WHERE loginuser = %u LIMIT 0, 1';        
    }
    $sql = str_replace('%u', $dbh->quote($rcmail->user->data['username'], 'text'), $sql); 
    $res = $dbh->query($sql);
    $result = $dbh->query ( $sql );
    if ($row = $dbh->fetch_array ( $result )) {
      return $row[0];
    } else {
      die("FATAL ERROR ::: RoundCube Plugin ::: vmail_autoanswer SQL query error: " . $sql);
      return '0';    
    }
  }


  private function get_data() {
    $rcmail = rcmail::get_instance ();
    $dbh = $this->get_dbh ();
    $sql = 'SELECT id, tofolder, body, datefrom, dateend, active FROM maildropfilter WHERE ownerid = %u AND tofolder LIKE "+%" LIMIT 0, 1';
    $sql = str_replace('%u', $dbh->quote( $this->get_ownerid (), 'text'), $sql);
    $res = $dbh->query($sql);
                 
    if ($err = $dbh->is_error()){
       return $err;
    }
    $ret = $dbh->fetch_assoc($res);
    return $ret;  
  }


  private function write_data($recno, $datefrom, $dateend, $body, $enabled) {
    $dbh = $this->get_dbh ();
    $sql = 'INSERT INTO maildropfilter (id, ownerid, position, datefrom, dateend, filtertype, flags, fieldname, fieldvalue, tofolder, body, active) ' . 
           ' values (%id, %od, %po, %df, %de, %ft, %fl, %fn, %fv, %to, %bd, %ac ) ON DUPLICATE KEY UPDATE position = %po, datefrom = %df, dateend = %de, tofolder = %to, body = %bd, active = %ac;';  
   
    $sql = str_replace('%id', $dbh->quote($recno, 'text'), $sql);
    $sql = str_replace('%od', $dbh->quote( $this->get_ownerid (), 'text'), $sql);
    
    $sql = str_replace('%po', $dbh->quote('75', 'text'), $sql);

    $sql = str_replace('%df', $dbh->quote($datefrom,'text'), $sql);            
    $sql = str_replace('%de', $dbh->quote($dateend,'text'), $sql);

    $sql = str_replace('%ft', $dbh->quote('anymessage', 'text'), $sql);
    $sql = str_replace('%fl', $dbh->quote('4', 'text'), $sql);
    $sql = str_replace('%fn', $dbh->quote('', 'text'), $sql);
    $sql = str_replace('%fv', $dbh->quote('', 'text'), $sql);
      
    $sql = str_replace('%to', $dbh->quote('+days=1', 'text'), $sql);
    $sql = str_replace('%bd', $dbh->quote($body,'text'), $sql);
    $sql = str_replace('%ac', $dbh->quote($enabled,'text'), $sql);
  
    $res = $dbh->query($sql);
    if ($err = $dbh->is_error())
      return $err;
  }

  /**
   * Initialize database handler  */
  private function get_dbh() {
		$rcmail = rcmail::get_instance ();  
    if (!$this->db) {
      if ($dsn = $rcmail->config->get ('vmail_db_dsn')) {
        $this->db = rcube_db::factory ($dsn, '', false);
        $this->db->set_debug ((bool) $rcmail->config->get ('sql_debug'));
        $this->db->db_connect ('r');
      } else {
//        $this->db = $rcmail->get_dbh ();
        die("FATAL ERROR ::: RoundCube Plugin ::: vmail_autoanswer ::: \$config['vmail_db_dsn'] undefined !!! ==> die");
      }
    }
    return $this->db;
  }  
  
}

?>
