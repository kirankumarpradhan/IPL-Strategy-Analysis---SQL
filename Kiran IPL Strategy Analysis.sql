drop view if exists all_data;
create view all_data as
select 
	bb.Match_Id,
    m.Season_Id,
    m.Venue_Id,
    bb.Innings_No,
    bb.Over_Id,
    bb.Ball_Id,
    bb.Team_Batting,
    bb.Team_Bowling,
    bb.Runs_Scored,
    bb.Striker,
    wt.Player_Out,
    bb.Bowler
from ball_by_ball bb
left join wicket_taken wt
on 
	bb.Match_Id = wt.Match_Id and
    bb.Innings_No = wt.Innings_No and
    bb.Over_Id = wt.Over_Id and
    bb.Ball_Id = wt.Ball_Id
join matches m 
on m.Match_Id = bb.Match_Id;
select * from all_data;

-- OBJECTIVE ANSWERS

-- 1) List the different dtypes of columns in table “ball_by_ball” (using information schema)
select 
	Column_name,
    Data_type
from information_schema.columns
where 
	table_name = "ball_by_ball" and 
    table_schema = "ipl";

-- 2) What is the total number of runs scored in 1st season by RCB (bonus: also include the extra runs using the extra runs table)
select 
	sum(ad.Runs_Scored + case when er.Extra_Runs is not null then er.Extra_Runs else 0 end) as Total_Runs_Scored_RCB_1st_Season
from all_data ad
left join extra_runs er
on 
	ad.Match_Id = er.Match_Id and
	ad.Over_Id = er.Over_Id and
    ad.Ball_Id = er.Ball_Id and
    ad.Innings_No = er.Innings_No
where 
	Season_Id = (select min(Season_ID) from all_data) and
    ad.Team_Batting = 2;

-- 3) How many players were more than the age of 25 during season 2014?
with Player_Age_Details_2014_Season as (select 
	p.Player_Name,
    p.DOB,
    timestampdiff(year, p.DOB, m.Match_Date) as Age
from matches m 
join player_match pm 
on m.Match_Id = pm.Match_Id
join player p 
on pm.Player_Id = p.Player_Id
where 
	year(m.Match_Date) = 2014 and
	timestampdiff(year, p.DOB, '2014-12-31') > 25)
    
select count(Distinct Player_Name) as Number_of_Players 
from Player_Age_Details_2014_Season;

-- 4) How many matches did RCB win in 2013? 
select  
	count(Match_Id) as Number_of_Matches_Won_by_RCB_in_2013
from matches
where 
	year(Match_Date) = 2013 and 
    Match_Winner = 2; 
    
-- 5) List the top 10 players according to their strike rate in the last 4 seasons
select
	ad.Striker as Player_Id,
    P.Player_Name,
    round((sum(ad.Runs_Scored)/count(ad.Ball_Id)) * 100, 2) as Strike_Rate
from all_data ad
join player p 
on ad.Striker = p.Player_Id
group by ad.Striker, P.Player_Name
having count(ad.Ball_Id) > 100
order by Strike_Rate desc
limit 10;

-- 6) What are the average runs scored by each batsman considering all the seasons?
with Total_Runs_Scored_All_Matches as (select
	ad.Striker as Player_Id,
    p.Player_Name,
    sum(ad.Runs_Scored) as Total_Runs_Scored,
    count(distinct concat(ad.Match_Id, " ", ad.Innings_No)) as Total_Matches_Played
from all_data ad
join player p 
on ad.Striker = p.Player_Id
group by ad.Striker, p.Player_Name)

select
	Player_Id,
    Player_Name,
    Total_runs_Scored,
    Total_Matches_Played,
	Round((Total_Runs_Scored / Total_Matches_Played), 2) as Average_Runs
from Total_Runs_Scored_All_Matches
order by Average_Runs desc;

