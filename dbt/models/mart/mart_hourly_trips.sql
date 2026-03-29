-- Hourly trip volume (for peak demand dashboard tile)
select
    extract(hour from pickup_datetime) as pickup_hour,
    count(*) as trip_count,
    round(avg(total_amount), 2) as avg_fare,
    round(avg(trip_distance), 2) as avg_distance
from {{ ref('stg_yellow_taxi') }}
group by pickup_hour
order by pickup_hour
