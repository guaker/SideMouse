# 开发说明

## 目录

```text
Sources/SideMouse/    应用源码
  App.swift          启动、授权重试、退出
  DesktopDirection.swift  侧键映射和快捷键描述
  MouseController.swift   鼠标监听及状态
  ShortcutSender.swift    快捷键序列及释放
  SingleInstanceLock.swift  单实例文件锁
  StatusWindow.swift      状态窗口
Resources/           Info.plist、图标、多语言应用名
Tests/               不发送系统事件的回归检查
scripts/check.sh     代码、资源和回归检查入口
docs/images/         使用说明截图
build.sh             构建入口
scripts/release.sh   公证、打包和校验和
```

## 检查和构建

需要 macOS 13 或更新版本及 Xcode Command Line Tools，无第三方运行时依赖。

```sh
./scripts/check.sh
./build.sh
```

检查脚本验证 Swift 类型、编译警告、Shell 语法和 plist，并检查侧键方向、事件标志、权限与修饰键保护、快速连按、取消与重新发送。测试通过内存回调记录事件，不创建系统事件监听器、不请求隐私权限、不切换桌面。

构建先在临时目录编译、签名和验证，成功后生成项目根目录中的 `SideMouse.app`，清理临时文件。失败时保留原应用包。不会覆盖 `/Applications` 中的安装版本。默认生成当前机器架构的优化构建，最低系统版本为 macOS 13。应用包不纳入源码仓库。

默认使用原 Developer ID 证书。无该证书时可使用临时签名：

```sh
SIDEMOUSE_SIGNING_IDENTITY=- SIDEMOUSE_OUTPUT_DIR=dist ./build.sh
```

`SIDEMOUSE_OUTPUT_DIR` 指定输出目录，默认项目根目录。Developer ID 构建启用 Hardened Runtime 并附加可信时间戳；更换签名身份可能需要重新授权。签名验证通过不代表已完成 Apple 公证。

## 发布

先在钥匙串中保存 Apple 公证凭据。可使用 Apple ID 专用密码和 Team ID，或 App Store Connect API Key；只使用本机 `notarytool` 钥匙串配置，不要将密码或私钥提交到仓库。

```sh
xcrun notarytool store-credentials SideMouseNotary \
  --apple-id '<Apple ID 邮箱>' \
  --team-id '7W443PQ7JZ'
```

完成交互式凭据录入后运行 `./scripts/release.sh`。脚本将构建 Developer ID 应用、公证、装订票据、验证 Gatekeeper、生成 ZIP 和 SHA-256 文件。将 `dist/` 中两个发布文件上传至对应的 GitHub Release。Apple 公证凭据通过 `SIDEMOUSE_NOTARY_PROFILE` 选择，默认名称为 `SideMouseNotary`。

## 运行约束

- `--background` 启动时隐藏窗口；关闭窗口继续运行，退出时停止监听并释放尚未松开的合成按键。
- 只消费侧键 3、4 的按下和松开。映射和窗口描述共用 `DesktopDirection`，其他鼠标按键及键盘事件不进入监听范围。
- 监听、状态更新和发送都在主运行循环中执行。事件回调仅筛选侧键并排队；实际发送使用经实测的 Control / 方向键事件标志，50 ms 后释放。
- 快捷键发送要求具备发送权限、没有 Control / Command / Option / Shift 实体修饰键按下，且没有正在发送的快捷键。
- 权限请求分别记录，每次进程运行只请求一次；监听启动失败时每 2 秒重试。
- 使用系统统一日志，子系统为 `com.guaker.sidemouse`，类别为 `MouseController`。

当前版本使用新的 Bundle ID `com.guaker.sidemouse`、可执行文件名 `SideMouse` 和单实例锁路径。重新安装后，需要在系统设置中为新应用重新开启两项权限；旧应用、旧权限项和旧登录项可以删除。

自动检查不能代替实体鼠标验证。安装新版本后，需确认两项权限、两个侧键的方向、关闭窗口后的映射，以及退出后的正常键盘输入。
