# MoonPay Flow 项目说明

## 项目

MoonPay Flow：MoonBit 实现的 ISO 20022 支付报文解析、校验与对账工具。

## 比赛方向

数据处理、开发者工具。

## 问题

支付业务需要同时处理付款意图、支付状态和银行入账记录。`pain.001`、
`pain.002`、`pacs.008`、`pacs.002` 和 `camt.053` 之间存在金额、币种、
交易 ID 和状态关系，手工核对容易遗漏。

## 当前进度

- 读取 `pain.001.xml`
- 提取消息 ID、创建时间、付款指令数和交易数
- 校验必填字段
- 校验 `EndToEndId` 唯一性
- 校验 `PmtInfId` 唯一性
- 校验 `MsgId`、`PmtInfId` 和 `EndToEndId` 最大长度
- 校验日期、日期时间、金额和币种格式
- 校验 `PmtMtd` 和 `ChrgBr` 枚举
- 校验 IBAN 校验和和 BIC 格式
- 校验 `NbOfTxs`
- 校验 `CtrlSum`
- 自研 XML 事件读取器
- 自研定点十进制解析、比较和求和
- 输出 text、JSON、Markdown
- 支持 `pain.002`、`pacs.008`、`pacs.002` 和 `camt.053` 的基础解析与校验
- 支持 `pain.001` 与状态报告交易按 `EndToEndId` 对账
- 支持 `camt.053` 借贷方向校验
- 支持付款、状态报告和对账单三方生命周期分类
- 支持按状态与对账证据输出用户处理动作
- 提供可查询的规则目录
- 提供有效、无效和格式错误示例
- 提供 `scripts/check.sh`

## 支持范围

当前支持 `pain.001.001.03`、`pain.002.001.03`、`pacs.008.001.08`、
`pacs.002.001.10` 和 `camt.053.001.08` 的常用字段与规则，不覆盖 ISO 20022
全部标准和全部报文变体。

## 实现

- 主要语言：MoonBit
- XML 解析：项目自研 XML pull reader（`xml_reader.mbt`）
- 十进制处理：项目自研定点 Decimal 模块（`decimal.mbt`）
- 文件读取：`moonbitlang/x/fs`
- 测试：`moon test`
- 测试数量：47 个单元测试
- 云端检查：GitHub Actions

## 验收

- 仓库公开
- MoonBit 为主要实现语言
- README 包含运行说明
- 包含有效和无效样例
- 单元测试通过
- CLI 可以运行并输出校验结果
- 使用 Apache-2.0 许可证

## 后续

- 增加 ISO 4217 币种小数位规则
- 增加更完整的交易状态和原因码校验
- 增加 `camt.053` 借贷方向、余额和账期校验
- 增加 HTML 报告

## 合规

测试样例均为项目自建合成报文，不包含客户数据。
