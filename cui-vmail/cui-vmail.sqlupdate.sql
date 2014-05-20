DROP TABLE IF EXISTS `vmail_version`;
COMMIT;
# add new fields:
ALTER TABLE `virtual_users` ADD `admin` TINYINT(1) UNSIGNED NOT NULL DEFAULT 0 AFTER `toall`;
ALTER TABLE `access` ADD `sourcestart` INT UNSIGNED DEFAULT 0 AFTER `source`;
ALTER TABLE `access` ADD `sourceend` INT UNSIGNED DEFAULT 0 AFTER `sourcestart`;
COMMIT;
UPDATE `access` SET `sourcestart` = INET_ATON(`source`), `sourceend` = INET_ATON(`source`) WHERE source REGEXP '^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$';
# set new vmail version
CREATE TABLE IF NOT EXISTS `vmail_version`(`id` int(10) unsigned NOT NULL) ENGINE=InnoDB;
INSERT INTO `vmail_version` (`id`) VALUES ( 10 );
COMMIT;