-- ADS 应用层 · 用户下单→完成漏斗转化（流程维度的「漏」）
-- 口径声明：见 docs/ads_w10_w11_metrics.md 声明七
--   ① 步骤与为什么只有两步：下单（宽进）→ 已完成（严出）；仅两步 = 数据资产限制（无浏览/加购埋点），接入点击流可扩展五级
--   ② 分母 order_users = 任意状态（含已取消/已退款）下过单的用户
--   ③ 分子 finish_users = 有 ≥1 笔已完成订单的用户，按「人」不按「订单」（MAX 发旗：一人一面，一人多单只算一次）
--   ④ 顺序性免费：分子 ⊂ 分母，天然满足，不判序
--   ⑤ 时间窗 = 全 horizon 累计（2025-08-01 ~ 2025-08-11），全表一口钟
--   ⑥ lost_users = 下过单但「从未」有已完成订单的用户（MIN 一票否决：全 0 才算从没完成）
--        收牌三规则：SUM 数票 / MAX 问「有没有过」/ MIN 问「是不是从没」
--        ⚠️ 不能用 MAX(CASE WHEN 完成 THEN 0 ELSE 1 END) —— 那问的是「有过没完成」(∃¬)，会冤杀王五（一完成一取消）
-- 结果：10 / 9 / 0.9 / 1（漏的 1 个是退款大单周九）
-- 来源表：dwd.dwd_order（按 user_id GROUP BY 收牌）

DROP TABLE IF EXISTS ads.ads_funnel_user;
CREATE TABLE ads.ads_funnel_user (
    order_users  INT,
    finish_users INT,
    conv_rate    DOUBLE,
    lost_users   INT
)
STORED AS ORC;

INSERT OVERWRITE TABLE ads.ads_funnel_user
SELECT
    COUNT(*)                                                     AS order_users,
    SUM(t.finish_users)                                          AS finish_users,
    ROUND(SUM(t.finish_users) / COUNT(*), 4)                     AS conv_rate,
    SUM(t.lost_users)                                            AS lost_users
FROM (
    SELECT
        user_id,
        MAX(CASE WHEN status = '已完成' THEN 1 ELSE 0 END)       AS finish_users,
        MIN(CASE WHEN status = '已完成' THEN 0 ELSE 1 END)       AS lost_users
    FROM dwd.dwd_order
    GROUP BY user_id
) t;
