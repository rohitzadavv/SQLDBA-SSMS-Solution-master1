--	https://docs.microsoft.com/en-us/sql/relational-databases/replication/monitor/measure-latency-and-validate-connections-for-transactional-replication?view=sql-server-ver15

/*	Job Step 01 - Insert Tracker Token */
set nocount on;
set quoted_identifier on;

declare @dbName varchar(200);
declare @dbId int;
declare @tsqlString nvarchar(4000);
declare @publicationTable table (publication_id int, publication varchar(500));
declare @publication_id int;
declare @publication varchar(500);
declare @tokenID bigint;
declare @ParmDefinition nvarchar(500);

SET @ParmDefinition = N'@publication varchar(200), @tokenIdOUT int OUTPUT'; 

declare cur_Databases cursor local fast_forward for
	select d.name as dbName, d.database_id as [dbId] from sys.databases as d where is_published = 1 order by dbName; 

open cur_Databases;  
fetch next from cur_Databases into @dbName, @dbId;

while @@FETCH_STATUS = 0  
begin
	delete from @publicationTable;
	--select @dbName as [@dbName];
	set @tsqlString = null;

	set @tsqlString = 'use '+quotename(@dbName)+';
select p.pubid as publication_id, p.name as pubName  from syspublications as p where status = 1;';

	insert @publicationTable
	exec (@tsqlString);

	declare cur_Publications cursor local fast_forward for
		select publication_id, publication from @publicationTable order by publication; 

	open cur_Publications;  
	fetch next from cur_Publications into @publication_id, @publication;
	while @@FETCH_STATUS = 0  
	begin
		set @tsqlString = 'use '+quotename(@dbName)+';
-- Insert a new tracer token in the publication database.
EXEC sys.sp_posttracertoken @publication = @publication, @tracer_token_id = @tokenIdOUT OUTPUT;';
		EXECUTE sp_executesql @tsqlString, @ParmDefinition, @publication = @publication, @tokenIdOUT=@tokenID OUTPUT;  
		
		insert DBA..Repl_TracerToken_Header (publication_id, publication,dbName,tracer_id,publisher_commit)
		values (@publication_id,@publication,@dbName,@tokenID,getdate());

		--print 'Tracer token '+cast(@tokenID as varchar(30))+' inserted for '+@publication+' publication @ '+cast(getdate() as varchar(30))+'.';
		fetch next from cur_Publications into @publication_id, @publication;
	end
	close cur_Publications;  
	deallocate cur_Publications;

	fetch next from cur_Databases into @dbName, @dbId;
end
close cur_Databases;  
deallocate cur_Databases;
go

/*
use DBA;
--drop table Repl_TracerToken_Header
create table Repl_TracerToken_Header
(	ID bigint identity(1,1) not null primary key, publication_id int not null, publisher_commit datetime not null, 
	publication varchar(200) not null, dbName varchar(200) not null, tracer_id bigint not null, is_processed bit not null default 0
);
create nonclustered index NCI_Repl_TracerToken_Header_ID
	on dbo.Repl_TracerToken_Header (publication) where is_processed = 0;
go

select * from Repl_TracerToken_Header
*/