
## API.war

Workspace REST API
D:\USR\uGit\che-src\wsmaster\che-core-api-workspace\src\main\java\org\eclipse\che\api\workspace\server\WorkspaceService.java

Workspace Manager
D:\USR\uGit\che-src\wsmaster\che-core-api-workspace\src\main\java\org\eclipse\che\api\workspace\server\WorkspaceManager.java

## DTO是什么概念？



## 编辑工作空间时获取installer列表

### 从代码到容器
curl -X GET --header 'Accept: application/json' 'http://10.24.19.123:8080/api/installer?maxItems=30&skipCount=0'

以ssh为例

  {
    "name": "SSH",
    "properties": {},
    "id": "org.eclipse.che.ssh",
    "script": "...",
    "version": "1.0.0",
    "description": "SSH server, key-pair generation",
    "servers": {
      "ssh": {
        "attributes": {},
        "protocol": "ssh",
        "port": "22/tcp"
      }
    },
    "dependencies": []
  }

对应源码：
D:\USR\uGit\che-src\agents\ssh\src\main\resources\installers\1.0.0\org.eclipse.che.ssh.json 

POM: ssh-agent
D:\USR\uGit\che-src\agents\ssh\pom.xml 

对应目标文件：
${che-src}/agents/ssh/target/ssh-agent-6.3.0.jar

被两个制件所依赖：
D:\USR\uGit\che-src\pom.xml 
D:\USR\uGit\che-src\assembly\assembly-wsmaster-war\pom.xml 
  -> ${chesrc}/assembly/assembly-wsmaster-war/target/assembly-wsmaster-war-6.3.0.war
  -> ${chesrc}/assembly/assembly-wsmaster-war/target/assembly-wsmaster-war-6.3.0/WEB-INF/lib/ssh-agent-6.3.0.jar

  assembly-wsmaster-war-6.3.0.war -> tomcat/webapps/api.war
  -> D:\USR\uGit\che-src\assembly\assembly-main\pom.xml
  -> D:\USR\uGit\che-src\assembly\assembly-main\src\assembly\assembly.xml
  -> ${chesrc}/assembly/assembly-main/target/eclipse-che-6.3.0.tar.gz
  
以上可以看到，必须保证最终目标文件：
${chesrc}/assembly/assembly-main/target/eclipse-che-6.3.0/eclipse-che-6.3.0/tomcat/webapps/api.war包含installer包


对应镜像 eclipse/che-server
  构建脚本：
  D:\USR\uGit\che-src\dockerfiles\che\build.sh

容器目录： 

  $ sudo docker exec che ls -l /home/user/eclipse-che/tomcat/webapps/api/WEB-INF/lib/ssh-agent-6.3.0.jar
  -rw-r--r--    1 root     root          3859 Apr  8 13:42 /home/user/eclipse-che/tomcat/webapps/api/WEB-INF/lib/ssh-agent-6.3.0.jar  

（？）如何到installer配置？如何到工作空间？

### 如何到dashboard

#### API 接口定义
![](https://www.eclipse.org/che/docs/6/che/docs/images/workspaces/installers.png)

curl -X GET --header 'Accept: application/json' 'http://10.24.19.123:8080/api/installer?maxItems=30&skipCount=0'

以ssh为例

  {
    "name": "SSH",
    "properties": {},
    "id": "org.eclipse.che.ssh",
    "script": "...",
    "version": "1.0.0",
    "description": "SSH server, key-pair generation",
    "servers": {
      "ssh": {
        "attributes": {},
        "protocol": "ssh",
        "port": "22/tcp"
      }
    },
    "dependencies": []
  }

认知：部署的war包

容器：
  ls -l /home/user/eclipse-che/tomcat/webapps/ | grep war
  api.war  dashboard.war  docs.war  ROOT.war  swagger.war  workspace-loader.war

代码：
  D:\USR\uGit\che-src\assembly\assembly-main\src\assembly\assembly.xml  

* org.eclipse.che:assembly-wsmaster-war -> tomcat/webapps/api.war
* org.eclipse.che.dashboard:che-dashboard-war -> tomcat/webapps/dashboard.war
* org.eclipse.che:assembly-ide-war -> tomcat/webapps/ROOT.war
* org.eclipse.che:assembly-wsagent-server -> lib/ws-agent.tar.gz
  * org.eclipse.che:assembly-wsagent-war -> webapps/ROOT.war  
* org.eclipse.che:assembly-workspace-loader-war -> tomcat/webapps/workspace-loader.war

其他：
  org.eclipse.che.docs:che-docs -> tomcat/webapps/docks.war
  org.eclipse.che.lib:che-swagger-war -> tomcat/webapps/swagger.war

#### API源码

1. REST

2. 控制

接口
  org.eclipse.che.api.installer.server.InstallerRegistry
  Page<? extends Installer> getInstallers(int maxItems, int skipCount) throws InstallerException;

实现类
  org.eclipse.che.api.installer.server.impl.LocalInstallerRegistry 

3. 数据访问

接口
  org.eclipse.che.api.installer.server.spi.InstallerDao
  Page<InstallerImpl> getAll(int maxItems, long skipCount) throws InstallerException;

实现
  org.eclipse.che.api.installer.server.jpa.JpaInstallerDao

```java
  @Override
  @Transactional
  public Page<InstallerImpl> getAll(int maxItems, long skipCount) throws InstallerException {
    checkArgument(maxItems >= 0, "The number of items to return can't be negative.");
    checkArgument(
        skipCount >= 0 && skipCount <= Integer.MAX_VALUE,
        "The number of items to skip can't be negative or greater than " + Integer.MAX_VALUE);
    try {
      final List<InstallerImpl> list =
          managerProvider
              .get()
              .createNamedQuery("Inst.getAll", InstallerImpl.class)
              .setMaxResults(maxItems)
              .setFirstResult((int) skipCount)
              .getResultList();
      return new Page<>(list, skipCount, maxItems, getTotalCount());
    } catch (RuntimeException x) {
      throw new InstallerException(x.getMessage(), x);
    }
  }
```    

-> 认知 javax.inject.Provider<T>.get() -> T
-> 认知 javax.persistence.EntityManager.createNamedQuery() -> TypedQuery
-> 认知 TypedQuery.
  setMaxResults
  setFirstResult
  getResultList

4. Installer实体类

org.eclipse.che.api.installer.server.model.impl.InstallerImpl

认知：javax.persistence.Table


5. 问题转换为 Installer的创建过程

读取installer列表

org.eclipse.che.api.installer.server.impl.InstallersProvider

```java
  @Override
  public Set<Installer> get() {
    Set<Installer> installers = new HashSet<>();

    try {
      Enumeration<URL> installerResources =
          Thread.currentThread().getContextClassLoader().getResources("/installers");
      while (installerResources.hasMoreElements()) {
        URL installerResource = installerResources.nextElement();

        IoUtil.listResources(
            installerResource.toURI(),
            versionDir -> {
              if (!isDirectory(versionDir)) {
                return;
              }

              List<Path> descriptors = findInstallersDescriptors(versionDir);
              for (Path descriptor : descriptors) {
                Optional<Path> script = findInstallerScript(descriptor);
                script.ifPresent(
                    path -> {
                      Installer installer = init(descriptor, script.get());
                      installers.add(installer);
                    });
              }
            });
      }
    } catch (IOException | URISyntaxException e) {
      throw new IllegalStateException(e);
    }

    return installers;
  }
```

-> che-core-api-installer.jar
-> assembly-wsmaster-war.war -> tomcat/webapps/api.war
-> eclipse-che-6.3.0 docker