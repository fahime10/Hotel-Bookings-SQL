USE hotelbookingsdb;

-- Necessary early transformations ----------------------------
UPDATE hotel_bookings 
SET agent = NULL 
WHERE agent = 'NULL'; 

ALTER TABLE hotel_bookings 
ALTER COLUMN agent INT; 

UPDATE hotel_bookings 
SET children = NULL 
WHERE children = 'NULL' OR children = 'NA'; 

ALTER TABLE hotel_bookings 
ALTER COLUMN children INT;
---------------------------------------------------------------

SELECT COUNT(*) AS total_bookings FROM hotel_bookings;

SELECT TOP 20 * FROM hotel_bookings;

SELECT hotel, COUNT(*) AS bookings
FROM hotel_bookings
GROUP BY hotel;

SELECT is_canceled, hotel, COUNT(*) AS total
FROM hotel_bookings
GROUP BY is_canceled, hotel
ORDER BY is_canceled;

----------------------------------------------------------
WITH bookings_with_date AS (
	SELECT 
		is_canceled, 
		hotel, 
		DATEFROMPARTS(
			arrival_date_year, 
			CASE arrival_date_month
                WHEN 'January' THEN 1
                WHEN 'February' THEN 2
                WHEN 'March' THEN 3
                WHEN 'April' THEN 4
                WHEN 'May' THEN 5
                WHEN 'June' THEN 6
                WHEN 'July' THEN 7
                WHEN 'August' THEN 8
                WHEN 'September' THEN 9
                WHEN 'October' THEN 10
                WHEN 'November' THEN 11
                WHEN 'December' THEN 12
            END,
			arrival_date_day_of_month) AS arrival_date
	FROM hotel_bookings
)

SELECT 
	is_canceled, 
	hotel, 
	arrival_date,
	COUNT(*) AS total
FROM bookings_with_date
GROUP BY is_canceled, hotel, arrival_date
ORDER BY is_canceled;

SELECT DISTINCT customer_type FROM hotel_bookings;

SELECT DISTINCT market_segment FROM hotel_bookings;
--------------------------------------------------------

-- Task 1: Cancellation rate by customer type, market segment and lead time
SELECT 
	customer_type,
	market_segment,
	CASE
		WHEN lead_time <= 7 THEN '0-7 days'
		WHEN lead_time <= 30 THEN '8-30 days'
		WHEN lead_time <= 90 THEN '31-90 days'
		ELSE '91+ days'
	END AS lead_time_bucket,
	COUNT(*) total_bookings,
	SUM(CASE WHEN is_canceled = 1 THEN 1 ELSE 0 END) AS canceled_bookings,
	CAST(
		SUM(CASE WHEN is_canceled = 1 THEN 1 else 0 END) * 1.0 / COUNT(*) AS DECIMAL(5, 2)
	) AS cancellation_rate
FROM hotel_bookings
GROUP BY
	customer_type,
	market_segment,
	CASE
		WHEN lead_time <= 7 THEN '0-7 days'
		WHEN lead_time <= 30 THEN '8-30 days'
		WHEN lead_time <= 90 THEN '31-90 days'
		ELSE '91+ days'
	END
HAVING COUNT(*) >= 100
ORDER BY cancellation_rate DESC;
---------------------------------------------------------------------

-- Task 2: Revenue maximization -------------------------------------
SELECT 
	hotel, 
	CAST(AVG(adr) AS DECIMAL(10, 2)) AS avg_adr_in_euros,
	CAST(AVG(adr *(stays_in_weekend_nights + stays_in_week_nights)) AS DECIMAL(10, 2)) AS avg_estimated_booking_value_in_euros
FROM hotel_bookings
WHERE is_canceled = 0 AND adr > 0
GROUP BY hotel;

