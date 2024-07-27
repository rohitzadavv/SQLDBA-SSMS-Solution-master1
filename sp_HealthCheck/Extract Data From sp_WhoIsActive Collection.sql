use dba;

--	Find all session where databases 'EIDR_Dedup' & 'EIDR_RegCache' used
select DENSE_RANK()OVER(ORDER BY collection_time ASC) AS CollectionBatchNO, * 
from [DBA]..[WhoIsActive_ResultSets] r 
where r.collection_time >= cast('2018-09-01 00:00' as date)
	and r.database_name IN ('EIDR_Dedup','EIDR_RegCache')
	or	r.locks.exist('/Database/@name[.="EIDR_Dedup"]') = 1
	or	r.locks.exist('/Database/@name[.="EIDR_RegCache"]') = 1
	--order by r.collection_time


use DBA;
/* Find all sessions involved in Blocking crossing 'Blocked Process Threshold' */
;with tQueries AS
(
	select [RequestTimeInMinutes] = (cast(LEFT([dd hh:mm:ss.mss],2) as int) * 24 * 60)
			+ (cast(SUBSTRING([dd hh:mm:ss.mss],4,2) as int) * 60)
			+ cast(SUBSTRING([dd hh:mm:ss.mss],7,2) as int),
			*
			,DENSE_RANK()OVER(ORDER BY collection_time ASC) AS CollectionBatchNO
	from [DBA]..[WhoIsActive_ResultSets] as r
	where (	blocking_session_id IS NOT NULL   OR blocked_session_count <> 0	)
		AND	(r.collection_time >= '2018-09-01 00:00:00.000' and r.collection_time <= GETDATE())
)
,t_each_wait as 
(	select CollectionBatchNO, session_id, wait_info
			,wait_details = ltrim(rtrim(case when CHARINDEX(',',wait_info) = 0 then wait_info ELSE left(wait_info,CHARINDEX(',',wait_info)-1) END))
			,wait_info_remaining = ltrim(rtrim(case when CHARINDEX(',',wait_info) = 0 then null else RIGHT(wait_info,len(wait_info)-CHARINDEX(',',wait_info)) end))
	from tQueries
	where blocking_session_id IS NOT NULL
	union all
	select CollectionBatchNO, session_id, wait_info
			,wait_details = ltrim(rtrim(case when CHARINDEX(',',wait_info_remaining) = 0 then wait_info_remaining ELSE left(wait_info_remaining,CHARINDEX(',',wait_info_remaining)-1) END))
			,wait_info_remaining = ltrim(rtrim(case when CHARINDEX(',',wait_info_remaining) = 0 then null else RIGHT(wait_info_remaining,len(wait_info_remaining)-CHARINDEX(',',wait_info_remaining)) end))
	from t_each_wait
	where wait_info_remaining is not null
)
,t2_wait_para as
(
	select CollectionBatchNO, session_id, wait_info, wait_details, wait_info_remaining
			,wait_para = SUBSTRING(wait_details,charindex('(',wait_details)+1,charindex(')',wait_details)-2)
	from t_each_wait
)
,t3_waits_concatenated as
(
	select CollectionBatchNO, session_id, wait_info, wait_details, wait_info_remaining, wait_para
			,wait_min_avg_max = replace(right(wait_para,len(wait_para)-charindex(': ',wait_para)),'ms','')
	from t2_wait_para
)
,t4_wait_min_avg_max as
(	select CollectionBatchNO, session_id, wait_info, wait_details, wait_info_remaining, wait_para, wait_min_avg_max
			,wait_ms = cast(ltrim(rtrim(case when CHARINDEX('/',wait_min_avg_max) = 0 then wait_min_avg_max ELSE left(wait_min_avg_max,CHARINDEX('/',wait_min_avg_max)-1) END)) as bigint)
			,wait_ms_remaining = ltrim(rtrim(case when CHARINDEX('/',wait_min_avg_max) = 0 then null else RIGHT(wait_min_avg_max,len(wait_min_avg_max)-CHARINDEX('/',wait_min_avg_max)) end))
	from t3_waits_concatenated
	union all
	select CollectionBatchNO, session_id, wait_info, wait_details, wait_info_remaining, wait_para, wait_min_avg_max
			,wait_ms = cast(ltrim(rtrim(case when CHARINDEX('/',wait_ms_remaining) = 0 then wait_ms_remaining ELSE left(wait_ms_remaining,CHARINDEX('/',wait_ms_remaining)-1) END)) as bigint)
			,wait_ms_remaining = ltrim(rtrim(case when CHARINDEX('/',wait_ms_remaining) = 0 then null else RIGHT(wait_ms_remaining,len(wait_ms_remaining)-CHARINDEX('/',wait_ms_remaining)) end))
	from t4_wait_min_avg_max
	where wait_ms_remaining is not null
)
,t5_wait_ms_max as
(
	select CollectionBatchNO, session_id, wait_info, max(wait_ms) as wait_ms_max from t4_wait_min_avg_max group by CollectionBatchNO, session_id, wait_info
)
,t_blocked_above_threshold as
(
	select [WaitingTime(Minutes)] = w.wait_ms_max/1000/60, r.CollectionBatchNO, collection_time, [RequestTimeInMinutes], [dd hh:mm:ss.mss], r.session_id, sql_text, login_name, r.wait_info, tasks, tran_log_writes, CPU, tempdb_allocations, tempdb_current, blocking_session_id, blocked_session_count, reads, writes, context_switches, physical_io, physical_reads, locks, used_memory, status, tran_start_time, open_tran_count, percent_complete, host_name, database_name, program_name, additional_info, start_time, login_time, request_id 
	from tQueries as r
	left join t5_wait_ms_max as w
	on w.CollectionBatchNO = r.CollectionBatchNO and w.session_id = r.session_id
	where w.wait_ms_max >= ((select cast(c.value_in_use as int) from sys.configurations c where c.name like 'blocked process threshold (s)') * 1000) -- Wait Time is 5 Minutes
)
select	*
from t_blocked_above_threshold
--
union all
--
select [WaitingTime(Minutes)] = NULL, r.CollectionBatchNO, collection_time, [RequestTimeInMinutes], [dd hh:mm:ss.mss], r.session_id, sql_text, login_name, r.wait_info, tasks, tran_log_writes, CPU, tempdb_allocations, tempdb_current, blocking_session_id, blocked_session_count, reads, writes, context_switches, physical_io, physical_reads, locks, used_memory, status, tran_start_time, open_tran_count, percent_complete, host_name, database_name, program_name, additional_info, start_time, login_time, request_id 
from tQueries as r
where r.blocked_session_count <> 0
and exists (select 1 from t_blocked_above_threshold as t where t.CollectionBatchNO = r.CollectionBatchNO and t.blocking_session_id = r.session_id)
order by CollectionBatchNO, blocked_session_count desc

