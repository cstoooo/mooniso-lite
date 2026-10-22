# 报文版本边界与支付生命周期案例

## 1. 当前支持的报文版本

本项目只对下列报文版本声明字段路径和规则支持。其他版本即使能被识别出容器名称，也不承诺字段行为和输出结果。

| 报文 | 当前版本 | 已支持范围 | 暂不覆盖 |
| --- | --- | --- | --- |
| `pain.001` | `pain.001.001.03` | 消息头、付款指令、交易 ID、账户 IBAN、执行日期、金额、币种、BIC、控制金额 | 全部 XSD 校验、代理行链、附件、复杂地址结构 |
| `pain.002` | `pain.002.001.03` | 原报文 ID、原交易 ID、交易状态、重复状态 | 原因码完整语义、批量状态汇总、拒绝回执模板 |
| `pacs.008` | `pacs.008.001.08` | 交易 ID、结算金额、币种 | 代理行链、费用承担、端到端路由、UETR 全链路 |
| `pacs.002` | `pacs.002.001.10` | 原报文 ID、原交易 ID、交易状态 | 原因码完整语义、批量状态汇总 |
| `camt.053` | `camt.053.001.08` | 对账条目、账户 IBAN、金额、币种、借贷方向、冲正标记、期初/期末余额、发生额汇总、精确重复流水 | 账期、利息、复杂交易明细、多账户分组 |

当前一个 `camt.053` 文件按一个对账单账户处理；多账户文件需要拆分为多个文件，后续再扩展为按 `Stmt` 分组解析。

版本边界原则：

- 当前是“常用字段、账户归属和业务规则校验”，不是完整 ISO 20022 schema 实现；
- 报文版本升级时，测试样例和字段路径需要单独补充；
- 未覆盖字段不应根据旧版本行为推断；
- 详细版本矩阵和测试样例以本文件及 `fixtures/` 为准。

## 2. 超出字段检查的核心语义

支付报文不是三类独立文件：

- `pain.001` 表示付款意图，包含债务人账户和收款人账户；
- `pain.002` / `pacs.002` 表示支付状态；
- `camt.053` 表示银行对账单中的实际入账证据。

项目不仅检查字段和 ID 集合，还会按 `EndToEndId` 建立一条支付生命周期，并判断每条对账流水属于债务人账户还是收款人账户：

```text
pain.001 付款意图（债务人账户 / 收款人账户）
    +
pain.002 / pacs.002 支付状态
    +
camt.053 银行对账单（账户 IBAN / DBIT / CRDT / RvslInd）
    ↓
按 EndToEndId 关联
    ↓
账户归属 + 借贷方向 + 退回/冲正 + 净入账金额
    ↓
生命周期分类 + 用户处理动作
```

### 2.1 账户归属和借贷方向

对每笔付款，项目先从 `pain.001` 提取：

- `DbtrAcct/Id/IBAN`：债务人账户；
- `CdtrAcct/Id/IBAN`：收款人账户。

从 `camt.053` 提取：

- `Stmt/Acct/Id/IBAN`：对账单账户；
- `Ntry/CdtDbtInd`：`DBIT` 或 `CRDT`；
- `Ntry/RvslInd`：是否为冲正/退回；
- `Ntry/Amt` 和 `@Ccy`。

对账单账户与债务人账户一致时，正常付款方向是 `DBIT`；与收款人账户一致时，正常收款方向是 `CRDT`。反向流水或 `RvslInd=true` 被视为退回/冲正，而不是付款完成。

### 2.2 净入账金额

项目按 `EndToEndId` 汇总同一账户侧的流水：

```text
净入账金额 = 正常方向金额 - 退回/冲正金额
```

这样可以区分：

- 正常借记 100，后续贷记 100：净额 0，全额退回；
- 正常借记 60，后续贷记 20：净额 40，部分退回；
- 正常借记 100，没有退回：净额 100，可判定为已结算；
- 借记 39，但原付款为 40：净额与付款金额不一致，进入异常。

### 2.3 生命周期分类

