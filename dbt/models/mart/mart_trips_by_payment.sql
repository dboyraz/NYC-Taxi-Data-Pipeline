-- Aggregated trips by payment type (for categorical distribution dashboard tile)
select
    payment_type_name,
    count(*) as trip_count,
    round(avg(total_amount), 2) as avg_total_amount,
    round(avg(tip_amount), 2) as avg_tip_amount,
    round(avg(trip_distance), 2) as avg_distance
from {{ ref('stg_yellow_taxi') }}
group by payment_type_name
order by trip_count desc
