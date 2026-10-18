# cfdata 飞牛 fnOS FPK 应用

本仓库将 `cfdata-linux-amd64` (Linux x86_64 二进制) 打包为飞牛 fnOS 第三方应用 `.fpk` 安装包。

## 项目结构

```
cfdata-fpk/
├── cfdata/                         # fpk 应用源目录
│   ├── app/
│   │   └── cfdata-linux-amd64      # 主程序二进制
│   ├── cmd/
│   │   ├── main                    # 生命周期脚本 (start/stop/status)
│   │   ├── install_init
│   │   ├── install_callback
│   │   ├── upgrade_init
│   │   ├── upgrade_callback
│   │   ├── uninstall_init
│   │   ├── uninstall_callback
│   │   ├── config_init
│   │   └── config_callback
│   ├── config/
│   │   ├── privilege               # 权限声明 (JSON)
│   │   └── resource                # 资源声明 (JSON)
│   ├── wizard/                     # 安装向导目录
│   ├── manifest                    # 应用清单
│   ├── LICENSE                     # 许可证
│   ├── ICON.PNG                    # 小图标 (64x64)
│   └── ICON_256.PNG                # 大图标 (256x256)
├── .github/
│   └── workflows/
│       └── build-fpk.yml           # GitHub Actions 构建流水线
├── .gitignore
└── README.md
```

## 云端构建 (GitHub Actions)

推送代码到 GitHub 后，GitHub Actions 会自动：

1. 下载官方 `fnpack` 工具 (Linux amd64)
2. 运行 `fnpack build --directory cfdata`
3. 生成 `cfdata.fpk` 构建产物
4. 上传为 GitHub Artifact

触发方式：
- `git push` 到 `main` 分支
- 手动触发 (workflow_dispatch)
- 发布 Release 时自动构建并上传

## 安装到飞牛 fnOS

从 GitHub Releases 或 Actions Artifact 下载 `cfdata.fpk`，然后在飞牛 fnOS 应用中心 → 设置 → 手动安装应用 → 上传 `.fpk` 文件。

## 注意

- 飞牛 fnOS 第三方应用仅支持 **x86_64** 架构
- ARM 版飞牛设备暂时无法安装此 fpk