| 状态 | 条件 | 用户动作 |
| --- | --- | --- |
| `SETTLED` | 状态为 `ACSC`，净入账等于付款金额，账户归属明确 | 无需处理，保留审计证据 |
| `SETTLED_NOT_POSTED` | 状态为 `ACSC`，但没有对应流水 | 检查对账文件导入和银行入账 |
| `REJECTED` | 状态为 `RJCT` | 查看拒绝原因，决定是否重发 |
| `PENDING` | 状态为非终态 | 稍后查询状态 |
| `MISSING_STATUS` | 有付款记录，但没有状态记录 | 向支付服务方请求状态报告 |
| `STATEMENT_MISMATCH` | 净入账与付款金额或币种不一致 | 建立异常，核对金额、币种和借贷方向 |
| `STATEMENT_BEFORE_FINAL_STATUS` | 净入账匹配，但状态未到终态 | 核对状态和对账记录 |
| `PARTIALLY_REFUNDED` | 净入账大于 0 但小于付款金额，且存在退回/冲正 | 核对剩余金额和退回处理 |
| `FULLY_REFUNDED` | 净入账小于等于 0，或存在完整退回/冲正 | 不得把该付款视为已完成 |
| `ACCOUNT_UNMATCHED` | 对账单账户不属于债务人或收款人 | 追查账户归属或报告错配 |
| 孤立状态 | 状态报告中有 ID，付款记录中没有对应 ID | 追查原始付款或报告错配 |
| 孤立流水 | 对账单中有 ID，付款记录中没有对应 ID | 追查资金来源或报告错配 |

### 2.4 对账单余额审计

余额审计使用银行对账单自身的发生额验证期末余额：

```text
净变动 = 所有 CRDT 发生额 - 所有 DBIT 发生额
期望期末余额 = 期初余额 + 净变动
余额差额 = 实际期末余额 - 期望期末余额
```

其中 `DBIT` 余额按负数记账，`CRDT` 余额按正数记账。期初余额优先读取 `OPBD`，缺失时使用 `PRCD`；期末余额优先读取 `CLBD`，缺失时使用 `ITBD`。审计结果同时给出：

- 期初、期末余额及其类型；
- 贷方发生额、借方发生额和净变动；
- 期望期末余额和实际差额；
- `BALANCED`、`MISMATCH` 或 `INCOMPLETE` 状态。

余额审计还检查账户 IBAN、余额币种和流水币种。当前版本一个文件只处理一个对账单账户，出现多个账户时返回 `MULTI_ACCOUNT_STATEMENT_UNSUPPORTED`。

### 2.5 重复流水检测

系统使用以下六元组识别完全重复流水：

```text
(账户 IBAN, EndToEndId, 金额, 币种, 借贷方向, 冲正标记)
```

同一六元组出现两次及以上时，输出重复组和出现次数。金额、币种或借贷方向不同的相近记录不会被合并。重复流水是人工复核信号，不直接推断银行一定重复入账。

## 3. 对账单余额与重复流水案例

### 3.1 平衡样例

输入文件：`fixtures/balanced_camt053.xml`。

```text
OPBD 期初余额         1000.00 EUR CRDT
CRDT 入账              250.00 EUR
DBIT 出账              100.00 EUR
CLBD 期末余额         1150.00 EUR CRDT
```

运行：

```bash
moon run cmd/main -- audit fixtures/balanced_camt053.xml
```

关键结果：

```text
Net movement: 150.00
Expected closing: 1150.00
Closing difference: 0.00
Balance status: BALANCED
Result: VALID
```

### 3.2 余额不一致样例

输入文件：`fixtures/balance_mismatch_camt053.xml`。期初为 1000.00，贷方 250.00，借方 100.00，但期末记录为 1200.00。

关键结果：

```text
Expected closing: 1150.00
Closing difference: 50.00
Balance status: MISMATCH
[BALANCE_MISMATCH] Stmt/Bal: ...
```

用户动作：核对该账期的流水是否漏记、错记，或期末余额是否来自其他账户/时点。

### 3.3 重复流水样例

输入文件：`fixtures/duplicate_camt053.xml`。同一账户中，`DUP-TX-001` 的 `100.00 EUR CRDT` 记录出现两次。

