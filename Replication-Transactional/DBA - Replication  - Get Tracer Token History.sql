use master;
go

set nocount on;
set quoted_identifier on;

declare @c_publication varchar(200);
declare @c_publication_id int;
declare @c_dbName varchar(200);
declare @c_publisher_commit datetime;
declare @c_is_processed bit;
declare @c_tracer_id bigint;
declare @oldest_pending_publisher_commit datetime;
declare @tsqlString nvarchar(4000);

-- Find oldest tracer token yet to be processed in DBA table
select @oldest_pending_publisher_commit = dateadd(second,-5,min(publisher_commit))
from DBA..Repl_TracerToken_Header h where h.is_processed = 0;

-- Find all tracer token history since oldest pending tracer token 
if object_id('tempdb..#MStracer_tokens') is not null
	drop table #MStracer_tokens;
select d.tracer_id, d.publication_id, a.publication, d.publisher_commit, d.distributor_commit
		,a.name as agent_name, s.subscriber_commit, srv.name as subscriber, a.publisher_db, a.subscriber_db
into #MStracer_tokens
from DistributionServer.distribution.dbo.MStracer_tokens as d with (nolock)
inner join DistributionServer.distribution.dbo.MStracer_history as s with (nolock)
on s.parent_tracer_id = d.tracer_id
inner join DistributionServer.distribution.dbo.MSdistribution_agents as a with (nolock)
on a.id = s.agent_id
inner join DistributionServer.distribution.dbo.MSpublications as p with (nolock)
on p.publication = a.publication and p.publication_id = d.publication_id
inner join DistributionServer.master.sys.servers as srv on srv.server_id = a.subscriber_id
where d.publisher_commit >= @oldest_pending_publisher_commit;

--	select * from #MStracer_tokens
--	select * from DBA..Repl_TracerToken_Header where is_processed = 0

begin tran
	--	Insert processed tokens in History Table
	insert DBA..[Repl_TracerToken_History]
	(publication, publisher_commit, distributor_commit, subscriber, subscriber_db, subscriber_commit
	)
	select h.publication, h.publisher_commit, h.distributor_commit, h.subscriber, h.subscriber_db, h.subscriber_commit
	from #MStracer_tokens as h
	join DBA..Repl_TracerToken_Header as b
	on b.publication = h.publication 
	and b.tracer_id = h.tracer_id
	where b.is_processed = 0
	and h.subscriber_commit is not null;

	--	Update process flag for processed tokens in History Table
	update b
	set is_processed = 1
	from #MStracer_tokens as h
	join DBA..Repl_TracerToken_Header as b
	on b.publication = h.publication 
	and b.tracer_id = h.tracer_id
	where b.is_processed = 0
	and h.subscriber_commit is not null;
commit tran
-- select * from DBA..[Repl_TracerToken_History]

--	Update process flag for lost tokens
;with t_Repl_TracerToken_Lastest_Processed as (
	select publication, max(publisher_commit) as last_publisher_commit 
	from DBA..Repl_TracerToken_Header where is_processed = 1 group by publication
)
update h
set is_processed = 1
--select h.*
from DBA..Repl_TracerToken_Header as h
inner join t_Repl_TracerToken_Lastest_Processed as l
on l.publication = h.publication and h.publisher_commit < l.last_publisher_commit
where h.is_processed = 0

--	select * from DBA..[Repl_TracerToken_History]

/*
use DBA
go

--drop table [dbo].[Repl_TracerToken_History]

CREATE TABLE [dbo].[Repl_TracerToken_History](
	[publication] [sysname] NOT NULL,
	[publisher_commit] [datetime] NOT NULL,
	[distributor_commit] [datetime] NOT NULL,
	[distributor_latency] AS datediff(minute,publisher_commit,distributor_commit),
	[subscriber] [sysname] NOT NULL,
	[subscriber_db] [sysname] NOT NULL,
	[subscriber_commit] [datetime] NOT NULL,
	[subscriber_latency] AS datediff(minute,distributor_commit,subscriber_commit),
	[overall_latency] AS datediff(minute,publisher_commit,subscriber_commit),
	[collection_time] [datetime] NOT NULL DEFAULT getdate()
)
GO

CREATE CLUSTERED INDEX [CI_Repl_TracerToken_History] ON [dbo].[Repl_TracerToken_History]
(
	[collection_time] ASC,
	[publication] ASC
)
GO

CREATE NONCLUSTERED INDEX [NCI_Repl_TracerToken_History] ON [dbo].[Repl_TracerToken_History]
(
	[publication] ASC,
	[publisher_commit] ASC
)
go
*/