-- 7) What are the average wickets taken by each bowler considering all the seasons?
select
	ad.Bowler,
    p.Player_Name,
    count(Distinct ad.Match_Id) as Total_Matches_Played,
    sum(case when ad.player_Out is not null then 1 else 0 end) as Total_Wickets_Taken,
    round(sum(case when ad.player_Out is not null then 1 else 0 end)/count(Distinct ad.Match_Id), 2) as Average_Wickets_Taken
from all_data ad
join player p 
on ad.Bowler = p.Player_Id
group by ad.Bowler, p.Player_Name
order by Average_Wickets_Taken desc; 

-- 8a) List all the players who have average runs scored greater than the overall average 
select 
	ad.Striker,
    p.Player_Name,
    sum(ad.Runs_Scored) as Total_Runs,
    Count(ad.Player_Out) as cntOfMatches,
    (sum(ad.Runs_Scored) / Count(ad.Player_Out)) as Batting_Average
from all_data ad
join Player p 
on ad.Striker = p.Player_Id
group by ad.Striker, p.Player_Name
having Batting_Average > (select sum(Runs_Scored) / Count(Player_Out) from all_data)
order by Batting_Average desc
limit 20;

-- 8b) List all the players who have taken wickets greater than the overall average
select
	ad.Bowler,
    p.Player_Name,
    sum(ad.Runs_Scored) as Runs_Conceded,
    count(ad.Player_Out) as Total_Wickets_Taken,
	(sum(ad.Runs_Scored) /count(ad.Player_Out)) as Bowling_Average
from all_data ad 
join Player p 
on ad.Bowler = p.Player_Id
group by ad.Bowler, p.Player_Name
having Bowling_Average > (select sum(Runs_Scored) /count(Player_Out) from all_data)
order by Bowling_Average desc;

-- 9)Create a table rcb_record table that shows the wins and losses of RCB in an individual venue.
Drop Table If Exists rcb_record;
create table if not exists rcb_record as 	
with Wins_and_Lost_Data as 
(select
	m.Venue_Id,
    v.Venue_Name,
    sum(case when m.Match_Winner = 2 then 1 else 0 end) as Matches_Won,
    sum(case when m.Match_Winner != 2 then 1 else 0 end) as Matches_Lost
from matches m 
join venue v 
on m.Venue_Id = v.Venue_Id
where m.Team_1 = 2 or m.Team_2 = 2
group by m.Venue_Id, v.Venue_Name)

select 
	*,
    (Matches_Won + Matches_Lost) as Total_Matches,
	(Matches_Won / (Matches_Won + Matches_Lost)) * 100 as Winning_Percentage,
    (Matches_Lost / (Matches_Won + Matches_Lost)) * 100 as Losing_Percentage
from Wins_and_Lost_Data;
select * from rcb_record;

-- 10) What is the impact of bowling style on wickets taken?
select
	bs.Bowling_skill,
    sum(case when ad.Player_Out is not null then 1 else 0 end) as Number_of_Wickets
from all_data ad
join player p 
on ad.Bowler = p.Player_Id
join bowling_style bs 
on p.Bowling_skill = bs.Bowling_Id
group by bs.Bowling_skill
order by Number_of_Wickets desc;

-- 11) Write the SQL query to provide a status of whether the performance of the team is better than the previous year's performance on the basis of the number of runs scored by the team in the season and the number of wickets taken 
with current_and_prevous_year_runs_data as
(select
	bb.Team_Batting as Team_Id,
    t.Team_Name,
    sum(case when year(m.Match_Date) = 2016 then bb.Runs_Scored else 0 end) as Current_Year_2016_Total_Runs,
    sum(case when year(m.Match_Date) = 2015 then bb.Runs_Scored else 0 end) as Previous_Year_2015_Total_Runs 
from ball_by_ball bb
join matches m 
on bb.match_Id = m.Match_Id
join team t 
on bb.Team_Batting = t.Team_Id
where year(m.Match_Date) in (2015, 2016)
group by bb.Team_Batting, t.Team_Name
order by Team_Id),

