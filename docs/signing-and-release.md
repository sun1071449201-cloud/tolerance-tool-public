# 签名与发布

当前公开签名证书：

- CN=Tolerance Tool
- OU=Open Source
- O=Tolerance Tool Project
- C=CN

包名保持 com.sunliangyu.tolerance_tool。  
由于 v41 更换了签名，v41 不能直接覆盖安装旧版；先导出备份，再卸载旧版安装。

签名私钥/密码只在维护者本机和 GitHub Actions Secrets 中，不进入仓库。  
发布 APK 时必须同时发布 SHA256。
