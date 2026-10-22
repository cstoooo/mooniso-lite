# camt.053 余额与重复流水审计

## 输入边界

当前实现支持 `camt.053.001.08` 中的：

- `Stmt/Acct/Id/IBAN`：账户归属；
- `Ntry/Amt` 和 `@Ccy`：发生额及币种；
- `Ntry/CdtDbtInd`：`CRDT` 或 `DBIT`；
- `Ntry/RvslInd`：冲正标记；
- `Bal/Tp/CdOrPrtry/Cd`：`OPBD`、`PRCD`、`CLBD`、`ITBD`；
- `Bal/Amt`、`Bal/CdtDbtInd`：余额金额和余额方向。

一个文件只审计一个账户。账期、利息、复杂交易明细和多账户 `Stmt` 分组不在当前版本范围内。

## 余额规则

```text
净变动 = 贷方发生额 - 借方发生额
期望期末 = 期初余额 + 净变动
期末差额 = 实际期末 - 期望期末
```

余额方向参与正负号计算：

```text
CRDT 余额 -> 正数
DBIT 余额 -> 负数
```

期初优先使用 `OPBD`，缺失时使用 `PRCD`；期末优先使用 `CLBD`，缺失时使用 `ITBD`。

## 案例一：余额一致

输入：`fixtures/balanced_camt053.xml`

```text
期初 OPBD 1000.00 CRDT
贷方发生额 250.00
借方发生额 100.00
期末 CLBD 1150.00 CRDT
```

输出：

```json
{
  "netMovement": "150.00",
  "expectedClosing": "1150.00",
  "closingDifference": "0.00",
  "balanceStatus": "BALANCED",
  "valid": true
}
```

## 案例二：期末余额少记 50

输入：`fixtures/balance_mismatch_camt053.xml`

```text
期初 1000.00 + 贷方 250.00 - 借方 100.00 = 期望期末 1150.00
实际期末 = 1200.00
差额 = 50.00
```

输出包含：

```text
[BALANCE_MISMATCH] Stmt/Bal:
Closing balance does not equal opening balance plus credits minus debits; difference is 50.00.
```

用户动作：核对该账期的漏记流水、错记流水，或期末余额对应的账户和时点。

## 案例三：完全重复流水

输入：`fixtures/duplicate_camt053.xml`

```text
账户 DE89370400440532013000
EndToEndId DUP-TX-001
金额 100.00 EUR
方向 CRDT
出现次数 2
```

输出包含：

```text
Duplicate groups: 1
[STATEMENT_ENTRY_DUPLICATE] Exact statement entry is repeated 2 times for end-to-end ID DUP-TX-001.
```

重复判定使用以下六元组：

```text
(账户 IBAN, EndToEndId, 金额, 币种, 借贷方向, 冲正标记)
```

金额、币种、方向或冲正标记不同的记录不会合并。重复组需要人工确认是银行重复入账、系统重复导入，还是两笔业务共用同一 ID。

## CLI

```bash
moon run cmd/main -- audit fixtures/balanced_camt053.xml
moon run cmd/main -- audit fixtures/balance_mismatch_camt053.xml --format json
moon run cmd/main -- audit fixtures/duplicate_camt053.xml --format markdown
```

## MoonBit API

```moonbit
let report = @moonpay_flow.statement_audit(xml_text)
println(report.balance_status.name())
println(report.closing_difference.unwrap().to_string())
println(report.to_json())
```

主要字段：

- `entry_count`
- `total_credits`
- `total_debits`
- `net_movement`
- `opening_balance`
- `closing_balance`
- `expected_closing`
- `closing_difference`
- `balance_status`
- `duplicate_entries`
- `diagnostics`
