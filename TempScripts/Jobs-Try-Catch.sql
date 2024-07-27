SET NOCOUNT ON;

DECLARE @is_test_alert bit = 0;
DECLARE @continuous_failure_count tinyint = 4;
DECLARE @failure_notification_delay_minutes int = 30;
DECLARE @operator_2_notify varchar(255) = 'DBA';
DECLARE @mail_cc varchar(2000);

-- Variables for Try/Catch Block
DECLARE	@_errorNumber int,
				@_errorSeverity int,
				@_errorState int,
				@_errorLine int,
				@_errorMessage nvarchar(4000);

BEGIN TRY
	-- Last updated February 26, 2019
	;WITH [Waits] AS (
		SELECT
			[wait_type],
			[wait_time_ms] / 1000.0 AS [WaitS],
			([wait_time_ms] - [signal_wait_time_ms]) / 1000.0 AS [ResourceS],
			[signal_wait_time_ms] / 1000.0 AS [SignalS],
			[waiting_tasks_count] AS [WaitCount],
			100.0 * [wait_time_ms] / SUM ([wait_time_ms]) OVER() AS [Percentage],
			ROW_NUMBER() OVER(ORDER BY [wait_time_ms] DESC) AS [RowNum]
		FROM sys.dm_os_wait_stats
		WHERE [wait_type] NOT IN (
			-- These wait types are almost 100% never a problem and so they are
			-- filtered out to avoid them skewing the results. Click on the URL
			-- for more information.
			N'BROKER_EVENTHANDLER', -- https://www.sqlskills.com/help/waits/BROKER_EVENTHANDLER
			N'BROKER_RECEIVE_WAITFOR', -- https://www.sqlskills.com/help/waits/BROKER_RECEIVE_WAITFOR
			N'BROKER_TASK_STOP', -- https://www.sqlskills.com/help/waits/BROKER_TASK_STOP
			N'BROKER_TO_FLUSH', -- https://www.sqlskills.com/help/waits/BROKER_TO_FLUSH
			N'BROKER_TRANSMITTER', -- https://www.sqlskills.com/help/waits/BROKER_TRANSMITTER
			N'CHECKPOINT_QUEUE', -- https://www.sqlskills.com/help/waits/CHECKPOINT_QUEUE
			N'CHKPT', -- https://www.sqlskills.com/help/waits/CHKPT
			N'CLR_AUTO_EVENT', -- https://www.sqlskills.com/help/waits/CLR_AUTO_EVENT
			N'CLR_MANUAL_EVENT', -- https://www.sqlskills.com/help/waits/CLR_MANUAL_EVENT
			N'CLR_SEMAPHORE', -- https://www.sqlskills.com/help/waits/CLR_SEMAPHORE
			N'CXCONSUMER', -- https://www.sqlskills.com/help/waits/CXCONSUMER
			-- Maybe comment these four out if you have mirroring issues
			N'DBMIRROR_DBM_EVENT', -- https://www.sqlskills.com/help/waits/DBMIRROR_DBM_EVENT
			N'DBMIRROR_EVENTS_QUEUE', -- https://www.sqlskills.com/help/waits/DBMIRROR_EVENTS_QUEUE
			N'DBMIRROR_WORKER_QUEUE', -- https://www.sqlskills.com/help/waits/DBMIRROR_WORKER_QUEUE
			N'DBMIRRORING_CMD', -- https://www.sqlskills.com/help/waits/DBMIRRORING_CMD
			N'DIRTY_PAGE_POLL', -- https://www.sqlskills.com/help/waits/DIRTY_PAGE_POLL
			N'DISPATCHER_QUEUE_SEMAPHORE', -- https://www.sqlskills.com/help/waits/DISPATCHER_QUEUE_SEMAPHORE
			N'EXECSYNC', -- https://www.sqlskills.com/help/waits/EXECSYNC
			N'FSAGENT', -- https://www.sqlskills.com/help/waits/FSAGENT
			N'FT_IFTS_SCHEDULER_IDLE_WAIT', -- https://www.sqlskills.com/help/waits/FT_IFTS_SCHEDULER_IDLE_WAIT
			N'FT_IFTSHC_MUTEX', -- https://www.sqlskills.com/help/waits/FT_IFTSHC_MUTEX
			-- Maybe comment these six out if you have AG issues
			N'HADR_CLUSAPI_CALL', -- https://www.sqlskills.com/help/waits/HADR_CLUSAPI_CALL
			N'HADR_FILESTREAM_IOMGR_IOCOMPLETION', -- https://www.sqlskills.com/help/waits/HADR_FILESTREAM_IOMGR_IOCOMPLETION
			N'HADR_LOGCAPTURE_WAIT', -- https://www.sqlskills.com/help/waits/HADR_LOGCAPTURE_WAIT
			N'HADR_NOTIFICATION_DEQUEUE', -- https://www.sqlskills.com/help/waits/HADR_NOTIFICATION_DEQUEUE
			N'HADR_TIMER_TASK', -- https://www.sqlskills.com/help/waits/HADR_TIMER_TASK
			N'HADR_WORK_QUEUE', -- https://www.sqlskills.com/help/waits/HADR_WORK_QUEUE
			N'KSOURCE_WAKEUP', -- https://www.sqlskills.com/help/waits/KSOURCE_WAKEUP
			N'LAZYWRITER_SLEEP', -- https://www.sqlskills.com/help/waits/LAZYWRITER_SLEEP
			N'LOGMGR_QUEUE', -- https://www.sqlskills.com/help/waits/LOGMGR_QUEUE
			N'MEMORY_ALLOCATION_EXT', -- https://www.sqlskills.com/help/waits/MEMORY_ALLOCATION_EXT
			N'ONDEMAND_TASK_QUEUE', -- https://www.sqlskills.com/help/waits/ONDEMAND_TASK_QUEUE
			N'PARALLEL_REDO_DRAIN_WORKER', -- https://www.sqlskills.com/help/waits/PARALLEL_REDO_DRAIN_WORKER
			N'PARALLEL_REDO_LOG_CACHE', -- https://www.sqlskills.com/help/waits/PARALLEL_REDO_LOG_CACHE
			N'PARALLEL_REDO_TRAN_LIST', -- https://www.sqlskills.com/help/waits/PARALLEL_REDO_TRAN_LIST
			N'PARALLEL_REDO_WORKER_SYNC', -- https://www.sqlskills.com/help/waits/PARALLEL_REDO_WORKER_SYNC
			N'PARALLEL_REDO_WORKER_WAIT_WORK', -- https://www.sqlskills.com/help/waits/PARALLEL_REDO_WORKER_WAIT_WORK
			N'PREEMPTIVE_OS_FLUSHFILEBUFFERS', -- https://www.sqlskills.com/help/waits/PREEMPTIVE_OS_FLUSHFILEBUFFERS
			N'PREEMPTIVE_XE_GETTARGETSTATE', -- https://www.sqlskills.com/help/waits/PREEMPTIVE_XE_GETTARGETSTATE
			N'PWAIT_ALL_COMPONENTS_INITIALIZED', -- https://www.sqlskills.com/help/waits/PWAIT_ALL_COMPONENTS_INITIALIZED
			N'PWAIT_DIRECTLOGCONSUMER_GETNEXT', -- https://www.sqlskills.com/help/waits/PWAIT_DIRECTLOGCONSUMER_GETNEXT
			N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP', -- https://www.sqlskills.com/help/waits/QDS_PERSIST_TASK_MAIN_LOOP_SLEEP
			N'QDS_ASYNC_QUEUE', -- https://www.sqlskills.com/help/waits/QDS_ASYNC_QUEUE
			N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
				-- https://www.sqlskills.com/help/waits/QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP
			N'QDS_SHUTDOWN_QUEUE', -- https://www.sqlskills.com/help/waits/QDS_SHUTDOWN_QUEUE
			N'REDO_THREAD_PENDING_WORK', -- https://www.sqlskills.com/help/waits/REDO_THREAD_PENDING_WORK
			N'REQUEST_FOR_DEADLOCK_SEARCH', -- https://www.sqlskills.com/help/waits/REQUEST_FOR_DEADLOCK_SEARCH
			N'RESOURCE_QUEUE', -- https://www.sqlskills.com/help/waits/RESOURCE_QUEUE
			N'SERVER_IDLE_CHECK', -- https://www.sqlskills.com/help/waits/SERVER_IDLE_CHECK
			N'SLEEP_BPOOL_FLUSH', -- https://www.sqlskills.com/help/waits/SLEEP_BPOOL_FLUSH
			N'SLEEP_DBSTARTUP', -- https://www.sqlskills.com/help/waits/SLEEP_DBSTARTUP
			N'SLEEP_DCOMSTARTUP', -- https://www.sqlskills.com/help/waits/SLEEP_DCOMSTARTUP
			N'SLEEP_MASTERDBREADY', -- https://www.sqlskills.com/help/waits/SLEEP_MASTERDBREADY
			N'SLEEP_MASTERMDREADY', -- https://www.sqlskills.com/help/waits/SLEEP_MASTERMDREADY
			N'SLEEP_MASTERUPGRADED', -- https://www.sqlskills.com/help/waits/SLEEP_MASTERUPGRADED
			N'SLEEP_MSDBSTARTUP', -- https://www.sqlskills.com/help/waits/SLEEP_MSDBSTARTUP
			N'SLEEP_SYSTEMTASK', -- https://www.sqlskills.com/help/waits/SLEEP_SYSTEMTASK
			N'SLEEP_TASK', -- https://www.sqlskills.com/help/waits/SLEEP_TASK
			N'SLEEP_TEMPDBSTARTUP', -- https://www.sqlskills.com/help/waits/SLEEP_TEMPDBSTARTUP
			N'SNI_HTTP_ACCEPT', -- https://www.sqlskills.com/help/waits/SNI_HTTP_ACCEPT
			N'SOS_WORK_DISPATCHER', -- https://www.sqlskills.com/help/waits/SOS_WORK_DISPATCHER
			N'SP_SERVER_DIAGNOSTICS_SLEEP', -- https://www.sqlskills.com/help/waits/SP_SERVER_DIAGNOSTICS_SLEEP
			N'SQLTRACE_BUFFER_FLUSH', -- https://www.sqlskills.com/help/waits/SQLTRACE_BUFFER_FLUSH
			N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP', -- https://www.sqlskills.com/help/waits/SQLTRACE_INCREMENTAL_FLUSH_SLEEP
			N'SQLTRACE_WAIT_ENTRIES', -- https://www.sqlskills.com/help/waits/SQLTRACE_WAIT_ENTRIES
			N'VDI_CLIENT_OTHER', -- https://www.sqlskills.com/help/waits/VDI_CLIENT_OTHER
			N'WAIT_FOR_RESULTS', -- https://www.sqlskills.com/help/waits/WAIT_FOR_RESULTS
			N'WAITFOR', -- https://www.sqlskills.com/help/waits/WAITFOR
			N'WAITFOR_TASKSHUTDOWN', -- https://www.sqlskills.com/help/waits/WAITFOR_TASKSHUTDOWN
			N'WAIT_XTP_RECOVERY', -- https://www.sqlskills.com/help/waits/WAIT_XTP_RECOVERY
			N'WAIT_XTP_HOST_WAIT', -- https://www.sqlskills.com/help/waits/WAIT_XTP_HOST_WAIT
			N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG', -- https://www.sqlskills.com/help/waits/WAIT_XTP_OFFLINE_CKPT_NEW_LOG
			N'WAIT_XTP_CKPT_CLOSE', -- https://www.sqlskills.com/help/waits/WAIT_XTP_CKPT_CLOSE
			N'XE_DISPATCHER_JOIN', -- https://www.sqlskills.com/help/waits/XE_DISPATCHER_JOIN
			N'XE_DISPATCHER_WAIT', -- https://www.sqlskills.com/help/waits/XE_DISPATCHER_WAIT
			N'XE_TIMER_EVENT' -- https://www.sqlskills.com/help/waits/XE_TIMER_EVENT
			)
		AND [waiting_tasks_count] > 0
	)
	INSERT INTO dbo.WaitStats
	 ( [Collection_Time], RowNum, [WaitType] , [Wait_S] , [Resource_S] , [Signal_S] , [WaitCount] , [Percentage] )
	SELECT [Collection_Time] = GETDATE(), RowNum,
			w.wait_type, w.WaitS, w.ResourceS, w.SignalS, w.WaitCount, w.Percentage 
	FROM [Waits] AS w
	ORDER BY [Collection_Time], WaitS DESC, ResourceS DESC, SignalS DESC
	 /*
	SELECT 
		W1.[Collection_Time],
		MAX ([W1].[WaitType]) AS [WaitType],
		CAST (MAX ([W1].[Wait_S]) AS DECIMAL (16,2)) AS [Wait_S],
		CAST (MAX ([W1].[Resource_S]) AS DECIMAL (16,2)) AS [Resource_S],
		CAST (MAX ([W1].[Signal_S]) AS DECIMAL (16,2)) AS [Signal_S],
		MAX ([W1].[WaitCount]) AS [WaitCount],
		CAST (MAX ([W1].[Percentage]) AS DECIMAL (5,2)) AS [Percentage],
		CAST (MAX ([W1].[AvgWait_S]) AS DECIMAL (16,4)) AS [AvgWait_S],
		CAST (MAX ([W1].[AvgRes_S]) AS DECIMAL (16,4)) AS [AvgRes_S],
		CAST (MAX ([W1].[AvgSig_S]) AS DECIMAL (16,4)) AS [AvgSig_S]
		--,MAX([Help/Info URL]) AS [Help/Info URL]
	FROM dbo.WaitStats AS [W1]
	INNER JOIN dbo.WaitStats AS [W2] ON [W2].[RowNum] <= [W1].[RowNum] AND W1.Collection_Time = W2.Collection_Time
	GROUP BY W1.Collection_Time, [W1].[RowNum]
	HAVING SUM ([W2].[Percentage]) - MAX( [W1].[Percentage] ) < 99 -- percentage threshold
	ORDER BY Collection_Time, Percentage desc
	*/
	--select 12/0
