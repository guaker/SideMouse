# 鼠标侧切 · SideMouse

将鼠标两个侧键映射为 Control + 左/右箭头，切换 macOS 桌面。原生 Swift 应用，无需安装第三方映射软件。

## 项目缘起

MacBook 触控板可以用手势快速切换桌面，但使用外接键鼠或 Mac mini 时，操作就没那么顺手。macOS 虽支持 Control + 左/右箭头，仍需要键盘操作。我之前用 SteerMouse 配置侧键，但它是付费软件，功能也超出我的需要。于是做了 SideMouse：只用鼠标侧键切换桌面，简单专注，不附带其他鼠标管理功能。

| 按键 | 快捷键 | 功能 |
| --- | --- | --- |
| 侧键 3 | Control + → | 右侧桌面 |
| 侧键 4 | Control + ← | 左侧桌面 |

## 兼容性验证

| 项目 | 型号 / 版本 |
| --- | --- |
| 鼠标 | Logitech G309、Logitech G304、Razer Basilisk X HyperSpeed |
| 电脑 | MacBook Pro（Mac16,1，Apple M4） |
| 系统 | macOS 27.0.1（Build 26A434） |

其他鼠标的侧键编号可能不同。系统要求：macOS 13 或更新版本。

## 安装

1. 从 [Releases](https://github.com/guaker/SideMouse/releases/latest) 下载最新版 macOS 安装包，解压后将 `SideMouse.app` 拖入“应用程序”。
2. 打开应用，在“系统设置 → 隐私与安全性”中开启下表两项权限。
3. 授权后返回 SideMouse，应用会自动重新检测并启动监听；也可点击“重新检测”。

| 权限 | 用途 |
| --- | --- |
| 输入监控 | 监听鼠标侧键 |
| 设备控制和数据访问（部分系统显示为“辅助功能”） | 发送切换桌面的快捷键 |

只需这两项隐私权限。[查看授权截图](使用说明.md#权限设置)。

如果系统权限页没有显示 SideMouse，可使用应用窗口中的“输入监控设置”或“辅助功能设置”打开对应页面，再按说明开启权限。

## 使用

- 按鼠标侧键切换桌面；关闭窗口后继续运行，点击“退出”停止。
- 开机启动：在“系统设置 → 通用 → 登录项”中添加 `SideMouse.app`。
- 无法切换：检查两项权限，并确认实体键盘的 Control + 左/右箭头能切换桌面。

[图文使用说明](使用说明.md) · [第三方许可](THIRD_PARTY_NOTICES.md)

## 开发

运行 `./scripts/check.sh` 检查代码和快捷键回归，运行 `./build.sh` 生成签名应用。目录结构、签名配置见[开发说明](docs/development.md)。
