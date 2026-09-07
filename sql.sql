
-- [Q1] USA customers with completed orders during January through March 2024


SELECT
    cust.customer_name,
    ord.order_id,
    ord.order_date,
    ord.net_revenue
FROM customers cust
JOIN orders ord
    ON cust.customer_id = ord.customer_id
WHERE cust.country = 'USA'
  AND ord.status = 'Completed'
  AND ord.order_date >= '2024-01-01'
  AND ord.order_date < '2024-04-01'
ORDER BY ord.order_date ASC, ord.order_id ASC;


-- [Q2] Sales representatives in department 2 who never completed an order

SELECT
    emp.employee_id,
    emp.employee_name
FROM employees emp
LEFT JOIN orders ord
    ON emp.employee_id = ord.employee_id
   AND ord.status = 'Completed'
WHERE emp.department_id = 2
  AND ord.order_id IS NULL
ORDER BY emp.employee_name;


-- [Q3] Products that have no order history

SELECT
    prod.product_id,
    prod.product_name,
    prod.unit_price
FROM products prod
WHERE NOT EXISTS (
    SELECT 1
    FROM order_items item
    WHERE item.product_id = prod.product_id
)
ORDER BY prod.product_name;


-- [Q4] Employees earning more than their department's average salary

SELECT
    emp.employee_name,
    dept.department_name,
    emp.salary,
    (
        SELECT AVG(emp2.salary)
        FROM employees emp2
        WHERE emp2.department_id = emp.department_id
    ) AS department_avg_salary
FROM employees emp
JOIN departments dept
    ON emp.department_id = dept.department_id
WHERE emp.salary > (
    SELECT AVG(emp3.salary)
    FROM employees emp3
    WHERE emp3.department_id = emp.department_id
)
ORDER BY dept.department_name, emp.salary DESC;


-- [Q5] Segments generating more than $30,000 from completed orders

SELECT
    cust.segment,
    COUNT(ord.order_id) AS order_count,
    SUM(ord.net_revenue) AS total_revenue
FROM customers cust
JOIN orders ord
    ON ord.customer_id = cust.customer_id
WHERE ord.status = 'Completed'
GROUP BY cust.segment
HAVING total_revenue > 30000
ORDER BY total_revenue DESC;


-- =============================================================================
-- PART B: COMMON TABLE EXPRESSIONS & COMPLEX LOGIC
-- =============================================================================

-- [Q6] Classify customers according to their completed-order spending

WITH spending AS (
    SELECT
        c.customer_id,
        COALESCE(SUM(
            CASE
                WHEN o.status = 'Completed' THEN o.net_revenue
                ELSE 0
            END
        ), 0) AS amount_spent
    FROM customers c
    LEFT JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_id
),
classified_customers AS (
    SELECT
        customer_id,
        amount_spent,
        CASE
            WHEN amount_spent >= 20000 THEN 'High Spender'
            WHEN amount_spent >= 5000 THEN 'Mid Spender'
            ELSE 'Low Spender'
        END AS spending_group
    FROM spending
)
SELECT
    spending_group,
    COUNT(*) AS number_of_customers
FROM classified_customers
GROUP BY spending_group
ORDER BY
    CASE spending_group
        WHEN 'High Spender' THEN 1
        WHEN 'Mid Spender' THEN 2
        WHEN 'Low Spender' THEN 3
    END;


-- [Q7] Customers with at least two completed orders

SELECT
    c.customer_id,
    c.customer_name,
    MIN(o.order_date) AS first_order,
    MAX(o.order_date) AS latest_order
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
WHERE o.status = 'Completed'
GROUP BY
    c.customer_id,
    c.customer_name
HAVING COUNT(*) > 1
ORDER BY latest_order DESC;


-- [Q8] Generate January 1–10, 2024 and count orders for every date

WITH RECURSIVE calendar AS (
    SELECT CAST('2024-01-01' AS DATE) AS day_date

    UNION ALL

    SELECT DATE_ADD(day_date, INTERVAL 1 DAY)
    FROM calendar
    WHERE day_date < '2024-01-10'
)
SELECT
    cal.day_date,
    COUNT(ord.order_id) AS number_of_orders
FROM calendar cal
LEFT JOIN orders ord
    ON DATE(ord.order_date) = cal.day_date
GROUP BY cal.day_date
ORDER BY cal.day_date;


-- =============================================================================
-- PART C: RANKING WINDOW FUNCTIONS
-- =============================================================================

-- [Q9] Highest-paid employee(s) in every department

WITH salary_order AS (
    SELECT
        e.employee_id,
        e.employee_name,
        e.department_id,
        d.department_name,
        e.salary,
        DENSE_RANK() OVER (
            PARTITION BY e.department_id
            ORDER BY e.salary DESC
        ) AS salary_position
    FROM employees e
    JOIN departments d
        ON e.department_id = d.department_id
)
SELECT
    employee_id,
    employee_name,
    department_name,
    salary
FROM salary_order
WHERE salary_position = 1
ORDER BY department_name, employee_name;


-- [Q10] Select the earliest order for every customer

WITH numbered_orders AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_date,
        o.status,
        o.net_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY o.customer_id
            ORDER BY o.order_date, o.order_id
        ) AS sequence_no
    FROM orders o
)
SELECT
    order_id,
    customer_id,
    order_date,
    status,
    net_revenue
FROM numbered_orders
WHERE sequence_no = 1
ORDER BY customer_id;


-- [Q11] Place products into four price groups

SELECT
    product_name,
    unit_price,
    NTILE(4) OVER (
        ORDER BY unit_price ASC, product_name
    ) AS price_quartile