current_and_previous_year_wickets_data as
(select
	bb.Team_Bowling,
    t.Team_Name,
    sum(case when year(m.Match_Date) = 2016 and wt.Player_Out is not null then 1 else 0 end) as Current_Year_2016_Total_Wickets,
    sum(case when year(m.Match_Date) = 2015 and wt.Player_Out is not null then 1 else 0 end) as Previous_Year_2015_Total_Wickets
from ball_by_ball bb
join matches m 
on bb.Match_Id = m.Match_Id
join team t
on bb.Team_Bowling = t.Team_Id
join wicket_taken wt
on 
	wt.Match_Id = bb.Match_Id and 
	wt.Over_Id = bb.Over_Id and
    wt.Ball_Id = bb.Ball_Id and
    wt.Player_Out = bb.Striker
group by bb.Team_Bowling, t.Team_Name
order by bb.Team_Bowling)

select
	crd.Team_Id,
    crd.Team_Name,
    crd.Current_Year_2016_Total_Runs,
    crd.Previous_Year_2015_Total_Runs,
    cwd.Current_Year_2016_Total_Wickets,
    cwd.Previous_Year_2015_Total_Wickets,
    case
		when crd.Current_Year_2016_Total_Runs > crd.Previous_Year_2015_Total_Runs then "Increased"
        when crd.Current_Year_2016_Total_Runs < crd.Previous_Year_2015_Total_Runs then "Decreased"
        else "Consistent"
	end as Team_Runs_Performance,
    case
		when cwd.Current_Year_2016_Total_Wickets > cwd.Previous_Year_2015_Total_Wickets then "Increased"
        when cwd.Current_Year_2016_Total_Wickets < cwd.Previous_Year_2015_Total_Wickets then "Decreased"
        else "Consistent"
	end as Team_Wickets_Performance
from current_and_prevous_year_runs_data crd
join current_and_previous_year_wickets_data cwd
on crd.Team_Id = cwd.Team_Bowling
order by crd.Team_Id;

-- 12) Can you derive more KPIs for the team strategy?
-- a) Boundaries
select
	ad.Striker,
    p.Player_Name,
    sum(ad.Runs_Scored) as Total_Runs_Scored,
    sum(case when ad.Runs_Scored in (4,6) then ad.Runs_Scored else 0 end) as Total_Runs_From_Boundaries,
    round((sum(case when ad.Runs_Scored in (4,6) then ad.Runs_Scored else 0 end) / sum(ad.Runs_Scored))*100, 2) as Boundaries_Percentage
from all_data ad
join player p 
on ad.Striker = p.Player_Id
where ad.Season_Id between 6 and 9
group by ad.Striker, p.Player_Name
having Total_Runs_Scored > 800 and Boundaries_Percentage > 60
order by Boundaries_Percentage;

-- b) Batsmen
select
	ad.Striker,
    p.Player_Name,
    count(distinct ad.Match_Id) as Total_Matches_Played,
    sum(ad.Runs_Scored) as Total_Runs_Scored,
    sum(case when ad.Over_Id between 1 and 6 then ad.Runs_Scored else 0 end) as Power_Play_Total_Runs_Scored,
    sum(case when ad.Over_Id between 16 and 20 then ad.Runs_Scored else 0 end) as Death_Overs_Total_Runs_Scored
from all_data ad
join player p 
on ad.Striker = p.Player_Id
where ad.Season_Id between 6 and 9
group by ad.Striker, p.Player_Name
order by Total_Runs_Scored desc
limit 20;

-- c) Bowlers
select
	ad.Bowler,
    p.Player_Name,
    count(distinct ad.Match_Id) as Total_Matches_Played,
    sum(case when ad.Player_Out is not null then 1 else 0 end) as Total_Wickets_Taken,
    sum(case when ad.Over_Id between 1 and 6 and ad.Player_Out is not null then 1 else 0 end) as Wickets_Taken_in_Power_Play,
    sum(case when ad.Over_Id between 16 and 20 and ad.Player_Out is not null then 1 else 0 end) as Wickets_Taken_in_Death_Overs
