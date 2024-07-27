use StackOverflow
go

create or alter procedure rpt.usp_Top_500_answerers
as
begin
	-- https://data.stackexchange.com/stackoverflow/query/952/top-500-answerers-on-the-site
	-- Top 500 answerers on the site
	/*
	A list of the top 500 users with the highest average answer score excluding community wiki / closed posts or users with less than 10 answers
	*/
	SELECT 
		TOP 500
		Users.Id as [User Link],
		Count(Posts.Id) AS Answers,
		CAST(AVG(CAST(Score AS float)) as numeric(6,2)) AS [Average Answer Score]
	FROM
		Posts
	  INNER JOIN
		Users ON Users.Id = OwnerUserId
	WHERE 
		PostTypeId = 2 and CommunityOwnedDate is null and ClosedDate is null
	GROUP BY
		Users.Id, DisplayName
	HAVING
		Count(Posts.Id) > 10
	ORDER BY
		[Average Answer Score] DESC
end
go


exec rpt.usp_Top_500_answerers
go