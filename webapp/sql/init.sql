TRUNCATE TABLE themes;
TRUNCATE TABLE icons;
TRUNCATE TABLE reservation_slots;
TRUNCATE TABLE livestream_viewers_history;
TRUNCATE TABLE livecomment_reports;
TRUNCATE TABLE ng_words;
TRUNCATE TABLE reactions;
TRUNCATE TABLE tags;
TRUNCATE TABLE livestream_tags;
TRUNCATE TABLE livecomments;
TRUNCATE TABLE livestreams;
TRUNCATE TABLE users;

ALTER TABLE `themes` auto_increment = 1;
ALTER TABLE `icons` auto_increment = 1;
ALTER TABLE `reservation_slots` auto_increment = 1;
ALTER TABLE `livestream_tags` auto_increment = 1;
ALTER TABLE `livestream_viewers_history` auto_increment = 1;
ALTER TABLE `livecomment_reports` auto_increment = 1;
ALTER TABLE `ng_words` auto_increment = 1;
ALTER TABLE `reactions` auto_increment = 1;
ALTER TABLE `tags` auto_increment = 1;
ALTER TABLE `livecomments` auto_increment = 1;
ALTER TABLE `livestreams` auto_increment = 1;
ALTER TABLE `users` auto_increment = 1;

DROP INDEX `livestream_id_idx` ON `livestream_tags`;
ALTER TABLE livestream_tags ADD INDEX livestream_id_idx(livestream_id);

DROP INDEX `user_id_idx` ON `icons`;
ALTER TABLE icons ADD INDEX user_id_idx(user_id);

DROP INDEX `name_idx` ON `isudns`.records;
ALTER TABLE `isudns`.records ADD INDEX name_idx(name);

DROP INDEX `livestream_id_idx` ON reactions;
ALTER TABLE reactions ADD INDEX livestream_id_idx(livestream_id);

DROP INDEX `livestream_id_idx` ON livecomments;
ALTER TABLE livecomments ADD INDEX livestream_id_idx(livestream_id);

DROP INDEX `user_id_idx` ON themes;
ALTER TABLE themes ADD INDEX user_id_idx(user_id);

DROP INDEX `start_end_idx` ON reservation_slots;
ALTER TABLE reservation_slots ADD INDEX start_end_idx(start_at, end_at);