from all_data ad
join player p 
on ad.Bowler = p.Player_Id
where ad.Season_Id between 6 and 9
group by ad.Bowler, p.PLayer_Name
order by Total_Wickets_Taken desc
limit 20;

-- 13) Using SQL, write a query to find out the average wickets taken by each bowler in each venue. Also, rank the gender according to the average value
with wickets_data_players_venues as
(select 
	v.Venue_Id,
    v.Venue_Name,
    p.Player_Name,
    count(wt.Player_Out) as Total_Wickets_Taken,
    count(distinct m.Match_Id) as Total_Matches_Played
from wicket_taken wt
join ball_by_ball bb
on 
	wt.Match_Id = bb. Match_Id and
    wt. Over_Id = bb.Over_Id and
    wt.Ball_Id = bb.Ball_Id and 
    wt.Innings_No = bb.Innings_No
join player p 
on bb.Bowler = p.Player_Id
join matches m 
on wt.Match_Id = m.Match_Id
join venue v 
on m.Venue_Id = v.Venue_Id
group by v.Venue_Id, v.Venue_Name, p.Player_name
having Total_Matches_Played > 10),

wickets_data_players_venues_percenatge as
(select
	*,
    round((Total_Wickets_Taken / Total_Matches_Played), 2) as Average_Wickets_Taken
from wickets_data_players_venues)

select
	*,
    dense_rank() over(order by Average_Wickets_Taken desc) as Performance_Rank
from wickets_data_players_venues_percenatge	
order by Performance_Rank;

-- 14) Which of the given players have consistently performed well in past seasons? (will you use any visualization to solve the problem)
with each_player_data as 
(select 
	ad.Striker as Player_Id,
    p.player_Name,
    sum(ad.Runs_Scored) as Total_Runs_Scored,
    sum(case when ad.Player_Out is not null then 1 else 0 end) as Total_Wickets_Taken,
    count(distinct ad.Season_Id) as Total_Seasons_Played 
from all_data ad
join player p 
on ad.Striker = p.Player_Id
group by ad.Striker, p.Player_Name
having Total_Seasons_Played > 3)

select
	Player_Id,
    Player_Name,
    round(Total_Runs_Scored / Total_Seasons_Played, 2) as Avg_Runs_Scored_Per_Season,
    round(Total_Wickets_Taken / Total_Seasons_Played, 2) as Avg_Wickets_Taken_Per_Season
from each_player_data
order by Avg_Runs_Scored_Per_Season desc
limit 15;

-- 15) Are there players whose performance is more suited to specific venues or conditions? (how would you present this using charts?) 
-- a) Batsmen Performance
select * from all_data;
select * from venue;
select
	ad.Striker,
    p.Player_Name,
    v.Venue_Name,
    count(distinct ad.Match_Id) as Total_Matches_Played,
    sum(ad.Runs_Scored) as Total_Runs_Scored,
    count(ad.Ball_Id) as Total_Balls_Faced,
    round((sum(ad.Runs_Scored) / count(ad.Ball_Id))*100, 2) as Strike_Rate
from all_data ad
join venue v 
on 	ad.Venue_Id = v.Venue_Id
join player p 
on ad.Striker = p.Player_Id
group by ad.Striker, v.Venue_Name, p.Player_Name
having Total_Balls_Faced > 100
order by Total_Runs_Scored desc
limit 20;

-- b) Bowlers Performance
select 
	ad.Bowler as Player_Id,
    p.Player_Name,
    v.Venue_Name,
    count(distinct ad.Match_Id) as Total_Matches_Played,
    sum(case when ad.Player_Out is not null then 1 else 0 end) as Total_Wickets_Taken,
    count(ad.Ball_Id) as Total_Balls_Bowled
from all_data ad
join venue v
on ad.Venue_Id = v.Venue_Id
join player p 
on ad.Bowler = p.Player_Id
group by ad.Bowler, v.Venue_Name, p.Player_Name
having Total_Balls_Bowled > 100
order by Total_Wickets_Taken desc
limit 20;


