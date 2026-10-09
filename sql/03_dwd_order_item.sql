-- DWD 订单明细宽表：一行一条明细，4 表 JOIN + 维度退化（用户名/商品名/类目/订单状态搬进行）
CREATE TABLE IF NOT EXISTS dwd.dwd_order_item (
    item_id      INT,
    order_id     INT,
    user_id      INT,
    user_name    STRING,
    product_id   INT,
    product_name STRING,
    category     STRING,
    quantity     INT,
    unit_price   DECIMAL(10,2),
    amount       DECIMAL(10,2),
    order_status STRING,
    order_date   DATE
)
PARTITIONED BY (dt STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',';

INSERT OVERWRITE TABLE dwd.dwd_order_item PARTITION (dt)
SELECT
    CAST(oi.item_id AS INT)                            AS item_id,
    oi.order_id,
    o.user_id,
    u.user_name,
    CAST(oi.product_id AS INT)                         AS product_id,
    TRIM(p.product_name)                               AS product_name,
    TRIM(p.category)                                   AS category,
    CAST(oi.quantity AS INT)                           AS quantity,
    CAST(oi.unit_price AS DECIMAL(10,2))               AS unit_price,
    CAST(oi.quantity * oi.unit_price AS DECIMAL(10,2)) AS amount,
    o.status                                           AS order_status,
    o.order_date,
    DATE_FORMAT(o.order_date, 'yyyy-MM-dd')            AS dt
FROM ods.ods_order_items oi
JOIN dwd.dwd_order o     ON oi.order_id = o.order_id
JOIN dwd.dwd_user u      ON o.user_id = u.user_id
JOIN ods.ods_products p  ON oi.product_id = p.product_id;
