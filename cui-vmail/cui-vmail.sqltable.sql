CREATE TABLE IF NOT EXISTS `access` (
  `id`          INT(11) unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `source`      VARCHAR(128) NOT NULL,
  `sourcestart` INT UNSIGNED DEFAULT 0,
  `sourceend`   INT UNSIGNED DEFAULT 0,
  `response`    varchar(255) NOT NULL default 'DUNNO',
  `type`        enum('recipient','sender','client') NOT NULL default 'client',
  `active`      TINYINT(1)   UNSIGNED NOT NULL default '1',
  `note`        VARCHAR(255) default '',
  INDEX source (type, source)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE utf8_unicode_ci;


CREATE TABLE IF NOT EXISTS `virtual_domains` (
  `id`          INT(11) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `name`        VARCHAR(80) NOT NULL,
  `transport`   VARCHAR(80) NOT NULL default 'pop3imap:',
  `active`      TINYINT(1)  UNSIGNED NOT NULL default '1',
  UNIQUE KEY domain (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE utf8_unicode_ci;


CREATE TABLE IF NOT EXISTS `virtual_users` (
  `id`          INT(11)      UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `domain_id`   INT(11)      UNSIGNED NOT NULL,
  `loginuser`   VARCHAR(128) NOT NULL,
  `password`    VARBINARY(128) NOT NULL default '',
  `username`    VARCHAR(128) NOT NULL default '',
  `datacomment` VARCHAR(128) NOT NULL default '',
  `mailprotect` SMALLINT(1)  UNSIGNED NOT NULL default '0',
  `quota`       BIGINT(20)   NOT NULL default '0',
  `editlevel`   SMALLINT(1)  UNSIGNED NOT NULL default '0',
  `toall`       TINYINT(1)   UNSIGNED NOT NULL DEFAULT '1',
  `admin`       TINYINT(1)   UNSIGNED NOT NULL DEFAULT '0',
  `expired`     TIMESTAMP    NOT NULL DEFAULT '000-00-00 00:00:00',
  `active`      TINYINT(1)   UNSIGNED NOT NULL default '1',
  `signature`   TEXT         NOT NULL default '',
  CONSTRAINT UNIQUE_EMAIL UNIQUE (domain_id,loginuser),
  KEY `domain_id` (`domain_id`),
  FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE utf8_unicode_ci;


CREATE TABLE IF NOT EXISTS `virtual_users_mbexpire` (
  `id`          INT(11) unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY, 
  `ownerid`     INT(11) unsigned NOT NULL, 
  `mailbox`     VARCHAR(255) NOT NULL,
  `expirestamp` bigint(11) unsigned NOT NULL default '0',
  `active`      TINYINT(1) unsigned NOT NULL default '1',
  FOREIGN KEY (ownerid) REFERENCES virtual_users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE utf8_unicode_ci;


CREATE TABLE IF NOT EXISTS `virtual_users_shares` (
  `from_user`   VARCHAR(255) not null,
  `to_user`     VARCHAR(255) not null,
  `state`       CHAR(1) not null default '1',
  primary key (from_user, to_user)        
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE utf8_unicode_ci;


CREATE TABLE IF NOT EXISTS `virtual_relayhosts` (
  `id`          INT(11) unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `domain_id`   INT(11) unsigned NOT NULL, 
  `email`       VARCHAR(128) NOT NULL default '',
  `username`    VARCHAR(128) NOT NULL default '',
  `password`    VARBINARY(128) NOT NULL default '',
  `active`      TINYINT(1)   unsigned NOT NULL default '1',
  `note`        varchar(128) default '',
  FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE utf8_unicode_ci;


CREATE TABLE IF NOT EXISTS `virtual_aliases` (
  `id`          INT(11) unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `domain_id`   INT(11) unsigned NOT NULL,
  `source`      VARCHAR(128) NOT NULL,
  `destination` VARCHAR(128) NOT NULL,
  `mailprotect` SMALLINT(1)  unsigned NOT NULL default '0',
  `active`      TINYINT(1)   unsigned NOT NULL default '1',
  FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE,
  INDEX source (domain_id, source) 
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE utf8_unicode_ci; 


CREATE TABLE IF NOT EXISTS `canonical_maps` (
  `id`          INT(11) unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `domain_id`   INT(11) unsigned NOT NULL,
  `source`      VARCHAR(128) NOT NULL, 
  `destination` VARCHAR(128) NOT NULL,
  `active`      TINYINT(1)   unsigned NOT NULL default '1',
  FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE,
  INDEX source (domain_id, source) 
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE utf8_unicode_ci;

CREATE TABLE IF NOT EXISTS `fetchmail` (
  `id`          INT(11) unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `ownerid`     INT(11) unsigned NOT NULL default '0',
  `servername`  VARCHAR(128) NOT NULL default '',
  `prot`        enum('pop3','imap') NOT NULL default 'pop3',
  `loginname`   VARCHAR(128) NOT NULL default '',
  `password`    VARBINARY(128) NOT NULL default '',
  `recipient`   VARCHAR(128) NOT NULL default '*',
  `options`     VARCHAR(40)  NOT NULL default 'keep',
  `sslproto`    VARCHAR(5)   NOT NULL default '',
  `sslfingerprint` VARCHAR(50)  NOT NULL default '',
  `active`      TINYINT(1) unsigned NOT NULL default '1',
  INDEX servername (servername)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE utf8_unicode_ci;


CREATE TABLE IF NOT EXISTS `maildropfilter` (
  `id`          INT(11) unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `ownerid`     INT(11) unsigned NOT NULL default '0',
  `position`    TINYINT(2)  unsigned NOT NULL default '50',
  `datefrom`    bigint(11)  unsigned NOT NULL default '0',
  `dateend`     bigint(11)  unsigned NOT NULL default '0',
  `filtertype`  enum('anymessage','startswith','endswith','contains','hasrecipient','mimemultipart','textplain','islargerthan') NOT NULL default 'anymessage',
  `flags`       SMALLINT(2) unsigned NOT NULL default '0',
  `fieldname`   VARCHAR(40) NOT NULL default '',
  `fieldvalue`  VARCHAR(80) NOT NULL default '',
  `tofolder`    VARCHAR(128) NOT NULL default '',
  `body`        TEXT,
  `active`      TINYINT(1)  unsigned NOT NULL default '1',
  `dateupdate`  timestamp NOT NULL default CURRENT_TIMESTAMP,
  FOREIGN KEY (ownerid) REFERENCES virtual_users(id) ON DELETE CASCADE,
  INDEX ownerid (ownerid, position),
  INDEX datefrom (datefrom),
  INDEX dateend (dateend)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE utf8_unicode_ci;

COMMIT;
