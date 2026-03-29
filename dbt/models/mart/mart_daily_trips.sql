-- Daily trip aggregations (for time-series dashboard tile)
select
    date(pickup_datetime) as trip_date,
    count(*) as trip_count,
    round(avg(total_amount), 2) as avg_fare,
    round(sum(total_amount), 2) as total_revenue,
    round(avg(trip_distance), 2) as avg_distance,
    round(avg(passenger_count), 2) as avg_passengers
from {{ ref('stg_yellow_taxi') }}
group by trip_date
order by trip_date
