-- DWS 商品级预聚合宽表：一行一个商品，非分组列用 MAX() 包住取维度属性
CREATE TABLE IF NOT EXISTS dws.dws_product (
    product_id     INT,
    product_name   STRING,
    category       STRING,
    order_cnt      INT,
    total_amount   DECIMAL(12,2),
    paid_order_cnt INT,
    paid_amount    DECIMAL(12,2)
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',';

INSERT OVERWRITE TABLE dws.dws_product
SELECT
    product_id,
    MAX(product_name)                                       AS product_name,
    MAX(category)                                           AS category,
    COUNT(*)                                                AS order_cnt,
    SUM(amount)                                             AS total_amount,
    SUM(CASE WHEN order_status = '已完成' THEN 1 ELSE 0 END) AS paid_order_cnt,
    SUM(CASE WHEN order_status = '已完成' THEN amount ELSE 0 END) AS paid_amount
FROM dwd.dwd_order_item
GROUP BY product_id;
