--	https://www.sqlskills.com/blogs/jonathan/identifying-external-memory-pressure-with-dm_os_ring_buffers-and-ring_buffer_resource_monitor/
DECLARE @pool_name sysname --= 'REST';
DECLARE @top_x_program_rows SMALLINT = 10;
DECLARE @top_x_query_rows SMALLINT = 25;
DECLARE @cpu_trend_minutes INT = 30;

;with t_PerfMon as
(
	--Total amount of RAM consumed by database data (Buffer Pool). This should be the highest usage of Memory on the server.
	Select SQLBufferPoolUsedMemoryMB = (Select SUM(pages_kb)/1024 AS [SPA Mem, Mb] FROM sys.dm_os_memory_clerks WITH (NOLOCK) Where type = 'MEMORYCLERK_SQLBUFFERPOOL')
		   --Total amount of RAM used by SQL Server memory clerks (includes Buffer Pool)
		   , SQLAllMemoryClerksUsedMemoryMB = (Select SUM(pages_kb)/1024 AS [SPA Mem, Mb] FROM sys.dm_os_memory_clerks WITH (NOLOCK))
		   --How long in seconds since data was removed from the Buffer Pool, to be replaced with data from disk. (Key indicator of memory pressure when below 300 consistently)
		   ,[PageLifeExpectancy] = (SELECT cntr_value FROM sys.dm_os_performance_counters WITH (NOLOCK) WHERE [object_name] LIKE N'%Buffer Manager%' AND counter_name = N'Page life expectancy' )
		   --How many memory operations are Pending (should always be 0, anything above 0 for extended periods of time is a very high sign of memory pressure)
		   ,[MemoryGrantsPending] = (SELECT cntr_value FROM sys.dm_os_performance_counters WITH (NOLOCK) WHERE [object_name] LIKE N'%Memory Manager%' AND counter_name = N'Memory Grants Pending' )
		   --How many memory operations are Outstanding (should always be 0, anything above 0 for extended periods of time is a very high sign of memory pressure)
		   ,[MemoryGrantsOutstanding] = (SELECT cntr_value FROM sys.dm_os_performance_counters WITH (NOLOCK) WHERE [object_name] LIKE N'%Memory Manager%' AND counter_name = N'Memory Grants Outstanding' )
)
select  'Memory-Status' as RunningQuery, convert(datetime,sysutcdatetime()) as [Current-Time-UTC], [MemoryGrantsPending] as [**M/r-Grants-Pending**], [PageLifeExpectancy],
		cast(sm.total_physical_memory_kb * 1.0 / 1024 / 1024 as numeric(20,0)) as SqlServer_Process_memory_gb, 
		cast(sm.available_physical_memory_kb * 1.0 / 1024 / 1024 as numeric(20,2)) as available_physical_memory_gb, 
		cast((sm.total_page_file_kb - sm.available_page_file_kb) * 1.0 / 1024 / 1024 as numeric(20,0)) as used_page_file_gb,
		cast(sm.system_cache_kb * 1.0 / 1024 /1024 as numeric(20,2)) as system_cache_gb, 
		cast((sm.available_physical_memory_kb - sm.system_cache_kb) * 1.0 / 1024 as numeric(20,2)) as free_memory_mb,
		cast(page_fault_count*8.0/1024/1024 as decimal(20,2)) as page_fault_gb,
		[MemoryGrantsOutstanding], SQLBufferPoolUsedMemoryMB, SQLAllMemoryClerksUsedMemoryMB
from sys.dm_os_sys_memory as sm
full outer join sys.dm_os_process_memory as pm on 1 = 1
full outer join t_PerfMon as pfm on 1 = 1;


