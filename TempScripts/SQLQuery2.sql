/*
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
	
Test Case 04: audit_archive.dbo.commandlog_stage_testing_TestCase04
	-> file extention = different filegroups, sandbox, ndf
	-> start_time = '2020-08-12 17:15:00.000'
	-> end_time = '2020-08-13 00:26:05.000'
*/

-- select * from audit_archive.dbo.commandlog_stage_testing_TestCase01
-- select * from audit_archive.dbo.commandlog_stage_testing_TestCase02   
-- select * from audit_archive.dbo.commandlog_stage_testing_TestCase03
-- select * from audit_archive.dbo.commandlog_stage_testing_TestCase04

use audit_archive;

;with T_timeseries as (
select scenario, row_count, avg(duration) as duration_avg
from audit_archive.dbo.commandlog_stage_testing_TestCase01
where concurrency = 1
group by scenario, row_count
)
select GETDATE() as time,
		cast(row_count as varchar) + ' ('+scenario+') ' as metric,
		duration_avg as value
from T_timeseries
order by metric, value asc
