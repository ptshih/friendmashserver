-- --------------------------------------------------------------------------------
-- Routine DDL
-- --------------------------------------------------------------------------------
DELIMITER //

CREATE DEFINER=`friendmash`@`%` PROCEDURE `update_statistic_summary`()
BEGIN

  declare timeFrame varchar(50);
  declare totalMashes int;
  declare maleMashes int;
  declare femaleMashes int;
  declare timePlayed int;
  declare totalUsers int;
  
  set timeFrame = 'Total';
  set totalMashes = (select sum(votes+votes_network) from profiles);
  set maleMashes =  (select count(*) from results a join users b on a.winner_id = b.facebook_id where b.gender='male');
  set femaleMashes = totalMashes - maleMashes;
  set timePlayed = totalMashes*3.2/60;
	  -- this needs to be fixed to calculate based on a sessions table
	  -- guess based on 3.2sec per mash
  set totalUsers = (select count(*) from users);

	-- insert statistics
	drop table if exists temp_statistic_summary;
	create temporary table temp_statistic_summary
	select 1 as id, cast('Total Mashes' as char(100)) as name, cast(timeFrame as char(50)) as 'time_frame', totalMashes as value;

	insert delayed into temp_statistic_summary
	select 2, 'Total Users', 'Total', totalUsers;

	insert delayed  into temp_statistic_summary
	select 3, 'Time played (in minutes)', timeFrame, timePlayed as 'value';

	insert delayed into temp_statistic_summary
	select 4 as id, 'Male mashes played' as name, timeFrame, maleMashes as 'value';

  	insert delayed into temp_statistic_summary
  	select 5 as id, 'Female mashes played' as name, timeFrame, femaleMashes as 'value';

 	insert delayed into temp_statistic_summary
  	select 6 as id, 'Visit our Facebook fan page. Search "FriendMash" and checkout the photos and updates!' as name, timeFrame, null as 'value';

	-- create table statistic_summary
	-- idx, name, timeframe, value
	CREATE TABLE IF NOT EXISTS `statistic_summary` (
	  `id` int(11) NOT NULL AUTO_INCREMENT,
	  `name` varchar(100) DEFAULT NULL,
	  `time_frame` varchar(50) DEFAULT NULL,
	  `value` int(11) DEFAULT NULL,
	  PRIMARY KEY (`id`)
	) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

	IF( (select count(*) from statistic_summary)<1) then
	   insert into statistic_summary select * from temp_statistic_summary;
	ELSE
	  update statistic_summary a, temp_statistic_summary b
	  set a.value = b.value
	  where a.id=b.id;
	END IF;
END//
