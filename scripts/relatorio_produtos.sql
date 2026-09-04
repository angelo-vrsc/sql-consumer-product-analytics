/*
RELATÓRIO DE CONSUMO E DESEMPENHO DE PRODUTOS

Descrição: Query para consumo derivada das tabelas 'fact_sales' e 'dim_products.
           Consolida os principais KPIs de produto (recência, ciclo de vida,
           volume de pedidos, ticket médio e receita mensal) e aplica regras
           de negócio para segmentação de desempenho dos produtos.
*/


DROP VIEW IF EXISTS gold.relatorio_produtos;

CREATE VIEW gold.relatorio_produtos AS

-- CTE base

WITH base_query AS (
    SELECT
         f.order_number,
         f.order_date,
         f.customer_key,
         f.sales_amount,
         f.quantity,
         P.product_key,
         p.product_name,
         p.category,
         p.subcategory,
         p.cost
     FROM gold.fact_sales AS f
     LEFT JOIN gold.dim_products AS p
        ON f.product_key = p.product_key
     WHERE order_date IS NOT NULL
),

-- CTE agregada

product_agg AS (
SELECT
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    EXTRACT(YEAR FROM AGE(MAX(order_date), MIN(order_date))) * 12 +
        EXTRACT(MONTH FROM AGE(MAX(order_date), MIN(order_date))) AS lifespan,
    MAX(order_date) AS last_sale_date,
    COUNT(DISTINCT order_number) AS total_orders,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(sales_amount) AS total_sales,
    SUM(quantity) AS total_quantity,
    ROUND(AVG(CAST(sales_amount AS NUMERIC) / NULLIF(quantity, 0)), 1) AS avg_selling_price
FROM base_query
GROUP BY
    product_key,
    product_name,
    category,
    subcategory,
    cost
)

-- Query final

SELECT
    product_key AS key_produto,
    product_name AS nome_produto,
    category AS categoria,
    subcategory AS subcategoria,
    cost AS custo,
    last_sale_date AS data_ultima_venda,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, last_sale_date)) * 12 +
        EXTRACT(MONTH FROM AGE(CURRENT_DATE, last_sale_date)) AS recencia_em_meses,
    CASE
        WHEN total_sales > 50000 THEN 'Alto_Desempenho'
        WHEN total_sales >= 10000 THEN 'Medio_Desempenho'
        ELSE 'Baixo_Desempenho'
    END AS segmento_produto,
    lifespan AS tempo_de_vida,
    total_orders AS total_pedidos,
    total_quantity AS total_quantidade,
    total_customers AS total_clientes,
    avg_selling_price AS preco_medio_venda,
    CASE
        WHEN total_orders = 0 THEN 0
        ELSE total_sales / total_orders
    END AS ticket_medio,
    CASE
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan
    END AS receita_media_mensal
FROM product_agg
