# ADS 应用层指标口径（W10–W11）

> 配套 SQL：`sql/08_ads_user_repurchase.sql`、`09_ads_user_retention.sql`、`10_ads_user_segment.sql`、`11_ads_funnel_user.sql`
>
> 本文件是 `docs/metrics.md`（W5–W9 双口径声明 + DWS 表）的延续，专门登记四张 ADS 应用层表的口径。
> 口径原则：**口径是承诺不是描述；公式 = 跑通代码原样；字段名 = DDL 契约；文档撒谎比没文档更毒。**

---

## 口径声明

- **声明三（复购率口径）**：采用**订单数法**——同一天多笔已完成订单也算复购（简化口径，生产环境考虑购买日法/时间窗法）。分母为当月有已完成订单的用户：**9 人而非 10 人**——周九唯一一单 109 号（1599 元）已退款，未产生完成交易，不计入。
- **声明四（精度）**：`repurchase_rate` 存储保留 4 位小数（`ROUND(x, 4)`）。
- **声明五（留存口径）**：
  ① cohort 按首单日归属，一人只属一个 cohort（首单日是不可变事实，防归属漂移）；
  ② **宽进严出**——分母 = 当日有任意状态下单行为（含已退款），分子 = 首单日后 1~N 天内（**含第 N 天**）有已完成订单，首单当天不算回访；
  ③ **未观测 ≠ 零留存**：窗口（首单日 + N）超出**地平线**（数据集最大订单日期）的格子填 **NULL**，不填 0；
  ④ 地平线随每日重跑生长，历史数字由确定性重算保证不变。
- **声明五·补（d14/d30 扩展条件）**：
  1. **不建列**：目前地平线 08-11，与最早首单日 08-01 相差仅 10 天，不足 14/30——任何 cohort 都不满足行级判据，建出来是全 NULL 列，且会与「未观测」的 NULL 语义混淆；
  2. **列级触发**：地平线 `horizon ≥ 2025-08-15`（= 最早 cohort 08-01 观测满 14 天）时建 d14 列；`horizon ≥ 2025-08-31` 时建 d30 列；
  3. **行级判据**：`datediff(horizon, first_date) >= 14/30` 才出数，不满足的行保持 NULL（与 d1/d3/d7 的 NULL 同构）；
  4. 触发之前不建列、不占位。
- **声明六（分层口径）**：
  ① 金额 = 仅已完成（`dws_user.paid_amount`）；
  ② 固定阈值：高价值 ≥1000 / 中价值 ≥300 / 低价值 >0 / 未消费 =0，**边界带等号归高档**（包前不包后）；
  ③ **新用户 = 注册日距地平线 ≤7 天，优先级最高**（`CASE WHEN` 顺序 = 优先级，防新客误判）；
  ④ 地平线与留存表同一口钟；
  ⑤ `value_tier` 码值字典：`new_user`=新客保护期 / `high_value` / `mid_value` / `low_value` / `zero_paid`=无已完成订单。
- **声明七（漏斗转化口径）**：
  1. **步骤与为什么只有两步**：下单（宽进）→ 已完成（严出）；仅两步 = 数据资产限制（无浏览/加购埋点），接入点击流可扩展五级；
  2. **分母**：任意状态下单的用户（含已取消/已退款）；
  3. **分子**：有 ≥1 已完成订单的用户；**按人不按订单**（王五案例一句话）；
  4. **顺序性**：分子 ⊂ 分母，天然满足，不判序；
  5. **时间窗**：全 horizon 累计（2025-08-01 ~ 2025-08-11），全表一口钟。

---

## 指标登记表

### ads.ads_user_repurchase（月度，一行 = 一个月）

| 指标名称 | 字段名 | 业务含义 | 计算公式 | 来源表 | 粒度 | 口径 |
| --- | --- | --- | --- | --- | --- | --- |
| 月度复购率 | repurchase_rate | 当月已完成订单≥2 的用户占当月已完成订单≥1 用户的比例，衡量用户粘性 | `ROUND(SUM(CASE WHEN order_cnt>=2 THEN 1 ELSE 0 END)/COUNT(*),4)` | `dwd.dwd_order` | 一个月 | 仅已完成 |

### ads.ads_user_retention（按首单日 cohort，一日一行）

