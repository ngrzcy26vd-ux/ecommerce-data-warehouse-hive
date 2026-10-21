# 电商数据仓库（Hive）—— ODS → DWD → DWS → ADS 全链路实战

基于 Hive 从零搭建的电商数仓分层项目：从原始数据清洗、明细宽表、实体级预聚合，到应用层每日/每周 GMV 指标，全链路带数据质量校验与双口径指标管理。

## 分层架构

| 层 | 库名 | 职责 | 处理动作 |
|---|---|---|---|
| **ODS** | `ods` | 原始数据贴源层 | 原样装载（load data），不做任何清洗 |
| **DWD** | `dwd` | 明细事实层 | 清洗（trim/cast/NULL 置换）、去重（ROW_NUMBER）、维度退化、**按日期动态分区** |
| **DWS** | `dws` | 汇总宽表层 | 实体级预聚合（用户/商品粒度），双口径并排 |
| **ADS** | `ads` | 应用指标层 | 直接服务报表的指标结果表（日 GMV / 周 GMV） |

核心原则：**一层一个库；上游洗过下游直接用（清洗逻辑只写一遍）；结果表一律 INSERT OVERWRITE（幂等）。**

## 表清单

| 表 | 粒度 | 行数 | 分区 |
|---|---|---|---|
| `dwd.dwd_user` | 一个用户 | 10 | 10（按注册日期） |
| `dwd.dwd_order` | 一笔订单 | 15 | 11（按下单日期） |
| `dwd.dwd_order_item` | 一条订单明细 | 20 | 11（退化订单日期） |
| `dws.dws_user` | 一个用户 | 10 | 无（全量覆盖） |
| `dws.dws_product` | 一个商品 | 11 | 无（全量覆盖） |
| `ads.ads_sales_daily` | 一天 | 11 组 | 11 个日期值 |
| `ads.ads_sales_weekly` | 一周 | 3 组 | 无 |
| `ads.ads_user_repurchase` | 一个月 | 1 组 | 无（月度复购率 0.3333） |
| `ads.ads_user_retention` | 一个首单日 cohort | 10 组 | 无（d1/d3/d7 留存率） |
| `ads.ads_user_segment` | 一个用户 | 10 组 | 无（五档价值分层） |
| `ads.ads_funnel_user` | 全数据集 | 1 组 | 无（下单→完成漏斗 10/9/0.9/1） |

## W10–W11 ADS 应用层：用户旅程四维分析

四张 ADS 表从「时间 / 流程 / 深度 / 价值」四个维度回答业务问题，是本项目从「能跑数」到「能治理口径」的关键跃迁：

| 维度 | 表 | 回答的问题 | 关键口径 |
| --- | --- | --- | --- |
| 时间维度的漏 | `ads_user_retention` | 来了的人还回不回来？ | 按首单日切 cohort，宽进严出，窗口外填 NULL 不填 0 |
| 流程维度的漏 | `ads_funnel_user` | 走的人走到哪一步？ | 下单宽进→已完成严出，按人不按订单 |
| 深度的漏 | `ads_user_repurchase` | 走完的人还走不走第二遍？ | 订单数法，分母 = 当月有已完成单的用户 |
| 价值的秤 | `ads_user_segment` | 留下来的人各值多少钱？ | 固定阈值 + 新客保护期，五档分层 |

配套口径文档：

- `docs/metrics.md` —— W5–W9 双口径声明 + DWS 表登记
- `docs/ads_w10_w11_metrics.md` —— W10–W11 四张 ADS 表的口径声明（五/五·补/六/七）+ 指标登记表 + 验收四刀
- `docs/ads-metrics-deep-dive.md` —— 用户旅程四维分析专题（面试题纲、自测 8 题、治理三原则）

**口径治理是本项目区别于普通「数仓练习」的亮点**：所有指标带七列口径登记表、双口径并排、窗口外 NULL 语义、扩展列触发条件显式登记——面试官问「GMV 跌了怎么分析 / 电商用户怎么分析」时，这四张表 + 口径文档就是完整回答骨架。

## 指标口径

