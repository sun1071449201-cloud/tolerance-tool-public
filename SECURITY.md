# 安全说明

## 报告问题

请通过 GitHub Security Advisory 私下报告，不要公开贴可利用细节。

## 仓库约定

- 不提交 keystore、密码、PAT、token。
- CI 签名密钥只放在 GitHub Actions Secrets。
- 发布 APK 请附 SHA256。
- 如果怀疑密钥泄露，立即轮换 Secrets 并重新签名发布。

## 支持范围

只维护 main 分支的最新版本。