FROM products
ORDER BY unit_price ASC, product_name;


-- [Q12] Compare RANK and DENSE_RANK for product prices by category

SELECT
    p.product_name,
    c.category_name,
    p.unit_price,
    RANK() OVER (
        PARTITION BY p.category_id
        ORDER BY p.unit_price DESC
    ) AS regular_rank,
    DENSE_RANK() OVER (
        PARTITION BY p.category_id
        ORDER BY p.unit_price DESC
    ) AS dense_rank_position
FROM products p
JOIN categories c
    ON p.category_id = c.category_id
ORDER BY
    c.category_name,
    p.unit_price DESC;


-- =============================================================================
-- PART D: LAG AND LEAD
-- =============================================================================

-- [Q13] Monthly revenue and month-over-month dollar change

WITH monthly_sales AS (
    SELECT
        DATE_FORMAT(order_date, '%Y-%m-01') AS sales_month,
        SUM(net_revenue) AS revenue
    FROM orders
    WHERE status = 'Completed'
    GROUP BY DATE_FORMAT(order_date, '%Y-%m-01')
),
previous_sales AS (
    SELECT
        sales_month,
        revenue,
        LAG(revenue) OVER (
            ORDER BY sales_month
        ) AS prior_month_revenue
    FROM monthly_sales
)
SELECT
    sales_month,
    revenue,
    prior_month_revenue,
    revenue - prior_month_revenue AS revenue_growth
FROM previous_sales
ORDER BY sales_month;


-- [Q14] Number of days between a customer's successive orders

WITH order_history AS (
    SELECT
        order_id,
        customer_id,
        order_date,
        LAG(order_date) OVER (
            PARTITION BY customer_id
            ORDER BY order_date, order_id
        ) AS previous_order_date
    FROM orders
)
SELECT
    order_id,
    customer_id,
    order_date,
    DATEDIFF(order_date, previous_order_date) AS days_from_previous_order
FROM order_history
ORDER BY customer_id, order_date, order_id;


-- [Q15] Find each customer's next order date

SELECT
    order_id,
    customer_id,
    order_date,
    LEAD(order_date) OVER (
        PARTITION BY customer_id
        ORDER BY order_date, order_id
    ) AS following_order_date
FROM orders
ORDER BY customer_id, order_date, order_id;


-- =============================================================================
-- PART E: AGGREGATE WINDOW FUNCTIONS & FRAMES
-- =============================================================================

-- [Q16] Cumulative completed-order revenue

SELECT
    order_id,
    customer_id,
    order_date,
    net_revenue,
    SUM(net_revenue) OVER (
        ORDER BY order_date, order_id
        ROWS UNBOUNDED PRECEDING
    ) AS cumulative_revenue
FROM orders
WHERE status = 'Completed'
ORDER BY order_date, order_id;


-- [Q17] Daily revenue with a three-row moving average

WITH daily_sales AS (
    SELECT
        DATE(order_date) AS sales_date,
        SUM(net_revenue) AS daily_revenue
    FROM orders
    WHERE status = 'Completed'
    GROUP BY DATE(order_date)
)
SELECT
    sales_date,
    daily_revenue,
    AVG(daily_revenue) OVER (
        ORDER BY sales_date
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_average_3_days
FROM daily_sales
ORDER BY sales_date;


-- [Q18] Product revenue as a percentage of category revenue

WITH sales_by_product AS (
    SELECT
        p.product_id,
        p.product_name,
        p.category_id,
        c.category_name,
        SUM(oi.quantity * oi.unit_price) AS revenue
    FROM products p
    JOIN categories c
        ON p.category_id = c.category_id
    JOIN order_items oi
        ON p.product_id = oi.product_id
    JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.status = 'Completed'
    GROUP BY
        p.product_id,
        p.product_name,
        p.category_id,
        c.category_name
)
SELECT
    product_name,
    category_name,
    revenue AS product_revenue,
    ROUND(
        100 * revenue
        / SUM(revenue) OVER (
            PARTITION BY category_id
        ),
        2
    ) AS category_revenue_percent
FROM sales_by_product
ORDER BY category_name, product_revenue DESC;


-- [Q19] Difference between an employee's salary and their department maximum

SELECT
    e.employee_name,
    d.department_name,
    e.salary,
    MAX(e.salary) OVER (
        PARTITION BY e.department_id
    ) AS maximum_department_salary,
    MAX(e.salary) OVER (
        PARTITION BY e.department_id
    ) - e.salary AS salary_difference
FROM employees e
JOIN departments d
    ON e.department_id = d.department_id
ORDER BY
    d.department_name,
    e.salary DESC;


-- [Q20] Customers ordering in consecutive months during 2024

WITH monthly_customers AS (
    SELECT DISTINCT
        customer_id,
        DATE_FORMAT(order_date, '%Y-%m-01') AS month_start
    FROM orders
    WHERE status = 'Completed'
      AND order_date >= '2024-01-01'
      AND order_date < '2025-01-01'
),
month_comparison AS (
    SELECT
        customer_id,
        month_start,
        LEAD(month_start) OVER (
            PARTITION BY customer_id
            ORDER BY month_start
        ) AS following_month
    FROM monthly_customers
)
SELECT DISTINCT
    mc.customer_id,
    c.customer_name
FROM month_comparison mc
JOIN customers c
    ON c.customer_id = mc.customer_id
WHERE following_month = DATE_ADD(month_start, INTERVAL 1 MONTH)
ORDER BY mc.customer_id;
```
