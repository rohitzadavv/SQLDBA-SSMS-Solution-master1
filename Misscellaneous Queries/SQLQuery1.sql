$dbatools_latestversion = ((Get-Module dbatools -ListAvailable | Sort-Object Version -Descending | select -First 1).Version);
Import-Module dbatools -RequiredVersion $dbatools_latestversion;
Import-Module ImportExcel, PoshRSJob -DisableNameChecking;

$InventoryArc = 'some server 01'
$InventoryDesco = 'some server 02';

# Get list of servers from Inventory
$tsql_Servers = @"
select case when Pod like '%desco%' then FriendlyName else Dataserver end as Dataserver
from dbainfra.dbo.database_server_inventory as i --with (nolock)
where IsActive = 1 and Monitor = 'Yes'
and ServerType = 'DB' and Env <> 'DR'
and Pod not like '%desco%'
"@
$result_Servers = Invoke-DbaQuery -SqlInstance $InventoryArc -Query $tsql_Servers | select -ExpandProperty Dataserver;

# Find Temportal table for Each Server
$result_Servers | Start-RSJob -Name {"Temporal_$_"} -Throttle 8 -ScriptBlock {
$ServerName = $_;
$tsql_TemporalTables = @"
set quoted_identifier off;
set nocount on;

if cast(SERVERPROPERTY('ProductMajorVersion') as int) >= 13
begin
		if OBJECT_ID('tempdb..#temporal_tables') is not null
			drop table #temporal_tables;
		create table #temporal_tables
		(	ServerName varchar(200), dbName varchar(200), temporal_table_schema varchar(100), 
			temporal_table_name varchar(200), history_table_schema varchar(100), history_table_name varchar(200),
			retention_period varchar(200)
		);

		insert #temporal_tables
		exec sp_MSforeachdb "
		use [?];
		select '$ServerName' as ServerName, db_name() as dbName, schema_name(t.schema_id) as temporal_table_schema,
			 t.name as temporal_table_name,
			schema_name(h.schema_id) as history_table_schema,
			 h.name as history_table_name,
			case when t.history_retention_period = -1 
				then 'INFINITE' 
				else cast(t.history_retention_period as varchar) + ' ' + 
					t.history_retention_period_unit_desc + 'S'
			end as retention_period
		from sys.tables t with(nolock)
			left outer join sys.tables h with (nolock)
				on t.history_table_id = h.object_id
		where t.temporal_type = 2
		order by temporal_table_schema, temporal_table_name;
		";

		select * from #temporal_tables
end
"@
Invoke-DbaQuery -SqlInstance $ServerName -Query $tsql_TemporalTables;
}
Get-RSJob | ? {$_.Name -like 'Temporal_*'} | Wait-RSJob
$Result_TemporalTables = Get-RSJob | ? {$_.Name -like 'Temporal_*' -and $_.State -eq 'Completed'} | Receive-RSJob;

#Get-RSJob | ? {$_.Name -like 'Temporal_*'} | Stop-RSJob
Get-RSJob | Remove-RSJob;
$Result_TemporalTables | ogv

#Remove-Variable Result_TemporalTables
#Remove-Variable result_Servers
#$Result_TemporalTables | Export-Excel c:\temp\TemporalTables.xlsx -WorksheetName 'TemporalTableNames'
