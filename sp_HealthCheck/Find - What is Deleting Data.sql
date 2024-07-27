-- https://dba.stackexchange.com/questions/82615/passing-info-on-who-deleted-record-onto-a-delete-trigger
USE Ajay;  
GO  

CREATE TRIGGER Tgr_Delete_SalesOrderHeaderEnlarged ON dbo.SalesOrderHeaderEnlarged
FOR DELETE 
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE	@destination_table VARCHAR(4000);
	DECLARE @tableName varchar(30), 
			@userName varchar(30);
	DECLARE @Message varchar(255);
	  
	SET @destination_table = 'DBA.dbo.WhoIsActive_ResultSets';
	SET @tableName = 'dbo.SalesOrderHeaderEnlarged';  
	SET @userName = USER_NAME();  
	SELECT CONTEXT_INFO();

	EXEC DBA..sp_WhoIsActive @get_plans=1, @get_full_inner_text=1, @get_transaction_info=1, @get_task_info=2, @get_locks=1, 
						@get_avg_time=1, @get_additional_info=1,@find_block_leaders=1, @get_outer_command =1,
				@destination_table = @destination_table ;	
	
	SET @Message = 'Delete operation being performed on table '+@tableName+' using 
	Procedure: ' + object_name(@@procid) + '
	SPID: '+ cast(@@SPID as varchar)+'
';
 
	EXEC xp_logevent 60000, @Message, informational; 
END
GO