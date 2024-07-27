USE [master]
GO
CREATE RESOURCE POOL [BABEL] WITH(min_cpu_percent=0, 
		max_cpu_percent=100, 
		min_memory_percent=0, 
		max_memory_percent=100, 
		cap_cpu_percent=100, 
		AFFINITY SCHEDULER = (19,43 TO 44), 
		min_iops_per_volume=0, 
		max_iops_per_volume=0)
GO

USE [master]
GO
CREATE WORKLOAD GROUP [BABEL] WITH(group_max_requests=0, 
		importance=High, 
		request_max_cpu_time_sec=0, 
		request_max_memory_grant_percent=25, 
		request_memory_grant_timeout_sec=0, 
		max_dop=2) USING [BABEL]
GO




CREATE FUNCTION [dbo].[RG_Classifier_function_ro_latest]() RETURNS sysname 
WITH SCHEMABINDING
AS
BEGIN

    DECLARE @workload_group sysname

    IF (lower(APP_NAME())  like '%facebook%')
        SET @workload_group = 'FACEBOOK'

    IF (lower(APP_NAME())  like '%enerhyd%')
        SET @workload_group = 'ENERGY'

    IF (lower(APP_NAME())  like '%engytrd%')
        SET @workload_group = 'ENERGY'

    IF (lower(APP_NAME())  like '%babel%')
        SET @workload_group = 'BABEL'


	IF 
		(
 			lower(APP_NAME()) like '%excel gufi addin%' 
		-- OR	lower(APP_NAME()) like '%intraday_pnl%' 
		)

		SET @workload_group = 'MACRO'


    IF (
	
			LOWER(ORIGINAL_LOGIN()) IN ('sa','lab\SQLServices','sqlmon','nt authority\system','nt authority\network service') 
		OR 	LOWER(ORIGINAL_LOGIN()) LIKE N'lab\%[_]sa%' OR LOWER(ORIGINAL_LOGIN()) LIKE 'lab\sqlrepl%' 
		)
       
	   SET @workload_group = 'SQLADMIN'


    IF (@workload_group IS NULL)
        SET @workload_group = 'REST'

RETURN @workload_group

END;