SELECT
	hotel,
	market_segment,
	CAST(AVG(adr) AS DECIMAL(10, 2)) AS avg_adr_in_euros,
	CAST(AVG(adr * (stays_in_weekend_nights + stays_in_week_nights)) AS DECIMAL(10, 2)) AS avg_estimated_booking_value_in_euros,
	COUNT(*) AS total_bookings
FROM hotel_bookings
WHERE is_canceled = 0 AND adr > 0
GROUP BY 
	hotel, 
	market_segment
HAVING COUNT(*) >= 100
ORDER BY 
	hotel, 
	avg_estimated_booking_value_in_euros;
----------------------------
SELECT 
	hotel,
	arrival_date_month,
	CAST(AVG(adr) AS DECIMAL(10, 2)) AS avg_adr,
	CAST(AVG(adr * (stays_in_weekend_nights + stays_in_week_nights)) AS DECIMAL(10, 2)) AS avg_estimated_booking_value_in_euros,
	COUNT(*) AS total_bookings
FROM hotel_bookings
WHERE is_canceled = 0 AND adr > 0
GROUP BY 
	hotel, 
	arrival_date_month
ORDER BY 
	hotel, 
	avg_estimated_booking_value_in_euros;

WITH booking_value_base AS (
	SELECT
		hotel,
		market_segment,
		arrival_date_month,
		CAST(adr * (stays_in_weekend_nights + stays_in_week_nights) AS DECIMAL(10, 2)) AS estimated_booking_value_in_euros
	FROM hotel_bookings
	WHERE is_canceled = 0 AND adr > 0
),

segment_month_performance AS (
	SELECT
		hotel,
		market_segment,
		arrival_date_month,
		COUNT(*) AS total_bookings,
		AVG(estimated_booking_value_in_euros) AS avg_estimated_booking_value_in_euros
	FROM booking_value_base
	GROUP BY
		hotel,
		market_segment,
		arrival_date_month
),

hotel_baseline AS (
	SELECT
		hotel,
		AVG(estimated_booking_value_in_euros) AS hotel_avg_booking_value
	FROM booking_value_base
	GROUP BY hotel
)

SELECT 
	s.hotel,
	s.market_segment,
	s.arrival_date_month,
	s.total_bookings,
	CAST(s.avg_estimated_booking_value_in_euros AS DECIMAL(10, 2)) AS avg_estimated_booking_value_in_euros,
	CAST(h.hotel_avg_booking_value AS DECIMAL(10, 2)) AS hotel_avg_booking_value_in_euros,
	CAST((s.avg_estimated_booking_value_in_euros - h.hotel_avg_booking_value) / h.hotel_avg_booking_value AS DECIMAL(10, 2)) AS relative_performance_vs_hotel_avg
FROM segment_month_performance s
JOIN hotel_baseline h
ON s.hotel = h.hotel
ORDER BY relative_performance_vs_hotel_avg;

--- Complementary segment is not shown at the top of the results in this query -------
WITH booking_value_base AS (
	SELECT
		hotel,
		market_segment,
		arrival_date_month,
		CAST(adr * (stays_in_weekend_nights + stays_in_week_nights) AS DECIMAL(10, 2)) AS estimated_booking_value_in_euros
	FROM hotel_bookings
	WHERE is_canceled = 0 AND adr > 0
),

segment_month_performance AS (
	SELECT
		hotel,
		market_segment,
		arrival_date_month,
		COUNT(*) AS total_bookings,
		AVG(estimated_booking_value_in_euros) AS avg_estimated_booking_value_in_euros
	FROM booking_value_base
	GROUP BY
		hotel,
		market_segment,
		arrival_date_month
),

hotel_baseline AS (
	SELECT
		hotel,
		AVG(estimated_booking_value_in_euros) AS hotel_avg_booking_value
	FROM booking_value_base
	GROUP BY hotel
)

