DECLARE @Rows bigint
SET @Rows = 1000000--ABS(CHECKSUM(NEWID()))%100000000

SELECT @Rows as [Rows], SQRT(@Rows * 1000) as SqrtFormula, (20 * @Rows)/100 as [35% Formula]
--SQRT(number of rows * 1000)

