use audit_archive
go

select * from [dbo].[commandlog_stage_testing_TestCase01]

/* get serial result */
select scenario, row_count, AVG(duration) as avg_duration
from [dbo].[commandlog_stage_testing_TestCase01_TestCase01] 
where concurrency = 1
group by scenario, row_count
order by scenario, row_count

/* get concurrent result */
select *
from [dbo].[commandlog_stage_testing_TestCase01_TestCase01] 
where concurrency <> 1



/* TestCase01 - Serial Summary */
select	--'Serial-AVG' as RunningQuery, 
				row_count,
				[sandbox__create_table_with_clust__insert], [sandbox__create_table_with_nonclust__insert],
				[sandbox__create_table__insert__add_clust], [sandbox__create_table__insert__add_nonclust],
				[tempdb__create_table_with_clust__insert], [tempdb__create_table_with_nonclust__insert],
				[tempdb__create_table__insert__add_clust], [tempdb__create_table__insert__add_nonclust]
--into #TestCase01_Serial_Summary
from (  select scenario, row_count, duration from audit_archive.dbo.commandlog_stage_testing_TestCase01_TestCase01 as t where t.concurrency = 1 ) up
pivot
(
  avg(duration)
  for scenario in([tempdb__create_table__insert__add_clust], [tempdb__create_table__insert__add_nonclust], [tempdb__create_table_with_nonclust__insert], [sandbox__create_table_with_nonclust__insert], [tempdb__create_table_with_clust__insert], [sandbox__create_table__insert__add_clust], [sandbox__create_table__insert__add_nonclust], [sandbox__create_table_with_clust__insert])
) pvt
order by row_count;

select [TestCase-Scenario] = 'TestCase04-Serial', cast(min(t.start_time) as datetime) as start_time, cast(max(t.end_time) as datetime) as end_time
from audit_archive.dbo.commandlog_stage_testing_TestCase04 as t where t.concurrency = 1

select cast(min(t.start_time) as datetime), cast(max(t.end_time) as datetime)
from audit_archive.dbo.commandlog_stage_testing_TestCase04 as t 
where t.concurrency <> 1




/* TestCase01 - Parallel summary */
select	--'Parallel-AVG' as RunningQuery, 
				cast(row_count as varchar) +' | '+ cast(concurrency as varchar) as [row_count | concurrency],
				[sandbox__create_table_with_clust__insert], [sandbox__create_table_with_nonclust__insert],
				[sandbox__create_table__insert__add_clust], [sandbox__create_table__insert__add_nonclust],
				[tempdb__create_table_with_clust__insert], [tempdb__create_table_with_nonclust__insert],
				[tempdb__create_table__insert__add_clust], [tempdb__create_table__insert__add_nonclust]
				,case (SELECT MIN(v) 
								 FROM (VALUES ([sandbox__create_table_with_clust__insert]), ([sandbox__create_table_with_nonclust__insert]),
																([sandbox__create_table__insert__add_clust]), ([sandbox__create_table__insert__add_nonclust])
						) AS value(v)
				 ) 
				     when [sandbox__create_table_with_clust__insert] then 'create_table_with_clust__insert'
						 when [sandbox__create_table_with_nonclust__insert] then 'create_table_with_nonclust__insert'
						 when [sandbox__create_table__insert__add_clust] then 'create_table__insert__add_clust'
						 when [sandbox__create_table__insert__add_nonclust] then 'create_table__insert__add_nonclust'
						 else null
						 end as [winner_sandbox]
				,case (SELECT MIN(v) 
								 FROM (VALUES ([tempdb__create_table_with_clust__insert]), ([tempdb__create_table_with_nonclust__insert]),
												([tempdb__create_table__insert__add_clust]), ([tempdb__create_table__insert__add_nonclust])
						) AS value(v)
				 )
				     when [tempdb__create_table_with_clust__insert] then 'create_table_with_clust__insert'
						 when [tempdb__create_table_with_nonclust__insert] then 'create_table_with_nonclust__insert'
						 when [tempdb__create_table__insert__add_clust] then 'create_table__insert__add_clust'
						 when [tempdb__create_table__insert__add_nonclust] then 'create_table__insert__add_nonclust'
						 else null
						 end as [winner_tempdb]
				,case (SELECT MIN(v) 
								 FROM (VALUES ([sandbox__create_table_with_clust__insert]), ([sandbox__create_table_with_nonclust__insert]),
																([sandbox__create_table__insert__add_clust]), ([sandbox__create_table__insert__add_nonclust]),
																([tempdb__create_table_with_clust__insert]), ([tempdb__create_table_with_nonclust__insert]),
																([tempdb__create_table__insert__add_clust]), ([tempdb__create_table__insert__add_nonclust])
						) AS value(v)
				 )
				     when [sandbox__create_table_with_clust__insert] then 'sandbox'
						 when [sandbox__create_table_with_nonclust__insert] then 'sandbox'
						 when [sandbox__create_table__insert__add_clust] then 'sandbox'
						 when [sandbox__create_table__insert__add_nonclust] then 'sandbox'
						 when [tempdb__create_table_with_clust__insert] then 'tempdb'
						 when [tempdb__create_table_with_nonclust__insert] then 'tempdb'
						 when [tempdb__create_table__insert__add_clust] then 'tempdb'
						 when [tempdb__create_table__insert__add_nonclust] then 'tempdb'
						 else null
						 end as [winner]
from ( select scenario, row_count, concurrency, duration from audit_archive.dbo.commandlog_stage_testing_TestCase01 as t where t.concurrency <> 1 ) up
pivot
(
  avg(duration)
  for scenario in([tempdb__create_table__insert__add_clust], [tempdb__create_table__insert__add_nonclust], [tempdb__create_table_with_nonclust__insert], [sandbox__create_table_with_nonclust__insert], [tempdb__create_table_with_clust__insert], [sandbox__create_table__insert__add_clust], [sandbox__create_table__insert__add_nonclust], [sandbox__create_table_with_clust__insert])
) pvt
order by row_count, concurrency;
