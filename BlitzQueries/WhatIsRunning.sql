--	Query to find what's is running on server
SELECT	s.session_id, 
		DB_NAME(r.database_id) as DBName,
		r.percent_complete,
		[session_status] = s.status,
		[request_status] = r.status,
		[running_command] = r.command,
		[request_wait_type] = r.wait_type, 
		[request_wait_resource] = wait_resource,
		[request_start_time] = r.start_time,
		[request_running_time] = CAST(((DATEDIFF(s,r.start_time,GetDate()))/3600) as varchar) + ' hour(s), '
			+ CAST((DATEDIFF(s,r.start_time,GetDate())%3600)/60 as varchar) + 'min, '
			+ CAST((DATEDIFF(s,r.start_time,GetDate())%60) as varchar) + ' sec',
		[est_time_to_go] = CAST((r.estimated_completion_time/3600000) as varchar) + ' hour(s), '
						+ CAST((r.estimated_completion_time %3600000)/60000  as varchar) + 'min, '
						+ CAST((r.estimated_completion_time %60000)/1000  as varchar) + ' sec',
		[est_completion_time] = dateadd(second,r.estimated_completion_time/1000, getdate()),
		[blocked by] = r.blocking_session_id,
		[statement_text] = Substring(st.TEXT, (r.statement_start_offset / 2) + 1, (
				(
					CASE r.statement_end_offset
						WHEN - 1
							THEN Datalength(st.TEXT)
						ELSE r.statement_end_offset
						END - r.statement_start_offset
					) / 2
				) + 1),
		[Batch_Text] = st.text,
		[WaitTime(S)] = r.wait_time / (1000.0),
		[total_elapsed_time(S)] = r.total_elapsed_time / (1000.0),
		s.login_time, s.host_name, s.host_process_id, s.client_interface_name, s.login_name, 
		s.memory_usage, 
		[session_writes] = s.writes, 
		[request_writes] = r.writes, 
		[session_logical_reads] = s.logical_reads, 
		[request_logical_reads] = r.logical_reads, 
		s.is_user_process, 
		[session_row_count] = s.row_count,
		[request_row_count] = r.row_count,
		r.sql_handle, 
		r.plan_handle, 
		r.open_transaction_count,
		[request_cpu_time] = r.cpu_time,
		[granted_query_memory] = CASE WHEN ((CAST(r.granted_query_memory AS numeric(20,2))*8)/1024/1024) >= 1.0
									  THEN CAST(((CAST(r.granted_query_memory AS numeric(20,2))*8)/1024/1024) AS VARCHAR(23)) + ' GB'
									  WHEN ((CAST(r.granted_query_memory AS numeric(20,2))*8)/1024) >= 1.0
									  THEN CAST(((CAST(r.granted_query_memory AS numeric(20,2))*8)/1024) AS VARCHAR(23)) + ' MB'
									  ELSE CAST((CAST(r.granted_query_memory AS numeric(20,2))*8) AS VARCHAR(23)) + ' KB'
									  END,
		r.query_hash, 
		r.query_plan_hash,
		[BatchQueryPlan] = bqp.query_plan,
		[SqlQueryPlan] = CAST(sqp.query_plan AS xml),
		[program_name] = CASE	WHEN	s.program_name like 'SQLAgent - TSQL JobStep %'
				THEN	(	select	top 1 'SQL Job = '+j.name 
							from msdb.dbo.sysjobs (nolock) as j
							inner join msdb.dbo.sysjobsteps (nolock) AS js on j.job_id=js.job_id
							where right(cast(js.job_id as nvarchar(50)),10) = RIGHT(substring(s.program_name,30,34),10) 
						)
				ELSE	s.program_name
				END,
		[IsSqlJob] = CASE WHEN s.program_name like 'SQLAgent - TSQL JobStep %'THEN 1 ELSE 2	END
		,open_resultset_count
FROM	sys.dm_exec_sessions AS s
LEFT JOIN sys.dm_exec_requests AS r ON r.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
OUTER APPLY sys.dm_exec_query_plan(r.plan_handle) AS bqp
OUTER APPLY sys.dm_exec_text_query_plan(r.plan_handle,r.statement_start_offset, r.statement_end_offset) as sqp
WHERE	s.session_id != @@SPID
	AND (	(CASE	WHEN	s.session_id IN (select ri.blocking_session_id from sys.dm_exec_requests as ri )
					--	Get sessions involved in blocking (including system sessions)
					THEN	1
					WHEN	r.blocking_session_id IS NOT NULL AND r.blocking_session_id <> 0
					THEN	1
					ELSE	0
			END) = 1
			OR
			(CASE	WHEN	s.session_id > 50
							AND r.session_id IS NOT NULL -- either some part of session has active request
							--AND ISNULL(open_resultset_count,0) > 0 -- some result is open
							AND s.status <> 'sleeping'
					THEN	1
					ELSE	0
			END) = 1
			OR
			(CASE	WHEN	s.session_id > 50
							AND ISNULL(r.open_transaction_count,0) > 0
					THEN	1
					ELSE	0
			END) = 1
		)		
ORDER BY [request_start_time];


DECLARE @scheduler_count varchar(10);
SELECT @scheduler_count = COUNT(1) FROM sys.dm_os_schedulers WHERE status = 'VISIBLE ONLINE';

