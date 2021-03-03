# Initial Setup for Conduit MTCDT or MTCAP

Get a USB network adapter.

Set it to static, IP 192.168.2.200

Connect Conduit and boot up

Wait for flashing status light -- it takes a while.

## For mPower Systems (AEP)

Connect to 192.168.2.1 with a web browser. Accept the self-signed cert warning.

![Login screen](./assets/mpower-initial.png)

Set the default user to `admin`, and use the mLinux default root password.

Log in. Click through the setup wizard. At the network prompt, just accept the defaults (if it looks like this):

![Network setup](assets/mpower-set-network.png)

Use Administration > Access Configuration > SSH Settings > [x] Enabled, [x] via Lan.  Then "Save and Restart".

![Rebooting after ssh](assets/mpower-enable-ssh-reboot.png)

The device STATUS light will double flash for about a minute. Then the device will stay at 2 lights solid on for about two minutes. Once the STATUS light starts flashing again (or you get a login prompt on the dashboard), you can log in and complete the process.

Log in using SSH:

```bash
ssh admin@192.168.2.1
```

You will likely have to delete an old host key from your `known_hosts` file.

Confirm that all looks good.

Back on the PC, do the following:

```bash
cd /cygdrive/c/tmp
mkdir mtcdt
cd mtcdt
wget https://github.com/IthacaThings/mlinux-images/raw/master/3.3.24/mtcdt/ttni-base-image-mtcdt-upgrade-withboot.bin
```

The above only needs to be done once, to get the required file.

Then, from the `mtcdt` directory from above:

```bash
scp -p ttni-base-image-mtcdt-upgrade-withboot.bin admin@192.168.2.1:/tmp
```

The `scp` takes about forty-five seconds.

Log in again, and apply the firmware:

```console
admin@mtcdt:~$ sudo /usr/sbin/mlinux-firmware-upgrade /tmp/ttni-base-image-mtcdt-upgrade-withboot.bin
Password:
firmware_upgrade: Checking MD5 for bstrap.bin...
-: OK
firmware_upgrade: Checking MD5 for uboot.bin...
-: OK
firmware_upgrade: Checking MD5 for uImage.bin...
-: OK
firmware_upgrade: Checking MD5 for rootfs.jffs2...
-: OK
firmware_upgrade: Rebooting

Broadcast message from root@mtcdt (pts/0) (Mon Feb  8 00:40:00 2021):

The system is going down for reboot NOW!
admin@mtcdt:~$
```

You'll see lights flashing, then three lights solid, then two lights solid. At the two-light-solid point, the Conduit should be waiting for DHCP; but then it will come up at 192.168.2.1. Login using:

```bash
ssh root@192.168.2.1
```

The password is the mLinux default password.

Install the following in `/etc/network/interfaces`:

```
# The loopback interface
auto lo
iface lo inet loopback

# Wired interface
auto eth0
iface eth0 inet dhcp
    post-up ifconfig eth0 mtu 1100
    udhcpc_opts -b -t 2592000

```

I generally put the file (as `interface-dhcp`) in the same directory as my mtcdt image, and then I can simply do the following:

```bash
scp -p interface-dhcp root@192.168.2.1:/etc/network/interfaces
```

You can then power the Conduit down and move it to the provisioning network. Because of flash problems in the past, I manually prep the shutdown:

```bash
sync; sync; sync; sleep 2; shutdown -h now
```

Once on the provisioning network, follow the instructions in [`HOWTO-MASS-PROVISION.md`](HOWTO-MASS-PROVISION.md).
