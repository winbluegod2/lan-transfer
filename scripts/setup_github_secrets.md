# 配置 GitHub Actions Secrets（Android 签名）

Android release APK 需要签名。把 keystore 存到 GitHub Secrets，Actions 构建时自动使用。

## 步骤

### 1. 先生成 keystore（在本地运行）

```bash
# Linux/macOS
bash scripts/create_android_keystore.sh

# Windows PowerShell
keytool -genkey -v `
  -keystore android/app/keystore.jks `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -alias lan-transfer
```

### 2. 把 keystore 转为 base64

```bash
# Linux/macOS
base64 -i android/app/keystore.jks | tr -d '\n'

# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android\app\keystore.jks"))
```

复制输出的内容。

### 3. 在 GitHub 仓库设置 Secrets

进入：`你的仓库` → Settings → Secrets and variables → Actions → New repository secret

添加以下 4 个 Secret：

| Secret 名称 | 值 |
|---|---|
| `KEYSTORE_BASE64` | 上一步复制的 base64 字符串 |
| `KEY_STORE_PASSWORD` | keystore 密码 |
| `KEY_PASSWORD` | key 密码 |
| `KEY_ALIAS` | key alias（如 lan-transfer） |

### 4. 触发构建

```bash
git tag v1.0.0
git push origin v1.0.0
```

等待 Actions 完成（约 15-20 分钟），在 Releases 页面下载四个安装包。

---

## 不配置签名也可以

如果不配置 `KEYSTORE_BASE64`，Actions 会自动用 debug 签名打包 APK，
可以安装测试，但不能发布到 Google Play。
