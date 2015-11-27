![JEM](http://oi63.tinypic.com/huoc5d.jpg)

# **JEM**
JEM is an open source platform component, intended for injection of smart logic into containers. It gives extra abilities and extra automation for applications, designed to be run inside Linux containers.

## **JEM Core**
JEM Core is an application, that manages all of the JEM modules and libraries. Also, it does produce the command line interface for calling external functions, provided by application modules.

JEM Core Libraries represent a set of common system libraries for handling the operations, that are usually performed by application modules. These libraries comprise number of functions for processing system calls, mathematics, text processing, output processing, suppressing interactivity, testing, executing network-related operations, etc.


## **JEM Common libraries**  (blue color on a scheme)
**core.lib** - basic system library, that implements inheritance, including, trapping, executing, error throwing and other basic system operations.

**default.lib** - system library, used for handling default operations with application modules, e.g. adding descriptions, help management, visioning, defining usage rules, etc.

**output.lib** - system library, that specializes on output information management, like prompting errors and warnings, throwing JSON responses to STDOUT or STDERR outputs.

**envinfo.lib** - system library, that helps JEM application to retrieve the required information (like which kind of environment it is run at and list of dependent libraries, that needs to be included for managing stack) from container’s metadata and to pass it to JEM.

**log.lib** - system library, that implements logging functionality.

**xml.lib** - system library, that implements XML processing operations (deprecated).

**math.lib** - system library, that implements a set of mathematical operations.

**string.lib** - system library, that implements a set of text processing operations.

**net.lib** - system library, that implements common network-related operations like URL validation, parsing PORT/HOST/URI from URL, downloading files, etc.

**tests.lib** - system library, that tests external functions, implemented in application modules.

**uninterract.lib** - system library for suppressing applications input (currently, it’s used as a GIT client wrapper only).

**config.lib** - system library, used for managing configuration files.

**path-manip.lib** - system library, that is intended for manipulating paths.

**sendmailextip.lib** - library, that enables Sendmail for containers with external IP attached.

**fsutils.lib** - library, that handles operations with file system.

**extendperm.lib** - library, that implements the extended permissions’ management for files and directories.

**svn.lib** - library, that implements SVN management stuff

**git.lib** - library, that implements GIT management stuff

## **Application Layer Modules**  (green color on a scheme)
Application Layer Modules are designed for managing different application stacks inside containers. Such operations can be performed by Jelastic Platform Core or manually, with the help of command line interface. Each application module usually has functions, that are externally available from JEM. In case a module has a list of implementations, needed for different kinds of stacks, it includes specific extra libraries (each of which have unique implementation recipes, created specifically for a particular stack). Functions inside stack libraries are internal and cannot be called other than by parent module of this library.

The list of application modules includes:

**ssl.module** - implements basic functionality for enabling/disabling/configuring SSL certificates for:
Java application servers: tomcat, glassfish, jetty;
Load balancer: nginx;
PHP application servers: httpd (Apache 2) and php-fpm (NGINX-PHP).

It also requires a list of special libraries for managing each application server separately.

**vcs.module** - implements VCS functionality for application stacks, like VCS projects management, checkout and update of projects, etc. For now, only Git and SVN version control systems are available for use. 

***compute.module** - is used for deploying users’ applications into application servers. It also requires a list of dependent libraries with unique deployment procedures declared for different kinds of application servers.

**engine.module** - is used for switching JDK and PHP engines’ versions within the corresponding (i.e. running Java or PHP apps) application servers. 

**setmem.module** - sets up the proper memory configuration inside application stack accordingly to the amount of memory, available in a container.

**phpext.module** - is used for enabling/disabling PHP extensions for PHP application servers.

**apache2ext.module** - is used for enabling/disabling apache2 modules (deprecated).

**keystore.module** - is responsible for managing Java keystores, including handling operations with certificates (like certificate modules’ validation, getting list of alternative DNS names, retrieving certificate expiration date, downloading it from storage and much more).

**modules.module** - is used for processing information on other modules, listing their external functions and descriptions for these functions (if such are set in a module).

**iptables.module** - implements firewall iptables settings’ management, like addition/removal of rules, etc.

**balancer.module** - handles automatic configuration of load balancer nodes (upstreams generation, sticky sessions management, etc)

**cartridge.module** - is used for installing OpenShift v.1 cartridges.

**command.module** - common JEM module, that handles executing commands inside VZ containers.

**configure.module** - is responsible for environment configuration.

**maven.module** - implements the Maven build nodes’ management.

**docker.module** - handles the Docker-based containers’ management.

**dumper.module** - is used for dumping and restoring DBs at different database servers.

**export.module** - is used for exporting user data from a container.

**filemanager.module** - is designed for the container’s file system management.

**firewall.module** - manages sets of common and custom firewall rules.

**memcached.module** - is responsible for the memcached security management

**passwd.module** - manages authentication at different application servers and databases.

**router.module** - manages endpoints on Shared LB nodes.

**service.module** - is used for the application services’ management.

**storage.module** - is responsible for the shared storage management.

**unpack.module** - handles restoring of the imported application’s data.

**user.module** - implements users’ management.

## **JEM Application Libraries**  (orange color on a scheme)

**apache-php-deploy.lib** - implements the process of PHP applications deployment in Apache using mod_php5/7.

**apache-php-engine.lib** - handles PHP versions’ switching for apache2 and mod_php.

**apache-php-ssl.lib** - manages SSL certification for apache2.

**apache-ruby-deploy.lib** - implements the process of Ruby applications deployment in Apache using mod_ruby.

**balancer-nginx.lib** - handles automatic configuration of NGINX load-balancing nodes.

**cartridge-common.lib** - is used for converting OpenShift v.1 cartridges into VZ templates and manages them.

**cartridge-deploy.lib** - implements deployment of OpenShift v.1 cartridges.

**cartridge-dumper.lib** - dummy library (not implemented).

**cartridge-engine.lib** - dummy library (not implemented).

**cartridge-extipch.lib** - dummy library (not implemented).

**cartridge-passwd.lib** - dummy library (not implemented).

**common-extipch.lib** - injects extra logic in events of external IPv4 address addition/removal at a container.

**couchdb-passwd.lib** - implements the password reset function for CouchDB server.

**exceptor.lib** - is responsible for handling general exceptions in VZ containers.

**glassfish-deploy.lib** - implements the process of Java applications deployment to GlassFish server.

**glassfish-extipch.lib** - implements extra logic in events of external IPv4 address addition/removal  at GlassFish container.

**glassfish-passwd.lib** -  implements the password reset function for GlassFish server.

**glassfish-replication.lib** - manages clustering at GlassFish server.

**glassfish-ssl.lib** - implements the SSL certificates’ management at GlassFish server.

**glassfish-tools.lib** - includes a set of tools for the GlassFish cluster management.

**java-common-deploy.lib** - common library, which implements the general deployment concept for all Java application servers.

**java-common-engine.lib** - common library, that handles Java engine versions’ switching inside a container.

**jetty-deploy.lib** - implements the deployment automation for Jetty application server.

**jetty-replication.lib** - implements the clustering automation for Jetty application server.

**jetty-ssl.lib** - implements the SSL certificates’ management at Jetty server.

**mongo-passwd.lib** - handles the password reset function for MongoDB server.

**mysql-dumper.lib** - implements the database dumping operations at MySQL, MariaDB, Percona servers.

**mysql-passwd.lib** - handles the password resetting function for MySQL, MariaDB, Percona, etc.

**nginx-php-deploy.lib** - implements the deployment automation for php-fpm (NGINX-PHP) container.

**nginx-php-engine.lib** - handles PHP engine versions’ switching inside php-fpm (NGINX-PHP) container.

**nginx-php-ssl.lib** - implements the SSL certificates’ management at NGINX server.

**nginx-ruby-deploy.lib** - implements the deployment automation for NGINX-Ruby application server. 

**nginx-ruby-engine.lib** - handles Ruby engine versions’ switching inside a container.

**nodejs-common-engine.lib** - common library, that handles Node.js engine versions’ switching inside a container.

**path-manip.lib** - is responsible for paths’ management and switching.

**php-common-deploy.lib** - common library, that implements the general deployment automation for all PHP application servers.

**php-common-engine.lib** - common library, that handles PHP engine versions’ switching inside a container.

**php-setmem.lib** - is responsible for the automatic memory optimizations for PHP.

**postgres-dumper.lib** - implements the database dumping operations for PostgreSQL server.

**postgres-passwd.lib** - handles the password resetting function for PostgreSQL server.

**python-common-engine.lib** - common library, that handles Python engine versions’ switching inside a container.

**ruby-common-deploy.lib** - common library, which implements the general deployment concept for all Ruby application servers.

**ruby-common-engine.lib** - common library, that handles Ruby engine versions’ switching inside a container.

**ruby-common.lib** - common library, that implements RVM/Bundles management

**tomcat-deploy.lib** - implements deployment automation for Tomcat server.

**tomcat-replication.lib** - is responsible for clustering management at Tomcat servers, that are based on Catalina Tribes and Delta Manager.

**tomcat-ssl.lib** - implements SSL certificates management for Tomcat/TomEE servers.

**uninterract.lib** - manages interactive command-line applications in non-interactive way.

**user-common.lib** - common library, that is responsible for users’ management inside a container.

**user-gate.lib** - handles users’ management via SSH gateway, a proprietary Jelastic® Infrastructure Component.

**virtuozzo.lib** - implements a set of functions, related to Virtuozzo containers’ management.

**vzexec.lib** - handles remote commands’ execution on Virtuozzo/OpenVZ containers.
