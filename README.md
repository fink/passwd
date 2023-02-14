Passwd-core package for the Fink Project
http://www.finkproject.org/

The package passwd-core and its associated splitoffs and related .info files
are in the Public Domain.

This package provides a unified method by which several administrative user
and group entries can be added to your user database by the various "passwd-*"
packages. These are needed to protect the data of several daemons (e.g. news 
server, database server, etc.).

USAGE: 
This package installs the "update-passwd" script, which takes arguments in the 
following format:

/usr/local/sbin/update-passwd [<user name> <description> <home directory> <shell>] <group name> <group membership>

In addition, during the install process the package will check whether fink is
using an automatic ID range (the default as of fink-0.33.0) and set itself to 
match, or will query the user whether automatic or manual allocation is 
desired.  This setting is saved in /usr/local/etc/passwd.conf.   

UID and GID entries for users can be assigned in several ways:

1)  If there is already a matching user and/or group on the system, it/they
will be regarded as satisfying the requirement of the package that needs them.  
Examples are:  users/groups installed by previous versions of the passwd-* 
packages, or deployed via a central directory service.  No action is needed.

2)  If there is no matching user, then the UID and GID will be either 
generated dynamically or via the administrator's design, depending on whether 
the AutoUid entry in /usr/local/etc/passwd.conf is "true" or "false".  

In the latter case, the files /usr/local/etc/passwd-fink and /usr/local/etc/group-fink
from the 'passwd-configs' package will first be queried for UID and GID values.
The administrator may edit these files to set up desired UID and GID values for
the system.  If the user is not present in those files (e.g. a new user package
was added to Fink and passwd-configs hasn't been updated yet), then the 
administrator will be prompted to enter values manually.

If the user entry is not created, either because the administrator elected not to
proceed with the install, or if the dynamic allocation range is full,
the passwd-* package will still be installed.  In such a case, we advise the
administrator to resolve the situation to make sure the user/group exists via one
of these methods:
* Change the dynamic allocation range and run 'fink reinstall passwd-<user>' if
  dynamic UID/GID allocation is in use.
* Edit /usr/local/etc/passwd-fink and /usr/local/etc/group-fink to include the desired UID/GID
  values and run 'fink reinstall passwd-<user>' if dynamic allocation isn't being
  used.  
* Get the user/group from a central directory server.
* Create the entries manually.