--	Query to find what's is running on server
select  Concat
        (
            RIGHT('00'+CAST(ISNULL((datediff(second,r.start_time,GETDATE()) / 3600 / 24), 0) AS VARCHAR(2)),2)
            ,' '
            ,RIGHT('00'+CAST(ISNULL(datediff(second,r.start_time,GETDATE()) / 3600  % 24, 0) AS VARCHAR(2)),2)
            ,':'
            ,RIGHT('00'+CAST(ISNULL(datediff(second,r.start_time,GETDATE()) / 60 % 60, 0) AS VARCHAR(2)),2)
            ,':'
            ,RIGHT('00'+CAST(ISNULL(datediff(second,r.start_time,GETDATE()) % 3600 % 60, 0) AS VARCHAR(2)),2)
        ) as [dd hh:mm:ss]
		,r.session_id
		,st.text as sql_command
		,SUBSTRING(st.text, (r.statement_start_offset/2)+1,   
        ((CASE r.statement_end_offset WHEN -1 THEN DATALENGTH(st.text)  
				ELSE r.statement_end_offset END - r.statement_start_offset)/2) + 1) AS sql_text
		,r.command as command
		,s.login_name as login_name
		,db_name(r.database_id) as database_name
		,[program_name] = CASE	WHEN	s.program_name like 'SQLAgent - TSQL JobStep %'
				THEN	(	select	top 1 'SQL Job = '+j.name 
							from msdb.dbo.sysjobs (nolock) as j
							inner join msdb.dbo.sysjobsteps (nolock) AS js on j.job_id=js.job_id
							where right(cast(js.job_id as nvarchar(50)),10) = RIGHT(substring(s.program_name,30,34),10) 
						) + ' ( '+SUBSTRING(LTRIM(RTRIM(s.program_name)), CHARINDEX(': Step ',LTRIM(RTRIM(s.program_name)))+2,LEN(LTRIM(RTRIM(s.program_name)))-CHARINDEX(': Step ',LTRIM(RTRIM(s.program_name)))-2)+' )'
				ELSE	s.program_name
				END
		,(case when r.wait_time = 0 then null else r.wait_type end) as wait_type
		,r.wait_time as wait_time
		,(SELECT CASE
				WHEN pageid = 1 OR pageid % 8088 = 0 THEN 'PFS'
				WHEN pageid = 2 OR pageid % 511232 = 0 THEN 'GAM'
				WHEN pageid = 3 OR (pageid - 1) % 511232 = 0 THEN 'SGAM'
				WHEN pageid IS NULL THEN NULL
				ELSE 'Not PFS/GAM/SGAM' END
				FROM (SELECT CASE WHEN r.[wait_type] LIKE 'PAGE%LATCH%' AND r.[wait_resource] LIKE '%:%'
				THEN CAST(RIGHT(r.[wait_resource], LEN(r.[wait_resource]) - CHARINDEX(':', r.[wait_resource], LEN(r.[wait_resource])-CHARINDEX(':', REVERSE(r.[wait_resource])))) AS INT)
				ELSE NULL END AS pageid) AS latch_pageid
		) AS wait_resource_type
		,null as tempdb_allocations
		,null as tempdb_current
		,r.blocking_session_id
		,r.logical_reads as reads
		,r.writes as writes
		,r.cpu_time
		,granted_query_memory = CASE WHEN ((CAST(r.granted_query_memory AS numeric(20,2))*8)/1024/1024) >= 1.0
									  THEN CAST(((CAST(r.granted_query_memory AS numeric(20,2))*8)/1024/1024) AS VARCHAR(23)) + ' GB'
									  WHEN ((CAST(r.granted_query_memory AS numeric(20,2))*8)/1024) >= 1.0
									  THEN CAST(((CAST(r.granted_query_memory AS numeric(20,2))*8)/1024) AS VARCHAR(23)) + ' MB'
									  ELSE CAST((CAST(r.granted_query_memory AS numeric(20,2))*8) AS VARCHAR(23)) + ' KB'
									  END
		,r.status
		,r.open_transaction_count
		,s.host_name as host_name
		,r.start_time as start_time
		,s.login_time as login_time
		,GETDATE() as collection_time
FROM	sys.dm_exec_sessions AS s
LEFT JOIN sys.dm_exec_requests AS r ON r.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
OUTER APPLY sys.dm_exec_query_plan(r.plan_handle) AS bqp
OUTER APPLY sys.dm_exec_text_query_plan(r.plan_handle,r.statement_start_offset, r.statement_end_offset) as sqp
WHERE	s.session_id != @@SPID
	AND (	(CASE	WHEN	s.session_id IN (select ri.blocking_session_id from sys.dm_exec_requests as ri )
					--	Get sessions involved in blocking (including system sessions)
					THEN	1
					WHEN	r.blocking_session_id IS NOT NULL AND r.blocking_session_id <> 0
					THEN	1
					ELSE	0
			END) = 1
			OR
			(CASE	WHEN	s.session_id > 50
							AND r.session_id IS NOT NULL -- either some part of session has active request
							--AND ISNULL(open_resultset_count,0) > 0 -- some result is open
							AND s.status <> 'sleeping'
					THEN	1
					ELSE	0
			END) = 1
			OR
			(CASE	WHEN	s.session_id > 50
							AND ISNULL(r.open_transaction_count,0) > 0
					THEN	1
					ELSE	0
			END) = 1
		)		
ORDER BY start_time asc;

--select * from sys.dm_exec_requests