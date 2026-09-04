/*
RELATÓRIO DE CONSUMO E PERFIL DE CLIENTES (CUSTOMER ANALYTICS)

Descrição: Query para consumo derivada das tabelas 'fact_sales' e 'dim_customers'.
           Consolida o perfil demográfico e os hábitos de compra dos clientes,
           aplicando regras de negócio para agrupamento por faixa etária,
           segmentação de valor (VIP, Regular, Novo) e cálculo de KPIs vitais
           (recência, tempo de vida, ticket médio e gasto médio mensal).
*/

DROP VIEW IF EXISTS gold.relatorio_clientes;

CREATE VIEW gold.relatorio_clientes AS

-- CTE base

WITH base_query AS (
    SELECT
        f.order_number,
        f.product_key,
        f.order_date,
        f.sales_amount,
        f.quantity,
        c.customer_key,
        c.customer_number,
        c.first_name,
        c.last_name,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.birthdate)) AS age,
        c.birthdate
    FROM gold.fact_sales AS f
    LEFT JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
)

-- CTE agregada

, customer_agg AS (
    SELECT
        customer_key,
        customer_number,
        customer_name,
        age,
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT product_key) AS total_products,
        MAX(order_date) AS last_order_date,
        EXTRACT(YEAR FROM AGE(MAX(order_date), MIN(order_date))) * 12 +
            EXTRACT(MONTH FROM AGE(MAX(order_date), MIN(order_date))) AS lifespan
    FROM base_query
    GROUP BY
        customer_key,
        customer_number,
        customer_name,
        age
)

-- Query final

SELECT
    customer_key AS key_cliente,
    customer_number AS numero_cliente,
    customer_name AS nome_cliente,
    age AS idade,
    CASE
        WHEN age < 20 THEN 'Abaixo de 20'
        WHEN age BETWEEN 20 AND 29 THEN '20-29'
        WHEN age BETWEEN 30 AND 39 THEN '30-39'
        WHEN age BETWEEN 40 AND 49 THEN '40-49'
        ELSE '50 acima '
    END AS faixa_etaria,
    CASE
        WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'Novo'
    END AS segmento_cliente,
    last_order_date AS ultimo_pedido,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, last_order_date)) * 12 +
        EXTRACT(MONTH FROM AGE(CURRENT_DATE, last_order_date)) AS recencia,
    total_orders AS total_pedidos,
    total_sales AS total_vendas,
    total_quantity AS total_quantidade,
    total_products AS total_produtos,
    lifespan AS tempo_de_vida,
    CASE
        WHEN total_orders = 0 THEN 0
        ELSE total_sales / total_orders
    END AS ticket_medio,
    CASE
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan
    END AS gasto_medio_mensal
FROM customer_agg
