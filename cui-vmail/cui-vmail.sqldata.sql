INSERT IGNORE INTO virtual_domains (`id`,`name`,`transport`,`active`)  VALUES
( 1, 'virtual.test', 'pop3imap:', 1 ),
( 2, 'web.de', 'relay:smtp.web.de', 0 );

INSERT IGNORE INTO virtual_users (`id`,`domain_id`,`loginuser`,`password`,`username`,`quota`,`mailprotect`,`signature`) VALUES
(1, 1, 'info', 'encrypt', 'Info user', 0, 0, '-- \r\nInfo\r\nDemo signature \r\n\r\n' );

INSERT IGNORE INTO virtual_relayhosts (`id`,`domain_id`,`email`,`username`,`active`) VALUES
(1, 2, 'testuser@web.de','testuser@web.de', 0 );

INSERT IGNORE INTO virtual_users_mbexpire (`id`,`ownerid`,`mailbox`,`expirestamp`) VALUES
(1, 1, 'Drafts', 0 ),
(2, 1, 'Send', 0 ),
(3, 1, 'Trash', 0 );

INSERT IGNORE INTO virtual_aliases (`id`,`domain_id`,`source`,`destination`) VALUES
(1, 1, 'abuse', 'user@virtual.test' ),
(2, 1, 'mailadmin', 'user@virtual.test' ),
(3, 1, 'postmaster', 'user@virtual.test' ),
(4, 1, 'mailing-list1', 'user@virtual.test' ),
(5, 1, 'mailing-list1', 'user2@virtual.test' ),
(6, 1, 'mailing-list1', 'test@virtual.test' ),
(7, 1, 'mailing-list1', 'user@external-domain.test' );

