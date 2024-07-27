CREATE DATABASE PlanError
GO

USE PlanError
GO

CREATE TABLE designation_mst
(
id INT PRIMARY KEY IDENTITY (1,1),
varDesignation NVARCHAR (200),
varDesignationCode NVARCHAR (100),
chrActive CHAR (1)
)
GO

INSERT INTO designation_mst
SELECT 'Director','101','Y'
UNION ALL
SELECT 'Branch Manager','102','Y'
UNION ALL
SELECT 'ManagerR','103','Y'
UNION ALL
SELECT 'ManagerG','104','Y'
UNION ALL
SELECT 'ManagerT','105','Y'
UNION ALL
SELECT 'TeamLeader','106','Y'
UNION ALL
SELECT 'Sr','107','Y'
UNION ALL
SELECT 'Jr','108','Y'
GO

CREATE TABLE Employee_MST
(
id INT IDENTITY (1,1),
varEmpName VARCHAR(200),
varEmail VARCHAR(20),
fk_desiGlcode INT,
fk_empGlcode INT,
chrActive CHAR(1)
)
GO

INSERT INTO Employee_MST
SELECT 'Emp1','test1@gmail.com',1,0,'Y'

INSERT INTO Employee_MST
SELECT 'Emp2','test2@gmail.com',2,1,'Y'

INSERT INTO Employee_MST
SELECT 'Emp3','test3@gmail.com',3,2,'Y'

INSERT INTO Employee_MST
SELECT 'Emp4','test4@gmail.com',4,3,'Y'

INSERT INTO Employee_MST
SELECT 'Emp5','test5@gmail.com',5,4,'Y'

INSERT INTO Employee_MST
SELECT 'Emp6','test6@gmail.com',6,5,'Y'

INSERT INTO Employee_MST
SELECT 'Emp7','test7@gmail.com',7,6,'Y'

INSERT INTO Employee_MST
SELECT 'Emp8','test8@gmail.com',8,7,'Y'
GO

insert into Employee_MST
select 'EMP' +  CAST(MAX(ID) + ROW_NUMBER() OVER(ORDER BY MAX(ID))  AS VARCHAR(200)),
'test' +  CAST(MAX(ID) + ROW_NUMBER() OVER(ORDER BY MAX(ID))  AS VARCHAR(200)) + '@gmail.com',8,7,'Y'
FROM Employee_MST
go 5000

CREATE view get_employee
AS
	SELECT em.* FROM Employee_MST EM
	INNER JOIN designation_mst DM ON DM.id = EM.fk_desiGlcode
	AND DM.varDesignation = 'jr'
	AND DM.chrActive = 'y'
	where em.fk_empGlcode in
	(select em1.id FROM Employee_MST em1
	inner join designation_mst dm1 on dm1.id = em1.fk_desiGlcode
	AND dm1.varDesignation = 'sr'
	AND dm1.chrActive = 'y'
	and em1.fk_empGlcode in
	(select em2.id FROM Employee_MST em2
	inner join designation_mst dm2 on dm2.id = em2.fk_desiGlcode
	AND DM2.varDesignation = 'TeamLeader'
	AND DM2.chrActive = 'y'
	and em2.fk_empGlcode in
	(select em3.id FROM Employee_MST em3
	inner join designation_mst dm3 on dm3.id = em3.fk_desiGlcode
	AND dm3.varDesignation = 'ManagerT'
	AND dm3.chrActive = 'y'
	and em3.fk_empGlcode in 
	(select em4.id FROM Employee_MST em4
	inner join designation_mst dm4 on dm4.id = em4.fk_desiGlcode
	AND dm4.varDesignation = 'ManagerG'
	AND dm4.chrActive = 'y'
	and em4.fk_empGlcode IN
	(select em5.id FROM Employee_MST em5
	inner join designation_mst dm5 on dm5.id = em5.fk_desiGlcode
	AND dm5.varDesignation = 'ManagerR'
	AND dm5.chrActive = 'y'
	and em5.fk_empGlcode IN	   
	(select em6.id FROM Employee_MST em6
	inner join designation_mst dm6 on dm6.id = em6.fk_desiGlcode
	AND dm6.varDesignation = 'Branch Manager'
	AND dm6.chrActive = 'y'
	and em6.fk_empGlcode IN 
	(select em7.id FROM Employee_MST em7
	inner join designation_mst dm7 on dm7.id = em7.fk_desiGlcode
	AND dm7.varDesignation = 'Director'
	AND dm7.chrActive = 'y')))))))
	
	EXCEPT
	
	SELECT em.* FROM Employee_MST EM
	INNER JOIN designation_mst DM ON DM.id = EM.fk_desiGlcode
	AND DM.varDesignation = 'jr'
	AND DM.chrActive = 'y'
	where em.fk_empGlcode in
	(select em1.id FROM Employee_MST em1
	inner join designation_mst dm1 on dm1.id = em1.fk_desiGlcode
	AND dm1.varDesignation = 'sr'
	AND dm1.chrActive = 'y'
	and em1.fk_empGlcode in
	(select em2.id FROM Employee_MST em2
	inner join designation_mst dm2 on dm2.id = em2.fk_desiGlcode
	AND DM2.varDesignation = 'TeamLeader'
	AND DM2.chrActive = 'y'
	and em2.fk_empGlcode in
	(select em3.id FROM Employee_MST em3
	inner join designation_mst dm3 on dm3.id = em3.fk_desiGlcode
	AND dm3.varDesignation = 'ManagerT'
	AND dm3.chrActive = 'y'
	and em3.fk_empGlcode in 
	(select em4.id FROM Employee_MST em4
	inner join designation_mst dm4 on dm4.id = em4.fk_desiGlcode
	AND dm4.varDesignation = 'ManagerG'
	AND dm4.chrActive = 'y'
	and em4.fk_empGlcode IN
	(select em5.id FROM Employee_MST em5
	inner join designation_mst dm5 on dm5.id = em5.fk_desiGlcode
	AND dm5.varDesignation = 'ManagerR'
	AND dm5.chrActive = 'y'
	and em5.fk_empGlcode IN
	(select em6.id FROM Employee_MST em6
	inner join designation_mst dm6 on dm6.id = em6.fk_desiGlcode
	AND dm6.varDesignation = 'Branch Manager'
	AND dm6.chrActive = 'y'
	and em6.fk_empGlcode IN 
	(select em7.id FROM Employee_MST em7
	inner join designation_mst dm7 on dm7.id = em7.fk_desiGlcode
	AND dm7.varDesignation = 'Director'
	AND em7.varEmail = 'dp@gmail.com'
	AND dm7.chrActive = 'y'))))))) 


select *
from sys.databases d
where d.name = 'PlanError'


SELECT tt.*
FROM
(
SELECT ge.* FROM get_employee ge
CROSS APPLY get_employee gee WHERE (ISNULL(gee.fk_empGlcode,0) > 0 AND ISNULL(ge.fk_empGlcode,0) > 0 )
) tt
LEFT JOIN get_employee ggg on ggg.id = tt.id
WHERE ISNULL(ggg.fk_empGlcode,0) > 0

/*
DROP EVENT SESSION [track_8623] ON SERVER 
GO
CREATE EVENT SESSION [track_8623] ON SERVER 
ADD EVENT sqlserver.errorlog_written(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_id,sqlserver.database_name,sqlserver.server_principal_name,sqlserver.sql_text))
ADD TARGET package0.event_file(SET filename=N'D:\DataCollection\track_info\track_info.xel')
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF)
GO
*/