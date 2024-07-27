set statistics io on;
set statistics time on;
go

select '2020-09-09 12:00:00.0000000' as local_time, dbo.local2utc('2020-09-09 12:00:00.0000000') as utc_time;
/*
local_time						utc_time
2020-09-09 12:00:00.0000000		2020-09-09 06:30:00.0000000

2020-09-07 06:30:00.0000000
2020-09-09 06:30:00.0000000
*/

SELECT
  l2u.utc_time as time,
  page_life_expectancy = cntr_value
FROM
  dbo.dm_os_performance_counters
outer apply dbo.utc2local('2020-09-07 06:30:00.0000000') as st
outer apply dbo.utc2local('2020-09-09 06:30:00.0000000') as et
cross apply dbo.local2utc(collection_time) as l2u
WHERE (collection_time BETWEEN st.local_time AND et.local_time)
 AND [object_name] = 'SQLServer:Buffer Manager' AND counter_name = 'Page life expectancy'
/* Above query is doing Index Seek Predicate for collection_time only. No Parallelism */
go

declare @start_time datetime2, @end_time datetime2;
select	@start_time = dbo.utc2local('2020-09-07 06:30:00.0000000'), 
		@end_time = dbo.utc2local('2020-09-09 06:30:00.0000000');
SELECT
  dbo.local2utc(collection_time) as time,
  page_life_expectancy = cntr_value
FROM
  dbo.dm_os_performance_counters as opc
WHERE collection_time between @start_time and @end_time
	and object_name = 'SQLServer:Buffer Manager' AND counter_name = 'Page life expectancy';

/* Above query is doing Index Seek Predicate for collection_time only. No Parallelism */
go

declare @start_time datetime2, @end_time datetime2;
declare @sql nvarchar(max);
declare @param_definition nvarchar(500);
select	@start_time = dbo.utc2local('2020-09-07 06:30:00.0000000'), 
		@end_time = dbo.utc2local('2020-09-09 06:30:00.0000000');

set @param_definition = '@p_start_time datetime2, @p_end_time datetime2';

set @sql = '
SELECT
  dbo.local2utc(collection_time) as time,
  page_life_expectancy = cntr_value
FROM
  dbo.dm_os_performance_counters as opc
WHERE collection_time between @p_start_time and @p_end_time
	and object_name = ''SQLServer:Buffer Manager'' AND counter_name = ''Page life expectancy'';
';
exec sp_executesql @sql, @param_definition, @p_start_time = @start_time, @p_end_time = @end_time;

/* Above query is doing Index Seek Predicate for collection_time only. No Parallelism */
go


declare @start_time datetime2, @end_time datetime2;
declare @sql nvarchar(max);
declare @param_definition nvarchar(500);
select	@start_time = dbo.utc2local('2020-09-07 06:30:00.0000000'), 
		@end_time = dbo.utc2local('2020-09-09 06:30:00.0000000');

set @param_definition = '@p_start_time datetime2, @p_end_time datetime2';

set @sql = '
declare @p_start_time datetime2, @p_end_time datetime2;
set @p_start_time = '''+convert(varchar(30),@start_time,21)+'''
set @p_end_time = '''+convert(varchar(30),@end_time,21)+''';
SELECT
  dbo.local2utc(collection_time) as time,
  page_life_expectancy = cntr_value
FROM
  dbo.dm_os_performance_counters as opc
WHERE (collection_time between @p_start_time and @p_end_time)
	and object_name = ''SQLServer:Buffer Manager'' AND counter_name = ''Page life expectancy'';
'
print @sql;
exec (@sql)

/* Above query is doing Index Seek Predicate for collection_time only. No Parallelism */
go


declare @start_time datetime2, @end_time datetime2;
declare @sql nvarchar(max);
select	@start_time = dbo.utc2local('2020-09-07 06:30:00.0000000'), 
		@end_time = dbo.utc2local('2020-09-09 06:30:00.0000000');

set @sql = '
SELECT
  dbo.local2utc(collection_time) as time,
  page_life_expectancy = cntr_value
FROM
  dbo.dm_os_performance_counters as opc
WHERE (collection_time between '''+convert(varchar(30),@start_time,21)+''' and '''+convert(varchar(30),@end_time,21)+''')
	and object_name = ''SQLServer:Buffer Manager'' AND counter_name = ''Page life expectancy'';
'
print @sql;
exec (@sql)

/* Seek predicate including all key columns. Parallelism */
go

SELECT
  dbo.local2utc(collection_time) as time,
  page_life_expectancy = cntr_value
FROM
  dbo.dm_os_performance_counters as opc
WHERE (collection_time between '2020-09-07 12:00:00.0000000' and '2020-09-09 12:00:00.0000000')
	and object_name = 'SQLServer:Buffer Manager' AND counter_name = 'Page life expectancy';

/* Seek predicate including all key columns. Parallelism */
go


SELECT
  dbo.local2utc(collection_time) as time,
  page_life_expectancy = cntr_value
FROM
  dbo.dm_os_performance_counters as opc
WHERE (collection_time between dbo.utc2local('2020-09-07 06:30:00.0000000') and dbo.utc2local('2020-09-09 06:30:00.0000000'))
	and object_name = 'SQLServer:Buffer Manager' AND counter_name = 'Page life expectancy';

/* Seek predicate including all key columns. No Parallelism */
go


SELECT
  dbo.local2utc(collection_time) as time,
  page_life_expectancy = cntr_value
FROM
  dbo.dm_os_performance_counters as opc
join dbo.utc2local('2020-09-07 06:30:00.0000000') as st on opc.collection_time >= st.local_time
join dbo.utc2local('2020-09-09 06:30:00.0000000') as et on opc.collection_time <= et.local_time
WHERE object_name = 'SQLServer:Buffer Manager' AND counter_name = 'Page life expectancy';

/* Seek predicate including all key columns. No Parallelism */
go

select *
from dbo.utc2local('2020-09-07 06:30:00.0000000') as st

SELECT
  dbo.local2utc(collection_time) as time,
  page_life_expectancy = cntr_value
FROM
  dbo.dm_os_performance_counters
WHERE 1 = 1
 AND collection_time BETWEEN '2020-09-07 12:00:00.000' AND '2020-09-09 12:00:00.000'
 AND object_name = 'SQLServer:Buffer Manager' AND counter_name = 'Page life expectancy'

/* Seek predicate including all key columns. Parallelism */
go

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET QUOTED_IDENTIFIER OFF
DECLARE @sql varchar(max) = "
SELECT
  dbo.local2utc(collection_time) as time,
  page_life_expectancy = cntr_value
FROM
  dbo.dm_os_performance_counters
WHERE object_name = 'SQLServer:Buffer Manager' AND counter_name = 'Page life expectancy' 
	AND collection_time BETWEEN dbo.utc2local('2020-09-09T13:36:02Z') AND dbo.utc2local('2020-09-09T19:36:02Z')
--
union all
--
SELECT
  dbo.local2utc(collection_time) as time,
  page_life_expectancy = cntr_value
FROM
  dbo.dm_os_performance_counters_aggregated
WHERE object_name = 'SQLServer:Buffer Manager' AND counter_name = 'Page life expectancy' 
	AND collection_time BETWEEN dbo.utc2local('2020-09-09T13:36:02Z') AND dbo.utc2local('2020-09-09T19:36:02Z')
ORDER BY time asc;
"
SET QUOTED_IDENTIFIER ON
IF ('MSI' = SERVERPROPERTY('ServerName'))
BEGIN
  EXEC (@sql);
END;
ELSE
BEGIN
  EXEC (@sql) AT [MSI];
END;