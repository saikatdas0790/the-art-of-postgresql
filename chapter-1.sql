-- Query 1
begin;

create table factbook (
	year int,
	date date,
	shares text,
	trades text,
	dollars text
);

copy factbook
from
	'/tmp/factbook.csv' with delimiter E '\t' null '';

alter table
	factbook alter shares type bigint using replace(shares, ',', '') :: bigint,
	alter trades type bigint using replace(trades, ',', '') :: bigint,
	alter dollars type bigint using substring(
		replace(dollars, ',', '')
		from
			2
	) :: NUMERIC;

commit;

-- Query 2
\
set
	start '2017-02-01'
select
	date,
	to_char(shares, '99G999G999G999') as shares,
	to_char(trades, '99G999G999') as trades,
	to_char(dollars, 'L99G999G999G999') as dollars
from
	factbook
where
	date >= date :'start'
	and date < date :'start' + interval '1 month'
order by
	date;

-- Query 3
prepare foo as
select
	date,
	shares,
	trades,
	dollars
from
	factbook
where
	date >= $ 1 :: date
	and date < $ 1 :: date + interval '1 month'
order by
	date;

execute foo('2010-02-01');

-- Query 4
select
	cast(calendar.entry as date) as date,
	coalesce(shares, 0) as shares,
	coalesce(trades, 0) as trades,
	to_char(coalesce(dollars, 0), 'L99G999G999G999') as dollars
from
	generate_series(
		date :'start',
		date :'start' + interval '1 month' - interval '1 day',
		interval '1 day'
	) as calendar(entry)
	left join factbook on factbook.date = calendar.entry;

-- Query 5
with computed_data as (
	select
		cast(date as date) as date,
		to_char(date, 'Dy') as day,
		coalesce(dollars, 0) as dollars,
		lag(dollars, 1) over (
			partition by extract(
				'isodow'
				from
					date
			)
			order by
				date
		) as last_week_dollars
	from
		generate_series(
			date :'start' - interval '1 week',
			date :'start' + interval '1 month' - interval '1 day',
			interval '1 day'
		) as calendar(date)
		left join factbook using (date)
)
select
	date,
	day,
	to_char(coalesce(dollars, 0), 'L99G999G999G999') as dollars,
	case
		when dollars is not null
		and dollars <> 0 then round(
			100.0 * (dollars - last_week_dollars) / dollars,
			2
		)
	end as "WoW %"
from
	computed_data
where
	date >= date :'start'
order by
	date;