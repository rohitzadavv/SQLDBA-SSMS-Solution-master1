USE master;

CREATE SERVER AUDIT audit_dba
TO FILE
(
 FILEPATH = 'E:\audit',
 MAXSIZE = 5120 MB,
 MAX_ROLLOVER_FILES=4,
 RESERVE_DISK_SPACE = OFF
)
WITH (QUEUE_DELAY = 5000)
GO
ALTER SERVER AUDIT audit_dba WITH( STATE = ON)
GO

USE facebook
go
create database audit specification audit_dba
for server audit audit_dba
add (SELECT, INSERT, UPDATE, DELETE ON dbo.some_table by public),
add (SELECT, INSERT, UPDATE, DELETE ON dbo.some_table by public)
WITH (STATE = ON)