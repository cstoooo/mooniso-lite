# MoonISO Lite 项目说明

## 项目

MoonISO Lite：MoonBit 实现的 ISO 20022 `pain.001` 支付报文校验工具。

## 比赛方向

数据处理、开发者工具。

## 问题

`pain.001` 报文字段较多，开发人员和测试人员需要检查消息 ID、交易 ID、
执行日期、金额、币种和控制金额。手工检查容易遗漏。

## 当前进度

- 读取 `pain.001.xml`
- 提取消息 ID、创建时间、付款指令数和交易数
- 校验必填字段
- 校验 `EndToEndId` 唯一性
- 校验日期、日期时间、金额和币种格式
- 校验 `NbOfTxs`
- 校验 `CtrlSum`
- 输出 text、JSON、Markdown
- 提供有效、无效和格式错误示例
- 提供 `scripts/check.sh`

## 支持范围

只处理 `pain.001.001.03` 的常用字段和规则，不覆盖 ISO 20022 全部标准和
全部报文类型。

## 实现

- 主要语言：MoonBit
- XML 解析：MoonBit XML pull parser
- 文件读取：MoonBit 文件系统包
- 测试：`moon test`
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

- 增加 `pain.002`、`pacs.008`、`camt.053`
- 增加 IBAN、BIC 和 ISO 4217 规则
- 增加对账功能
- 增加 HTML 报告

## 合规

测试样例均为项目自建合成报文，不包含客户数据。
