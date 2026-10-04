# 构建工具

本目录保留 Godot 4.7.2 编辑器、Windows / Android 导出模板、Android SDK 和发行签名文件。它们供根目录的构建、测试和启动脚本使用。

- `package.py`：生成当前 Windows / 源码 ZIP 和 SHA-256 清单；从任意目录运行均可。
- `fetch_templates.py` / `fetch_android_templates.py`：下载本项目固定版本的官方导出模板。
- `generate_audio.py`：重新生成原创音效，无额外 Python 依赖。
- `generate_draw_fixture.py`：重新生成平局测试数据，需要 NumPy 和 SciPy；普通测试直接使用已保存的数据。

`gravity-four-release.keystore` 和 `release-key-password.txt` 是后续安卓覆盖更新所需的签名文件，应安全备份。打包脚本不会把它们、SDK 或引擎二进制放入源码 ZIP。

一次性代码修改脚本、旧 AI 副本、下载压缩包和安装日志已清理。
