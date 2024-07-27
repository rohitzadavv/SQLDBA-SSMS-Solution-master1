SELECT	--j.name,
		'exec msdb..sp_start_job '''+j.name+'''
GO
'
FROM msdb..sysjobs_view j
WHERE j.name like 'DBA Log Walk%'
AND j.enabled = 1


SELECT	d.name, d.recovery_model_desc
FROM	sys.databases d
WHERE	d.name IN ('AMG_Avg','AMG_Extra','AMG_Music','AMG_MusicMore','DSG_EU','Facebook','MuzeUK','MuzeVideo','RGS','Staging2','Twitter')
ORDER BY d.recovery_model_desc, d.name

SELECT	db_name(mf.database_id) as dbName, mf.physical_name
FROM	sys.master_files mf
WHERE	db_name(mf.database_id) in ('AMG_Avg','AMG_Extra','AMG_Music','AMG_MusicMore','DSG_EU','Facebook','MuzeUK','MuzeVideo','RGS','Staging2','Twitter')