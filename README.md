# Manufacturer's instructions for preparing a Conduit for shipping to customers

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

TODO: have a simpler setup.

# Setting up Conduit for Ansible

From the [factory](http://www.multitech.net/developer/software/mlinux/getting-started-with-conduit-mlinux/), 
the Conduit's initial IP address is `192.168.2.1`. 

In this first step, we'll do the following.
1. Connect to the Conduit via a dedicated Ethernet port.
2. Set up the Conduit for DHCP and prepare for Ansible control.
3. Restart.

## PC Setup Prerequisites

You need a specially-prepared NAT-ing IPv4 router -- a Wi-Fi gateway + router works well -- plus a Ubuntu 16.04 LTS amd64 PC. (This PC can be running in a VM on Windows.)

1. Make sure the NAT-ing router is connected to the Internet. DMZ is fine; or it can be on a corporate network.
2. Configure the NAT-ing router so that it's inner network is `192.168.2.0/24`.
3. Make sure the NAT-ing router's address on the inner network is `192.168.2.254`.
4. Set up the Ubuntu PC (or Windows host that is hosting the Ubuntu VM) a static network address on the NAT. Recommended address is `192.168.2.127`.
5. If you're doing one Conduit at a time, set up the NAT-ing router so that the dynamic address pool begins *and ends* with `192.168.2.1`. This means that the Conduit under test will be at `192.168.2.1` even after the switch to DNS. 


## Attaching the Conduit while in Factory State

1. Verify that networking is running, by pinging `8.8.8.8` from the Ubuntu system.

2. If necessary reset the Conduit to factory state.

3. Connect the Conduit to the router using the Ethernet cable and let it boot up.

4. Ping the Conduit:
    ```shell
    $ ping 192.168.2.1
    PING 192.168.2.1 (192.168.2.1) 56(84) bytes of data.
    64 bytes from 192.168.2.1: icmp_seq=1 ttl=64 time=0.805 ms
    64 bytes from 192.168.2.1: icmp_seq=2 ttl=64 time=0.780 ms
    ^C
    --- 192.168.2.1 ping statistics ---
    2 packets transmitted, 2 received, 0% packet loss, time 1024ms
    rtt min/avg/max/mdev = 0.780/0.792/0.805/0.030 ms
    ```

5. SSH to the Conduit:
    ```shell
    $ ssh root@192.128.2.1
    $ ssh root@192.168.2.1
    Password: 
    Last login: Sat Sep 30 02:06:07 2017 from 192.168.2.127
    root@mtcdt:~#
    ```

   At this point, the time is very likely to be wrong. The upstream gateway isn't set, so you can't do anything. And Ansible isn't set up. But we're about to change all that.

6. Check the mLinux version:
    ```shell
    root@mtcdt:~# cat /etc/mlinux-version
    mLinux 3.3.13
    Built from branch: (detachedfromecc3f47)
    Revision: ecc3f47d9fb7e9477aeb0bf2503217aa64082afd
    ```
   If the version is not at least 3.3.1, **stop** -- you have to upgrade to a newer version of mLinux before you can proceed.

## Set the Conduit to use DHCP and connect to the network
1. **Via USB**: On the Conduit, edit `/etc/network/interfaces` to enable DHCP client.
    ```
    # Wired interface
    auto eth0
    iface eth0 inet dhcp 
    ```

2. Connect to a network with DHCP and force a cycle.  **Via USB**:
    ```shell
    root@mtcdt:~# ifdown eth0 ; ifup eth0
    udhcpc (v1.22.1) started
    Sending discover...
    Sending discover...
    Sending select for 192.168.2.1...
    Lease of 192.168.2.1 obtained, lease time 86400
    /etc/udhcpc.d/50default: Adding DNS 192.168.2.254
    root@mtcdt:~#
    ```

3. Verify that ping is working. **Via USB**:
     ```
    root@mtcdt:~# ping 8.8.8.8
    PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
    64 bytes from 8.8.8.8: icmp_seq=1 ttl=54 time=9.31 ms
    64 bytes from 8.8.8.8: icmp_seq=2 ttl=54 time=8.70 ms
    64 bytes from 8.8.8.8: icmp_seq=3 ttl=54 time=8.99 ms
    64 bytes from 8.8.8.8: icmp_seq=4 ttl=54 time=8.94 ms
    64 bytes from 8.8.8.8: icmp_seq=5 ttl=54 time=9.06 ms
    ^C
    --- 8.8.8.8 ping statistics ---
    5 packets transmitted, 5 received, 0% packet loss, time 4006ms
    rtt min/avg/max/mdev = 8.703/9.005/9.318/0.215 ms
    root@mtcdt:~#
    ```

## Set time and Install Prerequisites

Return to the Ubuntu PC, and connect via Ethernet

1. Using the address noted above (`192.168.2.1` in this case, but it might be different if testing multiple Conduits in parallel), ssh into the Conduit.
    ```shell
    $ ssh root@192.168.2.1
    Password: 
    Last login: Sat Sep 30 02:06:07 2017 from 192.168.2.127
    root@mtcdt:~#
    ```

2. Install Prerequisites for Ansible. Cut and paste the following.
    ```shell
    ntpdate -ub pool.ntp.org && opkg update && opkg install python-pkgutil && opkg install python-distutils
    ```
   You'll see something like this:
    ```
     3 Nov 00:45:25 ntpdate[833]: step time server 204.9.54.119 offset offset 2923907.893520  sec
    Downloading http://multitech.net/mlinux/feeds/3.3.13/all/Packages.gz.
    Inflating http://multitech.net/mlinux/feeds/3.3.13/all/Packages.gz.
    Updated list of available packages in /var/lib/opkg/mlinux-all.
    Downloading http://multitech.net/mlinux/feeds/3.3.13/arm926ejste/Packages.gz.
    Inflating http://multitech.net/mlinux/feeds/3.3.13/arm926ejste/Packages.gz.
    Updated list of available packages in /var/lib/opkg/mlinux-arm926ejste.
    Downloading http://multitech.net/mlinux/feeds/3.3.13/mtcdt/Packages.gz.
    Inflating http://multitech.net/mlinux/feeds/3.3.13/mtcdt/Packages.gz.
    Updated list of available packages in /var/lib/opkg/mlinux-mtcdt.
    Installing python-pkgutil (2.7.3-r0.3.0) to root...
    Downloading http://multitech.net/mlinux/feeds/3.3.13/arm926ejste/python-pkgutil_2.7.3-  r0.3.0_arm926ejste.ipk.
    Configuring python-pkgutil.
    Installing python-distutils (2.7.3-r0.3.0) to root...
    Downloading http://multitech.net/mlinux/feeds/3.3.13/arm926ejste/python-distutils_2.7.3-    r0.3.0_arm926ejste.ipk.
    Configuring python-distutils.
    ```

Now that we have the Conduit set up, our next step is to set up the configuration.

# Dealing with Organizations

## Background

This Ansible system manages _**gateways**_.

Gateways are associated with _**organizations**_. The gateways for an organization are managed by an _**ops team**_.  One ops team may manage gateways for several organizations.

This document is intended for use by MCCI in its role as an ops team.

The data about gateways and organizations must not be shared indiscriminately. On the other hand, the scripts and procedures for configuration management are intended to be shared (both for code reuse, and for review).

So the ops team must separate the gateway and organization data from the procedures.

For example, at MCCI we now are managing:

- MCCI's gateways in Ithaca and New York
- Lancaster's gateways in California
- The Things Network Ithaca's gateways
- The Things Network New York's gateways
- The Hualian Garden gateway

The obvious way to separate the data is to create a directory for the organization that is separate from the data for the procedure.

So the ops team at MCCI puts the data for each organization in a separate directory, corresponding to a separate Git repository. 

We also need one or more _**jump hosts**_.  Jump hosts are intermediate systems that serve as a known place for contacting gateways that are otherwise not directly accessible on the internet. The gateway connects to the jump host; management clients connect to the jump host; software on the jump host sets up tunnels so that the clients think they're talking directly to the gateways.

Some organizations will want to set up their own jump hosts. But there is not necessarily a one-to-one mapping between organizations and jump hosts; and we think that there will (long term) be many more jump hosts than clients.

Awkwardly, a given jump host must (for technical reasons) assign unique _**forwarding ports**_ for each gateway. These ports are 16-bit numbers. There must be a table for each jump host that specifies the correspondence between forwarding port number and the associated gateway.

## Approach 

It may well be that we discover that what's needed is a database for the information (something stronger than `git`). But for now, we'll use `git` for storing the info, even though this probably will cause regrettable duplication of data.

When setting up an organization, the ops team can choose one of two approaches. They can have a master organization repository that includes the `ttn-multitech-cm` system as a submodule. Alternately, they can have the organization repository sit side-by-side with a separate (independent) clone of the `ttn-multitech-cm` repository. In that case, the computer system hosting the Ansible system would only need one copy; but it becomes very difficult to replicate results and track versions if there are multiple operators with laptops.  The problem with submodules is complexity -- they're not at all transparent, which makes them errorprone and somewhat tedious to use.

No matter what approach the ops team chooses, each organization directory will have a `hosts` file, a `host_vars` directory with one file for each managed Conduit, and a `group_vars` directory containing at least the file `group_vars/conduits.yaml`.  These are documented below.

## Organizational Information

For the purposes of this discussion, we'll assume the following directory structure.

<pre><em><strong>toplevel</strong></em>
    .git/
    .gitignore
    org/
        hosts
        group_vars/
            conduits.yml
        host_vars/
            ttn-<em><strong>host1</strong></em>.yml
            ttn-<em><strong>host2</strong></em>.yml
            ...
            <em><strong>jumphost1</strong></em>.yml
            ...
    ttn-multitech-cm/
        .git/
        Makefile
        ...</pre>

Note that `ttn-multitech-cm/` is a git [_**submodule**_](https://git-scm.com/book/en/v2/Git-Tools-Submodules). This complicates checkouts, but greatly simplifies ensuring consistency among different developers.

## The <code>org/</code> directory
This is an Ansible [_**inventory directory**_](http://docs.ansible.com/ansible/latest/intro_dynamic_inventory.html#using-inventory-directories-and-multiple-inventory-sources). As such, you need to be careful to only put the `hosts` file here; all files are liable to interpretation by Ansible. We note in passing that it is possible to specify the group hierarchy separately in a `groups` or `groups.yml` file, and then 
## The <code>hosts</code> file
The `hosts` file is an Ansible [_**inventory**_](http://docs.ansible.com/ansible/latest/intro_inventory.html) file. It provides the following information:
- the names we'll use to refer to each of the known systems (_**hosts**_) that are to be controlled by Ansible; and
- the _**groups**_ to which hosts belong.

A host always belongs to at least two groups, <code>[all]</code>, which conains all hosts, and some more specific group. Hosts that appear before the first header will be placed in the `[ungrouped]` group.

Hosts have associated _**variables**_. These are values associated with the host, which can be queried by Ansible components. This allows for host-by-host parameterization.

In our context, each gateway that we want to control is defined as a host in the inventory.

Hosts are normally (but not always) given names that correspond to their DNS names. Since our gateways often will not be visible in DNS, the names we assign to our gateway hosts are not DNS names. The names conventionally follow the pattern <code>ttn-<em>orgtag</em>-<em>gatewayname</em></code>, where <code><em>orgtag</em></code> is the same for all the gateways in the organization. 

The `hosts` inventory file is usually structured like a Windows `.ini` file.
- Lines of the form `[something]` are headers
- Other lines are content related to the header

Header lines come in three forms: 
- Lines of the form <code>[<em>groupname</em>]</code> start a section of host names. Each host named in the sectio belongs to the specfied group (and to all the groups that are parents of the specified group).
- Lines of the form <code>[<em>groupname</em>:vars]</code> start a section of variable settings that are to be defined for every host that's part of group <code><em>groupname</em></code>.
- Lines of the form <code>[<em>groupname</em>:children]</code> start a section of sub-group names, one name per line. Each group named in the section belongs to the parent group <code>[<em>groupname</em>]</code>.

Groups are used in two ways:
- they define specific subsets of the hosts in the inventory; and
- they provide specific variable values that are associated with each host in the group.

Although it is technically possible to put host and group variable settings in the inventory file, standard practice is to put the settings for a given host in a separate file. This file is a YAML file, and it lives in the `host_vars` directory next to the `hosts` inventory file, and is named <code><em><strong>hostname</strong></em>.yml</code>.

## host_vars/
This directory contains information (in the form of variable settings) about each of the gateways, one file per gateway. For convenience, information about the jump hosts is also placed in this directory, one file per jump host.

### host_vars/ttn-\{hostXX\}.yml
To be treated as a gateway description and acted upon, a given file, `ttn-{hostXX}` must appear in the `hosts` file under a `[Conduits]` section (typically in a subsection). Otherwise the file is ignored.

In the `ttn-multitech-cm/host_vars/` directory, you can find a sample file, `ttn-org-example.yml`, which can be used as a starting point. Make a copy in your organization's `host_vars` directory with the appropriate name to match the name used in your `hosts` file.

## group_vars/
This directory contains information (in the form of variable settings) about each of the groups, one file per group. The file for group <code>[<em>groupname</em>]</code> is named <code>group_vars/<em>groupname</em>.yml</code>.

### group_vars/conduits.yml

This file contains information (again, in the form of variable settings) that apply to all gateways that are in the `[conduits]` group in the inventory. 


