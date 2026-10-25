# 单一事实源与章节学习卡约定

## 为什么

五本书有大量交叉主题。如果每个章节都重新讲一遍，改标准/改数值时一定会出现“三本书三种说法”。  
约定：每个知识点只有一个主源章节，其他章节只写结论 + 参见，不复制大段内容。

## 主源表（v1）

| 主题 | 主源章节 | 说明 |
|---|---|---|
| GD&T 入门/验收 | qc_book.ch01 | 基准、公差带、MMC、检验判定 |
| GD&T 避坑 | pitfall_book.ch03 | 主源补充“设计侧反例”，不重复基础定义 |
| 尺寸公差/配合 | new_book.ch01 | ISO 286 / 孔基制 / 配合选择 |
| 配合避坑 | pitfall_book.ch04 | 只写失效案例与边界 |
| 表面处理 | qc_book.ch03 | 工艺、膜厚、镀前镀后、验收 |
| 材料与热处理 | new_book.ch04 | 材料牌号、热处理、硬度 |
| 标准件 | new_book.ch05 | 键、销、轴承、O 圈、挡圈 |
| 尺寸链 | pitfall_book.ch05 | 封闭环、最坏情况/RSS |
| CNC/钣金/压铸工艺 | pitfall_book.ch10~12 | 工艺极限与 DFM |
| 非标自动化 | auto_book.ch01~ch06 | 选型、公差链、可制造性 |
| 检验/测量 | qc_book.ch01/ch05 | GD&T 判定 + 影像测量 |
| 成长路径 | growth_book.ch01~ch12 | 学习路线，不承载标准数值 |

## 学习卡字段

assets/data/book_learning.json：

- summary：3 条结论，先给答案
- boundaries：适用/不适用
- counterexample：一个反例
- checklist：现场检查清单
- standard / reviewed_at：依据和复核日期
- canonical：是否主源
- see_also：参见章节 key
- quick_refs：关联速查 ref_id
- quiz：3 题，含答案和解释

## 维护规则

1. 改数值/标准，只改主源 + 数据表；其他章节只改“参见”说明。
2. 新增章节必须进 manifest；学习卡可选，未填时阅读页只显示“本章知识卡”（H2 自动派生）。
3. 主源章节标 canonical: true，阅读页显示“主源章节”。
4. 每次改标准版本，更新 standard 和 reviewed_at。
5. CI 跑 python3 tool/validate_book_content.py：检查 key、关联、题目、待核对残留。

## 当前覆盖

已写 8 个核心章节学习卡：GD&T、表面处理、公差配合、尺寸链、自动化配合、成长路径 GD&T。  
其余章节自动显示 H2 知识卡；后续按主源表逐章补 summary/quiz。