REPLACE INTO `access` (`id`, `source`, `sourcestart`, `sourceend`, `response`, `type`, `active`, `note`) VALUES
(1, 'abuse@', 0, 0, 'OK', 'recipient', 1, 'Dont do RBL checking for mail to abuse!'),
(2, 'postmaster@', 0, 0, 'OK', 'recipient', 1, 'Dont do RBL checking for mail to postmaster!'),
(3, 'aol.com', 0, 0, 'reject_unverified_sender', 'sender', 1, 'check if aol user exists'),
(4, 'freenet.de', 0, 0, 'reject_unverified_sender', 'sender', 1, 'check if freenet user exists'),
(5, 'gmail.com', 0, 0, 'reject_unverified_sender', 'sender', 1, 'check if google-mailuser exists'),
(6, 'gmx.de', 0, 0, 'reject_unverified_sender', 'sender', 1, 'check if gmx user exists'),
(7, 'googlemail.com', 0, 0, 'reject_unverified_sender', 'sender', 1, 'check if google-mailuser exists'),
(8, 'hotmail.com', 0, 0, 'reject_unverified_sender', 'sender', 1, 'check if hotmail-user exists'),
(9, 'web.de', 0, 0, 'reject_unverified_sender', 'sender', 1, 'check if web user exists'),
(10, 'yahoo.com', 0, 0, 'reject_unverified_sender', 'sender', 1, 'check if yahoo-user exists'),
(11, 'msn.com', 0, 0, 'reject_unverified_sender', 'sender', 1, 'Check if msn user exists'),
(12, 'amazon.com', 0, 0, 'OK', 'client', 1, 'amazon'),
(13, 'as.finanzit.net', 0, 0, 'OK', 'client', 1, 'Sparkassen'),
(14, 'easyjet.com', 0, 0, 'OK', 'client', 1, 'easyJet'),
(15, 'emarsys.net', 0, 0, 'OK', 'client', 1, 'eBay a.o.'),
(16, 'mailgate.db-group.com', 0, 0, 'OK', 'client', 1, 'Deutsche Bahn AG'),
(17, 'roy.matrix.msu.edu', 0, 0, 'OK', 'client', 1, 'h-soz-u-kult'),
(18, 'wendy.matrix.msu.edu', 0, 0, 'OK', 'client', 1, 'h-soz-u-kult'),
(19, 'mailout.zvab.com', 1654545705, 1654545705, 'OK', 'client', 1, 'ZVAB'),
(20, 'cendris.net', 0, 0, 'OK', 'client', 1, 'TNT'),
(21, '35.9.18.5/26', 587796997, 587797068, 'OK', 'client', 1, '*.matrix.msu.edu'),
(22, '54.240.0.1/24', 921698305, 921698559, 'OK', 'client', 1, 'a0-NNN.smtp-out.eu-west-1.amazonses.com'),
(23, '62.50.42.199', 1043475143, 1043475143, 'OK', 'client', 1, 'mailbox.mercateo.com'),
(24, '62.146.106.17/28', 1049782801, 1049782824, 'OK', 'client', 1, '*.udag.de (united domains)'),
(25, '64.12.143.75/27', 1074564939, 1074564946, 'OK', 'client', 1, 'omr-mNN.mx.aol.com'),
(26, '65.54.190.139/26', 1094106763, 1094106790, 'OK', 'client', 1, 'bay0-omc3-sNN.bay0.hotmail.com'),
(27, '74.125.83.1/25', 1249727233, 1249727359, 'OK', 'client', 1, 'mail-ee0-fNNN.google.com'),
(28, '77.87.228.73/30', 1297605705, 1297605708, 'OK', 'client', 1, 'mN-bn.bund.de'),
(29, '78.46.1.93', 1311637853, 1311637853, 'OK', 'client', 1, 'Hetzner-Robot'),
(30, '80.12.242.123/28', 1343025787, 1343025798, 'OK', 'client', 1, 'smtpNN.smtpout.orange.fr'),
(31, '80.67.18.70', 1346572870, 1346572870, 'OK', 'client', 1, 'ml06.ispgateway.de'),
(32, '80.67.31.24/27', 1346576152, 1346576170, 'OK', 'client', 1, 'smtprelayNN.ispgateway.de'),
(33, '80.149.113.165', 1351971237, 1351971237, 'OK', 'client', 1, 'tcmail13.telekom.de'),
(34, '80.152.192.96', 1352188000, 1352188000, 'OK', 'client', 1, 'vst-pro.de'),
(35, '80.237.138.239', 1357744879, 1357744879, 'OK', 'client', 1, 'mi016.mc1.hosteurope.de'),
(36, '81.28.224.28', 1360846876, 1360846876, 'OK', 'client', 1, 'relay2.mail.vrmd.de'),
(37, '85.10.252.151', 1426783383, 1426783383, 'OK', 'client', 1, 'fmx-1.kjm2.de'),
(38, '85.25.111.142', 1427730318, 1427730318, 'OK', 'client', 1, 'triton110.server4you.de'),
(39, '86.110.227.18', 1450107666, 1450107666, 'OK', 'client', 1, 'bratislava.goethe.org'),
(40, '87.193.142.54', 1472302646, 1472302646, 'OK', 'client', 1, 'Stiftung-EVZ'),
(41, '88.198.56.103', 1489385575, 1489385575, 'OK', 'client', 1, 'mailer1202.agnitas.de'),
(42, '89.1.8.213', 1493240021, 1493240021, 'OK', 'client', 1, 'cc-smtpout3.netcologne.de'),
(43, '89.245.129.21/28', 1509261589, 1509261599, 'OK', 'client', 1, 'mailNNdo.versatel.de'),
(44, '91.143.85.24', 1536120088, 1536120088, 'OK', 'client', 1, 's1.dns-thnetz.de'),
(45, '109.68.50.241', 1833186033, 1833186033, 'OK', 'client', 1, 'mx01.goethe.de'),
(46, '109.68.50.242', 1833186034, 1833186034, 'OK', 'client', 1, 'mx02.goethe.de'),
(47, '109.234.107.135', 1844079495, 1844079495, 'OK', 'client', 1, 'mail.nettworks.org'),
(48, '130.133.4.66', 2189755458, 2189755458, 'OK', 'client', 1, 'outpost1.zedat.fu-berlin.de'),
(49, '134.76.10.18', 2253130258, 2253130258, 'OK', 'client', 1, 'amailer.gwdg.de'),
(50, '134.147.64.30', 2257797150, 2257797150, 'OK', 'client', 1, 'mi.ruhr-uni-bochum.de'),
(51, '139.18.1.26', 2333212954, 2333212954, 'OK', 'client', 1, 'v1.rz.uni-leipzig.de'),
(52, '141.20.85.70', 2366920006, 2366920006, 'OK', 'client', 1, 'lists.clio-online.de'),
(53, '141.35.1.28', 2367881500, 2367881500, 'OK', 'client', 1, 'mailout0.rz.uni-jena.de'),
(54, '141.54.1.101/27', 2369126757, 2369126777, 'OK', 'client', 1, 'smtpout-NN.uni-weimar.de'),
(55, '176.9.212.65/26', 2953434177, 2953434239, 'OK', 'client', 1, 'mx-pNN.newstroll.de'),
(56, '192.109.42.17', 3228379665, 3228379665, 'OK', 'client', 1, 'fallback-mx.in-berlin.de'),
(57, '193.17.243.2', 3239179010, 3239179010, 'OK', 'client', 1, 'mail3.dbtg.de Bundestag'),
(58, '193.175.191.133', 3249520517, 3249520517, 'OK', 'client', 1, 'fhf3.fh-flensburg.de'),
(59, '193.191.3.133', 3250520965, 3250520965, 'OK', 'client', 1, 'customer.belnet'),
(60, '194.8.210.194', 3255358146, 3255358146, 'OK', 'client', 1, 'albert.hochschulverband.de'),
(61, '194.25.134.17/29', 3256452625, 3256452629, 'OK', 'client', 1, 'mailoutNN.t-online.de'),
(62, '194.25.134.80/29', 3256452688, 3256452693, 'OK', 'client', 1, 'mailoutNN.t-online.de'),
(63, '194.94.40.22', 3260950550, 3260950550, 'OK', 'client', 1, 'mail.dhm.de'),
(64, '194.94.155.51', 3260980019, 3260980019, 'OK', 'client', 1, 'rrzmta1.uni-regensburg.de'),
(65, '194.94.196.130/31', 3260990594, 3260990595, 'OK', 'client', 1, 'kswedgeN.klassik-stiftung.de'),
(66, '195.37.187.185', 3274030009, 3274030009, 'OK', 'client', 1, 'gatekeeper.stadtbibo-weimar.de'),
(67, '195.121.247.6', 3279550214, 3279550214, 'OK', 'client', 1, 'cpsmtp-fia03.kpnxchange.com'),
(68, '195.243.179.164', 3287528356, 3287528356, 'OK', 'client', 1, 'mail.telesec.de'),
(69, '200.68.102.217', 3359925977, 3359925977, 'OK', 'client', 1, 'irwf.org.ar'),
(70, '205.188.109.194', 3451678146, 3451678146, 'OK', 'client', 1, 'omr-d02.mx.aol.com'),
(71, '205.188.252.208', 3451714768, 3451714768, 'OK', 'client', 1, 'omr-d01.mx.aol.com'),
(72, '212.7.146.1/30', 3557265921, 3557265923, 'OK', 'client', 1, 'mxNN.versatel.de'),
(73, '212.27.42.0/24', 3558550016, 3558550271, 'OK', 'client', 1, 'free.fr'),
(74, '212.29.0.42', 3558670378, 3558670378, 'OK', 'client', 1, 'mailman.bpb.de'),
(75, '212.227.15.0/27', 3571650304, 3571650335, 'OK', 'client', 1, 'mout.web.de, gmx.de'),
(76, '212.227.17.0/27', 3571650816, 3571650847, 'OK', 'client', 1, 'mout.web.de, mout.gmx.net'),
(77, '212.227.126.130', 3571678850, 3571678851, 'OK', 'client', 1, 'moutng.kundenserver.de'),
(78, '212.227.126.187', 3571678907, 3571678907, 'OK', 'client', 1, 'moutng.kundenserver.de'),
(79, '213.17.161.74', 3574702410, 3574702410, 'OK', 'client', 1, 'fpnp.pl'),
(80, '213.174.32.96', 3584958560, 3584958560, 'OK', 'client', 1, 'mailout01.ims-firmen.de'),
(81, '216.218.133.242', 3638199794, 3638199794, 'OK', 'client', 1, 'PitneyBowes'),
(82, '217.5.205.143', 3641036175, 3641036175, 'OK', 'client', 1, 'mail3.packstation.de'),
(83, '217.76.96.46', 3645661230, 3645661230, 'OK', 'client', 1, 'mail.bn-online.net'),
(84, '176.32.127.4/25', 2954919684, 2954919790, 'OK', 'client', 1, 'smtp-out-127-NNN.amazon.com'),
(85, '192.30.252.192/27', 2954919684, 2954919790, 'OK', 'client', 1, 'github-smtp2-extN.iad.github.net');

