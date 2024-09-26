Rapid Construct Massive
=======================

RCM works with generate anything with goals to simplify any routine task.

## Install

Login as root, then make sure `wget` command is exist.

```
apt update
apt install -y wget
```

Download from Github.

```
wget git.io/rcm
chmod a+x rcm
```

You can put `rcm` file anywhere in $PATH:

```
sudo mv rcm -t /usr/local/bin
```

## How to use

**General**

Just execute.

```
rcm
```

```
Usage: rcm [options] [<command> [ -- [options]]]
```

## Extension

Inspired from Git LFS which is the extension of Git, we have some extension of RCM:

 1. [Drupal Auto Installer](https://github.com/ijortengab/drupal-autoinstaller)
 2. [ISPConfig Auto Installer](https://github.com/ijortengab/ispconfig-autoinstaller)

## Tips

Always fast.

```
alias rcm='rcm --fast'
```
