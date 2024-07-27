use StackOverflow

select	schema_name(o.schema_id)+'.'+o.name as ObjectName, sp.stats_id, st.name, sp.last_updated, sp.rows, 
		sp.rows_sampled, sp.steps, sp.unfiltered_rows, sp.modification_counter
		,convert(numeric(20,0),SQRT(sp.rows * 1000)) as SqrtFormula
		,case when convert(numeric(20,0),SQRT(sp.rows * 1000)) >= sp.modification_counter then 1 else 0 end as _Ola_IndexOptimize
from sys.stats as st
cross apply sys.dm_db_stats_properties(st.object_id, st.stats_id) as sp
join sys.objects o on o.object_id = st.object_id
where o.is_ms_shipped = 0
--and OBJECT_NAME(st.object_id) IN ('')
go