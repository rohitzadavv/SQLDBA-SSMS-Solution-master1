EXEC tempdb..sp_BlitzCache @Help = 1
EXEC tempdb..sp_BlitzCache @ExpertMode = 1, @ExportToExcel = 1

--	https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit#common-sp_blitzcache-parameters
EXEC master..sp_BlitzCache @Top = 50, @SortOrder = 'Reads' -- logical reads when PAGEIOLATCH_SH is most prominent wait type
EXEC master..sp_BlitzCache @Top = 50, @SortOrder = 'CPU' -- logical reads when PAGEIOLATCH_SH is most prominent wait type
EXEC master..sp_BlitzCache @Top = 50, @SortOrder = 'writes' -- logical reads when PAGEIOLATCH_SH is most prominent wait type
EXEC master..sp_BlitzCache @Top = 50, @SortOrder = 'memory grant' -- logical reads when PAGEIOLATCH_SH is most prominent wait type

--	Analyze using Procedure Name
exec master..sp_BlitzCache @StoredProcName = 'usp_rm_get_source_logo_gaps_Ajay'
exec master..sp_BlitzCache @StoredProcName = 'usp_rm_get_source_logo_gaps'

--	Analyze using Query Hash in case SQL Code is not procedure
exec tempdb..sp_BlitzCache @OnlyQueryHashes = '0x998533A642130191'

/*
USP_Program_DuplicateCheck 
USP_Program_IntegratedSearch_ProgramCPR   
USP_Get_Program_DeepLoad 
usp_schres_autofill_control
*/
