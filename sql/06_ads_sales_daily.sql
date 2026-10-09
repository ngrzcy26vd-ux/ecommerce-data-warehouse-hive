-- ADS 日 GMV 指标表：粒度 = 一天，直接取 dwd_order 现算（聚合不可逆，不回溯 dws_user）
CREATE TABLE IF NOT EXISTS ads.ads_sales_daily (
    dt                STRING,
    order_cnt         INT,
    total_amount      DECIMAL(12,2),
    paid_order_cnt    INT,
    paid_total_amount DECIMAL(12,2)
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',';

INSERT OVERWRITE TABLE ads.ads_sales_daily
SELECT
    DATE_FORMAT(order_date, 'yyyy-MM-dd')                        AS dt,
    COUNT(*)                                                     AS order_cnt,
    SUM(amount)                                                  AS total_amount,
    SUM(CASE WHEN status = '已完成' THEN 1 ELSE 0 END)           AS paid_order_cnt,
    SUM(CASE WHEN status = '已完成' THEN amount ELSE 0 END)      AS paid_total_amount
FROM dwd.dwd_order
GROUP BY DATE_FORMAT(order_date, 'yyyy-MM-dd');
