# MCCI's instructions for preparing a Conduit for shipping to customers

# Setting up the Conduit

If the Conduit is not an mLinux variant (is an AEP variant), then you must
re-flash the Conduit with an mLinux version.

## Reflashing the Conduit
TO BE SUPPLIED -- NOT NORMALLY REQUIRED

## Resetting to Factory Defaults
Reset the Conduit to factory defaults by powering on, then pressing and holding
the front-panel RESET button for 5 seconds.  Let the Conduit complete its 
reboot and reinitialization sequence.

# Setting up your Manufacturing Control System
This procedure requires that you have a VM with:
- Ubuntu-64 16.04LTS
- Ansible
- The other pre-requisites from https://github.com/IthacaThings/ttn-multitech-cm

## Ansible setup
You need to have a relatively recent verion.
Follow [the instructions](http://docs.ansible.com/ansible/latest/intro_installation.html#latest-releases-via-apt-ubuntu)
to get things set up properly.

After installation, check the version:
```shell
$ ansible --version
ansible 2.4.1.0
  config file = /etc/ansible/ansible.cfg
  configured module search path = [u'/home/tmm/.ansible/plugins/modules', u'/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python2.7/dist-packages/ansible
  executable location = /usr/bin/ansible
  python version = 2.7.12 (default, Nov 19 2016, 06:48:10) [GCC 5.4.0 20160609]
```

When things are working, `make syntax-check` should work, more or less (with some grumbles about jumphost.example.com).

