DROP VIEW IF EXISTS `view_sender_access`;
CREATE VIEW `view_sender_access` AS
  SELECT source, response
  FROM access WHERE type='sender' AND active = 1
  ORDER BY source LIMIT 1;

DROP VIEW IF EXISTS `view_client_access`;
CREATE VIEW `view_client_access` AS
  SELECT source, response
  FROM access WHERE type='client' AND active = 1
  ORDER BY source LIMIT 1;

DROP VIEW IF EXISTS `view_recipient_access`;
CREATE VIEW `view_recipient_access` AS
  SELECT source, response
  FROM access WHERE type='recipient' AND active = 1
  ORDER BY source LIMIT 1;

DROP VIEW IF EXISTS `view_users`;
CREATE VIEW `view_users` AS
  SELECT virtual_users.id,
  CONCAT(virtual_users.loginuser, _utf8 '@', virtual_domains.name) AS email,
  virtual_users.password,
  virtual_users.loginuser
  FROM virtual_users LEFT JOIN virtual_domains ON virtual_users.domain_id = virtual_domains.id
  WHERE virtual_users.active = 1 AND virtual_domains.active = 1 AND (UNIX_TIMESTAMP(virtual_users.expired) = 0 or UNIX_TIMESTAMP(virtual_users.expired) > UNIX_TIMESTAMP(NOW()))
  ORDER BY domain_id, loginuser;

DROP VIEW IF EXISTS `view_domains`;
CREATE VIEW `view_domains` AS
  SELECT id, name, transport
  FROM virtual_domains WHERE active = 1 AND NOT transport LIKE 'relay:%'
  ORDER BY name;

DROP VIEW IF EXISTS `view_domains_local`;
CREATE VIEW `view_domains_local` AS
  SELECT id,
         name,
         transport
  FROM virtual_domains WHERE active = 1 AND ( transport LIKE 'pop3imap:%' OR transport LIKE 'fax:%' OR transport LIKE 'sms:%' )
  ORDER BY name;

DROP VIEW IF EXISTS `view_domains_relay`;
CREATE VIEW `view_domains_relay` AS
  SELECT id, 
         CONCAT('@', name) AS name,
         SUBSTR( transport, 7) AS transport
  FROM virtual_domains WHERE active = 1 AND transport LIKE 'relay:%'
  ORDER BY name;

DROP VIEW IF EXISTS `view_mailprotect`;
CREATE VIEW `view_mailprotect` AS
  SELECT CONCAT(virtual_users.loginuser, _utf8 '@', virtual_domains.name) AS email,
         CONCAT('restrictions_', virtual_users.mailprotect) AS restriction
  FROM virtual_users LEFT JOIN virtual_domains ON virtual_users.domain_id = virtual_domains.id
  WHERE virtual_users.active = 1 AND virtual_domains.active = 1
  ORDER BY name, loginuser;

DROP VIEW IF EXISTS `view_quota`;
CREATE VIEW `view_quota` AS
  SELECT CONCAT(virtual_users.loginuser, _utf8 '@', virtual_domains.name) AS email,
         virtual_users.loginuser,
         virtual_users.quota
  FROM virtual_users LEFT JOIN virtual_domains ON virtual_users.domain_id = virtual_domains.id
  WHERE virtual_users.active = 1 AND virtual_domains.active = 1
  ORDER BY name, loginuser;

DROP VIEW IF EXISTS `view_expire`;
CREATE VIEW `view_expire` AS
  SELECT CONCAT(virtual_users.loginuser, _utf8 '@', virtual_domains.name) AS email,
         virtual_users.loginuser,
         virtual_users_mbexpire.mailbox,
         virtual_users_mbexpire.expirestamp
  FROM virtual_users 
  LEFT JOIN virtual_domains ON virtual_users.domain_id = virtual_domains.id
  LEFT JOIN virtual_users_mbexpire ON virtual_users_mbexpire.ownerid = virtual_users.id  
  WHERE virtual_users.active = 1 AND virtual_domains.active = 1 AND virtual_users_mbexpire.active = 1
  ORDER BY domain_id, loginuser, mailbox;

DROP VIEW IF EXISTS `view_signature`;
CREATE VIEW `view_signature` AS
  SELECT CONCAT(virtual_users.loginuser, _utf8 '@', virtual_domains.name) AS email,
  virtual_users.signature
  FROM virtual_users LEFT JOIN virtual_domains ON virtual_users.domain_id = virtual_domains.id
  WHERE virtual_users.active = 1 AND virtual_domains.active = 1
  ORDER BY name, loginuser;

DROP VIEW IF EXISTS `view_aliases`;
CREATE VIEW `view_aliases` AS
  SELECT CONCAT('an-alle@',virtual_domains.name) as email, 
  CONCAT(virtual_users.loginuser, _utf8 '@', virtual_domains.name) AS destination
  FROM virtual_users LEFT JOIN virtual_domains ON virtual_users.domain_id = virtual_domains.id
  WHERE virtual_users.active = 1 AND virtual_domains.active = 1 AND virtual_users.toall = 1 AND
  (UNIX_TIMESTAMP(virtual_users.expired) = 0 or UNIX_TIMESTAMP(virtual_users.expired) > UNIX_TIMESTAMP(NOW()))
  UNION ALL
  SELECT CONCAT(virtual_aliases.source, _utf8 '@', virtual_domains.name) AS email,
  destination
  FROM virtual_aliases LEFT JOIN virtual_domains
  ON virtual_aliases.domain_id = virtual_domains.id
  WHERE virtual_aliases.active = 1 AND virtual_domains.active = 1
  ORDER BY email, destination;

DROP VIEW IF EXISTS `view_canonical_maps`;
CREATE VIEW `view_canonical_maps` AS SELECT
  CONCAT(canonical_maps.source, '@', virtual_domains.name) AS email,
  canonical_maps.destination
  FROM canonical_maps LEFT JOIN virtual_domains ON canonical_maps.domain_id = virtual_domains.id 
  WHERE canonical_maps.active = 1
  ORDER BY domain_id, source;

DROP VIEW IF EXISTS `view_relaylogin`;
CREATE VIEW `view_relaylogin` AS
  SELECT SUBSTR( virtual_domains.transport, 7) AS transport,
  virtual_relayhosts.email AS email,
  virtual_relayhosts.username AS username,
  virtual_relayhosts.password AS password
  FROM virtual_relayhosts LEFT JOIN virtual_domains ON virtual_relayhosts.domain_id = virtual_domains.id
  WHERE virtual_relayhosts.active = 1 AND virtual_domains.active = 1
  ORDER BY transport, username;

COMMIT;

