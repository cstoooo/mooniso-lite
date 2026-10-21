# 报文版本边界与支付生命周期案例

## 1. 当前支持的报文版本

本项目只对下列报文版本声明字段路径和规则支持。其他版本即使能被识别出容器名称，也不承诺字段行为和输出结果。

| 报文 | 当前版本 | 已支持范围 | 暂不覆盖 |
| --- | --- | --- | --- |
| `pain.001` | `pain.001.001.03` | 消息头、付款指令、交易 ID、执行日期、金额、币种、IBAN、BIC、控制金额 | 全部 XSD 校验、代理行链、附件、复杂地址结构 |
| `pain.002` | `pain.002.001.03` | 原报文 ID、原交易 ID、交易状态、重复状态 | 原因码完整语义、批量状态汇总、拒绝回执模板 |
| `pacs.008` | `pacs.008.001.08` | 交易 ID、结算金额、币种 | 代理行链、费用承担、端到端路由、UETR 全链路 |
| `pacs.002` | `pacs.002.001.10` | 原报文 ID、原交易 ID、交易状态 | 原因码完整语义、批量状态汇总 |
| `camt.053` | `camt.053.001.08` | 对账条目 ID、金额、币种、借贷方向 | 余额、账期、利息、复杂交易明细、全部账户语义 |

版本边界原则：

- 当前是“常用字段和业务规则校验”，不是完整 ISO 20022 schema 实现；
- 报文版本升级时，测试样例和字段路径需要单独补充；
- 未覆盖字段不应根据旧版本行为推断；
- 详细版本矩阵和测试样例以本文件及 `fixtures/` 为准。

## 2. 超出字段检查的核心语义

支付报文不是三类独立文件：

- `pain.001` 表示付款意图；
- `pain.002` / `pacs.002` 表示支付状态；
- `camt.053` 表示银行对账单中的实际入账证据。

项目不仅检查字段和 ID 集合，还会按 `EndToEndId` 建立一条支付生命周期：

```text
付款意图 pain.001
    |
    +-- 状态报告 pain.002 / pacs.002
    |
    +-- 银行对账单 camt.053
    |
    +-- 生命周期分类与处理动作
```

分类规则：

| 状态 | 条件 | 用户动作 |
| --- | --- | --- |
| `SETTLED` | 状态为 `ACSC`，且对账单金额、币种一致 | 无需处理，保留审计证据 |
| `SETTLED_NOT_POSTED` | 状态为 `ACSC`，但没有对账单条目 | 检查对账文件导入和银行入账 |
| `REJECTED` | 状态为 `RJCT` | 查看拒绝原因，决定是否重发 |
| `PENDING` | 状态为 `PDNG`、`RCVD`、`ACSP` 等非终态 | 稍后查询状态 |
| `MISSING_STATUS` | 有付款记录，但没有状态记录 | 向支付服务方请求状态报告 |
| `STATEMENT_MISMATCH` | 有对账单条目，但金额或币种与付款不一致 | 建立异常，核对金额和币种 |
| `STATEMENT_BEFORE_FINAL_STATUS` | 有对账单条目，但状态仍未到终态 | 核对状态和对账记录 |
| 孤立状态 | 状态报告中有 ID，付款记录中没有对应 ID | 追查原始付款或报告错配 |
| 孤立对账条目 | 对账单中有 ID，付款记录中没有对应 ID | 追查资金来源或报告错配 |

## 3. 完整案例

案例文件：

- `fixtures/lifecycle_pain001.xml`
- `fixtures/lifecycle_pain002.xml`
- `fixtures/lifecycle_camt053.xml`

### 3.1 输入：付款意图

`pain.001` 中包含 7 笔付款：

```text
TX-SETTLED       100.00 EUR
TX-NOT-POSTED     80.00 EUR
TX-REJECTED       50.00 EUR
TX-PENDING        25.00 EUR
TX-MISMATCH       40.00 EUR
TX-BEFORE-FINAL   30.00 EUR
TX-NO-STATUS      10.00 EUR
```

### 3.2 输入：状态报告

`pain.002` 中包含对应状态：

```text
TX-SETTLED       ACSC
TX-NOT-POSTED    ACSC
TX-REJECTED      RJCT
TX-PENDING       PDNG
TX-MISMATCH      ACSC
TX-BEFORE-FINAL  ACSP
TX-ORPHAN-STATUS ACSC   # 没有对应付款
```

### 3.3 输入：银行对账单

`camt.053` 中包含实际对账条目：

```text
TX-SETTLED       100.00 EUR  CRDT
TX-MISMATCH       39.00 EUR  CRDT
TX-BEFORE-FINAL   30.00 EUR  CRDT
TX-ORPHAN-STATEMENT 5.00 EUR CRDT
```

### 3.4 处理关系

项目按 `EndToEndId` 关联三方记录，并比较：

1. 付款金额与对账单金额；
2. 付款币种与对账单币种；
3. 状态是否为终态；
4. 是否存在孤立状态；
5. 是否存在孤立对账条目。

### 3.5 输出

运行：

```bash
moon run cmd/main -- lifecycle \
  fixtures/lifecycle_pain001.xml \
  fixtures/lifecycle_pain002.xml \
  fixtures/lifecycle_camt053.xml
```

输出示例：

```text
TX-SETTLED | 100.00 EUR | status=ACSC | state=SETTLED
Action: No action; retain the report as audit evidence.

TX-NOT-POSTED | 80.00 EUR | status=ACSC | state=SETTLED_NOT_POSTED
Action: Check statement import and bank posting.

TX-REJECTED | 50.00 EUR | status=RJCT | state=REJECTED
Action: Review the rejection reason and decide whether to resend.

TX-PENDING | 25.00 EUR | status=PDNG | state=PENDING
Action: Query the payment status again later.

TX-MISMATCH | 40.00 EUR | status=ACSC | state=STATEMENT_MISMATCH
Action: Open an exception and verify amount or currency.

TX-BEFORE-FINAL | 30.00 EUR | status=ACSP | state=STATEMENT_BEFORE_FINAL_STATUS
Action: Reconcile the statement entry with the current status.

TX-NO-STATUS | 10.00 EUR | status=(missing) | state=MISSING_STATUS
Action: Request a status report from the payment provider.

Status entries without payment:
- TX-ORPHAN-STATUS

Statement entries without payment:
- TX-ORPHAN-STATEMENT
```

### 3.6 支持的用户动作

输出不是单纯的错误列表，而是面向操作人员的处理分类：

- 已结算：归档，无需人工动作；
- 已结算未入账：检查对账文件或银行流水；
- 拒绝：查看原因，决定重发或人工处理；
- 处理中：稍后重新查询；
- 缺状态：请求状态报告；
- 金额/币种不一致：创建异常单；
- 状态未终态但已入账：核对状态和对账单；
- 孤立状态/对账单：追查原始付款或报告归属。

## 4. 独立工程范围

本项目的独立范围不是“字段存在性检查”，而是：

- 项目内 XML 读取器和扁平字段提取；
- 项目内定点 Decimal；
- 五类报文版本边界；
- 统一报文识别与校验入口；
- 付款、状态、对账单三方关联；
- 生命周期状态分类；
- 差异分类和用户动作映射；
- text/JSON/Markdown 输出；
- 12 个固定样例、47 个测试和 CI。
