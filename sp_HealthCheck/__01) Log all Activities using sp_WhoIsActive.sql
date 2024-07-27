--	http://ajaydwivedi.com/2016/12/log-all-activities-using-sp_whoisactive/

--	Verify Server Name
SELECT @@SERVERNAME as SrvName;

--	Step 01: Create Your @destination_table
USE DBA
GO
	
DECLARE @destination_table VARCHAR(4000) ;
SET @destination_table = 'DBA.dbo.WhoIsActive_ResultSets';

DECLARE @schema VARCHAR(4000) ;
--	Specify all your proc parameters here
EXEC DBA..sp_WhoIsActive @get_plans=2, @get_full_inner_text=1, @get_transaction_info=1, @get_task_info=2, @get_locks=1, 
					@get_avg_time=1, @get_additional_info=1,@find_block_leaders=1, @get_outer_command =1
					,@return_schema = 1
					,@schema = @schema OUTPUT ;

SET @schema = REPLACE(@schema, '<table_name>', @destination_table) ;

PRINT @schema
EXEC(@schema) ;
GO

--	Step 02: Add Computed Column to get TimeInMinutes
USE DBA
GO
ALTER TABLE dbo.[WhoIsActive_ResultSets]
	ADD [TimeInMinutes] AS (cast(LEFT([dd hh:mm:ss.mss],2) as int) * 24 * 60)
			+ (cast(SUBSTRING([dd hh:mm:ss.mss],4,2) as int) * 60)
			+ cast(SUBSTRING([dd hh:mm:ss.mss],7,2) as int) PERSISTED
GO

--	Step 03: Add a clustered Index
CREATE CLUSTERED INDEX [CI_WhoIsActive_ResultSets] ON [dbo].[WhoIsActive_ResultSets]
(
	[collection_time] ASC, session_id
)
GO

--	Step 04: Add a Non-clustered Index
/*
CREATE NONCLUSTERED INDEX [NCI_WhoIsActive_ResultSets_Blockings] ON [dbo].[WhoIsActive_ResultSets]
(	blocking_session_id, blocked_session_count, [collection_time] ASC, session_id)
INCLUDE (login_name, [host_name], [database_name], [program_name])
GO
*/

--	Step 05: Test your Script
DECLARE	@destination_table VARCHAR(4000);
SET @destination_table = 'DBA.dbo.WhoIsActive_ResultSets';

EXEC DBA..sp_WhoIsActive @get_full_inner_text=1, @get_transaction_info=1, @get_task_info=2, @get_locks=1, 
					@get_avg_time=1, @get_additional_info=1,@find_block_leaders=1, @get_outer_command =1,
					@get_plans=2,
            @destination_table = @destination_table ;
GO

-- Step 06: Create SQL Agent Job
USE [msdb]
GO

/****** Object:  Job [DBA - Log_With_sp_WhoIsActive]    Script Date: 6/12/2018 11:51:38 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 6/12/2018 11:51:38 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA - Log_With_sp_WhoIsActive', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'This job will log activities using Adam Mechanic''s [sp_whoIsActive] stored procedure.

Results are saved into DBA..WhoIsActive_ResultSets table.

Job will run every 2 Minutes once started.', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Log activities with [sp_WhoIsActive]]    Script Date: 6/12/2018 11:51:38 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Log activities with [sp_WhoIsActive]', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE	@destination_table VARCHAR(4000);
SET @destination_table = ''DBA.dbo.WhoIsActive_ResultSets'';

EXEC DBA..sp_WhoIsActive @get_full_inner_text=1, @get_transaction_info=1, @get_task_info=2, @get_locks=1, @get_avg_time=1, @get_additional_info=1,@find_block_leaders=1, @get_outer_command =1	
					,@get_plans=2,
            @destination_table = @destination_table ;', 
		@database_name=N'DBA', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Log_Using_whoIsActive_Every_2_Minutes', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=2, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20161227, 
		@active_end_date=20180618, 
		@active_start_time=0, 
		@active_end_time=235900, 
		@schedule_uid=N'f583e6cd-9431-4afc-94a3-e3ef9bfa0d27'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

