-- Perfmon

SELECT  [ComputerName]
            , [CounterDateTime]
            ' + @column_list + N'
        FROM (
            SELECT CONCAT(det.[ObjectName], CHAR(92), det.[CounterName], NULLIF(CONCAT('' ('', det.InstanceName, '')''),'' ()'' )) AS PermonCounter
                    ,did.[DisplayString] AS [ComputerName]
                    ,dat.[CounterDateTime] AS [CounterDateTime]
                    ,dat.[CounterValue]
                FROM [dbo].[CounterData] AS dat
                    LEFT JOIN [dbo].[CounterDetails] AS det
                        ON det.CounterID = dat.CounterID
                    LEFT JOIN [dbo].[DisplayToID] AS did
                        ON did.[GUID] = dat.[GUID]
                WHERE det.[CounterName] LIKE CONCAT(N''%'', @CounterFilter + N''%'')
            ) AS s
        PIVOT(
            SUM([CounterValue])
        FOR [PermonCounter] IN (' + @pivot_list + ' )) AS pvt
    ORDER BY [CounterDateTime] ASC