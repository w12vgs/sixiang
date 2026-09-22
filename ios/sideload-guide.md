# 免费安装「四象」到 iPhone（自用 · 无需付费开发者账号）

原理：用你的免费 Apple ID 给 App 签名（Sideloadly 代劳），装到自己的 iPhone。
限制（Apple 免费签名的规定，任何工具都一样）：
- ⏰ **每 7 天续签一次**（Sideloadly 支持 Wi-Fi 自动续签，电脑开机且同网即可）
- 🧩 免费账号不支持 App Group → **小组件显示空数据**（App 本体全部功能正常）

## 一、准备

1. 本仓库 `dist/Sixiang.ipa`（每次代码更新后 CI 重新打包，替换这个文件即可）
2. Windows 电脑安装 **Sideloadly**：官网 https://sideloadly.io 下载安装
3. iPhone 数据线连接电脑，手机上点「信任此电脑」
4. Windows 商店安装 iTunes 或 Apple 设备 App（Sideloadly 需要苹果驱动；商店搜「Apple 设备」或去 apple.com 下载 iTunes for Windows）

## 二、安装（每次约 2 分钟）

1. 打开 Sideloadly → 左上角把 `Sixiang.ipa` 拖进去
2. Apple ID 栏输入你的 Apple ID → Start
3. 首次会要求输入 Apple ID 密码（可勾选 Remember）并可能要求验证码
4. 完成后手机桌面出现「四象」图标 → 到 设置 → 通用 → VPN 与设备管理 → 点你的 Apple ID → **信任**
5. 打开 App → 服务器地址填你的公网 API（部署见 deploy/README.md），注册登录即可

## 三、7 天续签

- 到期前 Sideloadly 开着（或手机与电脑同 WiFi）会自动续签；
- 没自动成功也没关系：到期后重复「二」的步骤重装一次，数据都在服务器上，不丢失。

## 安全提示

- 建议**单独注册一个 Apple ID** 用于签名，不要用主力账号（虽然 Sideloadly 口碑良好，但第三方工具终归涉及账号密码）；
- 手机上的「VPN 与设备管理」里随时可删除该签名。

## 常见问题

- **提示签名失败/证书问题**：Sideloadly 设置里勾选「Automatic Refresh」与「Use bundle ID」保持默认，重启 Sideloadly 重试。
- **Widget 扩展导致安装失败**：告诉我，我出一个不带小组件的精简版构建。
- **App 打开闪退**：检查服务器地址是否填写正确（必须 https 或局域网 http://电脑IP:3000）。
