![JEM](http://oi63.tinypic.com/huoc5d.jpg)

## **JEM **
JEM is an opensource component that is used for injection of smart logic into containers, that gives extra  abilities and extra automation to applications, that are designed to run inside Linux containers. 

## **JEM Core**
Jem Core is an application that manage all the JEM modules and libraries. Also it does produce command line interface to external functions that are available from application modules.

Jem Core Libraries is a set of JEM common system libraries that handling all the operations that are usually performed by the application modules, this librariles includes a set of functions for proccessing system calls, mathematics, text proccessing, output proccessing, operations related to network, suppressing interactivity, testing etc.

## **JEM Common libraries**
**core.lib** - basic JEM system library which implements inheritance, including, traping, executing, error throwing and othe basic system operations.

**default.lib** - JEM system library for managing application modules default operations like module description, managing help,  visioning, usage rules, etc.

**output.lib** -  JEM system library specialized on managing output in different ways like prompting errors, warning, throwing JSON responces to STDOUT or  STDERR output.

**envinfo.lib** - JEM system library that helps JEM application to get information from containers metadata to let JEM know which kind of environment it is executing from and which kind of dependecy libraries need to be includes for managing stack.

**log.lib** - JEM system library that implements logging  functionality.

**xml.lib** - JEM system library that implements XML processing operations (deprecated).

**math.lib** - JEM system library that implements a set of mathematics operations.

**string.lib** - JEM system library that implements a set of text processing oprations.

**net.lib** -  JEM system library that implements common operations related to network like validating URL, parsing PORT/HOST/URI  from URL,  downloading files, etc.

**tests.lib** - JEM system library that is used for testing external functions implemented in application modules.

**uninterract.lib** - JEM system library that is used for suppressing applications input (for now only used as GIT client wrapper)

**config.lib** - JEM system library that is used for managing configuration files.

**path-manip.lib** - JEM system library for manipulating paths.

**sendmailextip.lib** - JEM library that enables sendmail for containers with own external IPs. 

**fsutils.lib** - JEM library that responsible for filesystem operations

**extendperm.lib** - JEM library that implements extended permissions management on files and directories

**svn.lib** - JEM library that implements SVN management stuff

**git.lib**  - JEM library that implements GIT management stuff

## **Application Layer Modules**
Application Layer Modules is a set of modules that are created for managing different application stacks inside containers by the Core of Jelastic Platform or manually with a help of command line interface.
Each application module usually has functions that are externally available from JEM, in case if module has a list of implementations needed for different kind of stacks - it includes specific extra libraries that has unique implementation recipes created special for each stack separately. Functions inside stack libraries are internal and cannot be called by anything except parent module of this library.

Application modules includes:

**ssl.module** -  JEM application modules that implements basic functionality for enabling/disabling/configuring SSL certificates for JAVA application servers like: tomcat, glassfish, jetty;  loadbalancer like: nginx, application servers for serving  php like: httpd (apache2) and nginx.  Module for managing SSL also requires a list of special libraries for managing each application server separately.

**vcs.module** -  JEM application module that implements managing VCS functionality for stack  applications.  For now only GIT and SVN version control systems are available for use. VCS module implements functionality  like managing VCS projects,  checkout and update projects etc.

**compute.module** - JEM application module that is used for deploying users applications into application servers. This module requires a list of dependent libraries with unique deployment procedures for different kind of application servers.

**engine.module** -  JEM application modules that is used for switching so-called engines inside application servers like: switching between  JDK versions for application servers that are running java web applications and switching between PHP versions for application servers that are running PHP.

**setmem.module** -  JEM application module that is used for seeting up memory configuration inside application stack depends it amount of memory available in container.

**phpext.module** -   JEM application module that is used for enabling / disabling PHP extensions for application servers that are running PHP.

**apache2ext.module** -  JEM application module that is used for enabling / disabling apache2 modules.

**keystore.module** -   JEM application module that is responsible for managing java keystores, also including operations like ceritificate modules validation, receiving a list of DNS alternative names from ceritificate, getting expiration date of given ceritificate, downloading certificates from storage and much more.

**modules.module** -  JEM application module is used for processing information about other modules, listing it’s external functions and getting it’s funcitons description if it was set  in a module.

**iptables.module** -  JEM application module that is used for managing iptables firewall settings including adding / removing rules etc.

**balancer.module**  -  JEM application module that handles for automation  loadbalancers.
**cartridge.module** -  JEM application module that does installation for OpenShift cartridges v1.

**command.module** - JEM common module for executing commands inside VZ container

**configure.module**  -  JEM application module that is responsible for environment configuration.

**maven.module**  -  JEM application module that is responsible for Maven management

**docker.module**  -  JEM application module that is responsible for Docker management

**dumper.module** -  JEM application module that is responsible for dumping/restoring dataceses of different database servers

**export.module** - JEM application module that is desinged for exporting users data from container

**filemanager.module** - JEM application module that is desinged for managing filesystem

**firewall.module** - JEM application module that is desinged for managing common and custom firewall rules set

**memcached.module** - JEM application module that is responsible for memcached security management

**passwd.module** - JEM application module that is managing authentication for different application servers and databases

**router.module** - JEM application module that is managing endpoints on resolver nodes

**service.module** - JEM application service management module

**storage.module** - JEM application module for shared storage management 

**unpack.module** - JEM application module for restoring previosly imported applications data

**user.module** - JEM application module designed for user management


**JEM Application Libraries**

**apache-php-deploy.lib** - JEM library that implements deployment process for PHP applications in Apache using mod_php5/7 

**apache-php-engine.lib** - JEM library that implements switching PHP versions for Apache2 and mod_php

**apache-php-ssl.lib** - JEM for managing SSL certifications in Apache2

**apache-ruby-deploy.lib** - JEM library that implements deployment process for Ruby  applications in Apache using mod_ruby 

**balancer-nginx.lib** - JEM library that implements NGINX loadbalancing automatic configuration 

**cartridge-common.lib** - JEM library that is used for converting OpenShift v1 cartridges to VZ templates and managing them

**cartridge-deploy.lib** - JEM library implements deployment of OpenShift v1 cartiridge 

**cartridge-dumper.lib** - JEM dummy library (not implemented). 

**cartridge-engine.lib** - JEM dummy library (not implemented).  

**cartridge-extipch.lib** - JEM dummy library (not implemented). 

**cartridge-passwd.lib** - JEM dummy library (not implemented). 

**common-extipch.lib** - JEM library that inject extra logic in cases if external IPv4 was added/removed in container.

**couchdb-passwd.lib** - JEM library that implements password reset for CouchDB
exceptor.lib - JEM library that is responsible for handling general exceptions in VZ containers

**glassfish-deploy.lib** - JEM library that implements deploy for GlassFish server

**glassfish-extipch.lib** - JEM library that implements extra logic that works in case of adding external IPv4 to GF container

**glassfish-passwd.lib** - JEM library that implements password reset for GlassFish server

**glassfish-replication.lib** - JEM library that manage clusterring in GlassFish

**glassfish-ssl.lib** - JEM library that implements SSL certificates management
for GlassFish

**glassfish-tools.lib** - JEM library that has a set of tools for managing GlassFish cluster.

**java-common-deploy.lib** - JEM library that implements general deployment concept for Java application servers

**java-common-engine.lib** -JEM library that adds ablility to switch different Java versions inside the container.

**jetty-deploy.lib** - JEM library that implements deployment automation for Jetty

**jetty-replication.lib** - JEM library that implements clusterring automation for Jetty

**jetty-ssl.lib** - JEM library that implements SSL manament layer for Jetty servers.

**mongo-passwd.lib** - JEM library that implements password reset for MongoDB

**mysql-dumper.lib** - JEM library that implements dumping databases operations in MySQL

**mysql-passwd.lib** - JEM library that implements password reset for MySQL, MariaDB, Percona, etc

**nginx-php-deploy.lib** - JEM library that implements deployment automation for PHP-FPM container

**nginx-php-engine.lib** - JEM library that implements swithing PHP engines in container.

**nginx-php-ssl.lib** - JEM library that implements SSL manament layer for NGINX 
server.

**nginx-ruby-deploy.lib** - JEM library that implements deployment automation for NGINX+Ruby server

**nginx-ruby-engine.lib** - JEM common library that implements general concepts for switching Ruby engines.

**nodejs-common-engine.lib** - JEM common library that implements general concepts for switching NodeJS engines.

**path-manip.lib** - JEM library that implements path management/switching actions

**php-common-deploy.lib** - JEM common library that implements general deployment automation for PHP 

**php-common-engine.lib** - JEM common library that implements general concepts for switching PHP engines.

**php-setmem.lib** -JEM library that implements memory optimizations for PHP.
postgres-dumper.lib - JEM library that implements database dumping for PostgreSQL server.

**postgres-passwd.lib** - JEM library that implements password reset for PostgreSQL server.

**python-common-engine.lib** - JEM common library that implements general concepts for switching Python engines.

**ruby-common-deploy.lib** - JEM common library that implements general concepts for switching Python engines.

**ruby-common-engine.lib** - JEM common library that implements general concepts for switching Ruby engines.

**ruby-common.lib** - JEM common library that implements general concepts for switching Ruby engines.

**tomcat-deploy.lib** - JEM library that implements deployment automation for Tomcat servers.

**tomcat-replication.lib** - JEM library that implements clusterring management for Tomcat servers

**tomcat-ssl.lib** - JEM library that implements SSL certificates management for the Tomcat application server.

**uninterract.lib** - JEM library that implements management of interective command-line applications in non-interractive way.

**user-common.lib** - JEM library that implements users management inside the container

**user-gate.lib** - JEM library that implements a containers management to make containers compartible with SSH-gaway service provided by Jelastic (R)
 
**virtuozzo.lib** - JEM library that implements a set functions related to Virtuozzo containers management

**vzexec.lib** - JEM library that implements remote commands execution on VZ containers
