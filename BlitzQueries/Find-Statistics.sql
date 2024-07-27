

SELECT sp.stats_id, 
       st.name, 
       filter_definition, 
       last_updated, 
       rows, 
       rows_sampled, 
       steps, 
       unfiltered_rows, 
       modification_counter
	   ,STUFF((SELECT  ', ' + c.name
            FROM  sys.stats_columns as sc
				left join sys.columns as c on sc.object_id = c.object_id AND c.column_id = sc.column_id  
			WHERE sc.object_id = st.object_id and sc.stats_id = st.stats_id
            ORDER BY sc.stats_column_id
        FOR XML PATH('')), 1, 1, '') AS stats_columns
FROM sys.stats AS st
     CROSS APPLY sys.dm_db_stats_properties(st.object_id, st.stats_id) AS sp
WHERE st.object_id = OBJECT_ID('reconciler.manifestation');

