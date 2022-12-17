/* This Database contains 8 tables.

 1) Customers:    Contains customer data; 'customerNumber' is the 'primary key'; 'salesRepEmployeeNumber' is the 'foreign key';
       		      Relationship with 'orders' and 'payments' tables on 'customerNumber'; 
				  Relationship with 'employees' table on 'salesRepEmployeeNumber'
					
 2) Employees:    Contains all employee information; 'employeeNumber' is the 'primary key'; 'officeCode' is the 'foreign key';
				  Relationship with 'offices' table on 'officeCode'; Relationship with 'customers' table on 'employeeNumber';
				  Self-relationship between 'employeeNumber' and 'reportsTo'
   
 3) Offices:      Contains sales office information; 'officeCode' is the 'primary key'; 
				  Relationship with 'employees' table on 'officeCode'
   
 4) Orders:       Contains customers' sales orders; 'orderNumber' is the 'primary key'; 'customerNumber' is the 'foreign key';
				  Relationship with 'customers' table on 'customerNumber'; 
				  Relationship with 'orderdetails' table on 'orderNumber'
   
 5) OrderDetails: Contains sales order line for each sales order; 'orderNumber' and 'productCode' are 'primary key';
                  'orderNumber' is also foreign key; Relationship with 'orders' table on 'orderNumber';
				  Relationship with 'products' table on 'productCode'
   
 6) Payments:     Contains customers' payment records; 'customerNumber' and 'checkNumber' are 'primary key';
                  'customerNumber' is also foreign key; Relationship with 'customers' table on 'customerNumber'
   
 7) Products:     Contains a list of scale model cars; 'productCode' is the 'primary key'; 'productLine' is the 'foreign key';
  				  Relationship 'orderdetails' table on 'productCode'; Relationship with 'productlines' table on 'productLine'
   
 8) ProductLines: Contains a list of product line categories; 'productLine' is the 'primary key';
				  Relationship with 'products' table on 'productLine'
*/

-- Query1. Summarising the database
SELECT 'Customers' AS TableName, 13  AS NumAttributes , COUNT(*) AS NumRows
FROM customers

UNION ALL

SELECT 'Products' AS TableName,9 AS NumAttributes, COUNT(*) AS NumRows
FROM products

UNION ALL

SELECT 'ProductLines' AS TableName, 4 AS NumAttributes, COUNT(*) AS NumRows
FROM productlines

UNION ALL

SELECT 'Orders' AS TableName, 4 AS NumAttributes, COUNT(*) AS NumRows
FROM orders

UNION ALL

SELECT 'OrderDetails' AS TableName, 4 AS NumAttributes, COUNT(*) AS NumRows
FROM orderdetails

UNION ALL

SELECT 'Payments' AS TableName, 4 AS NumAttributes, COUNT(*) AS NumRows
FROM payments

UNION ALL

SELECT 'Employees' AS TableName, 4 AS NumAttributes, COUNT(*) AS NumRows
FROM employees

UNION ALL

SELECT 'Offices' AS TableName, 4 AS NumAttributes, COUNT(*) AS NumRows
FROM offices


-- Query2. Which Products Should We Order More of or Less of?
-- This question refers to inventory reports, including low stock and product performance. This will optimize the supply and the user experience by preventing the best-selling products from going out-of-stock.

--The low stock represents the quantity of each product sold divided by the quantity of product in stock. We can consider the ten lowest rates. These will be the top ten products that are (almost) out-of-stock.

--The product performance represents the sum of sales per product.

--Priority products for restocking are those with high product performance that are on the brink of being out of stock.

-- Methodology - Find the top 10 low_stock products then find the prformance of each product and sort the result in descending order.

with low_stock_table as(
select od.productCode , round((sum(quantityOrdered)*1.0)/quantityInStock , 2) as low_stock FROM
orderdetails od 
join products p 
on od.productCode = p.productCode
group by 1
order by low_stock 
limit 10) 

select productCode, sum(quantityOrdered*priceEach) as prod_perf
from orderdetails 
where productCode in (select productCode from low_stock_table)
group by productCode
order by prod_perf DESC


-- Query3. How Should We Match Marketing and Communication Strategies to Customer Behavior?
--This involves categorizing customers: finding the VIP (very important person) customers and those who are less engaged.

--VIP customers bring in the most profit for the store.

--Less-engaged customers bring in less profit.

--For example, we could organize some events to drive loyalty for the VIPs and launch a campaign for the less engaged.

with profit_per_cust_table as (
select o.customerNumber , round(sum(quantityOrdered*(priceEach-buyPrice)),2) as profit 
from products p
join orderdetails od 
on od.productCode = p.productCode
join orders o 
on o.orderNumber = od.orderNumber
where o.status = 'Shipped'
group by 1)
,
vip_cust as (
select c.customerName ,c.city, c.country, pt.profit from profit_per_cust_table pt 
join customers c
on pt.customerNumber = c.customerNumber
order by profit desc 
limit 10)
,
less_engaged_cust as (
select c.customerName ,c.city, c.country, pt.profit from profit_per_cust_table pt 
join customers c
on pt.customerNumber = c.customerNumber
order by profit asc 
limit 10)

select * from vip_cust
union ALL
select * from less_engaged_cust


-- Query4. How Much Can We Spend on Acquiring New Customers?
--First find the number of new customers arriving each month. That way we can check if it's worth spending money on acquiring new customers

WITH 
payment_with_year_month_table AS (
SELECT *, strftime('%Y%m', paymentDate) AS year_month
  FROM payments p
),

customers_by_month_table AS (
SELECT p.year_month, COUNT(*) AS number_of_customers, SUM(p.amount) AS total
  FROM payment_with_year_month_table p
 GROUP BY p.year_month), 

 
new_customers_table as(
select p1.year_month, count(*) new_customers, sum(p1.amount) as new_total
from payment_with_year_month_table p1 
where p1.customerNumber not in (select p2.customerNumber from payment_with_year_month_table p2 WHERE
									p1.year_month > p2.year_month)
group by p1.year_month),

merged_table as (
select nct.* , cmt.number_of_customers, cmt.total from new_customers_table nct
join  customers_by_month_table cmt
on cmt.year_month = nct.year_month)

select year_month , round(new_customers*100/number_of_customers,2) as new_cust_ratio , 
					round(new_total*100/total,2) as new_cust_amt_ratio
from merged_table

--As you can see, the number of clients has been decreasing since 2003, and in 2004, we had the lowest values. The year 2005, which is present in the database as well, isn't present in the table above, this means that the store has not had any new customers since September of 2004. This means it makes sense to spend money acquiring new customers.

--To determine how much money we can spend acquiring new customers, we can compute the Customer Lifetime Value (LTV), which represents the average amount of money a customer generates. We can then determine how much we can spend on marketing.

with rev_per_cust_table as(
select customerNumber , sum(quantityOrdered*(priceEach-buyPrice)) as revenue 
from orders o 
join orderdetails od 
on o.orderNumber = od.orderNumber
join products p 
on od.productCode = p.productCode
group by customerNumber)

select avg(revenue) as ltv
from rev_per_cust_table

--LTV tells us how much profit an average customer generates during their lifetime with our store. We can use it to predict our future profit. So, if we get ten new customers next month, we'll earn 390,395 dollars, and we can decide based on this prediction how much we can spend on acquiring new customers.







