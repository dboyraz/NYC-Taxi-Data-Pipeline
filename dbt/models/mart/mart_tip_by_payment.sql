-- Average tip percentage by payment type (for tipping behavior dashboard tile)
select
    payment_type_name,
    count(*) as trip_count,
    round(avg(tip_amount), 2) as avg_tip_amount,
    round(avg(case when fare_amount > 0 then tip_amount / fare_amount * 100 end), 2) as avg_tip_percentage
from {{ ref('stg_yellow_taxi') }}
group by payment_type_name
order by avg_tip_percentage desc
