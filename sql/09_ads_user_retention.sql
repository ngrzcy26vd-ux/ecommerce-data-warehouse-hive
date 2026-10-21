-- ADS 应用层 · 按首单日 cohort 的留存率（时间维度的「漏」）
-- 口径声明：见 docs/ads_w10_w11_metrics.md 声明五、五·补
--   ① cohort 按首单日归属，一人只属一个 cohort（首单日是不可变事实，防归属漂移）→ 分母封盘
--   ② 宽进严出：
--        分母 cohort_cnt = 当日有「任意状态」下单行为的用户（含已退款）
--        分子 dN_cnt     = 该 cohort 内首单日后 1~N 天内（含第 N 天）有「已完成」订单的用户
--        首单当天（diff=0）不算回访
--   ③ 未观测 ≠ 零留存：窗口（首单日 + N）超出地平线（数据集最大订单日期）的格子填 NULL，不填 0
--        → CASE WHEN DATEDIFF(horizon, first_date) >= N THEN ... END，不满足则 NULL（与 d7 同构）
--   ④ 地平线随每日重跑生长，历史数字由确定性重算保证不变
--   ⑤ d1/d3/d7 嵌套：累计窗口口径下 d7 ≥ d3 ≥ d1 恒成立（满足第 7 天必然满足第 3、1 天）
-- 来源表：dwd.dwd_order（cohort 归属 + 回访判定都回明细层现算，因 dws_user 已聚合掉每日明细）

DROP TABLE IF EXISTS ads.ads_user_retention;
CREATE TABLE ads.ads_user_retention (
    cohort_date  STRING,
    cohort_cnt   INT,
    d1_cnt       INT,
    d1_rate      DOUBLE,
    d3_cnt       INT,
    d3_rate      DOUBLE,
    d7_cnt       INT,
    d7_rate      DOUBLE
)
STORED AS ORC;

WITH first_date AS (
    SELECT
        user_id,
        MIN(order_date) AS first_date
    FROM dwd.dwd_order
    GROUP BY user_id
),
horizon AS (
    SELECT MAX(order_date) AS horizon
    FROM dwd.dwd_order
),
user_flag AS (
    SELECT
        f.user_id,
        f.first_date,
        MAX(CASE WHEN o.status = '已完成'
                  AND DATEDIFF(o.order_date, f.first_date) BETWEEN 1 AND 1
                 THEN 1 ELSE 0 END) AS d1,
        MAX(CASE WHEN o.status = '已完成'
                  AND DATEDIFF(o.order_date, f.first_date) BETWEEN 1 AND 3
                 THEN 1 ELSE 0 END) AS d3,
        MAX(CASE WHEN o.status = '已完成'
                  AND DATEDIFF(o.order_date, f.first_date) BETWEEN 1 AND 7
                 THEN 1 ELSE 0 END) AS d7
    FROM first_date f
    JOIN dwd.dwd_order o
      ON f.user_id = o.user_id
    GROUP BY f.user_id, f.first_date
)
INSERT OVERWRITE TABLE ads.ads_user_retention
SELECT
    DATE_FORMAT(f.first_date, 'yyyy-MM-dd')                              AS cohort_date,
    COUNT(*)                                                             AS cohort_cnt,
    CASE WHEN DATEDIFF(h.horizon, f.first_date) >= 1
         THEN SUM(r.d1) END                                              AS d1_cnt,
    CASE WHEN DATEDIFF(h.horizon, f.first_date) >= 1
         THEN ROUND(SUM(r.d1) / COUNT(*), 4) END                         AS d1_rate,
    CASE WHEN DATEDIFF(h.horizon, f.first_date) >= 3
         THEN SUM(r.d3) END                                              AS d3_cnt,
    CASE WHEN DATEDIFF(h.horizon, f.first_date) >= 3
         THEN ROUND(SUM(r.d3) / COUNT(*), 4) END                         AS d3_rate,
    CASE WHEN DATEDIFF(h.horizon, f.first_date) >= 7
         THEN SUM(r.d7) END                                              AS d7_cnt,
    CASE WHEN DATEDIFF(h.horizon, f.first_date) >= 7
         THEN ROUND(SUM(r.d7) / COUNT(*), 4) END                         AS d7_rate
FROM first_date f
JOIN user_flag r
  ON f.user_id = r.user_id AND f.first_date = r.first_date
CROSS JOIN horizon h
GROUP BY f.first_date, h.horizon
ORDER BY f.first_date;
