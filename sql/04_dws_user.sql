-- DWS 用户级预聚合宽表：一行一个用户，12 列双口径（全部订单 / 仅已完成）
-- 无分区：每次全量 INSERT OVERWRITE（幂等）
CREATE TABLE IF NOT EXISTS dws.dws_user (
    user_id          INT,
    user_name        STRING,
    city             STRING,
    register_date    DATE,
    order_cnt        INT,
    total_amount     DECIMAL(12,2),
    paid_order_cnt   INT,
    paid_amount      DECIMAL(12,2),
    first_order_date DATE,
    last_order_date  DATE,
    active_days      INT,
    avg_order_amount DECIMAL(12,2)
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',';

INSERT OVERWRITE TABLE dws.dws_user
SELECT
    u.user_id,
    u.user_name,
    u.city,
    u.register_date,
    COALESCE(o.order_cnt, 0)      AS order_cnt,
    COALESCE(o.total_amount, 0)   AS total_amount,
    COALESCE(o.paid_order_cnt, 0) AS paid_order_cnt,
    COALESCE(o.paid_amount, 0)    AS paid_amount,
    o.first_order_date,
    o.last_order_date,
    COALESCE(DATEDIFF(o.last_order_date, o.first_order_date) + 1, 0) AS active_days,
    CASE WHEN o.order_cnt > 0 THEN ROUND(o.total_amount / o.order_cnt, 2) ELSE 0 END AS avg_order_amount
FROM dwd.dwd_user u
LEFT JOIN (
    SELECT
        user_id,
        COUNT(*)                                             AS order_cnt,
        SUM(amount)                                          AS total_amount,
        SUM(CASE WHEN status = '已完成' THEN 1 ELSE 0 END)   AS paid_order_cnt,
        SUM(CASE WHEN status = '已完成' THEN amount ELSE 0 END) AS paid_amount,
        MIN(order_date)                                      AS first_order_date,
        MAX(order_date)                                      AS last_order_date
    FROM dwd.dwd_order
    GROUP BY user_id
) o ON u.user_id = o.user_id;