SELECT 
	s.hotel,
	s.market_segment,
	s.arrival_date_month,
	s.total_bookings,
	CAST(s.avg_estimated_booking_value_in_euros AS DECIMAL(10, 2)) AS avg_estimated_booking_value_in_euros,
	CAST(h.hotel_avg_booking_value AS DECIMAL(10, 2)) AS hotel_avg_booking_value_in_euros,
	CAST((s.avg_estimated_booking_value_in_euros - h.hotel_avg_booking_value) / h.hotel_avg_booking_value AS DECIMAL(10, 2)) AS relative_performance_vs_hotel_avg
FROM segment_month_performance s
JOIN hotel_baseline h
ON s.hotel = h.hotel
ORDER BY relative_performance_vs_hotel_avg DESC;
-----------------------------------------------------

-- Task 3: Booking trends ----------------------------
WITH monthly_trends AS (
	SELECT 
		hotel,
		arrival_date_month,
		CASE arrival_date_month	
			WHEN 'January' THEN 1
            WHEN 'February' THEN 2
            WHEN 'March' THEN 3
            WHEN 'April' THEN 4
            WHEN 'May' THEN 5
            WHEN 'June' THEN 6
            WHEN 'July' THEN 7
            WHEN 'August' THEN 8
            WHEN 'September' THEN 9
            WHEN 'October' THEN 10
            WHEN 'November' THEN 11
            WHEN 'December' THEN 12
		END AS month_num,
		COUNT(*) AS total_bookings,
		SUM(CASE WHEN is_canceled = 1 THEN 1 ELSE 0 END) AS canceled_bookings,
		CAST(SUM(CASE WHEN is_canceled = 1 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS DECIMAL(10, 2)) AS cancellation_rate,
		AVG(CASE WHEN is_canceled = 0 AND adr > 0 THEN adr END) AS avg_adr,
		AVG(CASE 
				WHEN is_canceled = 0 AND adr > 0 
				THEN adr * (stays_in_weekend_nights + stays_in_week_nights) 
			END
			) AS avg_estimated_booking_value
	FROM hotel_bookings
	GROUP BY hotel, arrival_date_month
)

SELECT
	hotel,
	arrival_date_month,
	total_bookings,
	canceled_bookings,
	cancellation_rate,
	CAST(avg_adr AS DECIMAL(10, 2)) AS avg_adr_in_euros,
	CAST(avg_estimated_booking_value AS DECIMAL(10, 2)) AS avg_estimated_booking_value_in_euros
FROM monthly_trends
ORDER BY hotel, month_num;

WITH monthly_trends AS (
	SELECT 
		hotel,
		arrival_date_month,
		CASE arrival_date_month	
			WHEN 'January' THEN 1
            WHEN 'February' THEN 2
            WHEN 'March' THEN 3
            WHEN 'April' THEN 4
            WHEN 'May' THEN 5
            WHEN 'June' THEN 6
            WHEN 'July' THEN 7
            WHEN 'August' THEN 8
            WHEN 'September' THEN 9
            WHEN 'October' THEN 10
            WHEN 'November' THEN 11
            WHEN 'December' THEN 12
		END AS month_num,
		COUNT(*) AS total_bookings,
		SUM(CASE WHEN is_canceled = 1 THEN 1 ELSE 0 END) AS canceled_bookings,
		CAST(SUM(CASE WHEN is_canceled = 1 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS DECIMAL(10, 2)) AS cancellation_rate,
		AVG(CASE WHEN is_canceled = 0 AND adr > 0 THEN adr END) AS avg_adr,
		AVG(CASE 
				WHEN is_canceled = 0 AND adr > 0 
				THEN adr * (stays_in_weekend_nights + stays_in_week_nights) 
			END
			) AS avg_estimated_booking_value
	FROM hotel_bookings
	GROUP BY hotel, arrival_date_month
)

SELECT 
	hotel,
	arrival_date_month,
	total_bookings,
	RANK() OVER (PARTITION BY hotel ORDER BY total_bookings DESC) AS demand_rank
FROM monthly_trends
WHERE total_bookings >= 100
ORDER BY hotel, demand_rank;
--------------------------------------------