# wujios

wujios 旨在提供一键服务部署

目前仅支持debian9、debian10 
提供一键服务的部署包括：
### 服务
| 服务      |    说明 | 端口分配  |
| :--------: | :--------:| :--: |
| 导航  | 网页导航 |  81   |
| rss     | 集成 tinyrss+rsshub+mery |  82  |
| calibre图书管理      |   基于docker | 83  |
| 可道云     | 可到云 |  84  |
| bitwarden密码管理|   基于docker | 85  |
| wallabag     | 基于docker  |  86  |
| 为知笔记 wiznote    |   基于docker | 89  |
| bt下载     | transmission |  9091  |
|Jellyfin      |   小带宽(<5m)不建议开启 | 8096  |

### 部署：


```shell
git clone https://github.com/wuji-os/wujios.git
cd wujios
bash install.sh
```

安装过程30min-3h不等，视主机性能。建议睡一觉再来。

打开 http://域名或ip:81 设置密码即可
