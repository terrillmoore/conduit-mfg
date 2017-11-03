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

TODO: have a simpler setup.

# Setting up Conduit for Ansible

From the [factory](http://www.multitech.net/developer/software/mlinux/getting-started-with-conduit-mlinux/), 
the Conduit's initial IP address is `192.168.2.1`. 

In this first step, we'll do the following.
1. Connect to the Conduit via a dedicated Ethernet port.
2. Set up the Conduit for DHCP and prepare for Ansible control.
3. Restart.

## PC Setup Prerequisites

You'll need a USB-to-Ethernet adapter. We'll configure that adapter to have address `192.168.2.2`, and we'll set up DHCP so that it will serve out addresses in the range `192.168.2.128` to `192.168.2.254`. We assume use of Ubuntu 16.04 LTS.

1. Connect the USB-to-Ethernet adapter. Attach it to your VM, if needed.
2. Check the system log.
   ```shell
   $ sudo tail /var/log/syslog
   Nov  2 21:47:31 Ubuntu16-04-02-64 NetworkManager[939]: <info>  [1509673651.4651] device (eth0): interface index 9 renamed iface from 'eth0' to 'enxc0335eeeb542'
   Nov  2 21:47:31 Ubuntu16-04-02-64 NetworkManager[939]: <info>  [1509673651.5377] devices added (path: /sys/devices/pci0000:00/0000:00:15.0/0000:03:00.0/usb4/4-1/4-1:2.0/net/enxc0335eeeb542, iface: enxc0335eeeb542)
   Nov  2 21:47:31 Ubuntu16-04-02-64 NetworkManager[939]: <info>  [1509673651.5377] device added (path: /sys/devices/pci0000:00/0000:00:15.0/0000:03:00.0/usb4/4-1/4-1:2.0/net/enxc0335eeeb542, iface: enxc0335eeeb542): no ifupdown configuration found.
   Nov  2 21:47:31 Ubuntu16-04-02-64 NetworkManager[939]: <info>  [1509673651.5379] device (enxc0335eeeb542): state change: unmanaged -> unavailable (reason 'managed') [10 20 2]
   Nov  2 21:47:31 Ubuntu16-04-02-64 kernel: [161491.245178] IPv6: ADDRCONF(NETDEV_UP): enxc0335eeeb542: link is not ready
   Nov  2 21:47:31 Ubuntu16-04-02-64 kernel: [161491.256175] cdc_ether 4-1:2.0 enxc0335eeeb542: kevent 12 may have been dropped
   Nov  2 21:47:31 Ubuntu16-04-02-64 kernel: [161491.256202] IPv6: ADDRCONF(NETDEV_UP): enxc0335eeeb542: link is not ready
   Nov  2 21:47:31 Ubuntu16-04-02-64 NetworkManager[939]: <info>  [1509673651.5522] keyfile: add connection in-memory (121757d4-560a-3fc6-9320-f8a48b818230,"Wired connection 2")
   Nov  2 21:47:31 Ubuntu16-04-02-64 NetworkManager[939]: <info>  [1509673651.5754] settings: (enxc0335eeeb542): created default wired connection 'Wired connection 2'
   Nov  2 21:47:33 Ubuntu16-04-02-64 ModemManager[915]: <info>  Couldn't find support for device at '/sys/devices/pci0000:00/0000:00:15.0/0000:03:00.0/usb4/4-1': not supported by any plugin
   ```
   - From this we can see that the device name is `enxc0335eeeb542`. We'll need that name in a moment.

   - If the name is anything else, you'll need to make the corresponding changes in teh following steps.
3. Get the configuration for that adapter using the command line.
    ```shell
   $ ifconfig enxc0335eeeb542
   enxc0335eeeb542 Link encap:Ethernet  HWaddr c0:33:5e:ee:b5:42  
             UP BROADCAST MULTICAST  MTU:1500  Metric:1
             RX packets:0 errors:0 dropped:0 overruns:0 frame:0
             TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
             collisions:0 txqueuelen:1000 
             RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)
    ```
   From this, you can get the Ethernet address (from `HWaddr`): `c0:33:5e:ee:b5:42` in this case.

4. Set up the static IP address for this adapter. To do this, we edit `/etc/network/interfaces` and add the following lines at the end.
   ```
   auto enxc0335eeeb542
   iface enxc0335eeeb542 inet static
   address 192.168.2.127
   netmask 255.255.255.0
   gateway 192.168.2.127
   ```
5. Test by saying:
   ```shell
   $ ifdown enxc0335eeeb542
   $ ifup enxc0335eeeb542
   $ ifconfig enxc0335eeeb542 Link encap:Ethernet  HWaddr c0:33:5e:ee:b5:42  
             inet addr:192.168.2.127  Bcast:192.168.2.255  Mask:255.255.255.0
             UP BROADCAST MULTICAST  MTU:1500  Metric:1
             RX packets:0 errors:0 dropped:0 overruns:0 frame:0
             TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
             collisions:0 txqueuelen:1000 
             RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)
   ```
   Note that the `inet addr` is now set.

6. Make sure DHCPD is installed.
   ```shell
    $ sudo apt-get install isc-dhcp-server
   ```

7. Edit `/etc/default/isc-dhcp-server`, and change the last line from `INTERFACES=""` to:
   ```shell
   # On what interfaces should the DHCP server (dhcpd) serve DHCP requests?
   #       Separate multiple interfaces with spaces, e.g. "eth0 eth1".
   INTERFACES="enxc0335eeeb542"
   ```

8. Replace the contents of `/etc/dhcp/dhcpd.conf` with the following:
   ```
   # /etc/dhcp/dhcpd.conf for MultiTech setup
   default-lease-time 600;
   max-lease-time 7200;
   authoritative;

   subnet 192.168.2.0 netmask 255.255.255.0 {
    range 192.168.2.1 192.168.2.1;
    option routers 192.168.2.127;
    option domain-name-servers 8.8.8.8;
    # option domain-name "mydomain.example";
   }
   ```
   This setup assumes that you'll connect one gateway at a time to the setup VM. It forces DHCPD to always assign `192.168.2.1`·to the attached Conduit (the same as the built-in static address). 

9. Restart _dhcpd_.
    ```shell
    sudo systemctl restart isc-dhcp-server.service
    ```

## Attaching the Conduit while in Factory State

1. Verify that networking is running.

2. Turn on forwarding (temporarily):
    ```shell
    sysctl net.ipv4.ip_forward=1
    ```
3. Connect the Conduit to the USB-Ethernet adapter using the Ethernet cable.
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

## Set the Conduit to use DHCP
1. On the Conduit, edit `/etc/network/interfaces` to enable DHCP client.
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
    Sending select for 192.168.4.5...
    Lease of 192.168.4.5 obtained, lease time 86400
    /etc/udhcpc.d/50default: Adding DNS 192.168.4.1
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

## Note the address assigned, then return to the Linux PC, and connect via Etherne

1. Using the address noted above (`192.168.4.5` in this case, but it will be different each time), ssh into the Conduit.
    ```shell
    $ ssh root@192.168.4.5
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
     3 Nov 00:45:25 ntpdate[833]: step time server 204.9.54.119 offset -0.000973 sec
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

# Create Your Initial Ansible Setup

