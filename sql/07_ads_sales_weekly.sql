-- ADS 周 GMV 指标表：粒度 = 一周（ISO 周，周一为起点）
-- week_id 用 CONCAT + LPAD 构造，补零让字符串排序等价于时间排序（W08 < W31）
-- YEAR + WEEKOFYEAR 两列一起 GROUP BY，防止跨年周碰撞
CREATE TABLE IF NOT EXISTS ads.ads_sales_weekly (
    week_id           STRING,
    order_cnt         INT,
    total_amount      DECIMAL(12,2),
    paid_order_cnt    INT,
    paid_total_amount DECIMAL(12,2)
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',';

INSERT OVERWRITE TABLE ads.ads_sales_weekly
SELECT
    CONCAT(CAST(YEAR(order_date) AS STRING), '-W',
           LPAD(CAST(WEEKOFYEAR(order_date) AS STRING), 2, '0')) AS week_id,
    COUNT(*)                                                     AS order_cnt,
    SUM(amount)                                                  AS total_amount,
    SUM(CASE WHEN status = '已完成' THEN 1 ELSE 0 END)           AS paid_order_cnt,
    SUM(CASE WHEN status = '已完成' THEN amount ELSE 0 END)      AS paid_total_amount
FROM dwd.dwd_order
GROUP BY YEAR(order_date), WEEKOFYEAR(order_date);
