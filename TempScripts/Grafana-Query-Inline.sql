SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET QUOTED_IDENTIFIER OFF
DECLARE @sql varchar(max) = "
declare @p_start_time datetime2;
declare @p_end_time datetime2;

select @p_start_time = st.local_time, @p_end_time = et.local_time 
from dbo.utc2local($__timeFrom()) as st join dbo.utc2local($__timeTo()) et on 1 = 1;

SELECT l2u.utc_time as time, instance_name as metric, cntr_value as [value]
FROM (	
		SELECT	collection_time, counter_name, cntr_value
		FROM	dbo.dm_os_performance_counters
		WHERE	( collection_time BETWEEN @p_start_time AND @p_end_time )
			AND object_name = 'SQLServer:Buffer Manager' AND counter_name = 'Page life expectancy'
		--
		UNION ALL
		--
		SELECT	collection_time, cntr_value
		FROM	dbo.dm_os_performance_counters_aggregated
		WHERE	(collection_time BETWEEN @p_start_time AND @p_end_time) 
			AND object_name = 'SQLServer:Buffer Manager' AND counter_name = 'Page life expectancy'
) AS pc
cross apply dbo.local2utc(collection_time) as l2u
order by collection_time;
"
SET QUOTED_IDENTIFIER ON
IF ('$server' = SERVERPROPERTY('ServerName'))
BEGIN
  EXEC (@sql);
END;
ELSE
BEGIN
  EXEC (@sql) AT [$server];
END;