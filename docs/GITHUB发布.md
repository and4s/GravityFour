# GitHub 发布与更新检测

仓库：`https://github.com/and4s/GravityFour`，默认分支 `main`。

## 作者、打赏和仓库

编辑 `assets/app_info.json`：`author` 为作者署名，`support_text` 为打赏说明，`support_url` 可填写 HTTPS 打赏页面，`github_repo` 为 `用户名/仓库名`。空链接不会显示跳转按钮。随后重新构建，关于页面展示这些信息。

用户也可在“设置 → 关于 / 作者 / 检查更新”填写公开仓库地址并保存。检查更新请求 GitHub `/repos/{owner}/{repo}/releases/latest`，使用 HTTPS，不上传用户名、对局记录或成绩。未配置仓库时不会发送请求。更新检查由按钮触发，未加入后台自动轮询。

发布正式 Release，标签使用 `v3.9.1` 这样的三段数字版本；预发布和仅创建 Git tag 不会作为正式更新。检查到较新版本后打开 Release 页面，用户选择对应 Windows ZIP 或 Android APK 下载、更新。

## 源码与构建

Git 只提交源码、音效、字体及许可、测试、文档和构建脚本。`.gitignore` 排除引擎缓存、构建产物、日志、SDK、引擎和签名密钥。保留了可提交的 Python 维护工具。

从新电脑构建需准备 Godot 4.7.2 Windows 编辑器到 `tools/`，执行对应 `fetch_*templates.py` 获取导出模板。安卓还需 Android SDK、Java SDK、Godot 编辑器的导出路径配置及原发行签名。签名路径 / 别名由 `Build-Android.ps1` 指定，密码文件不得提交 GitHub；请单独安全备份。

升级版本时同步修改 `scripts/update_checker.gd` 的 VERSION、`export_presets.cfg` 的版本号（安卓 version/code 递增）、构建与启动脚本的输出目录、`tools/package.py` 的版本路径，以及 README。运行测试、两个构建脚本和打包脚本，检查 `dist/release-版本-checksums.json`。

正式 Release 上传 Windows ZIP、Android APK、源码 ZIP 和校验清单。安卓覆盖更新必须沿用原签名和包名，不能换密钥。发行签名不包含在源码 ZIP 中。

当前 3.9 的联机协议为 9，双方使用 3.9；3.8 及更早版本无法与它联机。账户、历史记录和排行榜仍在原应用数据目录。

接口参考：[GitHub Releases API](https://docs.github.com/en/rest/releases/releases#get-the-latest-release)。
