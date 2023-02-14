Removing users/groups:

Fink doesn't remove package-specific users/groups, even when removing a passwd-*
pacakge, since these might have been deployed on the system by some other method.  
If you want to remove them, for example to change the legacy UID/GID from older 
passwd-* packages, the following commands should suffice:

```
sudo dscl . -delete /Users/<username>
sudo dscl . -delete /Groups/<groupname>
```

For example:

```
sudo dscl . -delete /Users/news
sudo dscl . -delete /Groups/news
```

to remove the "news" user installed by "passwd-news", or if installed manually. 
Then, to get a new UID/GID using dynamic allocation in a safe range, you could
just do

```
fink reinstall passwd-news
```

