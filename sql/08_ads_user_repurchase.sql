-- ADS 应用层 · 月度用户复购率（用户粘性）
-- 口径声明：见 docs/ads_w10_w11_metrics.md 声明三、四
--   ① 复购率采用「订单数法」：同一天多笔已完成订单也计入复购（简化口径；生产环境可换购买日法/时间窗法）
--   ② 分母 = 当月有「已完成」订单的用户（周九唯一一单 109 元已退款 → 不计入，分母 9 人而非 10 人）
--   ③ 分子 = 当月已完成订单数 ≥ 2 的用户（张三/李四/赵六，3 人）
--   ④ 按「人」不按「订单」：count(*) 数的是用户，不是订单
--   ⑤ 精度 ROUND(x, 4)
-- 结果：repurchase_rate = 3 / 9 = 0.3333
-- 来源表：dwd.dwd_order（仅已完成）

DROP TABLE IF EXISTS ads.ads_user_repurchase;
CREATE TABLE ads.ads_user_repurchase (
    stat_month       STRING,
    repurchase_rate  DOUBLE
)
STORED AS ORC;

INSERT OVERWRITE TABLE ads.ads_user_repurchase
SELECT
    '2025-08'                                                          AS stat_month,
    ROUND(SUM(CASE WHEN order_cnt >= 2 THEN 1 ELSE 0 END) / COUNT(*), 4) AS repurchase_rate
FROM (
    SELECT
        user_id,
        COUNT(*) AS order_cnt
    FROM dwd.dwd_order
    WHERE status = '已完成'
    GROUP BY user_id
) t;
