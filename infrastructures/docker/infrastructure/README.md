# DockerRuntime

## Installer生命周期

从这里开始        
DockerInternalRuntime.bootstrapInstallers
    D:\USR\uGit\che-src\infrastructures\docker\infrastructure\src\main\java\org\eclipse\che\workspace\infrastructure\docker\DockerInternalRuntime.java

```json
// 工作空间配置文件（部分）
    "dev-machine": {
        "attributes": {
        "memoryLimitBytes": "2147483648"
        },
        "servers": {},
        "agents": [
        "org.eclipse.che.ls.csharp",
        "org.eclipse.che.git-credentials",
        "org.eclipse.che.ssh",
        "org.eclipse.che.ws-agent",
        "org.eclipse.che.terminal",
        "org.eclipse.che.exec"
        ]
    }
```

```java
    public interface DockerBootstrapperFactory {
    DockerBootstrapper create(
        @Assisted String machineName,
        @Assisted RuntimeIdentity runtimeIdentity,
        @Assisted List<? extends Installer> installers,
        @Assisted DockerMachine dockerMachine);
    }
```

AbstractBootstrapper
    D:\USR\uGit\che-src\wsmaster\che-core-api-workspace\src\main\java\org\eclipse\che\api\workspace\server\bootstrap\AbstractBootstrapper.java

```java
  /**
   * Bootstraps installers and wait while they finished.
   *
   * @throws InfrastructureException when bootstrapping timeout reached
   * @throws InfrastructureException when bootstrapping failed
   * @throws InfrastructureException when any other error occurs while bootstrapping
   * @throws InterruptedException when the bootstrapping process was interrupted
   */
  public void bootstrap(int bootstrappingTimeoutMinutes)
      throws InfrastructureException, InterruptedException {
    if (finishEventFuture != null) {
      throw new IllegalStateException("Bootstrap method must be called only once.");
    }
    finishEventFuture = new CompletableFuture<>();

    eventService.subscribe(bootstrapperStatusListener, BootstrapperStatusEvent.class);
    try {
      doBootstrapAsync(installerEndpoint, outputEndpoint);

      // waiting for DONE or FAILED bootstrapper status event
      BootstrapperStatusEvent resultEvent =
          finishEventFuture.get(bootstrappingTimeoutMinutes, TimeUnit.MINUTES);
      if (resultEvent.getStatus().equals(BootstrapperStatus.FAILED)) {
        throw new InfrastructureException(resultEvent.getError());
      }
    } catch (ExecutionException e) {
      throw new InfrastructureException(e.getCause().getMessage(), e);
    } catch (TimeoutException e) {
      throw new InfrastructureException(
          "Bootstrapping of machine " + machineName + " reached timeout");
    } finally {
      eventService.unsubscribe(bootstrapperStatusListener, BootstrapperStatusEvent.class);
    }
  }
```  

DockerBootstrapper.doBootstrapAsync

```java
  @Override
  protected void doBootstrapAsync(String installerWebsocketEndpoint, String outputWebsocketEndpoint)
      throws InfrastructureException {
    injectBootstrapper();

    dockerMachine.exec(
        BOOTSTRAPPER_DIR
            + BOOTSTRAPPER_FILE
            + " -machine-name "
            + machineName
            + " -runtime-id "
            + String.format(
                "%s:%s:%s:%s",
                runtimeIdentity.getWorkspaceId(),
                runtimeIdentity.getEnvName(),
                runtimeIdentity.getOwnerName(),
                runtimeIdentity.getOwnerId())
            + " -push-endpoint "
            + installerWebsocketEndpoint
            + " -push-logs-endpoint "
            + outputWebsocketEndpoint
            + " -enable-auth"
            + " -server-check-period "
            + serverCheckPeriodSeconds
            + " -installer-timeout "
            + installerTimeoutSeconds
            + " -file "
            + BOOTSTRAPPER_DIR
            + CONFIG_FILE,
        null);
  }
```  

### installer的输出

