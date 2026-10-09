# ADS 指标口径

## 口径声明

- **声明一（双口径）**：出于不同要求，本表对于金额类指标有两种口径：第一种以**所有订单**为口径，第二种以**已完成**为口径。比如王五，他的订单金额和已完成订单金额相差数倍，不同口径结论完全不同

- **声明二（取数来源）**：dws_user 按 `user_id` 做 GROUP BY 时，**order_date 被聚合掉了，只剩 first/last 两个端点**——表里已经没有“每天”的明细信息，**聚合不可逆**，变不回每天一行，所以每日指标只能回 dwd_order 现算

## 指标登记表

| 指标名称             | 字段名            | 业务含义                                                  | 计算公式                                                                              | 来源表          | 粒度     | 口径     |
| -------------------- | ----------------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------- | --------------- | -------- | -------- |
| 所有订单数量         | order_cnt         | 一个用户所有订单的数量（状态=已完成/已退款/已取消）       | count(order_id) as order_cnt                                                          | dws.dws_user    | 一个用户 | 全部订单 |
| 所有订单金额总计     | total_amount      | 一个用户所有的订单金额的总计（状态=已完成/已取消/已退款） | sum(amount) as total_amount                                                           | dws.dws_user    | 一个用户 | 全部订单 |
| 已完成订单数量       | paid_order_cnt    | 一个用户已完成的订单数量的总计（状态=已完成）             | sum(case when status='已完成' then 1 else 0 end) as paid_order_cnt                    | dws.dws_user    | 一个用户 | 仅已完成 |
| 已完成订单金额       | paid_total_amount | 一个用户已完成的订单金额总计（状态=已完成）               | sum(case when status='已完成' then amount else 0 end) as paid_total_amount            | dws.dws_user    | 一个用户 | 仅已完成 |
| 第一次下单日期       | first_order_date  | 一个用户的第一次下单日期                                  | min(order_date) as first_order_date                                                   | dws.dws_user    | 一个用户 | 不适用   |
| 最后一次下单日期     | last_order_date   | 一个用户最后一次的下单日期                                | max(order_date) as last_order_date                                                    | dws.dws_user    | 一个用户 | 不适用   |
| 订单数量             | order_cnt         | 单个产品的下单数量（状态=已完成/已退款/已取消）           | count(item_id) as order_cnt                                                           | dws.dws_product | 一个产品 | 全部订单 |
| 产品总金额           | total_amount      | 单个产品下单的总金额（状态=已完成/已退款/已取消）         | sum(item_amount) as total_amount                                                      | dws.dws_product | 一个产品 | 全部订单 |
| 已完成订单数量       | paid_order_cnt    | 单个产品已完成的订单数量（状态=已完成）                   | sum(case when order_status='已完成' then 1 else 0 end) as paid_order_cnt              | dws.dws_product | 一个产品 | 仅已完成 |
| 已完成金额           | paid_total_amount | 单个产品的已完成金额总计（状态=已完成）                   | sum(case when order_status='已完成' then item_amount else 0 end) as paid_total_amount | dws.dws_product | 一个产品 | 仅已完成 |
| 产品第一次下单日期   | first_order_date  | 单个产品第一次的下单日期                                  | min(order_date) as first_order_date                                                   | dws.dws_product | 一个产品 | 不适用   |
| 产品最后一次下单日期 | last_order_date   | 单个产品最后一次下单日期                                  | max(order_date) as last_order_date                                                    | dws.dws_product | 一个产品 | 不适用   |