关键结果：

```text
Duplicate groups: 1
DUP-TX-001 | 100.00 EUR | CRDT | occurrences=2
[STATEMENT_ENTRY_DUPLICATE] ...
```

用户动作：确认重复是银行重复入账、系统重复导入，还是两笔业务确实共用同一 `EndToEndId`。

## 4. 支付生命周期完整案例

案例文件：

- `fixtures/lifecycle_pain001.xml`
- `fixtures/lifecycle_pain002.xml`
- `fixtures/lifecycle_camt053.xml`

### 4.1 输入：付款意图

`pain.001` 中包含 9 笔付款，债务人账户为：

```text
DE89370400440532013000
```

收款人账户为：

```text
FR1420041010050500013M02606
```

付款列表包括已结算、未入账、拒绝、处理中、金额不一致、状态未终态、缺状态、全额退回和部分退回。

### 4.2 输入：状态报告

`pain.002` 中包含对应的 `ACSC`、`RJCT`、`PDNG`、`ACSP` 状态，并额外包含一个没有对应付款的 `TX-ORPHAN-STATUS`。

### 4.3 输入：银行对账单

`camt.053` 的对账单账户为 `DE89370400440532013000`，其中包含：

```text
TX-SETTLED       DBIT 100.00
TX-MISMATCH      DBIT  39.00
TX-BEFORE-FINAL  DBIT  30.00
TX-FULL-REFUND   DBIT  20.00
TX-FULL-REFUND   CRDT  20.00  RvslInd=true
TX-PARTIAL-REFUND DBIT 60.00
TX-PARTIAL-REFUND CRDT 20.00  RvslInd=true
TX-ORPHAN-STATEMENT CRDT 5.00
```

### 4.4 输出

运行：

```bash
moon run cmd/main -- lifecycle \
  fixtures/lifecycle_pain001.xml \
  fixtures/lifecycle_pain002.xml \
  fixtures/lifecycle_camt053.xml
```

关键输出：

```text
TX-SETTLED | 100.00 EUR | status=ACSC | account=DEBTOR | net=100.00 | reversals=0 | state=SETTLED
TX-MISMATCH | 40.00 EUR | status=ACSC | account=DEBTOR | net=39.00 | reversals=0 | state=STATEMENT_MISMATCH
TX-FULL-REFUND | 20.00 EUR | status=ACSC | account=DEBTOR | net=0.00 | reversals=1 | state=FULLY_REFUNDED
TX-PARTIAL-REFUND | 60.00 EUR | status=ACSC | account=DEBTOR | net=40.00 | reversals=1 | state=PARTIALLY_REFUNDED
```

输出同时列出孤立状态和孤立流水。JSON 和 Markdown 输出保留账户角色、净入账金额、冲正次数和用户动作。

### 4.5 支持的用户动作

- 已结算：归档，无需人工动作；
- 已结算未入账：检查对账文件或银行流水；
- 拒绝：查看原因，决定重发；
- 处理中：稍后重新查询；
- 缺状态：请求状态报告；
- 金额/币种不一致：创建异常单；
- 部分退回：核对剩余金额和退回记录；
- 全额退回/冲正：不得把付款当成完成；
- 账户不匹配：追查账户归属或报告错配；
- 孤立状态/流水：追查原始付款或报告归属。

## 5. 独立工程范围

本项目的独立范围不是“字段存在性检查”，而是：

- 项目内 XML 读取器和逐 `Ntry` 流水解析；
- 项目内定点 Decimal；
- 五类报文版本边界；
- 统一报文识别与校验入口；
- 债务人和收款人账户归属判断；
- 借贷方向、`RvslInd` 和净入账金额计算；
- 期初/期末余额、借贷发生额、净变动和期末差额核对；
- 余额类型、账户范围、币种一致性和精确重复流水检查；
- 付款、状态、对账单三方关联；
- 生命周期分类、退回/冲正识别和用户动作映射；
- text/JSON/Markdown 输出；
- 15 个固定样例、67 个测试和 CI。
