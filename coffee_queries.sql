SELECT * FROM city;
SELECT * FROM products;
SELECT * FROM customers;
SELECT * FROM sales;

-- Report and  Data Analysis

-- 1. Coffe consumers count
-- How many people in each city are estimated to cosume coffee, given that 25% of the population does?
SELECT 
    city_name,
	ROUND((population * 0.25)/1000000,2) as coffee_consumer_in_millions,
	city_rank
FROM city
ORDER BY 2 DESC

-- 2. Total revenue from coffee sales
SELECT 
    SUM(total) as total_revenue
FROM sales  
WHERE
    EXTRACT(YEAR FROM sale_date) = 2023
	AND
	EXTRACT(quarter FROM sale_date) = 4

-- 3. in each city find total revenue
SELECT 
    ci.city_name,
    SUM(s.total) as total_revenue
FROM sales as s
JOIN customers as c
ON s.customer_id = c.customer_id
JOIN city as ci
ON ci.city_id = c.city_id
WHERE
    EXTRACT(YEAR FROM s.sale_date) = 2023
	AND
	EXTRACT(quarter FROM s.sale_date) = 4
GROUP BY 1
ORDER BY 2 DESC

--4. sales count for each product
-- How many units of each coffee products have said?
SELECT 
   p.product_name,
   COUNT(s.sale_id) as total_order
FROM products as p
LEFT JOIN
sales as s
ON s.product_id = p.product_id
GROUP BY 1
ORDER BY 2 DESC 

-- 5.Average sales amount per city
-- What is the average sales amount per customer in each city
SELECT 
    ci.city_name,
	SUM(s.total) as total_revenue,
	COUNT(DISTINCT s.customer_id) as total_cx,
	ROUND(
	       SUM(s.total)::numeric/
		   COUNT(DISTINCT s.customer_id)::numeric
		   ,2) as avg_sale_pr_cx
FROM city as ci
JOIN
customers as c
ON ci.city_id = c.city_id
JOIN
sales as s 
ON c.customer_id = s.customer_id
GROUP BY 1
ORDER BY 2 DESC

-- 6. city population and coffee consumers
-- provide a list of cities along with their populations and estimated coffee consumers

WITH city_table as
(    SELECT 
	     city_name,
		  ROUND((population * 0.25)/1000000,2) as coffee_consumers
	FROM city
),
customer_table
AS
(   SELECT 
	   ci.city_name,
	   COUNT(DISTINCT c.customer_id) as unique_cx
	FROM sales as s
	JOIN customers as c
	ON c.customer_id = s.customer_id
	JOIN city as ci
	ON ci.city_id = c.city_id
	GROUP BY 1
)
SELECT 
    ct.city_name,
	ct.coffee_consumers,
	cit.unique_cx
FROM city_table as ct
JOIN
customer_table as cit
ON cit.city_name = ct.city_name

-- 7. Top selling products by city
-- What are the top 3 selling products in each city based on sales volume
SELECT * 
FROM
(
SELECT 
    ci.city_name,
	p.product_name,
	COUNT(s.sale_id) as total_orders,
	DENSE_RANK() OVER(PARTITION BY city_name ORDER BY COUNT(s.sale_id) DESC ) as rank
FROM sales as s
JOIN products as p
ON s.product_id = p.product_id
JOIN customers as c
ON c.customer_id = s.customer_id
JOIN city as ci
ON ci.city_id = c.city_id
GROUP BY 1, 2
) as t1
WHERE rank <= 3

-- 8. How many unique customers are there in each city who have purchased coffee products
SELECT 
    ci.city_name,
	COUNT(DISTINCT c.customer_id) as unique_cx
FROM city as ci
LEFT JOIN
customers as c
ON c.city_id = ci.city_id
JOIN sales as s
ON s.customer_id = c.customer_id
WHERE 
   s.product_id IN (1,2,3,4,5,6,7,8,9,10,11,12,13,14)
GROUP BY 1


--9. Find each city and their average sale per customer and avg rent per customer
WITH city_table
AS
(
SELECT 
     ci.city_name,
	 COUNT(DISTINCT s.customer_id) as total_cx,
	 ROUND(
	       SUM(s.total)::numeric/
		   COUNT(DISTINCT s.customer_id)::numeric
		   ,2) as avg_sale_pr_cx
FROM sales as s
JOIN
customers as c
ON s.customer_id = c.customer_id
JOIN city as ci
ON c.city_id = ci.city_id
GROUP BY 1
ORDER  BY 2 DESC
),

city_rent
AS
(
SELECT 
    city_name,
    estimated_rent
FROM city
)

SELECT 
    cr.city_name,
	cr.estimated_rent,
	ct.total_cx,
	ct.avg_sale_pr_cx,
	ROUND(cr.estimated_rent::numeric/ct.total_cx::numeric,2) as avg_rent_per_cx
FROM city_table as ct
JOIN city_rent as cr
ON ct.city_name = cr.city_name
ORDER BY 4 DESC;

-- 10. Sales growth rate: Calculate the percentage growth in sales over different time period (monthly
-- by each city
WITH 
monthly_sale
AS
(
SELECT 
   ci.city_name,
   EXTRACT(MONTH FROM sale_date) as month,
   EXTRACT(YEAR FROM sale_date) as year,
   SUM(total) as total_sale
FROM sales as s
JOIN customers as c
ON s.customer_id = c.customer_id
JOIN city as ci
ON c.city_id = ci.city_id
GROUP BY 1, 2, 3
ORDER BY 1, 3, 2
),
growth_ratio
AS
(
	SELECT 
	    city_name,
	    month,
		year,
		total_sale as cr_month_sale,
		LAG(total_sale,1) OVER(PARTITION BY city_name ORDER BY year, month) as last_month_sale
	FROM monthly_sale
)

SELECT 
   city_name,
   month,
   year,
   cr_month_sale,
   last_month_sale,
   ROUND((cr_month_sale-last_month_sale)::numeric/last_month_sale ::numeric * 100,2) as growth_ratio
FROM growth_ratio
WHERE last_month_sale IS NOT NULL

-- 11. Identify top 3 city based on highest sales,return city name, total sale,total rent,total cutomers,estimated coffee consumer
WITH city_table
AS
(
	SELECT 
	    ci.city_name,
		SUM(s.total) as total_sales,
		COUNT(DISTINCT c.customer_id) as total_cx,
		ROUND(SUM(s.total)::numeric/COUNT(DISTINCT c.customer_id)::numeric,2) as avg_sale_per_cx
	FROM sales as s
	JOIN customers as c
	ON s.customer_id = c.customer_id
	JOIN city as ci
	ON ci.city_id = c.city_id
	GROUP BY 1
	ORDER BY 2 DESC
),
city_rent 
AS
(
	SELECT 
	    city_name,
		estimated_rent,
		ROUND((population * 0.25)/1000000,2) as coffee_consumers
		FROM city
)
SELECT 
     ct.city_name,
	 ct.total_sales,
	 ct.total_cx,
	 cr.coffee_consumers,
	 cr.estimated_rent,
	 ct.avg_sale_per_cx,
	 ROUND(cr.estimated_rent::numeric/ct.total_cx::numeric,2) as avg_rent_per_cx
FROM city_table as ct
JOIN city_rent as cr
ON ct.city_name = cr.city_name
ORDER BY 2 DESC