DECLARE @system_cpu_utilization VARCHAR(2000);
DECLARE @sql_cpu_utilization VARCHAR(2000);
;WITH T_Cpu_Ring_Buffer AS
(
	SELECT	EventTime,
			CASE WHEN system_cpu_utilization_post_sp2 IS NOT NULL THEN system_cpu_utilization_post_sp2 ELSE system_cpu_utilization_pre_sp2 END AS system_cpu_utilization,  
			CASE WHEN sql_cpu_utilization_post_sp2 IS NOT NULL THEN sql_cpu_utilization_post_sp2 ELSE sql_cpu_utilization_pre_sp2 END AS sql_cpu_utilization 
			,ROW_NUMBER()OVER(PARTITION BY CAST(EventTime as smalldatetime) ORDER BY EventTime ASC) as cpu_minute_id
	FROM  (	SELECT	record.value('(Record/@id)[1]', 'int') AS record_id,
					DATEADD (ms, -1 * (ts_now - [timestamp]), GETDATE()) AS EventTime,
					100-record.value('(Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS system_cpu_utilization_post_sp2, 
					record.value('(Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS sql_cpu_utilization_post_sp2,
					100-record.value('(Record/SchedluerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS system_cpu_utilization_pre_sp2,
					record.value('(Record/SchedluerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS sql_cpu_utilization_pre_sp2
			FROM (	SELECT	timestamp, CONVERT (xml, record) AS record, cpu_ticks / (cpu_ticks/ms_ticks) as ts_now
					FROM sys.dm_os_ring_buffers cross apply sys.dm_os_sys_info
					WHERE ring_buffer_type = 'RING_BUFFER_SCHEDULER_MONITOR'
					AND record LIKE '%<SystemHealth>%'
				 ) AS t 
		  ) AS t
	WHERE EventTime >= DATEADD(minute,-@cpu_trend_minutes,getdate())
)
SELECT @system_cpu_utilization = COALESCE(@system_cpu_utilization+' <- '+STR(system_cpu_utilization,3,0), STR(system_cpu_utilization,3,0)),
		@sql_cpu_utilization = COALESCE(@sql_cpu_utilization+' <- '+STR(sql_cpu_utilization,3,0), STR(sql_cpu_utilization,3,0))
FROM T_Cpu_Ring_Buffer
WHERE cpu_minute_id = 1
ORDER BY EventTime desc;

SELECT [*********************************************** Ring Buffer CPU Utilization Trend **********************************************] = 'Local Time -> ' + CONVERT(varchar, getdate(), 21) + '                      ' + 'UTC Time -> ' + CONVERT(varchar, cast(SYSUTCDATETIME() as datetime), 21) + '                      Allocated Schedulers -> ' + (select cast(count(IIF(dos.status = 'VISIBLE ONLINE','sql',NULL)) as varchar)+' / '+cast(count(IIF(dos.status IN ('VISIBLE ONLINE','VISIBLE OFFLINE'),'all',NULL)) as varchar) from sys.dm_os_schedulers dos)
UNION ALL
SELECT [Info] = LEFT('OS CPU'+REPLICATE('_',20),10 ) + ' = ' + @system_cpu_utilization
UNION ALL
SELECT [Info] = LEFT('SQL CPU'+REPLICATE('_',20),10 ) + ' = ' + @sql_cpu_utilization;


/* Begin Code to find Resource Pool Scheduler Affinity */
set nocount on;
if OBJECT_ID('tempdb..#resource_pool') is not null	drop table #resource_pool;
if OBJECT_ID('tempdb..#temp') is not null	drop table #temp;

create table #resource_pool (rpoolname sysname, scheduler_id int, cpu_id int);
create table #temp (name sysname, pool_id int, scheduler_mask bigint);

insert into #temp
select rp.name,rp.pool_id,pa.scheduler_mask 
from sys.dm_resource_governor_resource_pools rp 
left join sys.resource_governor_resource_pool_affinity pa on rp.pool_id=pa.pool_id
where rp.pool_id>2;

--select * from #temp

if not exists (select * from #temp where scheduler_mask is not null)
	print 'WARNING: No Scheduler Affinity Defined';
else
begin
	while((select count(1) from #temp) > 0)
	Begin
	declare @intvalue numeric,@rpoolname sysname
	declare @vsresult varchar(64)
	declare @inti numeric
	DECLARE @counter int=0
	select @inti = 64, @vsresult = ''
	select top 1 @intvalue = scheduler_mask,@rpoolname = name from #temp
	while @inti>0
	  begin
	  if(@intvalue %2 =1)
	  BEGIN
		insert into #resource_pool(rpoolname,scheduler_id) values(@rpoolname,@counter)
	  END
		select @intvalue = convert(bigint, (@intvalue / 2)), @inti=@inti-1
		set @counter = @counter+1
	  end
	  delete from #temp where name= @rpoolname
	End

	update rpl
	set rpl.cpu_id = dos.cpu_id
	from sys.dm_os_schedulers dos inner join #resource_pool rpl
	on dos.scheduler_id=rpl.scheduler_id
end

-- Insert schedulers NOT assigned to Any Pool, and still utilized by SQL Server
insert into #resource_pool
select 'REST' as rpoolname, dos.scheduler_id,dos.cpu_id 
from sys.dm_os_schedulers dos
left join #resource_pool rpl on dos.scheduler_id = rpl.scheduler_id 
where rpl.scheduler_id is NULL and dos.status = 'VISIBLE ONLINE';
--select * from #resource_pool

/* End Code to find Resource Pool Scheduler Affinity */


declare @object_name varchar(255);
set @object_name = (case when @@SERVICENAME = 'MSSQLSERVER' then 'SQLServer' else 'MSSQL$'+@@SERVICENAME end);
;WITH T_Pools AS (
	SELECT /* counter that require Fraction & Base */
			'Resource Pool CPU %' as RunningQuery,
			rtrim(fr.instance_name) as [Pool], 
			[% CPU @Server-Level] = convert(numeric(20,1),case when bs.cntr_value <> 0 then (100*((fr.cntr_value*1.0)/bs.cntr_value)) else fr.cntr_value end),		
			[% Schedulers@Total] = case when rp.Scheduler_Count <> 0 then convert(numeric(20,1),((rp.Scheduler_Count*1.0)/(select count(1) as cpu_counts from sys.dm_os_schedulers as dos where dos.status IN ('VISIBLE ONLINE','VISIBLE OFFLINE')))*100) else NULL end,	
			[% Schedulers@Sql] = case when rp.Scheduler_Count <> 0 then convert(numeric(20,1),((rp.Scheduler_Count*1.0)/(select count(1) as cpu_counts from sys.dm_os_schedulers as dos where dos.status = 'VISIBLE ONLINE'))*100) else NULL end,	
			[Assigned Schedulers] = case when rp.Scheduler_Count <> 0 then rp.Scheduler_Count else null end
	FROM sys.dm_os_performance_counters as fr
	OUTER APPLY
		(	SELECT * FROM sys.dm_os_performance_counters as bs 
			WHERE bs.cntr_type = 1073939712 /* PERF_LARGE_RAW_BASE  */ 
			AND bs.[object_name] = fr.[object_name] 
			AND (	REPLACE(LOWER(RTRIM(bs.counter_name)),' base','') = REPLACE(LOWER(RTRIM(fr.counter_name)),' ratio','')
				OR
				REPLACE(LOWER(RTRIM(bs.counter_name)),' base','') = LOWER(RTRIM(fr.counter_name))
				)
			AND bs.instance_name = fr.instance_name
		) as bs
	OUTER APPLY (	SELECT COUNT(*) as Scheduler_Count FROM #resource_pool AS rp WHERE rp.rpoolname = rtrim(fr.instance_name)	) as rp
	WHERE fr.cntr_type = 537003264 /* PERF_LARGE_RAW_FRACTION */
		--and fr.cntr_value > 0.0
		and
		(
			( fr.[object_name] like (@object_name+':Resource Pool Stats%') and fr.counter_name like 'CPU usage %' )
		)
)
SELECT RunningQuery, convert(datetime,sysutcdatetime()) as [Current-Time-UTC], [Pool], 
		[% CPU @Pool-Level] = CASE WHEN [Assigned Schedulers] IS NULL THEN NULL WHEN [% Schedulers@Total] <> 0 THEN CONVERT(NUMERIC(20,2),([% CPU @Server-Level]*100.0)/[% Schedulers@Total]) ELSE [% CPU @Server-Level] END,
		[% CPU @Server-Level], [% Schedulers@Total],		
		[% Schedulers@Sql], [Assigned Schedulers]
FROM T_Pools
WHERE NOT ([Assigned Schedulers] IS NULL AND [% CPU @Server-Level] = 0)
ORDER BY [% CPU @Pool-Level] desc, [% CPU @Server-Level] desc;

--SELECT scheduler_id,count(*) FROM #resource_pool AS rp group by scheduler_id


IF (SELECT count(distinct rpoolname) FROM #resource_pool) < 2
	SET @pool_name = NULL;
;WITH T_Requests AS 
(
	SELECT [Pool], s.program_name, r.session_id, r.request_id
	FROM  sys.dm_exec_requests r
	JOIN	sys.dm_exec_sessions s ON s.session_id = r.session_id
	OUTER APPLY
		(	select rgrp.name as [Pool]
			from sys.resource_governor_workload_groups rgwg 
			join sys.resource_governor_resource_pools rgrp ON rgwg.pool_id = rgrp.pool_id
			where rgwg.group_id = s.group_id
		) rp
	WHERE s.is_user_process = 1	
		AND login_name NOT LIKE '%sqlexec%'
		AND (@pool_name is null or [Pool] = @pool_name )
)
,T_Programs_Tasks_Total AS
(
	SELECT	[Pool], r.program_name,
			[active_request_counts] = COUNT(*),
			[num_tasks] = SUM(t.tasks)
	FROM  T_Requests as r
	OUTER APPLY (	select count(*) AS tasks, count(distinct t.scheduler_id) as schedulers 
								from sys.dm_os_tasks t where r.session_id = t.session_id and r.request_id = t.request_id
							) t
	GROUP  BY [Pool], r.program_name
)
,T_Programs_Schedulers AS
(
	SELECT [Pool], r.program_name, [num_schedulers] = COUNT(distinct t.scheduler_id)
	FROM T_Requests as r
	JOIN sys.dm_os_tasks t
		ON t.session_id = r.session_id AND t.request_id = r.request_id
	GROUP BY [Pool], program_name
)
SELECT RunningQuery = (COALESCE(@pool_name,'ALL')+'-POOL/')+'Active Requests/program',
		ptt.[Pool],
		ptt.program_name, ptt.active_request_counts, ptt.num_tasks, ps.num_schedulers, 
		[scheduler_percent] = case when @pool_name is not null then Floor(ps.num_schedulers * 100.0 / rp.Scheduler_Count)
									else Floor(ps.num_schedulers * 100.0 / (select count(*) from sys.dm_os_schedulers as os where os.status = 'VISIBLE ONLINE'))
									end
FROM	T_Programs_Tasks_Total as ptt
JOIN	T_Programs_Schedulers as ps
	ON ps.program_name = ptt.program_name
OUTER APPLY (	SELECT COUNT(*) as Scheduler_Count FROM #resource_pool AS rp WHERE rp.rpoolname = ptt.[Pool]	) as rp
ORDER  BY [Pool], [scheduler_percent] desc, active_request_counts desc, [num_tasks] desc
OFFSET 0 ROWS FETCH NEXT @top_x_program_rows ROWS ONLY; 


--	Query to find what's is running on server
;WITH T_Active_Requests AS
(
SELECT	[Pool] = case when @pool_name is null then rgrp.name else @pool_name end,
				Concat
        (
            RIGHT('00'+CAST(ISNULL((datediff(second,r.start_time,GETDATE()) / 3600 / 24), 0) AS VARCHAR(2)),2)
            ,' '
            ,RIGHT('00'+CAST(ISNULL(datediff(second,r.start_time,GETDATE()) / 3600  % 24, 0) AS VARCHAR(2)),2)
            ,':'
            ,RIGHT('00'+CAST(ISNULL(datediff(second,r.start_time,GETDATE()) / 60 % 60, 0) AS VARCHAR(2)),2)
            ,':'
            ,RIGHT('00'+CAST(ISNULL(datediff(second,r.start_time,GETDATE()) % 3600 % 60, 0) AS VARCHAR(2)),2)
        ) as [dd hh:mm:ss],
				[program_name] = CASE	WHEN	s.program_name like 'SQLAgent - TSQL JobStep %'
				THEN	(	select	top 1 'SQL Job = '+j.name 
							from msdb.dbo.sysjobs (nolock) as j
							inner join msdb.dbo.sysjobsteps (nolock) AS js on j.job_id=js.job_id
							where right(cast(js.job_id as nvarchar(50)),10) = RIGHT(substring(s.program_name,30,34),10) 
						)
				ELSE	s.program_name
				END,
				s.login_name,
				DB_NAME(r.database_id) as DBName,
				[running_command] = r.command,
				s.host_name,
				COUNT(*) OVER(PARTITION BY program_name, LEFT(st.text,500)) as query_count,
				s.session_id,
				[request_status] = r.status,
				--[request_status] = r.status,
				[request_wait_type] = r.wait_type+case when wait_resource is not null then '('+wait_resource+')' else '' end,
				[blocked by] = r.blocking_session_id,
				r.open_transaction_count,
				[granted_query_memory] = CASE WHEN ((CAST(r.granted_query_memory AS numeric(20,2))*8)/1024/1024) >= 1.0
												THEN CAST(((CAST(r.granted_query_memory AS numeric(20,2))*8)/1024/1024) AS VARCHAR(23)) + ' GB'
												WHEN ((CAST(r.granted_query_memory AS numeric(20,2))*8)/1024) >= 1.0
												THEN CAST(((CAST(r.granted_query_memory AS numeric(20,2))*8)/1024) AS VARCHAR(23)) + ' MB'
												ELSE CAST((CAST(r.granted_query_memory AS numeric(20,2))*8) AS VARCHAR(23)) + ' KB'
												END,
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
				s.login_time, s.client_interface_name,  
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
				[request_cpu_time] = r.cpu_time,
				[request_start_time] = r.start_time,
				r.query_hash, 
				r.query_plan_hash,
				[BatchQueryPlan] = bqp.query_plan,
				[SqlQueryPlan] = CAST(sqp.query_plan AS xml),		
				[IsSqlJob] = CASE WHEN s.program_name like 'SQLAgent - TSQL JobStep %'THEN 1 ELSE 2	END
				,open_resultset_count
FROM	sys.dm_exec_sessions AS s
LEFT JOIN sys.dm_exec_requests AS r ON r.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
OUTER APPLY sys.dm_exec_query_plan(r.plan_handle) AS bqp
OUTER APPLY sys.dm_exec_text_query_plan(r.plan_handle,r.statement_start_offset, r.statement_end_offset) as sqp
LEFT JOIN sys.resource_governor_workload_groups rgwg ON s.group_id = rgwg.group_id
LEFT JOIN sys.resource_governor_resource_pools rgrp ON rgwg.pool_id = rgrp.pool_id
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
AND (@pool_name is null or s.group_id is null or rgrp.name = @pool_name )
)
SELECT *
FROM T_Active_Requests
ORDER BY query_count desc, [request_start_time]
OFFSET 0 ROWS FETCH NEXT @top_x_query_rows ROWS ONLY; 
