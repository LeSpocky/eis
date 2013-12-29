DELIMITER //
CREATE TRIGGER `filter_last_edit` BEFORE UPDATE ON `maildropfilter`
 FOR EACH ROW SET NEW.dateupdate = NOW()
//
DELIMITER ;

COMMIT;

