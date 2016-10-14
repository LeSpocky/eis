<?php

/**
 * Vmail mail forwarding
 * Plugin that gives access to mail forwarding with using vmail database
 *
 * @version 1.1 - 22.07.2016
 * @author Jens Vehlhaber jens@eisfair.org
 *
 * Requirements: vmail (eisfair-ng 2.7.x ... 3.x)
 *
 **/
             

class vmail_forward extends rcube_plugin
{
  public $task = 'settings';
  private $db;

  function init() {
		$rcmail = rcmail::get_instance();
		$this->load_config();		
    $this->add_texts('localization/');
    $this->add_hook('settings_actions', array($this, 'settings_actions'));  
    $this->register_action('plugin.vmail_forward', array($this, 'vmail_forward_init'));
    $this->register_action('plugin.vmail_forward-save', array($this, 'vmail_forward_save'));
    $this->include_script('vmail_forward.js');
  }


  function settings_actions($args) {
		// add forward tab
		$args['actions'][] = array('action' => 'plugin.vmail_forward', 'class' => 'vmail_forward', 'label' => 'forward', 'domain' => 'vmail_forward', 'role' => 'button', 'aria-disabled' => 'false', 'tabindex' => '0');
    return $args;
  }


  function vmail_forward_init() {
    $this->add_texts('localization/');
    $this->register_handler('plugin.body', array($this, 'vmail_forward_form'));

    $rcmail = rcmail::get_instance();
    $rcmail->output->set_pagetitle($this->gettext('forward')); 
    $rcmail->output->send('plugin');
  }

  
  function vmail_forward_save() {
    $rcmail = rcmail::get_instance();
    $recno            = rcube_utils::get_input_value('_forwardrecno', RCUBE_INPUT_POST, FALSE, NULL);
//    $subject          = get_input_value('_forwardsubject', RCUBE_INPUT_POST);
    $tofolder         = rcube_utils::get_input_value('_forwardtofolder', RCUBE_INPUT_POST, FALSE, NULL);
    $vmfwd_startday   = rcube_utils::get_input_value('_forwarddatefromd', RCUBE_INPUT_POST, FALSE, NULL);
    $vmfwd_startmon   = rcube_utils::get_input_value('_forwarddatefromm', RCUBE_INPUT_POST, FALSE, NULL);
    $vmfwd_startyear  = rcube_utils::get_input_value('_forwarddatefromy', RCUBE_INPUT_POST, FALSE, NULL);    
    $vmfwd_endday     = rcube_utils::get_input_value('_forwarddatetod', RCUBE_INPUT_POST, FALSE, NULL);
    $vmfwd_endmon     = rcube_utils::get_input_value('_forwarddatetom', RCUBE_INPUT_POST, FALSE, NULL);
    $vmfwd_endyear    = rcube_utils::get_input_value('_forwarddatetoy', RCUBE_INPUT_POST, FALSE, NULL);
    $enabled          = rcube_utils::get_input_value('_forwardenabled', RCUBE_INPUT_POST, FALSE, NULL);

    if(!$recno) $recno = 0;
    if(!$enabled) $enabled = 0;

    $datefrom = 0;
    if ( $vmfwd_startyear > 0 ) {
        if (checkdate( $vmfwd_startmon, $vmfwd_startday, $vmfwd_startyear )) {
            $datefrom = mktime(0,0,0, $vmfwd_startmon, $vmfwd_startday, $vmfwd_startyear);
        }
    }
    $dateend = 0;
    if ( $vmfwd_endyear > 0 ) {
        if (checkdate( $vmfwd_endmon, $vmfwd_endday, $vmfwd_endyear )) {
            $dateend = mktime(0,0,0, $vmfwd_endmon, $vmfwd_endday, $vmfwd_endyear);
        }
    }

    if (!($res = $this->write_data($recno, $datefrom, $dateend, $tofolder, $enabled))) {
      $rcmail->output->command('display_message', $this->gettext('successfullysaved'), 'confirmation');
    } else {
      $rcmail->output->command('display_message', "DUPA.".$res, 'error');
    }
    $this->vmail_forward_init();
  }


