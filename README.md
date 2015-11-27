![JEM](http://oi63.tinypic.com/huoc5d.jpg)

# **JEM**
**JEM** is an open source platform component, intended for injection of smart logic into containers. It gives extra abilities and extra automation for applications, designed to be run inside Linux containers.

## **JEM Core**
**JEM Core** is an application, that manages all of the JEM modules and libraries. Also, it does produce the command line interface for calling external functions, provided by application modules.

**JEM Core Libraries** represent a set of common system libraries for handling the operations, that are usually performed by application modules. These libraries comprise number of functions for processing system calls, mathematics, text processing, output processing, suppressing interactivity, testing, executing network-related operations, etc.


## **JEM Common libraries**  (blue-colored)
_**core.lib**_ - basic system library, that implements inheritance, including, trapping, executing, error throwing and other basic system operations.

_**default.lib**_ - system library, used for handling default operations with application modules, e.g. adding descriptions, help management, visioning, defining usage rules, etc.

_**output.lib**_ - system library, that specializes on output information management, like prompting errors and warnings, throwing JSON responses to *STDOUT* or *STDERR* outputs.

_**envinfo.lib**_ - system library, that helps JEM application to retrieve the required information (like which kind of environment it is run at and list of dependent libraries, that needs to be included for managing stack) from container’s metadata and to pass it to JEM.

_**log.lib**_ - system library, that implements logging functionality.

_**xml.lib**_ - system library, that implements XML processing operations (deprecated).

_**math.lib**_ - system library, that implements a set of mathematical operations.

_**string.lib**_ - system library, that implements a set of text processing operations.

_**net.lib**_ - system library, that implements common network-related operations like URL validation, parsing *PORT*/*HOST*/*URI* from URL, downloading files, etc.

_**tests.lib**_ - system library, that tests external functions, implemented in application modules.

_**uninterract.lib**_ - system library for suppressing applications input (currently, it’s used as a GIT client wrapper only).

_**config.lib**_ - system library, used for managing configuration files.

_**path-manip.lib**_ - system library, that is intended for manipulating paths.

_**sendmailextip.lib**_ - library, that enables Sendmail for containers with external IP attached.

_**fsutils.lib**_ - library, that handles operations with file system.

_**extendperm.lib**_ - library, that implements the extended permissions’ management for files and directories.

_**svn.lib**_ - library, that implements SVN management stuff

_**git.lib**_ - library, that implements GIT management stuff

## **Application Layer Modules**  (green-colored)
**Application Layer Modules** are designed for managing different application stacks inside containers. Such operations can be performed by Jelastic Platform Core or manually, with the help of command line interface. Each application module usually has functions, that are externally available from JEM. In case a module has a list of implementations, needed for different kinds of stacks, it includes specific extra libraries (each of which have unique implementation recipes, created specifically for a particular stack). Functions inside stack libraries are internal and cannot be called other than by parent module of this library.

The list of application modules includes:

_**ssl.module**_ - implements basic functionality for enabling/disabling/configuring SSL certificates for:
* Java application servers: *tomcat*, *glassfish*, *jetty*;
* Load balancer: *nginx*;
* PHP application servers: *httpd* (Apache 2) and *php-fpm* (NGINX-PHP).

It also requires a list of special libraries for managing each application server separately.

_**vcs.module**_ - implements VCS functionality for application stacks, like VCS projects management, checkout and update of projects, etc. For now, only Git and SVN version control systems are available for use. 

_**compute.module**_ - is used for deploying users’ applications into application servers. It also requires a list of dependent libraries with unique deployment procedures declared for different kinds of application servers.

_**engine.module**_ - is used for switching JDK and PHP engines’ versions within the corresponding (i.e. running Java or PHP apps) application servers. 

_**setmem.module**_ - sets up the proper memory configuration inside application stack accordingly to the amount of memory, available in a container.

_**phpext.module**_ - is used for enabling/disabling PHP extensions for PHP application servers.

_**apache2ext.module**_ - is used for enabling/disabling *apache2* modules (deprecated).

_**keystore.module**_ - is responsible for managing Java keystores, including handling operations with certificates (like certificate modules’ validation, getting list of alternative DNS names, retrieving certificate expiration date, downloading it from storage and much more).

_**modules.module**_ - is used for processing information on other modules, listing their external functions and descriptions for these functions (if such are set in a module).

_**iptables.module**_ - implements firewall iptables settings’ management, like addition/removal of rules, etc.

_**balancer.module**_ - handles automatic configuration of load balancer nodes (upstreams generation, sticky sessions management, etc)

_**cartridge.module**_ - is used for installing OpenShift v.1 cartridges.

_**command.module**_ - common JEM module, that handles executing commands inside VZ containers.

_**configure.module**_ - is responsible for environment configuration.

_**maven.module**_ - implements the Maven build nodes’ management.

_**docker.module**_ - handles the Docker-based containers’ management.

_**dumper.module**_ - is used for dumping and restoring DBs at different database servers.

_**export.module**_ - is used for exporting user data from a container.

_**filemanager.module**_ - is designed for the container’s file system management.

_**firewall.module**_ - manages sets of common and custom firewall rules.

_**memcached.module**_ - is responsible for the *memcached* security management

_**passwd.module**_ - manages authentication at different application servers and databases.

_**router.module**_ - manages endpoints on Shared LB nodes.

_**service.module**_ - is used for the application services’ management.

_**storage.module**_ - is responsible for the shared storage management.

_**unpack.module**_ - handles restoring of the imported application’s data.

_**user.module**_ - implements users’ management.

## **JEM Application Libraries**  (green-colored)

_**apache-php-deploy.lib**_ - implements the process of PHP applications deployment in Apache using *mod_php5/7*.

_**apache-php-engine.lib**_ - handles PHP versions’ switching for *apache2* and *mod_php*.

_**apache-php-ssl.lib**_ - manages SSL certification for *apache2*.

_**apache-ruby-deploy.lib**_ - implements the process of Ruby applications deployment in Apache using *mod_ruby*.

_**balancer-nginx.lib**_ - handles automatic configuration of NGINX load-balancing nodes.

_**cartridge-common.lib**_ - is used for converting OpenShift v.1 cartridges into VZ templates and manages them.

_**cartridge-deploy.lib**_ - implements deployment of OpenShift v.1 cartridges.

_**cartridge-dumper.lib**_ - dummy library (not implemented).

_**cartridge-engine.lib**_ - dummy library (not implemented).

_**cartridge-extipch.lib**_ - dummy library (not implemented).

_**cartridge-passwd.lib**_ - dummy library (not implemented).

_**common-extipch.lib**_ - injects extra logic in events of external IPv4 address addition/removal at a container.

_**couchdb-passwd.lib**_ - implements the password reset function for CouchDB server.

_**exceptor.lib**_ - is responsible for handling general exceptions in VZ containers.

_**glassfish-deploy.lib**_ - implements the process of Java applications deployment to GlassFish server.

_**glassfish-extipch.lib**_ - implements extra logic in events of external IPv4 address addition/removal  at GlassFish container.

_**glassfish-passwd.lib**_ -  implements the password reset function for GlassFish server.

_**glassfish-replication.lib**_ - manages clustering at GlassFish server.

_**glassfish-ssl.lib**_ - implements the SSL certificates’ management at GlassFish server.

_**glassfish-tools.lib**_ - includes a set of tools for the GlassFish cluster management.

_**java-common-deploy.lib**_ - common library, which implements the general deployment concept for all Java application servers.

_**java-common-engine.lib**_ - common library, that handles Java engine versions’ switching inside a container.

_**jetty-deploy.lib**_ - implements the deployment automation for Jetty application server.

_**jetty-replication.lib**_ - implements the clustering automation for Jetty application server.

_**jetty-ssl.lib**_ - implements the SSL certificates’ management at Jetty server.

_**mongo-passwd.lib**_ - handles the password reset function for MongoDB server.

_**mysql-dumper.lib**_ - implements the database dumping operations at MySQL, MariaDB, Percona servers.

_**mysql-passwd.lib**_ - handles the password resetting function for MySQL, MariaDB, Percona, etc.

_**nginx-php-deploy.lib**_ - implements the deployment automation for *php-fpm* (NGINX-PHP) container.

_**nginx-php-engine.lib**_ - handles PHP engine versions’ switching inside *php-fpm* (NGINX-PHP) container.

_**nginx-php-ssl.lib**_ - implements the SSL certificates’ management at NGINX server.

_**nginx-ruby-deploy.lib**_ - implements the deployment automation for NGINX-Ruby application server. 

_**nginx-ruby-engine.lib**_ - handles Ruby engine versions’ switching inside a container.

_**nodejs-common-engine.lib**_ - common library, that handles Node.js engine versions’ switching inside a container.

_**path-manip.lib**_ - is responsible for paths’ management and switching.

_**php-common-deploy.lib**_ - common library, that implements the general deployment automation for all PHP application servers.

_**php-common-engine.lib**_ - common library, that handles PHP engine versions’ switching inside a container.

_**php-setmem.lib**_ - is responsible for the automatic memory optimizations for PHP.

_**postgres-dumper.lib**_ - implements the database dumping operations for PostgreSQL server.

_**postgres-passwd.lib**_ - handles the password resetting function for PostgreSQL server.

_**python-common-engine.lib**_ - common library, that handles Python engine versions’ switching inside a container.

_**ruby-common-deploy.lib**_ - common library, which implements the general deployment concept for all Ruby application servers.

_**ruby-common-engine.lib**_ - common library, that handles Ruby engine versions’ switching inside a container.

_**ruby-common.lib**_ - common library, that implements RVM/Bundles management

_**tomcat-deploy.lib**_ - implements deployment automation for Tomcat server.

_**tomcat-replication.lib**_ - is responsible for clustering management at Tomcat servers, that are based on Catalina Tribes and Delta Manager.

_**tomcat-ssl.lib**_ - implements SSL certificates management for Tomcat/TomEE servers.

_**uninterract.lib**_ - manages interactive command-line applications in non-interactive way.

_**user-common.lib**_ - common library, that is responsible for users’ management inside a container.

_**user-gate.lib**_ - handles users’ management via SSH gateway, a proprietary *Jelastic® Infrastructure Component*.

_**virtuozzo.lib**_ - implements a set of functions, related to Virtuozzo containers’ management.

_**vzexec.lib**_ - handles remote commands’ execution on Virtuozzo/OpenVZ containers.
