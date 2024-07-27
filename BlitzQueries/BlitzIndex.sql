use tempdb
EXEC DBA.dbo.sp_BlitzIndex @getalldatabases = 1, @BringThePain = 1
EXEC DBA.dbo.sp_BlitzIndex @getalldatabases = 1, @Mode = 2 -- index usage details

EXEC tempdb..sp_BlitzIndex @DatabaseName = 'VDP' ,@BringThePain = 1 -- Bring only main issues
EXEC tempdb..sp_BlitzIndex @DatabaseName = 'FMO' ,@BringThePain = 1 -- Bring only main issues
EXEC tempdb..sp_BlitzIndex @DatabaseName = 'SRA' ,@BringThePain = 1 -- Bring only main issues

EXEC tempdb..sp_BlitzIndex @DatabaseName = 'Cosmo', @SchemaName = 'dbo', @TableName = 'rm_image'
EXEC tempdb..sp_BlitzIndex @DatabaseName = 'Cosmo', @SchemaName = 'dbo', @TableName = 'rm_image_file'
EXEC tempdb..sp_BlitzIndex @DatabaseName = 'Cosmo', @SchemaName = 'dbo', @TableName = 'rm_image_relevancy_link'
EXEC tempdb..sp_BlitzIndex @DatabaseName = 'Cosmo', @SchemaName = 'dbo', @TableName = 'schedule_link'
EXEC tempdb..sp_BlitzIndex @DatabaseName = 'Cosmo', @SchemaName = 'dbo', @TableName = 'schres_configuration'
EXEC tempdb..sp_BlitzIndex @DatabaseName = 'Cosmo', @SchemaName = 'dbo', @TableName = 'source_tv'
