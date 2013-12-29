INSERT INTO virtual_domains (`name`,`active`)  VALUES ( 'virtual.test', 1 );
INSERT INTO virtual_domains (`name`,`transport`,`active`)  VALUES ( 'web.de', 'relay:smtp.web.de', 0 );

INSERT INTO virtual_users (`domain_id`,`loginuser`,`password`,`username`,`quota`,`mailprotect`,`signature`) VALUES (1, 'info', 'encrypt', 'Info user', 0, 0, '-- \r\nInfo\r\nDemo signature \r\n\r\n' );

INSERT INTO virtual_relayhosts (`domain_id`,`email`,`username`,`active` ) VALUES (2, 'testuser@web.de','testuser@web.de', 0 );

INSERT INTO virtual_users_mbexpire (`ownerid`,`mailbox`,`expirestamp`) VALUES (1, 'Drafts', 0 );
INSERT INTO virtual_users_mbexpire (`ownerid`,`mailbox`,`expirestamp`) VALUES (1, 'Send', 0 );
INSERT INTO virtual_users_mbexpire (`ownerid`,`mailbox`,`expirestamp`) VALUES (1, 'Trash', 0 );

INSERT INTO virtual_aliases (`domain_id`,`source`,`destination`) VALUES ( 1, 'abuse', 'user@virtual.test' );
INSERT INTO virtual_aliases (`domain_id`,`source`,`destination`) VALUES ( 1, 'mailadmin', 'user@virtual.test' );
INSERT INTO virtual_aliases (`domain_id`,`source`,`destination`) VALUES ( 1, 'postmaster', 'user@virtual.test' );
INSERT INTO virtual_aliases (`domain_id`,`source`,`destination`) VALUES ( 1, 'mailing-list1', 'user@virtual.test' );
INSERT INTO virtual_aliases (`domain_id`,`source`,`destination`) VALUES ( 1, 'mailing-list1', 'user2@virtual.test' );
INSERT INTO virtual_aliases (`domain_id`,`source`,`destination`) VALUES ( 1, 'mailing-list1', 'test@virtual.test' );
INSERT INTO virtual_aliases (`domain_id`,`source`,`destination`) VALUES ( 1, 'mailing-list1', 'user@external-domain.test' );

INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'abuse@','OK', 'recipient', 1, 'Dont do RBL checking for mail to abuse!' );
INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'postmaster@','OK', 'recipient', 0, 'Dont do RBL checking for mail to postmaster!' );

INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'aol.com','reject_unverified_sender','sender',1,'check if aol user exists');
INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'freenet.de','reject_unverified_sender','sender',1,'check if freenet user exists');
INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'gmail.com','reject_unverified_sender','sender',1,'check if google-mailuser exists');
INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'gmx.de','reject_unverified_sender','sender',1,'check if gmx user exists');
INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'googlemail.com','reject_unverified_sender','sender',1,'check if google-mailuser exists');
INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'hotmail.com','reject_unverified_sender','sender',1,'check if hotmail-user exists');
INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'web.de','reject_unverified_sender','sender',1,'check if web user exists');
INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'yahoo.com','reject_unverified_sender','sender',1,'check if yahoo-user exists');

INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'amazon.com','OK','client',1,'amazon');
INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'as.finanzit.net','OK','client',1,'Sparkassen');
INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'easyjet.com','OK','client',1,'easyJet');
INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'emarsys.net','OK','client',1,'eBay a.o.');
INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'mailgate.db-group.com','OK','client',1,'Deutsche Bahn AG');
INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'mo-p00-ob.rzone.de','OK','client',1,'Strato Rechenzentrum');
INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'mo-p01-ob.rzone.de','OK','client',1,'Strato Rechenzentrum');
INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'mo-p02-ob.rzone.de','OK','client',1,'Strato Rechenzentrum');
INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'mo-p03-ob.rzone.de','OK','client',1,'Strato Rechenzentrum');
INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'mo-p04-ob.rzone.de','OK','client',1,'Strato Rechenzentrum');
INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'mo-p05-ob.rzone.de','OK','client',1,'Strato Rechenzentrum');
INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'mo-p06-ob.rzone.de','OK','client',1,'Strato Rechenzentrum');
INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'mo-p07-ob.rzone.de','OK','client',1,'Strato Rechenzentrum');
INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'roy.matrix.msu.edu','OK','client',1,'h-soz-u-kult');
INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'wendy.matrix.msu.edu','OK','client',1,'h-soz-u-kult');
INSERT INTO `access` (`source`,`response`,`type`,`active`,`note`) VALUES ( 'mailout.zvab.com','OK','client',1,'ZVAB');

INSERT INTO fetchmail VALUES ( 1, 1, 'mail.testserver.test', 'pop3', 'user', '', 'info@virtual.test', 'keep', '', '', 0);

INSERT INTO `maildropfilter` (`id`, `ownerid`, `position`, `datefrom`, `dateend`, `filtertype`, `flags`, `fieldname`, `fieldvalue`, `tofolder`, `body`, `active`) VALUES
(1, 1, 50, 0, 0, 'contains',   8, 'Message-ID', 'bugs.eisfair.org',        'Tracker', 'Move to Tracker folder', 1),
(2, 1, 50, 0, 0, 'contains',   8, 'List-Id',    'org-website.eisler.',     'org-website', 'Move to org-website', 1),
(3, 1, 50, 0, 0, 'contains',   8, 'List-Id',    'org-dev.eisler.',         'org-dev', 'Move to Org-dev', 1),
(4, 1, 50, 0, 0, 'contains',   8, 'List-Id',    'eisfair-dev.eisler.',     'eisfair-dev', 'Move to eisfair-dev folder', 1),
(5, 1, 50, 0, 0, 'contains',   8, 'List-Id',    'nettworks-aktiv.eisler.', 'networks', 'Move to the networks folder', 1),
(6, 1, 50, 0, 0, 'contains',   8, 'List-Id',    'eisfair-team.eisler.',    'eisfair-team', 'Move to the eisfair-team folder', 1 ),
(7, 1, 50, 0, 0, 'contains',   8, 'List-Id',    'fleis-team.eisler',       'fleis-team', 'Move to the fleis-team folder', 1),
(8, 1, 50, 0, 0, 'anymessage', 4, '',           '',                        '!user2@virtual.test', 'Forward CC to: user2@virtual.test', 0),
(9, 1, 50, 0, 0, 'startwith',  0, 'subject',    '[SPAM]',                  'Trash',      'Write spam to Trash', 0),
(10,1, 75, 0, 0, 'anymessage', 0, '',           '',                        '+days=4','Write the out of office message text here...', 0);

COMMIT;