-- SUBJECTIVE ANSWERS

-- 1) 	How does the toss decision affect the result of the match? (which visualizations could be used to present your answer better) And is the impact limited to only specific venues?
with wins_loss_data as
(select 
	m.Venue_Id,
    v.Venue_Name,
    td.Toss_Name,
    count(distinct m.Match_Id) as Total_Matches,
    sum(case when m.Toss_Winner = m.Match_Winner then 1 else 0 end) as Total_Wins_By_Toss_Winner,
    sum(case when m.Toss_Winner != m.Match_Winner then 1 else 0 end) as Total_Wins_By_Toss_Looser
from matches m
join toss_decision td
on m.Toss_Decide = td.Toss_Id
join venue v 
on m.Venue_Id = v.Venue_Id
group by m.Venue_Id, v.Venue_Name, td.Toss_Name
having Total_Matches > 5
order by m.Venue_Id)

select 
	*,
    round((Total_Wins_By_Toss_Winner / Total_Matches) * 100, 2) as Toss_Winner_Winnig_Percentage
from wins_loss_data
order by Toss_Winner_Winnig_Percentage desc;

-- 2) Suggest some of the players who would be best fit for the team.
-- a) Suggested Bowlers
select 
	ad.Bowler,
    p.Player_Name,
    count(ad.Ball_Id) as Total_Balls_Bowled,
    sum(case when ad.Player_Out is not null then 1 else 0 end) as Total_Wickets_Taken,
    round(sum(ad.Runs_Scored) / sum(case when ad.Player_Out is not null then 1 else 0 end), 2) as Bowling_Average,
    round(sum(ad.Runs_Scored) / (count(ad.Ball_Id)/6), 2) as Economy_Rate,
    round(count(ad.Ball_Id) / sum(case when ad.Player_Out is not null then 1 else 0 end), 2) as Strike_Rate_Medium
from all_data ad
join player p 
on ad.Bowler = p.Player_Id
where ad.Season_Id between 6 and 9
group by ad.Bowler, p.Player_Name
having 
	Total_Wickets_Taken > 30 and
	Bowling_Average < 25 and
	Economy_Rate < 10 and
    Strike_Rate_Medium < 20
order by Total_Wickets_Taken desc, Bowling_Average, Economy_Rate
limit 20;

-- b) Suggested Batsmen	
select 
	ad.Striker,
	p.Player_Name,
    sum(ad.Runs_Scored) as Total_Runs_Scored,
    round(sum(ad.Runs_Scored) / sum(case when ad.Player_Out is not null then 1 else 0 end), 2) as Batting_Average,
    round((sum(ad.Runs_Scored) / count(ad.Ball_Id)) * 100, 2) as Strike_Rate
from all_data ad
join player p 
on ad.Striker = p.Player_Id
where ad.Season_Id between 6 and 9
group by ad.Striker, p.Player_Name
having 
	Total_Runs_Scored > 800 and
    Batting_Average > 30 and
	Strike_Rate > 100
order by Total_Runs_Scored desc, Batting_Average desc, Strike_Rate desc;

-- 3) What are some of the parameters that should be focused on while selecting the players?
-- a) Bowlers
select 
	ad.Bowler,
    p.Player_Name,
    count(ad.Ball_Id) as Total_Balls_Bowled,
    sum(case when ad.Player_Out is not null then 1 else 0 end) as Total_Wickets_Taken,
    round(sum(ad.Runs_Scored) / sum(case when ad.Player_Out is not null then 1 else 0 end), 2) as Bowling_Average,
    round(sum(ad.Runs_Scored) / (count(ad.Ball_Id)/6), 2) as Economy_Rate,
    round(count(ad.Ball_Id) / sum(case when ad.Player_Out is not null then 1 else 0 end), 2) as Strike_Rate_Medium
