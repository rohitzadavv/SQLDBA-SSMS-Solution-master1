EXEC sp_WhoIsActive @get_outer_command = 1, @get_task_info=2 --,@get_avg_time=1,
					--,@find_block_leaders=1 , @get_additional_info=1
					--,@get_transaction_info=1 , @get_task_info=2, @get_additional_info=1, 	
					--,@get_full_inner_text=1
					--,@get_locks=1
					--,@get_plans=1
					--,@sort_order = '[CPU] DESC'					
					--,@filter_type = 'login' ,@filter = 'CORP\dwivedaj_sa'
					--,@filter_type = 'program' ,@filter = 'ODBC|risktrd|risk_master_write_prod|/proj/risk/adhocRuns/Risk_26520_24.py'

					--,@filter_type = 'database' ,@filter = 'security_master'
					--,@sort_order = '[reads] desc'

--kill 814 with statusonly
EXEC sp_WhoIsActive @get_outer_command = 1, @get_task_info=2, @get_locks=1
					
/*
EXEC sp_WhoIsActive @filter_type = 'login' ,@filter = 'CORP\dwivedaj_sa'
					,@output_column_list = '[session_id][percent_complete][sql_text][login_name][wait_info][blocking_session_id][start_time]'

EXEC sp_WhoIsActive @filter_type = 'session' ,@filter = '174'
					,@output_column_list = '[session_id][percent_complete][sql_text][login_name][wait_info][blocking_session_id][start_time]'

--	EXEC sp_WhoIsActive @destination_table = 'audit_archive.dbo.WhoIsActive_ResultSets'

*/

--	exec sp_WhoIsActive @help = 1