END TRY  -- Perform main logic inside Try/Catch
BEGIN CATCH
	DECLARE @_mail_to varchar(2000);
	DECLARE @_tableHTML  NVARCHAR(MAX);  
	DECLARE @_subject nvarchar(1000);
	DECLARE @_job_name nvarchar(500);
	DECLARE @_job_step_name nvarchar(500);
	DECLARE	@_job_step_id int;

	SELECT @_job_name = name FROM msdb.dbo.sysjobs WHERE job_id = CONVERT(uniqueidentifier, $(ESCAPE_NONE(JOBID)));
	--SET @_job_name = 'Test Job by Ajay';
	SET @_job_step_id = $(ESCAPE_NONE(STEPID));
	SELECT @_job_step_name = step_name FROM msdb.dbo.sysjobsteps where job_id = CONVERT(uniqueidentifier, $(ESCAPE_NONE(JOBID))) and step_id = @_job_step_id;

	SET @_subject = '[The job failed.] SQL Server Job System: '''+@_job_name+''' completed on \\'+@@SERVERNAME+'.'
	IF @is_test_alert = 1
		SET @_subject = 'TestAlert - '+@_subject;

	SELECT @_errorNumber	 = Error_Number()
				,@_errorSeverity = Error_Severity()
				,@_errorState	 = Error_State()
				,@_errorLine	 = Error_Line()
				,@_errorMessage	 = Error_Message();

	SET @_tableHTML =
		N'Sql Agent job '''+@_job_name+''' has failed for step '+CAST(@_job_step_id AS varchar)+' - '''+ @_job_step_name +''' @'+ CONVERT(nvarchar(30),getdate(),121) +'.'+
		N'<br><br>Error Number: ' + convert(varchar, @_errorNumber) + 
		N'<br>Line Number: ' + convert(varchar, @_errorLine) +
		N'<br>Error Message: <br>"' + @_errorMessage + '"' +
		N'<br><br>Kindly resolve the job failure based on above error message.';

	select @_mail_to = email_address from msdb.dbo.sysoperators where name = @operator_2_notify;

	IF 1 = 1 /* Logic for @failure_notification_delay_minutes & @continuous_failure_count */
	BEGIN
			EXEC msdb.dbo.sp_send_dbmail
							@recipients = @_mail_to,
							@copy_recipients = @mail_cc,
							--@profile_name = @@SERVERNAME,
							@subject = @_subject,
							@body = @_tableHTML,
							@body_format = 'HTML';
	END

END CATCH

IF @_errorMessage IS NOT NULL
	THROW 50000, @_errorMessage, 1;