from all_data ad
join player p 
on ad.Bowler = p.Player_Id
where ad.Season_Id between 6 and 9
group by ad.Bowler, p.Player_Name
having 
	Total_Wickets_Taken > 30 and
	Bowling_Average < 25 and
	Economy_Rate < 10 and
    Strike_Rate_Medium < 20
order by Total_Wickets_Taken desc, Bowling_Average, Economy_Rate
limit 20;	

-- b) Batsmen
select 
	ad.Striker,
	p.Player_Name,
    sum(ad.Runs_Scored) as Total_Runs_Scored,
    round(sum(ad.Runs_Scored) / sum(case when ad.Player_Out is not null then 1 else 0 end), 2) as Batting_Average,
    round((sum(ad.Runs_Scored) / count(ad.Ball_Id)) * 100, 2) as Strike_Rate,
    round(sum(case when ad.Over_Id between 1 and 6 then ad.Runs_Scored else 0 end)/count(case when ad.Over_Id between 1 and 6 then ad.Ball_Id else 0 end) * 100, 2) as Power_Play_Strike_Rate,
    round(sum(case when ad.Over_Id between 16 and 20 then ad.Runs_Scored else 0 end)/count(case when ad.Over_Id between 16 and 20 then ad.Ball_Id else 0 end) * 100, 2) as Death_Over_Strike_Rate
from all_data ad
join player p 
on ad.Striker = p.Player_Id
where ad.Season_Id between 6 and 9
group by ad.Striker, p.Player_Name
having 
	Total_Runs_Scored > 800 and
    Batting_Average > 30 and
	Strike_Rate > 100
order by Total_Runs_Scored desc, Batting_Average desc, Strike_Rate desc;

-- 4) Which players offer versatility in their skills and can contribute effectively with both bat and ball?
with batting_data as
(select 
	ad.Striker as Player_Id,
    p.Player_Name,
    sum(ad.Runs_Scored) as Total_Runs_Scored,
    round((sum(ad.Runs_Scored) / count(ad.Ball_Id)) * 100, 2) as Batting_Strike_Rate
from all_data ad 
join player p 
on ad.Striker = p.Player_Id
where ad.Season_Id between 6 and 9
group by ad.Striker, p.Player_Name),

bowling_data as
(select 
	ad.Bowler as Player_Id,
    p.Player_Name,
    sum(case when ad.Player_Out is not null then 1 else 0 end) as Total_Wickets_Taken,
    round(count(ad.Ball_Id) / sum(case when ad.Player_Out is not null then 1 else 0 end), 2) as Bowling_Strike_Rate
from all_data ad
join player p 
on ad.Bowler = p.Player_Id
where ad.Season_Id between 6 and 9
group by ad.Bowler, p.Player_Name)

select
	t1.Player_Id,
    t1.Player_Name,
    t1.Total_Runs_Scored,
    t1.Batting_Strike_Rate,
    t2.Total_Wickets_Taken,
    t2.Bowling_Strike_Rate
from batting_data t1
join bowling_data t2
on t1.Player_Id = t2.Player_Id
where
	t1.Batting_Strike_Rate >= 100 and
    t2.Bowling_Strike_Rate <= 40 and 
    t2.Total_Wickets_Taken >= 15
order by t1.Total_Runs_Scored desc, t2.Total_Wickets_Taken desc
limit 20;

-- 5) Are there players whose presence positively influences the morale and performance of the team?
-- a) Batsmen
select
	ad.Striker as Player_Id,
    p.Player_Name,
    sum(ad.Runs_Scored) as Total_Runs_Scored,
    sum(case when ad.Over_Id between 1 and 6 then ad.Runs_Scored else 0 end) as Power_Play_Total_Runs_Scored,
    sum(case when ad.Over_Id between 7 and 15 then ad.Runs_Scored else 0 end) as Middle_Over_Total_Runs_Scored,
    sum(case when ad.Over_Id between 16 and 20 then ad.Runs_Scored else 0 end) as Death_Over_Total_Runs_Scored
