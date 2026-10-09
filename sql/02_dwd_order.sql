-- DWD 订单事实表：一行一笔订单，清洗 + 去重 + 按下单日期动态分区
CREATE TABLE IF NOT EXISTS dwd.dwd_order (
    order_id    INT,
    user_id     INT,
    status      STRING,
    amount      DECIMAL(10,2),
    order_date  DATE
)
PARTITIONED BY (dt STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',';

INSERT OVERWRITE TABLE dwd.dwd_order PARTITION (dt)
SELECT
    CAST(order_id AS INT)         AS order_id,
    CAST(user_id AS INT)          AS user_id,
    TRIM(status)                  AS status,
    CAST(amount AS DECIMAL(10,2)) AS amount,
    CAST(order_date AS DATE)      AS order_date,
    DATE_FORMAT(CAST(order_date AS DATE), 'yyyy-MM-dd') AS dt
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_date DESC) AS rn
    FROM ods.ods_orders
) t
WHERE rn = 1;
