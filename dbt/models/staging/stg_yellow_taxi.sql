with source as (
    select * from {{ source('nyc_taxi', 'yellow_taxi') }}
),

cleaned as (
    select
        VendorID as vendor_id,
        tpep_pickup_datetime as pickup_datetime,
        tpep_dropoff_datetime as dropoff_datetime,
        passenger_count,
        trip_distance,
        RatecodeID as ratecode_id,
        store_and_fwd_flag,
        PULocationID as pickup_location_id,
        DOLocationID as dropoff_location_id,
        payment_type as payment_type_id,
        case payment_type
            when 1 then 'Credit Card'
            when 2 then 'Cash'
            when 3 then 'No Charge'
            when 4 then 'Dispute'
            when 5 then 'Unknown'
            else 'Other'
        end as payment_type_name,
        fare_amount,
        extra,
        mta_tax,
        tip_amount,
        tolls_amount,
        improvement_surcharge,
        total_amount,
        congestion_surcharge,
        airport_fee
    from source
    where tpep_pickup_datetime between '2024-01-01' and '2024-12-31'
      and fare_amount > 0
      and trip_distance > 0
)

select * from cleaned