```
[STDOUT] Rsync agent installed
[STDOUT] Exec Agent binary is downloaded remotely
[STDOUT] 2018/03/28 02:44:23 Exec-agent configuration
[STDOUT] 2018/03/28 02:44:23   Server
[STDOUT] 2018/03/28 02:44:23     - Address: :4412
[STDOUT] 2018/03/28 02:44:23     - Base path: '/[^/]+'
[STDOUT] 2018/03/28 02:44:23   Authentication
[STDOUT] 2018/03/28 02:44:23     - Enabled: true
[STDOUT] 2018/03/28 02:44:23     - Tokens expiration timeout: 10m
[STDOUT] 2018/03/28 02:44:23   Workspace master server
[STDOUT] 2018/03/28 02:44:23     - API endpoint: https://codenvy.io/api
[STDOUT] 2018/03/28 02:44:23   Process executor
[STDOUT] 2018/03/28 02:44:23     - Logs dir: /home/user/che/exec-agent/logs
[STDOUT] 2018/03/28 02:44:23 
[STDOUT] 2018/03/28 02:44:23 ⇩ Registered HTTPRoutes:
[STDOUT] 
[STDOUT] 2018/03/28 02:44:23 Process Routes:
[STDOUT] 2018/03/28 02:44:23 ✓ Start Process ........................... POST   /process
[STDOUT] 2018/03/28 02:44:23 ✓ Get Process ............................. GET    /process/:pid
[STDOUT] 2018/03/28 02:44:23 ✓ Kill Process ............................ DELETE /process/:pid
[STDOUT] 2018/03/28 02:44:23 ✓ Get Process Logs ........................ GET    /process/:pid/logs
[STDOUT] 2018/03/28 02:44:23 ✓ Get Processes ........................... GET    /process
[STDOUT] 2018/03/28 02:44:23 
[STDOUT] 2018/03/28 02:44:23 Exec-Agent WebSocket routes:
[STDOUT] 2018/03/28 02:44:23 ✓ Connect to Exec-Agent(websocket) ........ GET    /connect
[STDOUT] 2018/03/28 02:44:23 
[STDOUT] 2018/03/28 02:44:23 ⇩ Registered RPCRoutes:
[STDOUT] 
[STDOUT] 2018/03/28 02:44:23 Process Routes:
[STDOUT] 2018/03/28 02:44:23 ✓ process.start
[STDOUT] 2018/03/28 02:44:23 ✓ process.kill
[STDOUT] 2018/03/28 02:44:23 ✓ process.subscribe
[STDOUT] 2018/03/28 02:44:23 ✓ process.unsubscribe
[STDOUT] 2018/03/28 02:44:23 ✓ process.updateSubscriber
[STDOUT] 2018/03/28 02:44:23 ✓ process.getLogs
[STDOUT] 2018/03/28 02:44:23 ✓ process.getProcess
[STDOUT] 2018/03/28 02:44:23 ✓ process.getProcesses
[STDOUT] Terminal Agent binary is downloaded remotely
[STDOUT] 2018/03/28 02:44:26 Terminal-agent configuration
[STDOUT] 2018/03/28 02:44:26   Server
[STDOUT] 2018/03/28 02:44:26     - Address: :4411
[STDOUT] 2018/03/28 02:44:26     - Base path: '/[^/]+'
[STDOUT] 2018/03/28 02:44:26   Terminal
[STDOUT] 2018/03/28 02:44:26     - Slave command: ''
[STDOUT] 2018/03/28 02:44:26     - Activity tracking enabled: true
[STDOUT] 2018/03/28 02:44:26   Authentication
[STDOUT] 2018/03/28 02:44:26     - Enabled: true
[STDOUT] 2018/03/28 02:44:26     - Tokens expiration timeout: 10m
[STDOUT] 2018/03/28 02:44:26   Workspace master server
[STDOUT] 2018/03/28 02:44:26     - API endpoint: https://codenvy.io/api
[STDOUT] 2018/03/28 02:44:26 
[STDOUT] 2018/03/28 02:44:26 ⇩ Registered HTTPRoutes:
[STDOUT] 
[STDOUT] 2018/03/28 02:44:26 Terminal routes:
[STDOUT] 2018/03/28 02:44:26 ✓ Connect to pty(websocket) ............... GET    /pty
[STDOUT] 2018/03/28 02:44:26 
[STDOUT] Workspace Agent will be downloaded from Workspace Master
[STDOUT] 2018-03-28 02:44:32,200[main]             [INFO ] [o.a.c.s.VersionLoggerListener 89]    - Server version:        Apache Tomcat/8.5.11
[STDOUT] 2018-03-28 02:44:32,206[main]             [INFO ] [o.a.c.s.VersionLoggerListener 91]    - Server built:          Jan 10 2017 21:02:52 UTC
[STDOUT] 2018-03-28 02:44:32,207[main]             [INFO ] [o.a.c.s.VersionLoggerListener 93]    - Server number:         8.5.11.0
[STDOUT] 2018-03-28 02:44:32,207[main]             [INFO ] [o.a.c.s.VersionLoggerListener 95]    - OS Name:               Linux
[STDOUT] 2018-03-28 02:44:32,214[main]             [INFO ] [o.a.c.s.VersionLoggerListener 97]    - OS Version:            3.10.0-693.17.1.el7.x86_64
[STDOUT] 2018-03-28 02:44:32,214[main]             [INFO ] [o.a.c.s.VersionLoggerListener 99]    - Architecture:          amd64
[STDOUT] 2018-03-28 02:44:32,215[main]             [INFO ] [o.a.c.s.VersionLoggerListener 101]   - Java Home:             /usr/lib/jvm/java-8-openjdk-amd64/jre
[STDOUT] 2018-03-28 02:44:32,215[main]             [INFO ] [o.a.c.s.VersionLoggerListener 103]   - JVM Version:           1.8.0_131-8u131-b11-2ubuntu1.16.04.3-b11
[STDOUT] 2018-03-28 02:44:32,216[main]             [INFO ] [o.a.c.s.VersionLoggerListener 105]   - JVM Vendor:            Oracle Corporation
[STDOUT] 2018-03-28 02:44:32,216[main]             [INFO ] [o.a.c.s.VersionLoggerListener 107]   - CATALINA_BASE:         /home/user/che/ws-agent
[STDOUT] 2018-03-28 02:44:32,217[main]             [INFO ] [o.a.c.s.VersionLoggerListener 109]   - CATALINA_HOME:         /home/user/che/ws-agent
[STDOUT] 2018-03-28 02:44:32,218[main]             [INFO ] [o.a.c.s.VersionLoggerListener 115]   - Command line argument: -Djava.util.logging.config.file=/home/user/che/ws-agent/conf/logging.properties
[STDOUT] 2018-03-28 02:44:32,218[main]             [INFO ] [o.a.c.s.VersionLoggerListener 115]   - Command line argument: -Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager
[STDOUT] 2018-03-28 02:44:32,219[main]             [INFO ] [o.a.c.s.VersionLoggerListener 115]   - Command line argument: -Xms256m
[STDOUT] 2018-03-28 02:44:32,219[main]             [INFO ] [o.a.c.s.VersionLoggerListener 115]   - Command line argument: -Xmx2048m
[STDOUT] 2018-03-28 02:44:32,219[main]             [INFO ] [o.a.c.s.VersionLoggerListener 115]   - Command line argument: -XX:+UseG1GC
[STDOUT] 2018-03-28 02:44:32,220[main]             [INFO ] [o.a.c.s.VersionLoggerListener 115]   - Command line argument: -XX:+UseStringDeduplication
[STDOUT] 2018-03-28 02:44:32,220[main]             [INFO ] [o.a.c.s.VersionLoggerListener 115]   - Command line argument: -Djava.security.egd=file:/dev/./urandom
[STDOUT] 2018-03-28 02:44:32,221[main]             [INFO ] [o.a.c.s.VersionLoggerListener 115]   - Command line argument: -Dche.logs.dir=/home/user/che/ws-agent/logs
[STDOUT] 2018-03-28 02:44:32,221[main]             [INFO ] [o.a.c.s.VersionLoggerListener 115]   - Command line argument: -Dche.logs.level=INFO
[STDOUT] 2018-03-28 02:44:32,222[main]             [INFO ] [o.a.c.s.VersionLoggerListener 115]   - Command line argument: -Djuli-logback.configurationFile=file:/home/user/che/ws-agent/conf/tomcat-logger.xml
[STDOUT] 2018-03-28 02:44:32,222[main]             [INFO ] [o.a.c.s.VersionLoggerListener 115]   - Command line argument: -Djdk.tls.ephemeralDHKeySize=2048
[STDOUT] 2018-03-28 02:44:32,222[main]             [INFO ] [o.a.c.s.VersionLoggerListener 115]   - Command line argument: -Djava.protocol.handler.pkgs=org.apache.catalina.webresources
[STDOUT] 2018-03-28 02:44:32,223[main]             [INFO ] [o.a.c.s.VersionLoggerListener 115]   - Command line argument: -Dcom.sun.management.jmxremote
[STDOUT] 2018-03-28 02:44:32,223[main]             [INFO ] [o.a.c.s.VersionLoggerListener 115]   - Command line argument: -Dcom.sun.management.jmxremote.ssl=false
[STDOUT] 2018-03-28 02:44:32,224[main]             [INFO ] [o.a.c.s.VersionLoggerListener 115]   - Command line argument: -Dcom.sun.management.jmxremote.authenticate=false
[STDOUT] 2018-03-28 02:44:32,224[main]             [INFO ] [o.a.c.s.VersionLoggerListener 115]   - Command line argument: -Dche.local.conf.dir=/mnt/che/conf
[STDOUT] 2018-03-28 02:44:32,224[main]             [INFO ] [o.a.c.s.VersionLoggerListener 115]   - Command line argument: -Dcatalina.base=/home/user/che/ws-agent
[STDOUT] 2018-03-28 02:44:32,225[main]             [INFO ] [o.a.c.s.VersionLoggerListener 115]   - Command line argument: -Dcatalina.home=/home/user/che/ws-agent
[STDOUT] 2018-03-28 02:44:32,225[main]             [INFO ] [o.a.c.s.VersionLoggerListener 115]   - Command line argument: -Djava.io.tmpdir=/home/user/che/ws-agent/temp
[STDOUT] 2018-03-28 02:44:32,454[main]             [INFO ] [o.a.c.http11.Http11NioProtocol 525]  - Initializing ProtocolHandler ["http-nio-4401"]
[STDOUT] 2018-03-28 02:44:32,507[main]             [INFO ] [o.a.t.util.net.NioSelectorPool 67]   - Using a shared selector for servlet write/read
[STDOUT] 2018-03-28 02:44:32,511[main]             [INFO ] [o.a.catalina.startup.Catalina 617]   - Initialization processed in 952 ms
[STDOUT] 2018-03-28 02:44:32,562[main]             [INFO ] [c.m.JmxRemoteLifecycleListener 336]  - The JMX Remote Listener has configured the registry on port 32002 and the server on port 32102 for the Platform server
[STDOUT] 2018-03-28 02:44:32,562[main]             [INFO ] [o.a.c.core.StandardService 416]      - Starting service Catalina
[STDOUT] 2018-03-28 02:44:32,563[main]             [INFO ] [o.a.c.core.StandardEngine 259]       - Starting Servlet Engine: Apache Tomcat/8.5.11
[STDOUT] 2018-03-28 02:44:32,731[ost-startStop-1]  [INFO ] [o.a.c.startup.HostConfig 923]        - Deploying web application archive /home/user/che/ws-agent/webapps/ROOT.war
[STDOUT] 2018-03-28 02:44:39,211[ost-startStop-1]  [INFO ] [o.e.c.a.p.s.WorkspaceHolder 59]      - Workspace ID: workspacem31e6wpg2ly1kazb
[STDOUT] 2018-03-28 02:44:39,217[ost-startStop-1]  [INFO ] [o.e.c.a.p.s.WorkspaceHolder 60]      - API Endpoint: https://codenvy.io/api
[STDOUT] 2018-03-28 02:44:39,217[ost-startStop-1]  [INFO ] [o.e.c.a.p.s.WorkspaceHolder 61]      - User Token  : true
[STDOUT] Wed Mar 28 02:44:39 UTC 2018 - [localhost-startStop-1] Product-specified preferences called before plugin is started
[STDOUT] 2018-03-28 02:44:40,347[ost-startStop-1]  [WARN ] [org.reflections.Reflections 180]     - given scan urls are empty. set urls in the configuration
[STDOUT] 2018-03-28 02:44:40,390[ost-startStop-1]  [INFO ] [o.a.c.startup.HostConfig 987]        - Deployment of web application archive /home/user/che/ws-agent/webapps/ROOT.war has finished in 7,658 ms
[STDOUT] 2018-03-28 02:44:40,401[main]             [INFO ] [o.a.c.http11.Http11NioProtocol 570]  - Starting ProtocolHandler [http-nio-4401]
[STDOUT] 2018-03-28 02:44:40,418[main]             [INFO ] [o.a.catalina.startup.Catalina 668]   - Server startup in 7906 ms
[STDOUT] 2018/03/28 02:44:55 Start new terminal.
```

## 以ws-agent为例

installer所做的工作，是通过sh脚本文件将服务器包安装到本地，并启动服务

```
    [root@localhost /]# docker exec -ti a3e73848c7f1 /bin/bash
    bash-4.3# find -name ws-agent.tar.gz
    ./home/user/eclipse-che/lib/ws-agent.tar.gz
    ./data/lib/ws-agent.tar.gz
```