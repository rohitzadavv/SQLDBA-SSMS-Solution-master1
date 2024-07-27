USE [DBA]
GO

IF OBJECT_ID('dbo.usp_GetLogWalkJobHistoryAlert_Suppress') IS NULL
	EXEC('CREATE PROCEDURE [dbo].[usp_GetLogWalkJobHistoryAlert_Suppress] AS SELECT 1 AS [Dummy];')
GO

USE [DBA]
GO

ALTER PROCEDURE [dbo].[usp_GetLogWalkJobHistoryAlert_Suppress] 
		@p_JobName VARCHAR(125) = NULL,
		@p_GetSessionRequestDetails BIT = 0,
		@p_Verbose BIT = 0,

		@p_NoOfContinousFailuresThreshold TINYINT = 2,		@p_SuppressNotification TINYINT = 0,
		@p_SendMail BIT = 0,
		@p_Mail_TO VARCHAR(1000) = NULL,
		@p_Mail_CC VARCHAR(1000) = NULL,
		@p_SlackMailID VARCHAR(1000) = 'k2b0c1w9g1k7d5e0@contso.slack.com;IT-Ops-DBA@contso.com;',
		@p_Help BIT = 0
AS
BEGIN 
	/*
		Version:		1.2
		Created By:		Ajay Kumar Dwivedi
		Created Date:	17-Mar-2019
		Updated Date:	29-Apr-2019
		Purpose:		To have custom alerting system for Log Walk jobs
		Modification:	20-Apr-2019 - Corrected Notification mail where mail was received without body
						29-Apr-2019	- Add logic to send Blocking info to Slack Email
	*/
	SET NOCOUNT ON;

	IF @p_Verbose = 1
		SELECT [@p_JobName] = @p_JobName;

	IF @p_Verbose = 1
		PRINT 'Declaring local variables..';
	-- Declare Local Variables
	DECLARE @_errorMSG VARCHAR(2000);
	DECLARE @NoOfContinousFailures INT;
	DECLARE @JobHistoryRecordCounts INT;
	DECLARE @SQLString NVARCHAR(MAX);
	DECLARE @ParmDefinition NVARCHAR(500);
	DECLARE @T_JobHistory TABLE (RID INT, Server varchar(125),JobName varchar(125),Instance_Id bigint, Step_Id int, Step_Name varchar(125), Run_Status int, Run_Status_Desc varchar(20), Enabled bit, Category_Id int, RunDateTime datetime, RunDurationMinutes int);
	DECLARE @_collection_time_start datetime;
	DECLARE @_collection_time_end datetime;
	DECLARE @IsBlockingIssue BIT;
	DECLARE @_SendMailRequired BIT;
	DECLARE @_mailSubject VARCHAR(255)
			,@_mailBody VARCHAR(4000);
	IF OBJECT_ID('DBA..LogWalkThresholdInstance') IS NULL
		CREATE TABLE DBA..LogWalkThresholdInstance (JobName varchar(125), Instance_Id bigint);		
	IF OBJECT_ID('DBA..JobBlockers') IS NULL
		CREATE TABLE DBA.[dbo].[JobBlockers]
		(
			[collection_time] smalldatetime NULL,
			[BLOCKING_TREE] [nvarchar](max) NULL,
			[session_id] [smallint] NULL,
			[blocking_session_id] [smallint] NULL,
			--[sql_text] [xml] NULL,
			[host_name] varchar(128) NULL,
			[database_name] varchar(128) NULL,
			[login_name] varchar(128) NULL,
			[program_name] varchar(128) NULL,
			[wait_info] varchar(4000) NULL,
			[blocked_session_count] varchar(30) NULL,
			--[locks] [xml] NULL,
			[tran_start_time] smalldatetime NULL,
			[open_tran_count] smallint NULL,
			--[additional_info] [xml] NULL,
			[CPU] [varchar](30) NULL,
			[tempdb_allocations] [varchar](30) NULL,
			[tempdb_current] [varchar](30) NULL,
			[reads] [varchar](30) NULL,
			[writes] [varchar](30) NULL,
			[physical_io] [varchar](30) NULL,
			[physical_reads] [varchar](30) NULL
		);
	ELSE
		TRUNCATE TABLE DBA.[dbo].[JobBlockers];

	IF @p_Verbose = 1
		PRINT 'Initilizing local variables..';
	SET @IsBlockingIssue = 0;
	SET @_SendMailRequired = 0;


	IF @p_Help = 1
	BEGIN -- If @p_Help
		IF @p_Verbose = 1
			PRINT 'Inside @p_Help = 1';
		SELECT	*
		FROM (	
				SELECT	[Parameter Name] = '! ******* Version ********!', 
						[Data Type] = 'Information', 
						[Default Value] = '1.1',
						[Parameter Description] = 'Last Updated - Mar 30, 2019',
						[Supporting Parameters] = 'https://github.com/imajaydwivedi/SQLDBA-SSMS-Solution'
				--
				UNION ALL
				--
				SELECT	[Parameter Name] = '@p_Help', 
						[Data Type] = 'bit', 
						[Default Value] = '0',
						[Parameter Description] = 'Display Help Message',
						[Supporting Parameters] = NULL
				--
				UNION ALL
				--
				SELECT	[Parameter Name] = '@p_JobName', 
						[Data Type] = 'varchar(125)', 
						[Default Value] = NULL,
						[Parameter Description] = 'Name of SQL Server Agent job for which Email Notification is required',
						[Supporting Parameters] = '@p_SendMail, @p_NoOfContinousFailuresThreshold, @p_Mail_TO, @p_Mail_CC, @p_SuppressNotification, @p_GetSessionRequestDetails, @p_Verbose'
				--
				UNION ALL
				--
				SELECT	[Parameter Name] = '@p_GetSessionRequestDetails', 
						[Data Type] = 'bit', 
						[Default Value] = '0',
						[Parameter Description] = 'Display details of session details involved in blocking the @p_JobName.',
						[Supporting Parameters] = '@p_JobName'
				--
				UNION ALL
				--
				SELECT	[Parameter Name] = '@p_NoOfContinousFailuresThreshold', 
						[Data Type] = 'tinyint', 
						[Default Value] = '2',
						[Parameter Description] = 'Threshold value for Continous Job failure. Default value of 2 means notification should be received when the job fails for 2 or more continous times',
						[Supporting Parameters] = '@p_JobName'
				--
				UNION ALL
				--
				SELECT	[Parameter Name] = '@p_SuppressNotification', 
						[Data Type] = 'bit', 
						[Default Value] = '0',
						[Parameter Description] = 'To avoid notification mail, we call execute the proc with this parameter ',
						[Supporting Parameters] = '@p_JobName'
				--
				UNION ALL
				--
				SELECT	[Parameter Name] = '@p_SendMail', 
						[Data Type] = 'bit', 
						[Default Value] = '0',
						[Parameter Description] = 'To get Email Notification, this option should be set to 1',
						[Supporting Parameters] = '@p_JobName, @p_Mail_TO, @p_Mail_CC'
				--
				UNION ALL
				--
				SELECT	[Parameter Name] = '@p_Mail_TO', 
						[Data Type] = 'varchar(1000)', 
						[Default Value] = NULL,
						[Parameter Description] = 'Email Ids of main recepients separated by Semicolon (;)',
						[Supporting Parameters] = '@p_JobName, @p_SendMail'
				--
				UNION ALL
				--
				SELECT	[Parameter Name] = '@p_Mail_CC', 
						[Data Type] = 'varchar(1000)', 
						[Default Value] = NULL,
						[Parameter Description] = 'Email Ids of Copy recepients separated by Semicolon (;)',
						[Supporting Parameters] = '@p_JobName, @p_SendMail'
			 ) AS F;
	END
	ELSE
	BEGIN -- Else portion of @p_Help = 1
		-- Check @p_JobName
		IF @p_JobName IS NULL
		BEGIN
			SET @_errorMSG = 'Kindly provide value for parameter @p_JobName.';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END

		-- Make sure either user wants mail or want to debug, or want both
		IF @p_SendMail = 0 AND @p_Verbose = 0 AND @p_GetSessionRequestDetails = 0 AND @p_SuppressNotification = 0
		BEGIN
			SET @_errorMSG = 'Kindly use at least one of the following parameters:- @p_SendMail, @p_Verbose, @p_GetSessionRequestDetails, or @p_SuppressNotification';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END


		IF @p_Verbose = 1
			PRINT 'Trying to find Job history..';
		SET @ParmDefinition = N'@_JobName VARCHAR(125)'; 
		SET @SQLString = '
			SELECT	TOP 20 
					ROW_NUMBER() OVER(ORDER BY j.name, h.instance_id desc) AS RID,
					h.server,
					[JobName] = j.name,
					h.instance_id,
					h.step_id,
					h.step_name,
					h.run_status,
					[run_status_desc] = (case when h.run_status = 0 then ''Failed'' when h.run_status =  1 then ''Succeeded'' when h.run_status =  2 then ''Retry'' when h.run_status =  3 then ''Canceled'' else ''In Progress'' END),
					j.enabled,
					j.category_id,
					[RunDateTime] = msdb.dbo.agent_datetime(run_date, run_time),
					[RunDurationMinutes] = ((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) / 60)
			FROM	msdb.dbo.sysjobs j 
			INNER JOIN msdb.dbo.sysjobhistory h 
				ON	j.job_id = h.job_id 
			WHERE	j.name = @_JobName
				AND step_id = 0
			ORDER BY JobName, instance_id desc
		';
		INSERT @T_JobHistory
		EXECUTE sp_executesql @SQLString, @ParmDefinition,  
							  @_JobName = @p_JobName; 

		SET @JobHistoryRecordCounts = COALESCE((SELECT COUNT(*) FROM @T_JobHistory),0);

		-- Check if no job history found, or Job name is invalid
		IF @JobHistoryRecordCounts = 0
		BEGIN
			IF EXISTS(SELECT * FROM msdb..sysjobs as j WHERE j.name = @p_JobName)
				SET @_errorMSG = 'No job execution history found for @p_JobName = '+QUOTENAME(@p_JobName);
			ELSE
				SET @_errorMSG = 'No job named '+QUOTENAME(@p_JobName)+' is found';

			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END
		ELSE
		BEGIN -- block if Job History is found
			IF @p_Verbose = 1
			BEGIN
				PRINT 'SELECT * FROM @T_JobHistory;';
				SELECT	Q.*, J.*
				FROM	(	SELECT	'SELECT * FROM @T_JobHistory;' AS RunningQuery	) AS Q
				CROSS JOIN
						@T_JobHistory AS J;

				PRINT 'SELECT * FROM DBA..LogWalkThresholdInstance;';
				SELECT	Q.*, J.*
				FROM	(	SELECT	'SELECT * FROM DBA..LogWalkThresholdInstance;' AS RunningQuery	) AS Q
				CROSS JOIN
						DBA..LogWalkThresholdInstance AS J;
			END

			-- Find No of Continous Failures
			SELECT @NoOfContinousFailures = COALESCE(MIN(RID)-1,0) FROM @T_JobHistory h WHERE h.Run_Status_Desc = 'Succeeded';
			IF @p_Verbose = 1
			BEGIN
				PRINT '@NoOfContinousFailures = '+CAST(@NoOfContinousFailures AS VARCHAR(5));
				PRINT 'Job ['+@p_JobName+'] has been failing continously for last '+cast(@NoOfContinousFailures as varchar(2))+ ' times.'
			END

			-- If unchecked job failure is there, then find Blocking details
			IF @NoOfContinousFailures <> 0
			BEGIN -- Populate #JobSessionBlockers
				IF @p_Verbose = 1
					PRINT 'Proceeding to find Blocking details..';

				SELECT	@_collection_time_start = MIN(h.RunDateTime), @_collection_time_end = GETDATE() --MAX(h.RunDateTime)
				FROM	@T_JobHistory AS h
				WHERE	h.RID <= @NoOfContinousFailures;

				IF @p_Verbose = 1
					SELECT [@_collection_time_start] = @_collection_time_start, [@_collection_time_end] = @_collection_time_end;

				-- Find Job Session along with its Blockers
				IF OBJECT_ID('tempdb..#JobSessionBlockers') IS NOT NULL
					DROP TABLE #JobSessionBlockers;
				;WITH T_JobCaptures AS
				(
					SELECT [dd hh:mm:ss.mss], [dd hh:mm:ss.mss (avg)], [session_id], [sql_text], [sql_command], [login_name], [wait_info], [tasks], [tran_log_writes], [CPU], [tempdb_allocations], [tempdb_current], [blocking_session_id], [blocked_session_count], [reads], [writes], [context_switches], [physical_io], [physical_reads], [locks], [used_memory], [status], [tran_start_time], [open_tran_count], [percent_complete], [host_name], [database_name], [program_name], [additional_info], [start_time], [login_time], [request_id], [collection_time]
					FROM [DBA]..[WhoIsActive_ResultSets] as r
					WHERE r.program_name = ('SQL Job = '+@p_JobName)
						AND r.collection_time >= @_collection_time_start
						AND    r.collection_time <= @_collection_time_end
					--
					UNION ALL
					--
					SELECT r.[dd hh:mm:ss.mss], r.[dd hh:mm:ss.mss (avg)], r.[session_id], r.[sql_text], r.[sql_command], r.[login_name], r.[wait_info], r.[tasks], r.[tran_log_writes], r.[CPU], r.[tempdb_allocations], r.[tempdb_current], r.[blocking_session_id], r.[blocked_session_count], r.[reads], r.[writes], r.[context_switches], r.[physical_io], r.[physical_reads], r.[locks], r.[used_memory], r.[status], r.[tran_start_time], r.[open_tran_count], r.[percent_complete], r.[host_name], r.[database_name], r.[program_name], r.[additional_info], r.[start_time], r.[login_time], r.[request_id], r.[collection_time]
					FROM T_JobCaptures AS j
					INNER JOIN [DBA]..[WhoIsActive_ResultSets] as r
						ON r.collection_time = j.collection_time
						AND j.blocking_session_id = r.session_id
				)
				SELECT	*
				INTO	#JobSessionBlockers
				FROM	T_JobCaptures;

				-- If Blockers are found
				IF OBJECT_ID('tempdb..#JobSessionBlockers') IS NOT NULL AND EXISTS(SELECT 1 FROM #JobSessionBlockers as jb WHERE jb.program_name = ('SQL Job = '+@p_JobName) AND jb.blocking_session_id IS NOT NULL)
				BEGIN
					SET @IsBlockingIssue = 1;
				END

				IF OBJECT_ID('tempdb..#JobSessionBlockers') IS NOT NULL AND (@p_Verbose = 1 OR @p_GetSessionRequestDetails = 1)
					SELECT	Q.*, DENSE_RANK()OVER(ORDER BY J.collection_time ASC) AS CollectionBatchNO, J.*
					FROM	(	SELECT	'What Was Running' AS RunningQuery	) AS Q
					FULL OUTER JOIN
							#JobSessionBlockers AS J
						ON	1 = 1;

			END -- Populate #JobSessionBlockers

			-- Logic if Job Failure is due to Blocking Issue
			IF @IsBlockingIssue = 1
			BEGIN -- Block -> Logic if Job Failure is due to Blocking Issue
				IF @p_Verbose = 1
					PRINT 'Logic processing when Job has failed due to Blocking Issue';

				IF @p_Verbose = 1
				BEGIN
					
					IF EXISTS (SELECT * FROM @T_JobHistory h WHERE h.Run_Status = 0 AND h.RID = @p_NoOfContinousFailuresThreshold AND h.Instance_Id IN (SELECT e.Instance_Id FROM DBA..LogWalkThresholdInstance AS e WHERE e.JobName = @p_JobName))
					BEGIN
						IF @p_Verbose = 1
							PRINT 'Setting @_SendMailRequired = 0';
						SET @_SendMailRequired = 0;
						
						PRINT '
Exception is present to suppress failure notification @p_SuppressNotification.
Incase this is not required, Kindly execute below query:-
DELETE FROM DBA..LogWalkThresholdInstance WHERE JobName = '''+@p_JobName+''';

	'
					END
				END

				-- If Job has been failing for more than @p_NoOfContinousFailuresThreshold with consideration of Exception @p_SuppressNotification
				IF ((SELECT COUNT(*) FROM @T_JobHistory WHERE Run_Status = 0 AND RID <= @p_NoOfContinousFailuresThreshold AND Instance_Id NOT IN (SELECT e.Instance_Id FROM DBA..LogWalkThresholdInstance AS e WHERE e.JobName = @p_JobName)) = @p_NoOfContinousFailuresThreshold)
				BEGIN -- block if failure issue is found

					IF @p_SuppressNotification = 1
					BEGIN
						IF @p_Verbose = 1
							PRINT 'Inside @p_SuppressNotification = 1 block';
					
						DELETE FROM DBA..LogWalkThresholdInstance WHERE JobName = @p_JobName;

						INSERT DBA..LogWalkThresholdInstance
						SELECT @p_JobName, instance_id FROM	@T_JobHistory WHERE Run_Status = 0 AND RID = @p_NoOfContinousFailuresThreshold;

						IF @p_Verbose = 1
						BEGIN
							SELECT	Q.*, J.*
							FROM	(	SELECT	'SELECT * FROM DBA..LogWalkThresholdInstance' AS RunningQuery	) AS Q
							CROSS JOIN
									DBA..LogWalkThresholdInstance AS J;
						END
					END
					ELSE
					BEGIN -- Else @p_SuppressNotification
						IF @p_Verbose = 1
							PRINT 'Setting @_SendMailRequired = 1';
						SET @_SendMailRequired = 1

						IF @p_SendMail = 1
						BEGIN
							
							IF @p_Verbose = 1
								PRINT 'Trying to find blockers..';
							SET @ParmDefinition = N'@p_collection_time_start smalldatetime, @p_collection_time_end smalldatetime, @p_JobName VARCHAR(125)'; 
							SET @SQLString = '
;WITH T_JobCaptures AS
(
	SELECT [dd hh:mm:ss.mss], [dd hh:mm:ss.mss (avg)], [session_id], [sql_text], [sql_command], [login_name], [wait_info], [tasks], [tran_log_writes], [CPU], [tempdb_allocations], [tempdb_current], [blocking_session_id], [blocked_session_count], [reads], [writes], [context_switches], [physical_io], [physical_reads], [locks], [used_memory], [status], [tran_start_time], [open_tran_count], [percent_complete], [host_name], [database_name], [program_name], [additional_info], [start_time], [login_time], [request_id], [collection_time]
		,[sql_query] = REPLACE(REPLACE(REPLACE(REPLACE(CAST(COALESCE([sql_text],[sql_command]) AS VARCHAR(MAX)),char(13),''''),CHAR(10),''''),''<?query --'',''''),''--?>'','''')
		,[LEVEL] = CAST (REPLICATE (''0'', 4-LEN (CAST (r.session_id AS VARCHAR))) + CAST (r.session_id AS VARCHAR) AS VARCHAR (1000))
	FROM [DBA]..[WhoIsActive_ResultSets] as r
	WHERE r.collection_time >= @p_collection_time_start AND r.collection_time <= @p_collection_time_end
	AND	(ISNULL(r.blocking_session_id,0) = 0 OR ISNULL(r.blocking_session_id,0) = r.session_id)
	AND EXISTS (SELECT * FROM [DBA].[dbo].WhoIsActive_ResultSets AS R2 WHERE R2.collection_Time = r.collection_Time AND ISNULL(R2.blocking_session_id,0) = r.session_id AND ISNULL(R2.blocking_session_id,0) <> R2.session_id AND R2.program_name = ''SQL Job = ''+@p_JobName)
	--
	UNION ALL
	--
	SELECT r.[dd hh:mm:ss.mss], r.[dd hh:mm:ss.mss (avg)], r.[session_id], r.[sql_text], r.[sql_command], r.[login_name], r.[wait_info], r.[tasks], r.[tran_log_writes], r.[CPU], r.[tempdb_allocations], r.[tempdb_current], r.[blocking_session_id], r.[blocked_session_count], r.[reads], r.[writes], r.[context_switches], r.[physical_io], r.[physical_reads], r.[locks], r.[used_memory], r.[status], r.[tran_start_time], r.[open_tran_count], r.[percent_complete], r.[host_name], r.[database_name], r.[program_name], r.[additional_info], r.[start_time], r.[login_time], r.[request_id], r.[collection_time]
		,[sql_query] = REPLACE(REPLACE(REPLACE(REPLACE(CAST(COALESCE(r.[sql_text],r.[sql_command]) AS VARCHAR(MAX)),char(13),''''),CHAR(10),''''),''<?query --'',''''),''--?>'','''')
		,[LEVEL] = CAST (b.LEVEL + RIGHT (CAST ((1000 + r.session_id) AS VARCHAR (100)), 4) AS VARCHAR (1000))
	FROM T_JobCaptures AS b
	INNER JOIN [DBA]..[WhoIsActive_ResultSets] as r
		ON r.collection_time = B.collection_time
		AND	r.blocking_session_id = B.session_id
	WHERE	r.blocking_session_id <> r.session_id
)
SELECT	[collection_time], 
		[BLOCKING_TREE] = N''    '' + REPLICATE (N''|         '', LEN (LEVEL)/4 - 1) 
						+	CASE	WHEN (LEN(LEVEL)/4 - 1) = 0
									THEN ''HEAD -  ''
									ELSE ''|------  '' 
							END
						+	CAST (r.session_id AS NVARCHAR (10)) + N'' '' + (CASE WHEN LEFT(r.[sql_query],1) = ''('' THEN SUBSTRING(r.[sql_query],CHARINDEX(''exec'',r.[sql_query]),LEN(r.[sql_query]))  ELSE r.[sql_query] END),
		[session_id], [blocking_session_id], 				
		--[sql_text], 
		[host_name], [database_name], [login_name], [program_name],	[wait_info], [blocked_session_count], 
		--[locks], 
		[tran_start_time], [open_tran_count] --,additional_info
		,r.[CPU], r.[tempdb_allocations], r.[tempdb_current], r.[reads], r.[writes], r.[physical_io], r.[physical_reads] --, r.[query_plan]
FROM	T_JobCaptures as r
ORDER BY r.collection_time, LEVEL ASC;
							';

							IF @p_Verbose = 1
							BEGIN
								PRINT @SQLString;
							END

							--IF @p_SlackMailID IS NOT NULL
							--BEGIN
							INSERT DBA.[dbo].[JobBlockers]
							EXECUTE sp_executesql @SQLString, @ParmDefinition,
													@p_collection_time_start = @_collection_time_start,
													@p_collection_time_end = @_collection_time_end,
													@p_JobName = @p_JobName; 

							IF @p_Verbose = 1
							BEGIN
								SELECT 'SELECT * FROM DBA.[dbo].[JobBlockers]' AS RunningQuery, * FROM DBA.[dbo].[JobBlockers];
							END
							
							IF @p_Verbose = 1
								PRINT 'Executing procedure DBA..[usp_GetMail_4_SQLAlerts];';

							EXEC DBA..[usp_GetMail_4_SQLAlerts] @p_Option = 'JobBlockers', @p_JobName = @p_JobName, @p_recipients = @p_Mail_TO, @p_Verbose=@p_Verbose;
							--END
							
							SELECT /*
							@_mailBody = 'Dear DSG-Team,

SQL Agent Job '+QUOTENAME(@p_JobName)+' has been failing for '+cast(@NoOfContinousFailures as varchar(2))+ ' times continously.

LAST JOB RUN:		'+CAST(jh.RunDateTime AS varchar(50))+'
DURATION:		'+CAST(jh.RunDurationMinutes AS varchar(10))+' Minutes
STATUS: 		Failed
MESSAGES:		Job '+QUOTENAME(@p_JobName)+' COULD NOT obtain EXCLUSIVE access of underlying database to start its activity. 
RCA:			Kindly execute below query to find out details of Blockers.


		;WITH T_JobCaptures AS
		(
			SELECT [collection_time], [dd hh:mm:ss.mss], [session_id], [sql_command], [login_name], [wait_info], [tasks], [tran_log_writes], [CPU], [tempdb_allocations], [tempdb_current], [blocking_session_id], [blocked_session_count], [reads], [writes], [context_switches], [physical_io], [physical_reads], [locks], [used_memory], [status], [tran_start_time], [open_tran_count], [percent_complete], [host_name], [database_name], [program_name], [additional_info], [start_time], [login_time], [request_id]
			FROM [DBA]..[WhoIsActive_ResultSets] as r
			WHERE r.program_name = ''SQL Job = '+@p_JobName+'''
				AND (r.collection_time >= '''+CAST(@_collection_time_start AS VARCHAR(30))+''' AND r.collection_time <= '''+CAST(@_collection_time_end AS VARCHAR(30))+''')
			--
			UNION ALL
			--
			SELECT r.[collection_time], r.[dd hh:mm:ss.mss], r.[session_id], r.[sql_command], r.[login_name], r.[wait_info], r.[tasks], r.[tran_log_writes], r.[CPU], r.[tempdb_allocations], r.[tempdb_current], r.[blocking_session_id], r.[blocked_session_count], r.[reads], r.[writes], r.[context_switches], r.[physical_io], r.[physical_reads], r.[locks], r.[used_memory], r.[status], r.[tran_start_time], r.[open_tran_count], r.[percent_complete], r.[host_name], r.[database_name], r.[program_name], r.[additional_info], r.[start_time], r.[login_time], r.[request_id]
			FROM T_JobCaptures AS j
			INNER JOIN [DBA]..[WhoIsActive_ResultSets] as r
				ON r.collection_time = j.collection_time
				AND j.blocking_session_id = r.session_id
		)
		SELECT	DENSE_RANK()OVER(ORDER BY collection_Time ASC) AS CollectionBatch, *
		FROM	T_JobCaptures
		ORDER BY collection_time;

' */
							@_mailBody = 'Dear DSG-Team,

SQL Agent Job '+QUOTENAME(@p_JobName)+' has been failing for '+cast(@NoOfContinousFailures as varchar(2))+ ' times continously.

LAST JOB RUN:		'+CAST(jh.RunDateTime AS varchar(50))+'
DURATION:		'+CAST(jh.RunDurationMinutes AS varchar(10))+' Minutes
STATUS: 		Failed
MESSAGES:		Job '+QUOTENAME(@p_JobName)+' COULD NOT obtain EXCLUSIVE access of underlying database to start its activity. 
RCA:			Kindly execute below query to find out details of Blockers.


		;WITH T_JobCaptures AS
		(
			SELECT [dd hh:mm:ss.mss], [dd hh:mm:ss.mss (avg)], [session_id], [sql_text], [sql_command], [login_name], [wait_info], [tasks], [tran_log_writes], [CPU], [tempdb_allocations], [tempdb_current], [blocking_session_id], [blocked_session_count], [reads], [writes], [context_switches], [physical_io], [physical_reads], [locks], [used_memory], [status], [tran_start_time], [open_tran_count], [percent_complete], [host_name], [database_name], [program_name], [additional_info], [start_time], [login_time], [request_id], [collection_time]
				,[sql_query] = REPLACE(REPLACE(REPLACE(REPLACE(CAST(COALESCE([sql_text],[sql_command]) AS VARCHAR(MAX)),char(13),''''),CHAR(10),''''),''<?query --'',''''),''--?>'','''')
				,[LEVEL] = CAST (REPLICATE (''0'', 4-LEN (CAST (r.session_id AS VARCHAR))) + CAST (r.session_id AS VARCHAR) AS VARCHAR (1000))
			FROM [DBA]..[WhoIsActive_ResultSets] as r
			WHERE r.collection_time >= '''+CAST(@_collection_time_start AS VARCHAR(30))+''' AND r.collection_time <= '''+CAST(@_collection_time_end AS VARCHAR(30))+'''
			AND	(ISNULL(r.blocking_session_id,0) = 0 OR ISNULL(r.blocking_session_id,0) = r.session_id)
			AND EXISTS (SELECT * FROM [DBA].[dbo].WhoIsActive_ResultSets AS R2 WHERE R2.collection_Time = r.collection_Time AND ISNULL(R2.blocking_session_id,0) = r.session_id AND ISNULL(R2.blocking_session_id,0) <> R2.session_id AND R2.program_name = ''SQL Job = '+@p_JobName+''')
			--
			UNION ALL
			--
			SELECT r.[dd hh:mm:ss.mss], r.[dd hh:mm:ss.mss (avg)], r.[session_id], r.[sql_text], r.[sql_command], r.[login_name], r.[wait_info], r.[tasks], r.[tran_log_writes], r.[CPU], r.[tempdb_allocations], r.[tempdb_current], r.[blocking_session_id], r.[blocked_session_count], r.[reads], r.[writes], r.[context_switches], r.[physical_io], r.[physical_reads], r.[locks], r.[used_memory], r.[status], r.[tran_start_time], r.[open_tran_count], r.[percent_complete], r.[host_name], r.[database_name], r.[program_name], r.[additional_info], r.[start_time], r.[login_time], r.[request_id], r.[collection_time]
				,[sql_query] = REPLACE(REPLACE(REPLACE(REPLACE(CAST(COALESCE(r.[sql_text],r.[sql_command]) AS VARCHAR(MAX)),char(13),''''),CHAR(10),''''),''<?query --'',''''),''--?>'','''')
				,[LEVEL] = CAST (b.LEVEL + RIGHT (CAST ((1000 + r.session_id) AS VARCHAR (100)), 4) AS VARCHAR (1000))
			FROM T_JobCaptures AS b
			INNER JOIN [DBA]..[WhoIsActive_ResultSets] as r
				ON r.collection_time = B.collection_time
				AND	r.blocking_session_id = B.session_id
			WHERE	r.blocking_session_id <> r.session_id
		)
		SELECT	[collection_time], 
				[BLOCKING_TREE] = N''    '' + REPLICATE (N''|         '', LEN (LEVEL)/4 - 1) 
								+	CASE	WHEN (LEN(LEVEL)/4 - 1) = 0
											THEN ''HEAD -  ''
											ELSE ''|------  '' 
									END
								+	CAST (r.session_id AS NVARCHAR (10)) + N'' '' + (CASE WHEN LEFT(r.[sql_query],1) = ''('' THEN SUBSTRING(r.[sql_query],CHARINDEX(''exec'',r.[sql_query]),LEN(r.[sql_query]))  ELSE r.[sql_query] END),
				[session_id], [blocking_session_id], 				
				[sql_text], 
				[host_name], [database_name], [login_name], [program_name],	[wait_info], [blocked_session_count], [locks], [tran_start_time], [open_tran_count], additional_info
				,r.[CPU], r.[tempdb_allocations], r.[tempdb_current], r.[reads], r.[writes], r.[physical_io], r.[physical_reads] --, r.[query_plan]
		FROM	T_JobCaptures as r
		ORDER BY r.collection_time, LEVEL ASC;

'
		
							FROM	@T_JobHistory as jh
							WHERE	jh.RID = 1;
						END -- If @p_SendMail
					END -- Else @p_SuppressNotification
				END -- block if failure issue is found
				ELSE
				BEGIN
					IF @p_Verbose = 1
						PRINT 'Verifying if @_SendMailRequired should be set to 0';
					
					IF @p_NoOfContinousFailuresThreshold > @NoOfContinousFailures
					BEGIN
						SET @_SendMailRequired = 0;
						IF @p_Verbose = 1
							PRINT 'Setting @_SendMailRequired = 0';
					END

				END
			END -- Block -> Logic if Job Failure is due to Blocking Issue
			ELSE IF @NoOfContinousFailures <> 0 AND @IsBlockingIssue = 0
			BEGIN -- Block for Non-Blocking Issue 
				IF @p_Verbose = 1
					PRINT 'Logic processing when Job has failed due to Non-blocking Issues';

				-- If @p_SuppressNotification is used for latest job failure
				IF EXISTS (SELECT * FROM @T_JobHistory h WHERE h.RID = 1 AND h.Instance_Id IN (SELECT e.Instance_Id FROM DBA..LogWalkThresholdInstance AS e WHERE e.JobName = @p_JobName))
				BEGIN
					IF @p_Verbose = 1
						PRINT 'Setting @_SendMailRequired = 0';
					SET @_SendMailRequired = 0;
					
					IF @p_Verbose = 1
					BEGIN
						PRINT '
Exception is present to suppress failure notification @p_SuppressNotification.
Incase this is not required, Kindly execute below query:-
DELETE FROM DBA..LogWalkThresholdInstance WHERE JobName = '''+@p_JobName+''';

'
					END
				END
				ELSE
				BEGIN -- Block when @p_SuppressNotification is NOT used for latest job failure
					
					IF @p_SendMail = 1
					BEGIN
						SELECT @_mailBody = 'Dear DBA Team,

SQL Agent Job '+QUOTENAME(@p_JobName)+' has been failing for '+cast(@NoOfContinousFailures as varchar(2))+ ' times continously.

LAST JOB RUN:		'+CAST(jh.RunDateTime AS varchar(50))+'
DURATION:		'+CAST(jh.RunDurationMinutes AS varchar(10))+' Minutes
STATUS: 		Failed

Kindly check Job Step Error Message' 
						FROM	@T_JobHistory as jh
						WHERE	jh.RID = 1;
					END -- If @p_SendMail
				END -- Block when @p_SuppressNotification is NOT used for latest job failure
				
				IF @p_SuppressNotification = 1
				BEGIN
					IF @p_Verbose = 1
						PRINT 'Inside @p_SuppressNotification = 1 block';
					
					DELETE FROM DBA..LogWalkThresholdInstance WHERE JobName = @p_JobName;

					INSERT DBA..LogWalkThresholdInstance
					SELECT @p_JobName, instance_id FROM	@T_JobHistory WHERE Run_Status = 0 AND RID = 1;
				END
				ELSE
				BEGIN
					IF @p_Verbose = 1
						PRINT 'Setting @_SendMailRequired = 1';
					SET @_SendMailRequired = 1
				END
				
				--ELSE -- Send Mail
				
				
			END -- Block for Non-Blocking Issue 
			ELSE
				PRINT 'Job ['+@p_JobName+'] has not crossed threshold of '+cast(@p_NoOfContinousFailuresThreshold as varchar(2))+ ' continous failures. No action required.';

			-- Send Mail
			IF @NoOfContinousFailures <> 0 AND @p_SendMail = 1 AND @_SendMailRequired = 1
			BEGIN
				SET @_mailSubject = 'SQL Agent Job '+QUOTENAME(@p_JobName)+' Failed for '+cast(@NoOfContinousFailures as varchar(2))+ ' times';
				SET @_mailBody += '


Thanks & Regards,
SQL Alerts
It-Ops-DBA@contso.com
-- Alert Coming from SQL Agent Job [DBA Log Walk Alerts]
		';

				IF @p_Verbose = 1
				BEGIN
					PRINT 'Mail body';
					PRINT @_mailBody;

					PRINT 'Sending mail..';

				END
				
				EXEC msdb..sp_send_dbmail
							@profile_name = @@servername,
							@recipients = @p_Mail_TO,
							@copy_recipients =  @p_Mail_CC,
							@subject = @_mailSubject,
							@body = @_mailBody;
			END
		END -- block if Job History is found
	END -- Else portion of @p_Help = 1
END -- Procedure Body
GO
