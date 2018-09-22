# Configuring a Conduit AP

## Procedure

1. Set up your manufacturing environment as described in [README.md](README.md#setting-up-your-manufacturing-station)

2. Download the TTN Ithaca mLinux distribution from [CloudAtCost](https://download.cloudatcost.com/download/jm9cwhjbfnni4mnocqna1xq28). The file will appear as `ttni-base-image-mtcap-upgrade-withboot.bin.txt`. Put this file on your manufacturing station.

3. Rename the downloaded file `ttni-base-image-mtcap-upgrade-withboot.bin`.  For example, the following bash command will do this.

   ```shell
   mv ttni-base-image-mtcap-upgrade-withboot.bin{.txt,}
   ```

4. Connect the Conduit AP to your engineering network as 192.168.2.1

5. Log in to the Conduit:

   ```console
   $ ssh root@192.168.2.1
   Password:
   root@mtcap:~#
   ```

   Enter the root password for your distribution. For a MultiTech distribution, the root password is `root`. For TTN Ithaca distributions, contact us for the root password, as it varies by build.

   _The purpose of this login is mainly to verify that things are properly connected._

6. **On your manufacturing PC:** Copy the image file to the Conduit.

   ```shell
   scp ttni-base-image-mtcap-upgrade-withboot.bin root@192.168.2.1:
   ```

   The trailing '`:`' is very important!

7. **On the Conduit:** start the upgrade procedure by entering the following comand:

   ```shell
   /usr/sbin/mlinux-firmware-upgrade /home/root/ttni-base-image-mtcap-upgrade-withboot.bin
   ```

   This will kick off a lot of activity:

   ```console
   root@mtcap:~# /usr/sbin/mlinux-firmware-upgrade /home/root/ttni-base-image-mtcap-upgrade-withboot.bin
   firmware_upgrade: Checking MD5 for bstrap.bin...
   -: OK
   firmware_upgrade: Checking MD5 for uboot.bin...
   -: OK
   firmware_upgrade: Checking MD5 for uImage.bin...
   -: OK
   firmware_upgrade: Checking MD5 for rootfs.jffs2...
   -: OK
   firmware_upgrade: Rebooting

   Broadcast message from root@mtcap (pts/0) (Wed Dec 27 21:27:06 2017):

   The system is going down for reboot NOW!
   root@mtcap:~# Connection to 192.168.2.1 closed by remote host.
   Connection to 192.168.2.1 closed
   ```
