use audit_archive
go

Test Case 01:		audit_archive.dbo.commandlog_stage_testing_TestCase01
	-> file extention = *.mdf	
	-> start_time = '2020-07-27 15:12:00.0000000'	
	-> end_time = '2020-07-28 07:14:52.0000000'	
		
Test Case 02:		audit_archive.dbo.commandlog_stage_testing_TestCase02
	-> file extention = *.ndf	
	-> start_time = '2020-07-29 11:22:00.000'	
	-> end_time = '2020-07-30 2:55:00.000'	
		
Test Case 03:		audit_archive.dbo.commandlog_stage_testing_TestCase03
	-> file extention = *.ndf & 'tempdb enabled with InMemoryOLTP'. Only tempdb capture	
	-> start_time = '2020-07-30 14:11:56.160'	
	-> end_time = '2020-07-30 14:11:56.160' -- 07/31/2020 14:07:17	
		
Test Case 04:		audit_archive.dbo.commandlog_stage_testing_TestCase04		
	-> file extention = different filegroups, sandbox, ndf	
	-> start_time = '2020-08-12 17:15:00.000'	
	-> end_time = '2020-08-13 00:26:05.000'	
go

select * from [dbo].commandlog_stage_testing_TestCase02
select * from [dbo].commandlog_stage_testing_TestCase04


select 'single-fg' as [TestCase], scenario, row_count, concurrency, duration
into #t_results_case4_parallel_c1
from [dbo].[commandlog_stage_testing_TestCase02] as c1
where concurrency <> 1 and scenario like 'sandbox%'
order by scenario, row_count, concurrency

select 'multi-fg' as [TestCase], scenario, row_count, concurrency, duration
into #t_results_case4_parallel_c2
from [dbo].[commandlog_stage_testing_TestCase04] as c2
where concurrency <> 1
order by scenario, row_count, concurrency

select *
from #t_results_case4_parallel_c1
union all
select *
from #t_results_case4_parallel_c2



/* TestCase02 - Parallel summary */
select	--'Parallel-AVG' as RunningQuery, 
				cast(row_count as varchar) +' | '+ cast(concurrency as varchar) + ' ('+TestCase+')' as [row_count | concurrency],
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
from ( 
	select *
	from #t_results_case4_parallel_c1
	union all
	select *
	from #t_results_case4_parallel_c2
) up
pivot
(
  avg(duration)
  for scenario in([tempdb__create_table__insert__add_clust], [tempdb__create_table__insert__add_nonclust], [tempdb__create_table_with_nonclust__insert], [sandbox__create_table_with_nonclust__insert], [tempdb__create_table_with_clust__insert], [sandbox__create_table__insert__add_clust], [sandbox__create_table__insert__add_nonclust], [sandbox__create_table_with_clust__insert])
) pvt
order by row_count, concurrency;
