--------------------------------------------------------------------------------- 
--Database Backups for all databases For Previous Week 
--------------------------------------------------------------------------------- 
SELECT TOP 100 CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS SERVER
	,bs.database_name
	,bs.backup_start_date
	,bs.backup_finish_date
	,bs.expiration_date
	,CASE bs.type
		WHEN 'D'
			THEN 'Database'
		WHEN 'L'
			THEN 'Log'
		WHEN 'I'
			THEN 'Diff'
		END AS backup_type
	,bs.backup_size
	,bmf.logical_device_name
	,bmf.physical_device_name
	,bs.name AS backupset_name
	,bs.description
	,first_lsn
	,last_lsn
	,checkpoint_lsn
	,database_backup_lsn
	,is_copy_only
FROM msdb.dbo.backupmediafamily AS bmf
INNER JOIN msdb.dbo.backupset AS bs ON bmf.media_set_id = bs.media_set_id
WHERE database_name = 'StagingTurkey'
ORDER BY bs.backup_finish_date DESC
