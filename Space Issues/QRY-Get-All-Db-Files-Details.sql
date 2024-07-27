set nocount on;

declare @dbname varchar(200);
declare @sql varchar(max);
if object_id('tempdb..#Dbs') is not null
	drop table #Dbs;
create table #Dbs (DatabaseName varchar(200), LogicalName varchar(200), type_desc varchar(20), physical_name varchar(500), size_MB numeric(20,2), size_GB numeric(20,2));

declare cur_db cursor forward_only for
	select name from sys.databases d where database_id > 4;
open cur_db
fetch next from cur_db into @dbname;

while @@FETCH_STATUS = 0
begin

	set @sql = '
use ['+@dbname+'];
--	Find used/free space in Database Files
select DB_NAME() as DatabaseName, f.name as LogicalName, f.type_desc, f.physical_name, (f.size*8.0)/1024 as size_MB, (f.size*8.0)/1024/1024 as size_GB
from sys.database_files f
order by f.data_space_id;
'
	insert #Dbs
	execute (@sql)

	fetch next from cur_db into @dbname;
end
close cur_db;
deallocate cur_db;

select sysutcdatetime() as CollectionTime_UTC, '$ServerInstance' as ServerInstance, *
from #Dbs;