--	Drop and Re-create Extended Event Session
IF EXISTS (
	SELECT * FROM sys.server_event_sessions WHERE name = 'CaptureQueries'
)
DROP EVENT SESSION [CaptureQueries] ON SERVER;
GO

CREATE EVENT SESSION [CaptureQueries] ON SERVER 
ADD EVENT sqlserver.rpc_completed,
ADD EVENT sqlserver.sql_batch_completed(SET collect_batch_text=(1)
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.context_info,sqlserver.database_name,sqlserver.nt_username,sqlserver.plan_handle,sqlserver.query_hash,sqlserver.query_plan_hash,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.sql_text)
    WHERE ([physical_reads]>=(1000)))
ADD TARGET package0.event_file(SET filename=N' F:\dba\ExtendedEvent\CaptureQueries')
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF)
GO

ALTER EVENT SESSION [CaptureQueries]
ON SERVER
STATE = START
GO