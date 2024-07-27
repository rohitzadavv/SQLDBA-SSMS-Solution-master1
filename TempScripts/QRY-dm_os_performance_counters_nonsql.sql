SET NOCOUNT ON;

DECLARE @is_test_alert bit = 0;
DECLARE @continuous_failure_count tinyint = 4;
DECLARE @failure_notification_delay_minutes int = 30;
DECLARE @operator_2_notify varchar(255) = 'DBA';
DECLARE @mail_cc varchar(2000);

-- Variables for Try/Catch Block
DECLARE	@_errorNumber int,
				@_errorSeverity int,
				@_errorState int,
				@_errorLine int,
				@_errorMessage nvarchar(4000);

BEGIN TRY
	INSERT into dbo.dm_os_performance_counters_nonsql
	(collection_time, server_name, [object_name], counter_name, instance_name, cntr_value, cntr_type, id)
	select *
	from (
	select	collection_time = p2l.local_time
			,server_name = REPLACE(MachineName,'\\','')
			,[object_name] = dtls.ObjectName
			,counter_name = dtls.CounterName
			,instance_name = dtls.InstanceName
			,cntr_value = AVG(CounterValue)
			,cntr_type = dtls.CounterType
			,id = ROW_NUMBER()OVER(PARTITION BY p2l.local_time, ObjectName, CounterName ORDER BY  InstanceName, SYSDATETIME())
	FROM dbo.CounterData as dt -- GUID, CounterID, RecordIndex
	JOIN dbo.CounterDetails as dtls ON dtls.CounterID = dt.CounterID
	OUTER APPLY dbo.perfmon2local(dt.CounterDateTime) as p2l
	GROUP BY p2l.local_time, REPLACE(MachineName,'\\',''), 
					dtls.ObjectName, dtls.CounterName, dtls.InstanceName, dtls.CounterType
	) as pc
	WHERE NOT EXISTS (SELECT * FROM dbo.dm_os_performance_counters_nonsql epc 
						WHERE epc.collection_time = pc.collection_time and epc.object_name = pc.object_name
							and epc.counter_name = pc.counter_name and epc.id = pc.id
							--and epc.instance_name = pc.instance_name
					)
			--AND p2l.local_time = '2020-09-11 08:00:35.4200000' and ObjectName = 'LogicalDisk' and CounterName = 'Current Disk Queue Length'
	ORDER BY collection_time, server_name, [object_name], counter_name;

	update [dbo].[DisplayToID]
	set RunID = 1
	where RunID = 0;
	--select 12/0
END TRY  -- Perform main logic inside Try/Catch
BEGIN CATCH
	DECLARE @_mail_to varchar(2000);
	DECLARE @_tableHTML  NVARCHAR(MAX);  
	DECLARE @_subject nvarchar(1000);
	DECLARE @_job_name nvarchar(500);
	DECLARE @_job_step_name nvarchar(500);
	DECLARE	@_job_step_id int;

	--SELECT @_job_name = name FROM msdb.dbo.sysjobs WHERE job_id = CONVERT(uniqueidentifier, $(ESCAPE_NONE(JOBID)));
	SET @_job_name = '(dba) Collect Metrics - NonSqlServer Perfmon Counters';
	--SET @_job_step_id = $(ESCAPE_NONE(STEPID));
	SET @_job_step_id = 1;
	--SELECT @_job_step_name = step_name FROM msdb.dbo.sysjobsteps where job_id = CONVERT(uniqueidentifier, $(ESCAPE_NONE(JOBID))) and step_id = @_job_step_id;
	SET @_job_step_name = 'Some Step_Name';

	SET @_subject = '[The job failed.] SQL Server Job System: '''+@_job_name+''' completed on \\'+@@SERVERNAME+'.'
	IF @is_test_alert = 1
		SET @_subject = 'TestAlert - '+@_subject;

	SELECT @_errorNumber	 = Error_Number()
				,@_errorSeverity = Error_Severity()
				,@_errorState	 = Error_State()
				,@_errorLine	 = Error_Line()
				,@_errorMessage	 = Error_Message();

	SET @_tableHTML =
		N'Sql Agent job '''+@_job_name+''' has failed for step '+CAST(@_job_step_id AS varchar)+' - '''+ @_job_step_name +''' @'+ CONVERT(nvarchar(30),getdate(),121) +'.'+
		N'<br><br>Error Number: ' + convert(varchar, @_errorNumber) + 
		N'<br>Line Number: ' + convert(varchar, @_errorLine) +
		N'<br>Error Message: <br>"' + @_errorMessage + '"' +
		N'<br><br>Kindly resolve the job failure based on above error message.';

	select @_mail_to = email_address from msdb.dbo.sysoperators where name = @operator_2_notify;

	IF 1 = 1 /* Logic for @failure_notification_delay_minutes & @continuous_failure_count */
	BEGIN
			EXEC msdb.dbo.sp_send_dbmail
							@recipients = @_mail_to,
							@copy_recipients = @mail_cc,
							--@profile_name = @@SERVERNAME,
							@subject = @_subject,
							@body = @_tableHTML,
							@body_format = 'HTML';
	END

END CATCH

IF @_errorMessage IS NOT NULL
	THROW 50000, @_errorMessage, 1;
