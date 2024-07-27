use audit_archive
go

select * from [dbo].[commandlog_stage_testing_TestCase02]


/* create temp table for serial result */
select '*.mdf' as [TestCase], scenario, row_count, AVG(duration) as avg_duration
into #t_results_c1
from [dbo].[commandlog_stage_testing_TestCase01] as c1
where concurrency = 1
group by scenario, row_count
order by scenario, row_count

select '*.ndf' as [TestCase], scenario, row_count, AVG(duration) as avg_duration
into #t_results_c2
from [dbo].[commandlog_stage_testing_TestCase02] as c2
where concurrency = 1
group by scenario, row_count
order by scenario, row_count

select *
from #t_results_c1 as c1
--
union all
--
select *
from #t_results_c2 as c2
order by scenario, row_count, [TestCase], avg_duration


/* TestCase01 - Serial Summary */
select	--'Serial-AVG' as RunningQuery, 
				TestCase,
				row_count,
				[sandbox__create_table_with_clust__insert], [sandbox__create_table_with_nonclust__insert],
				[sandbox__create_table__insert__add_clust], [sandbox__create_table__insert__add_nonclust],
				[tempdb__create_table_with_clust__insert], [tempdb__create_table_with_nonclust__insert],
				[tempdb__create_table__insert__add_clust], [tempdb__create_table__insert__add_nonclust]
--into #TestCase01_Serial_Summary
from (  select *
		from #t_results_c1 as c1
		--
		union all
		--
		select *
		from #t_results_c2 as c2 
	) up
pivot
(
  avg(avg_duration)
  for scenario in([tempdb__create_table__insert__add_clust], [tempdb__create_table__insert__add_nonclust], [tempdb__create_table_with_nonclust__insert], [sandbox__create_table_with_nonclust__insert], [tempdb__create_table_with_clust__insert], [sandbox__create_table__insert__add_clust], [sandbox__create_table__insert__add_nonclust], [sandbox__create_table_with_clust__insert])
) pvt
order by row_count;




/* create temp table for parallel result */
select '*.mdf' as [TestCase], scenario, row_count, concurrency, duration
into #t_results_parallel_c1
from [dbo].[commandlog_stage_testing_TestCase01] as c1
where concurrency <> 1
order by scenario, row_count

select '*.ndf' as [TestCase], scenario, row_count, concurrency, duration
into #t_results_parallel_c2
from [dbo].[commandlog_stage_testing_TestCase02] as c1
where concurrency <> 1
order by scenario, row_count

select *
from #t_results_parallel_c1
union all
select *
from #t_results_parallel_c2



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
	from #t_results_parallel_c1
	union all
	select *
	from #t_results_parallel_c2
) up
pivot
(
  avg(duration)
  for scenario in([tempdb__create_table__insert__add_clust], [tempdb__create_table__insert__add_nonclust], [tempdb__create_table_with_nonclust__insert], [sandbox__create_table_with_nonclust__insert], [tempdb__create_table_with_clust__insert], [sandbox__create_table__insert__add_clust], [sandbox__create_table__insert__add_nonclust], [sandbox__create_table_with_clust__insert])
) pvt
order by row_count, concurrency;