| 指标名称 | 字段名 | 业务含义 | 计算公式 | 来源表 | 粒度 | 口径 |
| --- | --- | --- | --- | --- | --- | --- |
| 首单日 | cohort_date | 某个用户第一次下单日期 | `DATE_FORMAT(first_date,'yyyy-MM-dd')` | `dwd.dwd_order` | 一日一行 | 任意状态订单取 MIN，一人一 cohort |
| 当日首单人数 | cohort_cnt | 当日首单日人数 | `COUNT(*)` | `dwd.dwd_order` | 一日一行 | 有下单行为的用户（宽进） |
| n 日回访人数 | d1/d3/d7_cnt | 该 cohort 内首单后 1~N 天内（含第 N 天）完成回访（有已完成订单）的人数 | `CASE WHEN DATEDIFF(horizon,first_date)>=N THEN SUM(dN) END` | `dwd.dwd_order` | 一日一行 | 严出：首单日后 1~N 天内（含第 N 天）有已完成订单，首单当天不算 |
| 留存率 | d1/d3/d7_rate | 第 1–第 n 天用户的留存率 | `CASE WHEN DATEDIFF(horizon,first_date)>=N THEN ROUND(SUM(dN)/COUNT(*),4) END` | 本表 | 一日一行 | 同上 |

### ads.ads_user_segment（用户分层，一行 = 一个用户）

| 指标名称 | 字段名 | 业务含义 | 计算公式 | 来源表 | 粒度 | 口径 |
| --- | --- | --- | --- | --- | --- | --- |
| 注册天数 | reg_days | 用户注册日期距数据地平线（数据集最大订单日期）的天数 | `DATEDIFF(horizon, register_date)` | `dws.dws_user` + `dwd.dwd_order` | 一个用户 | 不适用 |
| 用户分层 | value_tier | 按已完成金额与注册时长打出的用户分层标签 | `CASE WHEN DATEDIFF(horizon,register_date)<=7 THEN 'new_user' WHEN paid_amount>=1000 THEN 'high_value' WHEN paid_amount>=300 AND paid_amount<1000 THEN 'mid_value' WHEN paid_amount>0 AND paid_amount<300 THEN 'low_value' WHEN paid_amount=0 THEN 'zero_paid' ELSE 'low_value' END` | `dws.dws_user` + `dwd.dwd_order` | 一个用户 | 见声明六 |

### ads.ads_funnel_user（用户漏斗转化，全数据集一行）

| 指标名称 | 字段名 | 业务含义 | 计算公式 | 来源表 | 粒度 | 口径 |
| --- | --- | --- | --- | --- | --- | --- |
| 下单用户数量 | order_users | 所有下单用户 | `COUNT(*)` | `dwd.dwd_order` | 所有用户 | 所有用户 |
| 已完成用户数量 | finish_users | 订单≥1 且已完成的人的数量 | `SUM(t.finish_users)`，其中 `finish_users = MAX(CASE WHEN status='已完成' THEN 1 ELSE 0 END)` | `dwd.dwd_order` | 所有用户 | 仅已完成 |
| 转化率 | conv_rate | 已完成用户数量 / 所有下单用户 | `ROUND(SUM(t.finish_users)/COUNT(*),4)` | 本表 | 所有用户 | 所有用户 |
| 失去用户数量 | lost_users | 下单用户中从未有已完成订单的用户数 | `SUM(t.lost_users)`，其中 `lost_users = MIN(CASE WHEN status='已完成' THEN 0 ELSE 1 END)` | `dwd.dwd_order` | 所有用户 | 除已完成外 |

---

## 验收对账（四刀）

1. **预期表**：复购率 0.3333（3/9）；留存 08-01 团 0.5/1.0/1.0、08-03 团 0/0/0.5；分层高 4/中 2/低 3/zero 1/new 0；漏斗 10/9/0.9/1。
2. **守恒对账**：留存 `SUM(cohort_cnt) = COUNT(DISTINCT user_id) = 10`；漏斗 `lost = order − finish`（10 − 9 = 1）。
3. **边界样本穿透**：王五（一完成一取消：按人转化、按单流失）、周九（唯一单退款：进分母不进分子）。
4. **独立路径**：心算 9/10 = 0.9；Python 预演复购 3/9 = 0.3333。

**验钞机**：`conv_rate > 1`、`d7 < d3`、`rate ∉ [0,1]` → 数学上不可能，一秒识破。
**静默 bug 检测**：同质数据下两种写法结果相同 → 必须靠边界样本翻车；没有边界样本的验收 = 只验了不翻车的情况。