**所有金额类指标均为双口径并排，不做单一口径：**

| 口径 | 定义 | 全链路守恒值 |
|---|---|---|
| 全部订单 | 不过滤状态 | 15 单 / 11256.40 元 |
| 仅已完成 | `status = '已完成'` | 13 单 / 8758.40 元 |

- `ads_sales_daily` 与 `ads_sales_weekly` 同源（都取自 `dwd_order`），周表守恒四数与日表**逐列一字不差**（W31/W32/W33 求和验证）。
- 周编号用 `YEAR + WEEKOFYEAR` 两列一起 GROUP BY，防止跨年周碰撞；`week_id` 用 `CONCAT + LPAD` 构造成 `2025-W31` 形式，**补零让字符串排序等价于时间排序**（否则 W8 会排在 W31 后面）。

## 数据质量校验（四校验）

1. **完整性**：行数对账 + 主键唯一性（`COUNT(*)` vs `COUNT(DISTINCT pk)`）
2. **准确性**：抽样穿透挑**边界样本**（有异常值/单条记录/值为 0 的），不挑典型样本
3. **一致性**：`UNION ALL` 把「来源表现算」与「本表预计算」**并排输出成一张两行表**，逐列比对
4. **有效性**：不变式违规计数（如 `paid_amount ≤ total_amount`、`buyer_cnt ≤ order_cnt`），用开关式 `CASE WHEN` 发牌 + 外层 `SUM` 收牌，违规数 = 0 ⟺ 全部满足

对账只挑**可加量**（SUM/COUNT）；AVG、比率等不可加量换分组就变，不能直接跨层比。

## 技术要点

- **清洗不删行**：非法值用 `CASE WHEN ... ELSE NULL` 置空保留行，删行必须有明确业务口径（防静默 bug：源数据全合法时错写法和对写法结果一样）
- **修复跟着病灶走**：源数据脏 → 内层 SELECT 洗；JOIN 产生的 NULL → 外层 SELECT 用 COALESCE 保护
- **JOIN 三原则**：事实表不能丢就放 FROM（LEFT JOIN 保主）；能从左表拿的列都从左表拿；聚合参数里不许再套聚合函数
- **维度退化**：`dwd_order_item` 把用户名、商品名、类目、订单状态、订单日期直接搬进行，避免下游反复 JOIN
- **MAX 包属性**：`dws_product` 里非分组列用 `MAX()` 包住取值，绕开"只 GROUP BY 部分列"的语义限制
- **动态分区**：`SET hive.exec.mode.local.auto=true`（小内存 VM 防 OOM）+ 分区上限调整，写入 `~/.hiverc` 永久生效

## 目录结构

```
sql/
  01_dwd_user.sql          # 用户维表：清洗 + 去重 + 动态分区
  02_dwd_order.sql         # 订单事实表：清洗 + 去重 + 动态分区
  03_dwd_order_item.sql    # 明细宽表：4 表 JOIN + 维度退化
  04_dws_user.sql          # 用户级预聚合：12 列双口径
  05_dws_product.sql       # 商品级预聚合：MAX 包维度属性
  06_ads_sales_daily.sql    # 日 GMV 指标
  07_ads_sales_weekly.sql   # 周 GMV 指标（ISO 周）
  08_ads_user_repurchase.sql # 月度用户复购率（粘性）
  09_ads_user_retention.sql  # 按首单日 cohort 留存率（d1/d3/d7）
  10_ads_user_segment.sql    # 用户价值五档分层
  11_ads_funnel_user.sql     # 下单→完成漏斗转化
docs/
  metrics.md                 # W5–W9 双口径声明 + DWS 表登记
  ads_w10_w11_metrics.md     # W10–W11 四张 ADS 表口径声明 + 登记 + 验收四刀
  ads-metrics-deep-dive.md   # 用户旅程四维分析专题（面试向）
```

## 环境

- Hive 3.x（MapReduce 引擎）on CentOS 虚拟机，MySQL 作 Metastore
- 样例数据：10 用户 / 15 订单 / 20 条明细 / 11 商品（2025-08 区间）