INSERT IGNORE INTO `access` (`id`, `source`, `sourcestart`, `sourceend`, `response`, `type`, `active`, `note`) VALUES
(200, '255.255.255.255', 0, 0, 'OK', 'client', 0, 'BENUTZERDATEN ab ID Nr. 200');

INSERT IGNORE INTO fetchmail VALUES ( 1, 1, 'mail.testserver.test', 'pop3', 'user', '', 'info@virtual.test', 'keep', '', '', 0);

INSERT IGNORE INTO `maildropfilter` (`id`, `ownerid`, `position`, `datefrom`, `dateend`, `filtertype`, `flags`, `fieldname`, `fieldvalue`, `tofolder`, `body`, `active`) VALUES
(1, 1, 50, 0, 0, 'contains',   8, 'Message-ID', 'bugs.eisfair.org',        'Tracker', 'Move to Tracker folder', 1),
(2, 1, 50, 0, 0, 'contains',   8, 'List-Id',    'org-website.eisler.',     'org-website', 'Move to org-website', 1),
(3, 1, 50, 0, 0, 'contains',   8, 'List-Id',    'org-dev.eisler.',         'org-dev', 'Move to Org-dev', 1),
(4, 1, 50, 0, 0, 'contains',   8, 'List-Id',    'eisfair-dev.eisler.',     'eisfair-dev', 'Move to eisfair-dev folder', 1),
(5, 1, 50, 0, 0, 'contains',   8, 'List-Id',    'nettworks-aktiv.eisler.', 'networks', 'Move to the networks folder', 1),
(6, 1, 50, 0, 0, 'contains',   8, 'List-Id',    'eisfair-team.eisler.',    'eisfair-team', 'Move to the eisfair-team folder', 1 ),
(7, 1, 50, 0, 0, 'contains',   8, 'List-Id',    'fleis-team.eisler',       'fleis-team', 'Move to the fleis-team folder', 1),
(8, 1, 50, 0, 0, 'anymessage', 4, '',           '',                        '!user2@virtual.test', 'Forward CC to: user2@virtual.test', 0),
(9, 1, 50, 0, 0, 'startwith',  0, 'subject',    '[SPAM]',                  'Trash',      'Write spam to Trash', 0),
(10,1, 75, 0, 0, 'anymessage', 0, '',           '',                        '+days=4','Write the out of office message text here...', 0)
ON DUPLICATE KEY UPDATE id = id ;

COMMIT;

