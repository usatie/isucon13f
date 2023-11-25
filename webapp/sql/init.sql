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

DELIMITER //

DROP PROCEDURE IF EXISTS RecreateIndexIfNeeded;
CREATE PROCEDURE RecreateIndexIfNeeded(
    IN p_database_name VARCHAR(255),
    IN p_table_name VARCHAR(255),
    IN p_index_name VARCHAR(255),
    IN p_index_columns VARCHAR(255)
)
BEGIN
    DECLARE indexExists INT;

    SELECT COUNT(*)
    INTO indexExists
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE table_schema = p_database_name
      AND table_name = p_table_name
      AND index_name = p_index_name;

    IF indexExists > 0 THEN
        SET @s = CONCAT('DROP INDEX ', p_index_name, ' ON ', p_database_name, '.', p_table_name);
        PREPARE stmt FROM @s;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;

    SET @s = CONCAT('ALTER TABLE ', p_database_name, '.', p_table_name, ' ADD INDEX ', p_index_name, '(', p_index_columns, ')');
    PREPARE stmt FROM @s;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END //

DELIMITER ;

CALL RecreateIndexIfNeeded('isupipe', 'livestream_tags', 'livestream_id_idx', 'livestream_id');
CALL RecreateIndexIfNeeded('isupipe', 'icons', 'user_id_idx', 'user_id');
CALL RecreateIndexIfNeeded('isudns', 'records', 'name_idx', 'name');
CALL RecreateIndexIfNeeded('isupipe', 'reactions', 'livestream_id_idx', 'livestream_id');
CALL RecreateIndexIfNeeded('isupipe', 'livecomments', 'livestream_id_idx', 'livestream_id');
CALL RecreateIndexIfNeeded('isupipe', 'themes', 'user_id_idx', 'user_id');
CALL RecreateIndexIfNeeded('isupipe', 'reservation_slots', 'start_end_idx', 'start_at, end_at');
CALL RecreateIndexIfNeeded('isupipe', 'ng_words', 'user_livestream_id_idx', 'user_id, livestream_id');