from all_data ad
join player p 
on ad.Striker = p.Player_Id
where ad.Season_Id between 6 and 9
group by ad.Striker, p.Player_Name
order by Total_Runs_Scored desc
limit 20;

-- 5b) Bowlers
select
	ad.Bowler as Player_Id,
    p.Player_Name,
    sum(case when ad.Player_Out is not null then 1 else 0 end) as Total_wickets_Taken,
    sum(case when ad.Player_Out is not null and ad.Over_Id between 1 and 6 then 1 else 0 end) as Wickets_Taken_in_Power_Play,
    sum(case when ad.Player_Out is not null and ad.Over_Id between 7 and 15 then 1 else 0 end) as Wickets_Taken_in_Middle_Overs,
    sum(case when ad.Player_Out is not null and ad.Over_Id between 16 and 20 then 1 else 0 end) as Wickets_Taken_in_Death_Overs
from all_data ad
join player p 
on ad.Bowler = p.Player_Id
where ad.Season_Id between 6 and 9
group by ad.Bowler, p.Player_Name
order by Total_Wickets_Taken desc
limit 20;

-- 6) What would you suggest to RCB before going to the mega auction? 
select
	m.Win_Type as Win_Id,
    wb.Win_Type,
    count(m.Match_Id) as Total_Matches_Played,
    sum(case when m.Match_Winner = 2 then 1 else 0 end) as Matches_Won,
    sum(case when m.Match_Winner != 2 then 1 else 0 end) as Matches_Lost
from matches m 
join win_by wb
on m.Win_Type = wb.Win_Id
where 
	m.Team_1 = 2 or m.Team_2 = 2 and
    m.Season_Id between 6 and 9 and
    m.Outcome_Type != 2
group by m.Win_Type, wb.Win_Type;

with batting_data as
(select 
	ad.Striker as Player_Id,
    p.Player_Name,
    sum(ad.Runs_Scored) as Total_Runs_Scored,
    round((sum(ad.Runs_Scored) / count(ad.Ball_Id)) * 100, 2) as Batting_Strike_Rate
from all_data ad
join player p 
on ad.Striker = p.Player_Id
where ad.Season_Id between 6 and 9
group by ad.Striker, p.Player_Name),

bowling_data as 
(select 
	ad.Bowler as Player_Id,
    p.Player_Name,
    sum(case when ad.Player_Out is not null then 1 else 0 end) as Total_Wickets_Taken,
    round(count(ad.Ball_Id) / sum(case when ad.Player_Out is not null then 1 else 0 end), 2) as Bowling_Strike_Rate
from all_data ad
join player p 
on ad.Bowler = p.Player_Id
where ad.Season_Id between 6 and 9
group by ad.Bowler, p.Player_Name)

select
	 t1.Player_Id,
     t1.Player_Name,
     t1.Total_Runs_Scored,
     t1.Batting_Strike_Rate,
     t2.Total_Wickets_Taken,
     t2.Bowling_Strike_Rate
from batting_data t1
join bowling_data t2
on t1.Player_Id = t2.Player_Id
where 
	t1.Batting_Strike_Rate >= 100 and
    t2.Total_Wickets_Taken >= 15 and
    t2.Bowling_Strike_Rate <= 40
order by t1.Total_Runs_Scored desc, t2.Total_Wickets_Taken desc
limit 20;

-- 7) What do you think could be the factors contributing to the high-scoring matches and the impact on viewership and team strategies
-- a) Venues have higher impact on viewership
select
	ad.Venue_Id,
    v.Venue_Name,
    count(distinct ad.Match_Id) as Total_Matches_Played,
    sum(ad.Runs_Scored) as Total_Runs_Scored,
    round(sum(ad.Runs_Scored) / count(distinct ad.Match_Id), 2) as Average_Runs_Per_Match
