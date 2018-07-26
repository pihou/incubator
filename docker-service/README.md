### 使用docker-compose, 单机部署startup各基础服务
1. drone_cluster 提供ci cd服务
2. gitlab_cluster 提供代码管理git服务
3. svn_cluster 提供文档svn服务
4. redmine_cluster 提供研发管理服务
5. harbor_cluster 提供docker registry服务
6. wordpress_cluster 提供公司站点服务
7. kubernetes_cluster kubernetes方式部署核心服务
8. longban_cluster 内含openresty动态反向代理及通信中间件服务

### nginx反向代理，根据访问域名提供虚拟主机服务
