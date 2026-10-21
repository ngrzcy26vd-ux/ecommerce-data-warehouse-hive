-- ADS 应用层 · 用户价值分层（价值的「秤」）
-- 口径声明：见 docs/ads_w10_w11_metrics.md 声明六
--   ① 金额口径 = 仅已完成（取 dws.dws_user.paid_amount，即已完成订单金额总计）
--   ② 固定阈值：高价值 ≥1000 / 中价值 ≥300 / 低价值 >0 / 未消费 =0，边界带等号归高档（包前不包后）
--   ③ 新用户 = 注册日距地平线（数据集最大订单日期）≤ 7 天，优先级最高
--        → CASE WHEN 顺序即优先级：先判 new_user，再判金额档，防新客误判成 low_value
--   ④ 地平线与留存表同一口钟（都取 dwd.dwd_order 最大订单日期）
--   ⑤ value_tier 码值字典：new_user / high_value / mid_value / low_value / zero_paid
-- 本质是「贴标签」而非「聚合」：一行一个用户，不 GROUP BY（聚合不可逆，分层要保留每个用户）
-- 来源表：dws.dws_user（已完成金额 + 注册日）+ dwd.dwd_order（地平线）

DROP TABLE IF EXISTS ads.ads_user_segment;
CREATE TABLE ads.ads_user_segment (
    user_id          INT,
    user_name        STRING,
    paid_amount      DECIMAL(12,2),
    reg_days         INT,
    value_tier       STRING
)
STORED AS ORC;

WITH horizon AS (
    SELECT MAX(order_date) AS horizon
    FROM dwd.dwd_order
)
INSERT OVERWRITE TABLE ads.ads_user_segment
SELECT
    u.user_id,
    u.user_name,
    u.paid_amount,
    DATEDIFF(h.horizon, u.register_date)                                  AS reg_days,
    CASE
        WHEN DATEDIFF(h.horizon, u.register_date) <= 7
             THEN 'new_user'
        WHEN u.paid_amount >= 1000
             THEN 'high_value'
        WHEN u.paid_amount >= 300 AND u.paid_amount < 1000
             THEN 'mid_value'
        WHEN u.paid_amount > 0 AND u.paid_amount < 300
             THEN 'low_value'
        WHEN u.paid_amount = 0
             THEN 'zero_paid'
        ELSE 'low_value'
    END                                                                  AS value_tier
FROM dws.dws_user u
CROSS JOIN horizon h;