from all_data ad
join venue v 
on ad.Venue_Id = v.Venue_Id
where ad.Season_Id between 6 and 9
group by ad.Venue_Id, v.Venue_Name
having Average_Runs_Per_Match > 300
order by Total_Runs_Scored desc, Average_Runs_Per_Match desc;

-- b) Each team's power play and death over batting performances, as players play aggressively in these overs to score more runs in both cases while chasing or putting targets
select 
	t.Team_Id,
    t.Team_Name,
    sum(ad.Runs_Scored) as Total_Runs_Scored,
    sum(case when ad.Over_Id between 1 and 6 then ad.Runs_Scored else 0 end) as Total_Power_Play_Runs,
    sum(case when ad.Over_Id between 16 and 20 then ad.Runs_Scored else 0 end) as Total_Death_Over_Runs
from team t
join matches m 
on t.Team_Id = m.Team_1 or t.Team_Id = m.Team_2
join all_data ad
on m.Match_Id = ad.Match_Id and t.Team_Id = ad.Team_Batting
where ad.Season_Id between 6 and 9
group by t.Team_Id, t.Team_Name
order by t.Team_Id;

-- 8) Analyze the impact of home-ground advantage on team performance and identify strategies to maximize this advantage for RCB.
select
	case 
		when m.Venue_Id = 1 then "Home"
        else "Away"
	end as Venue_Type,
	count(distinct m.Match_Id) as Total_Matches_Played,
    sum(case when m.Match_Winner = 2 then 1 else 0 end) as Winning_Count,
    sum(case when m.Match_Winner != 2 then 1 else 0 end) as Losing_Count,
    round((sum(case when m.Match_Winner = 2 then 1 else 0 end) / count(distinct m.Match_Id)) * 100, 2) as Winning_Percentage
from matches m 
join venue v 
on m.Venue_Id = v.Venue_Id
where (m.Team_1 = 2 or m.Team_2 = 2) and m.Outcome_type != 2
group by Venue_Type
order by Winning_Percentage desc;

-- 9) Come up with a visual and analytical analysis of the RCB's past season's performance and potential reasons for them not winning a trophy.
-- Winning Percentage
select
	m.Season_Id,
    s.Season_Year,
    count(case when m.Team_1 = 2 or m.Team_2 = 2 then m.Match_Id end) as Total_Matches_Played,
	sum(case when m.Team_1 = 2 or m.Team_2 = 2 and m.Match_Winner = 2 then 1 else 0 end) as Total_Matches_Won,
    round((sum(case when m.Team_1 = 2 or m.Team_2 = 2 and m.Match_Winner = 2 then 1 else 0 end) / count(case when m.Team_1 = 2 or m.Team_2 = 2 then m.Match_Id end)) * 100, 2) as Win_Percentage
from matches m
join season s 
on m.Season_Id = s.Season_Id
where m.Season_Id between 6 and 9
group by m.Season_Id;

-- Highest Scorers
select
	ad.Striker as Player_Id,
    p.Player_Name,
    round(sum(ad.Runs_Scored) / count(distinct concat(ad.Match_Id,"_",ad.Innings_No)), 2) as Average_Runs_Scored_Per_Match
from all_data ad
join player p 
on ad.Striker = p.Player_Id
where 
	ad.Season_Id between 6 and 9 and
	ad.Team_Batting = 2
group by ad.Striker, p.Player_Name
having Average_Runs_Scored_Per_Match > 30
order by Average_Runs_Scored_Per_Match desc;

-- Highest Wicket Takers
select 
	ad.Bowler as Player_Id,
    p.Player_Name,
    round(sum(case when ad.Player_Out is not null then 1 else 0 end) / count(distinct ad.Match_Id), 2) as Average_Wickets_Taken_Per_Match
from all_data ad
join player p 
on ad.Bowler = p.Player_Id
where 
	ad.Season_Id between 6 and 9 and
    ad.Team_Bowling = 2
group by ad.Bowler, p.Player_Name
having Average_Wickets_Taken_Per_Match > 1.5
order by Average_Wickets_Taken_Per_Match desc;