  function vmail_forward_form()
  {
    $aremove = array("!", "+");
    $rcmail = rcmail::get_instance();

    // add some labels to client
    $rcmail->output->add_label(
      'vmail_forward.forward',
      'vmail_forward.dateformatinconsistency',
      'vmail_forward.dateformat',
      'vmail_forward.entervalidmonth',
      'vmail_forward.entervalidday',
      'vmail_forward.enterfordigityear',
      'vmail_forward.entervaliddate',
      'vmail_forward.dateinpast',
      'vmail_forward.subjectempty',
      'vmail_forward.and'
    );
    
    $rcmail->output->add_script("var settings_account=true;");  

    $settings      = $this->get_data ();
    $recnoid       = $settings['id'];
    $tofolder      = str_replace($aremove, "", $settings['tofolder']);
    $datefrom      = $settings['datefrom'];
    $dateend       = $settings['dateend'];
    $enabled       = $settings['active'];

    $vmfwd_startday    = '00';
    $vmfwd_startmon    = '00';
    $vmfwd_startyear   = '0000';
    $vmfwd_endday      = '00'; 
    $vmfwd_endmon      = '00';
    $vmfwd_endyear     = '0000';

    if ( $datefrom > 0 ){
      $vmfwd_startday    = $rcmail->format_date ($datefrom, "d");
      $vmfwd_startmon    = $rcmail->format_date ($datefrom, "m");
      $vmfwd_startyear   = $rcmail->format_date ($datefrom, "Y");
    }
    if ( $dateend > 0 ){
      $vmfwd_endday      = $rcmail->format_date ($dateend, "d");
      $vmfwd_endmon      = $rcmail->format_date ($dateend, "m");
      $vmfwd_endyear     = $rcmail->format_date ($dateend, "Y");
    }
       
    $rcmail->output->set_env('product_name', $rcmail->config->get('product_name'));

    // allow the following attributes to be added to the <table> tag
    $attrib_str = html::attrib_string($attrib, array('style', 'class', 'id', 'cellpadding', 'cellspacing', 'border', 'summary'));

    // return the complete edit form as table
    $table = new html_table(array('cols' => 2));

    $input_forwardrecno = new html_hiddenfield(array('name' => '_forwardrecno', 'value' => $recnoid));
    $out = $input_forwardrecno->show();
    
    $field_id = 'forwardtofolder';
    $input_forwardtofolder = new html_inputfield(array('name' => '_forwardtofolder', 'id' => $field_id, 'value' => $tofolder, 'maxlength' => 50, 'size' => 50));

    $table->add('title', html::label($field_id, rcube_utils::rep_specialchars_output($this->gettext('forwardmessage'),'' , true)));
    $table->add(null, $input_forwardtofolder->show($tofolder));

    $field_id = 'forwarddatefrom';
    $input_forwardfromd = new html_inputfield(array('name' => '_forwarddatefromd', 'id' => $field_id, 'value' => $date, 'maxlength' => 2, 'size' => 2));
    $input_forwardfromm = new html_inputfield(array('name' => '_forwarddatefromm', 'id' => $field_id, 'value' => $date, 'maxlength' => 2, 'size' => 2));
    $input_forwardfromy = new html_inputfield(array('name' => '_forwarddatefromy', 'id' => $field_id, 'value' => $date, 'maxlength' => 4, 'size' => 4));     

    $table->add('title', html::label($field_id, rcube_utils::rep_specialchars_output($this->gettext('forwarddatefrom'),'', true)));
    $table->add(null, $input_forwardfromd->show($vmfwd_startday) . " " .  
      $input_forwardfromm->show($vmfwd_startmon) . " " . 
      $input_forwardfromy->show($vmfwd_startyear) . " " .
      $this->gettext('dateformat'));

    $field_id = 'forwarddateto';
    $input_forwardtod = new html_inputfield(array('name' => '_forwarddatetod', 'id' => $field_id, 'value' => $date, 'maxlength' => 2, 'size' => 2));
    $input_forwardtom = new html_inputfield(array('name' => '_forwarddatetom', 'id' => $field_id, 'value' => $date, 'maxlength' => 2, 'size' => 2));
    $input_forwardtoy = new html_inputfield(array('name' => '_forwarddatetoy', 'id' => $field_id, 'value' => $date, 'maxlength' => 4, 'size' => 4));

    $table->add('title', html::label($field_id, rcube_utils::rep_specialchars_output($this->gettext('forwarddateto'),'' , true)));
    $table->add(null, $input_forwardtod->show($vmfwd_endday) . " ". 
      $input_forwardtom->show($vmfwd_endmon) . " " . 
      $input_forwardtoy->show($vmfwd_endyear) . " " .
      $this->gettext('dateformat'));    

    $field_id = 'forwardenabled';
    $input_forwardenabled = new html_checkbox(array('name' => '_forwardenabled', 'id' => $field_id, 'value' => 1));

    $table->add('title', html::label($field_id, rcube_utils::rep_specialchars_output($this->gettext('forwardenabled'),'' , true)));
    $table->add(null, $input_forwardenabled->show($enabled));


    $out .= html::div(array('class' => 'box'),
	    html::div(array('id' => 'prefs-title', 'class' => 'boxtitle'), $this->gettext('forwardtitle')) .
	    html::div(array('class' => 'boxcontent'), $table->show() .
	    html::p(null,
		  $rcmail->output->button(array(
			'command' => 'plugin.vmail_forward-save',
			'type' => 'input',
			'class' => 'button mainaction',
			'label' => 'save'
    	)))));
 
    $rcmail->output->add_gui_object('forwardform', 'forward-form');

    return $rcmail->output->form_tag(array(
    	'id' => 'forwardform',
	    'name' => 'forwardform',
	    'method' => 'post',
	    'action' => './?_task=settings&_action=plugin.vmail_forward-save',
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
    $sql = 'SELECT id, tofolder, body, datefrom, dateend, active FROM maildropfilter WHERE ownerid = %u AND tofolder LIKE "!%" AND position = "65" LIMIT 0, 1';
    $sql = str_replace('%u', $dbh->quote( $this->get_ownerid (), 'text'), $sql);
    $res = $dbh->query($sql);
                 
    if ($err = $dbh->is_error()){
       return $err;
    }
    $ret = $dbh->fetch_assoc($res);
    return $ret;  
  }


  private function write_data($recno, $datefrom, $dateend, $tofolder, $enabled) {
    $dbh = $this->get_dbh ();
    $sql = 'INSERT INTO maildropfilter (id, ownerid, position, datefrom, dateend, filtertype, flags, fieldname, fieldvalue, tofolder, body, active) ' . 
           ' values (%id, %od, %po, %df, %de, %ft, %fl, %fn, %fv, %to, %bd, %ac ) ON DUPLICATE KEY UPDATE position = %po, datefrom = %df, dateend = %de, tofolder = %to, body = %bd, active = %ac;';
   
    $sql = str_replace('%id', $dbh->quote($recno, 'text'), $sql);
    $sql = str_replace('%od', $dbh->quote( $this->get_ownerid (), 'text'), $sql);
    
    $sql = str_replace('%po', $dbh->quote('65', 'text'), $sql);

    $sql = str_replace('%df', $dbh->quote($datefrom, 'text'), $sql);            
    $sql = str_replace('%de', $dbh->quote($dateend, 'text'), $sql);

    $sql = str_replace('%ft', $dbh->quote('anymessage', 'text'), $sql);
    $sql = str_replace('%fl', $dbh->quote('4', 'text'), $sql);
    $sql = str_replace('%fn', $dbh->quote('', 'text'), $sql);
    $sql = str_replace('%fv', $dbh->quote('', 'text'), $sql);
      
    $sql = str_replace('%to', $dbh->quote('!' . $tofolder, 'text'), $sql);
    $sql = str_replace('%bd', $dbh->quote('Forward CC to: ' . $tofolder,'text'), $sql);
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
        die("FATAL ERROR ::: RoundCube Plugin ::: vmail_forward ::: \$config['vmail_db_dsn'] undefined !!! ==> die");
      }
    }
    return $this->db;
  }  
  
}

?>
