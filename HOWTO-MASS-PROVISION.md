# How To Mass Provision

1. go to the router, and download a list of mac address => IP address mappings. You may need to reboot the router if there's a huge list. (We may also need to switch to a PI-based router for this.)

2. If the router is not able to deal,

   a. Connect the Linux system to the 192.168.1 network

   b. Ping all the addresses:

      ```shell
      for i in $(seq 1 255); do
        { ( ping -c2 -W1 192.168.1.$i |& grep -q '0 received' || echo 192.168.1.$i > /dev/tty ; ) & disown; }
      done >& /dev/null
      ```

   c. Use `arp` to get a list of matching devices, and match to the MultiTech network address.

      ```shell
      sudo arp -vn | grep '00:08:00' | tr : - | sort -k1.11n | awk '{ printf("%s\t%s\tTYPE\n", $1, $3) }'
      ```

   d. Review results and make sure all expected gateways are present.

3. Create a directory:  `mfg/systems-`{date}.

4. In that directory, create `ConduitProvisioning.txt`, and set the first line, e.g.:

   ```shell
   cd mfg/systems-{date}
   { printf "Device Type\tClient IP address\tClients MAC Address\n" ; sudo arp -vn | grep '00:08:00' | tr : - | sort -k3 | awk '{ printf("TYPE\t%s\t%s\n", $1, $3) }' ; } > ConduitProvisioning.txt
   ```

5. Fill in the data, **separated by tabs**. Device types are "Conduit 210L", "Conduit 246L", "246L-L4N1", "Conduit AP", "Conduit AP-LNA3-915" e.g.:

   ```provisioning
   Device Type	Client IP address	Clients MAC Address
   Conduit 246L	192.168.1.19	00-08-00-4a-45-16
   Conduit 246L	192.168.1.20	00-08-00-4a-45-17
   Conduit 246L	192.168.1.28	00-08-00-4a-45-1f
   Conduit 246L	192.168.1.29	00-08-00-4a-45-20
   ```

   Note use of '-' in MAC address.

   If you're remote, you can get the Multi-Tech idea of the type by `ssh`ing to the target, and entering:

   ```bash
   mts-io-sysfs show product-id
   ```

   However, this won't be exactly right. You should set as follows:

   Standard name | Use for:
   --------------|---------------
   Conduit 210L  | MTCDT-210L, MTCDT-210A
   Conduit 246L  | MTCDT-246L, MTCDT-246A, MTCDT-246L-L4N1
   Conduit AP    | MTCAP, MTCAP-LNA3-915-041A

6. Sort this by mac address:

   ```shell
   LC_ALL=c sort -t \t -k3 ConduitProvisioning.txt -o ConduitProvisioning.txt
   ```

   You'll have to move the heading back to the top manually in a text editor. I use VS Code, and it's really easy.

7. We'll use `expand-mfg-gateways.sh` to expand the gateway last, but first, we need to get some info from the gateways.

   - If some gateways are being used for MCCI purposes, then use the '`-mi`' switch to reserve some gateways for our use.

   - Set the org to the default org, "Tompkins County" (`-I ttn-ithaca-gateways`).

   - find out the next available number for gateways. (`egrep 'Tompkins County|TTN Ithaca' ../../../org-ttn-ithaca-gateways/inventory/hosts | sort -t'#' -k3n`) and see the next available numbers for infrastructure and personal). Looked like 56 when I wrote this. You'll use this as the argument `-ii#` (`-ii56` in this case).

   For multi-gateway deployments for WeRadiate and Cornell, we search for 'WeRadiate' or 'Cornell' above.

   This is not actually critical; just need unique names. You can edit things.

   You may need to install `sshpass` (using `sudo apt install sshpass`).

8. Run `expand-mfg-gateways.sh` in scan mode:

   ```shell
   ../../expand-mfg-gateways.sh -s -I ttn-ithaca -O 'TTN Ithaca' -ii56 ConduitProvisioning.txt
   ```

   You'll be prompted for the root password for the gateways. All the gateways must have the same root password at this point.

9. You may get some errors from `known_hosts`.  Fix things until that's resolved. If someone has reset the root password, you'll need to set the password manually to the value in the script.

10. Run `expand-mfg-gateways.sh` in scan mode, but put info into a file.

    ```shell
    ../../expand-mfg-gateways.sh -s -I ttn-ithaca -O 'TTN Ithaca' -ii56 ConduitProvisioning.txt > ConduitDB.txt
    ```

    There should be no error messages and no warnings.

11. Examine the file `ConduitDB.txt` and correct anything that needs to be corrected. (Generally there's nothing, but the automation doesn't try to be perfect; low-frequency events have to be handled manually.)

12. Run `expand-mfg-gateways.sh` in deploy mode, capturing the output.

    ```shell
    ../../expand-mfg-gateways.sh -I ttn-ithaca -O 'TTN Ithaca' -ii56 ConduitDB.txt > ConduitDB2.txt
    ```

13. If you get `Received disconnect from 54.221.216.139 port 22:2: Too many authentication failures`, you'll need to clear out your ssh-agent. Neither the jumphost nor the gateways can deal with large collections of keys.

    ```shell
    ssh-add -D
    ssh-add {identity-for-jumphost}
    ssh-add {identity-for-conduits}
    ```

14. After `expand-mfg-gateways` has run successfully in deploy mode, the devices have been registered with the jumphost and their keys have been pushed into the jumphost. Check on the jumphost by logging in and saying:

    ```shell
    jumphost-tools/live-gateways
    ```

    Make sure the new gateways are in the list. (Note that `kick-all-gateways` might not work, since the gateways are still not fully set up.)

15. Rename the new database on top of the old database.

    ```shell
    mv ConduitDB2.txt ConduitDB.txt
    ```

16. Make sure that `python-terminal` and `python-multiprocessing` are installed on the target(s). Also create the `/usr/local/lib` directory.

    On each gateway, run:

    ```bash
    opkg update && opkg install python-terminal python-multiprocessing && mkdir -p /usr/local/lib
    ```

    (mlinux 5.3.31 doesn't need the opkg, but it doesn't hurt.)

    A massive way to do this is something like this. This is done locally,
    while you can access the devices via the local network.

    ```bash
    export GWS=$(tail -n+2 ConduitDB.txt | cut -f2)
    for i in $GWS ; do ssh root@$i 'opkg update && opkg install python-terminal python-multiprocessing && mkdir -p /usr/local/lib' ; done
    ```

17. Do a dry run of `create-ansible-mfg-gateways` for each of your target organizations, using a suitable input pattern.

    ```console
    $ ../../create-ansible-mfg-gateways.sh -I 'ttn-nyc' -O ../../../org-ttn-nyc-gateways -d ConduitDB.txt
    Would write gateway file: ../../../org-ttn-nyc-gateways/inventory/host_vars/ttn-nyc-00-08-00-4a-44-f9.yml
    Would write host file: ../../../org-ttn-nyc-gateways/inventory/hosts_new
    $ ../../create-ansible-mfg-gateways.sh -I 'ttn-ithaca' -O ../../../org-ttn-ithaca-gateways -d ConduitDB.txt
    Would write gateway file: ../../../org-ttn-ithaca-gateways/inventory/host_vars/ttn-ithaca-00-08-00-4a-44-fa.yml
    Would write gateway file: ../../../org-ttn-ithaca-gateways/inventory/host_vars/ttn-ithaca-00-08-00-4a-44-fc.yml
    Would write gateway file: ../../../org-ttn-ithaca-gateways/inventory/host_vars/ttn-ithaca-00-08-00-4a-44-fd.yml
    ...
    Would write host file: ../../../org-ttn-ithaca-gateways/inventory/hosts_new
    ```

    If it says "`File exists ../../../org-ttn-nyc-gateways/inventory/hosts_new`", you have a leftover file. Move it out of the way.

    If it says "`File exists: ../../../org-ttn-ithaca-gateways/inventory/host_vars/ttn-ithaca-00-08-00-xx-xx-xx.yaml`", then the gateway is already in the database; you should remove it from the `ConduitDB.txt` file.

18. Write the host files.

    ```shell
    ../../create-ansible-mfg-gateways.sh -I 'ttn-nyc' -O ../../../org-ttn-nyc-gateways ConduitDB.txt
    ../../create-ansible-mfg-gateways.sh -I 'ttn-ithaca' -O ../../../org-ttn-ithaca-gateways ConduitDB.txt
    ```

19. Edit the `hosts` file(s) to merge in the `hosts_new` info.

20. Get the list of hosts to be provisioned into a variable, for example:

    ```shell
    NEWHOSTS="$(sed -ne '1,/^\[test/d' -e 's/^\([^ \t][^ \t]*\).*$/\1/p' ../../../org-ttn-ithaca-gateways/inventory/hosts_new)"
    ```

21. Change directory to the `ttn-multitech-cm` repo, and do a ping:

    ```shell
    make TTN_ORG=../org-ttn-ithaca-gateways TARGET=${NEWHOSTS//[[:space:]]/,} ping
    ```

22. Make sure `ttn-lw-cli` is set up:

    ```bash
    # if ttn-lw-cli is not installed:
    sudo snap install --classic ttn-lw-stack
    sudo snap alias ttn-lw-stack.ttn-lw-cli ttn-lw-cli
    # set up path to config file.
    export TTN_LW_CONFIG=$(realpath ./ttn-lw-cli.yml)
    ```
    See if you're already logged in:

    ```console
    $ ttn-lw-cli user get ohjsjuju
    {
    "ids": {
        "user_id": "ohjsjuju"
    },
    "created_at": "2021-07-13T04:31:42.869Z",
    "updated_at": "2021-07-13T04:31:42.869Z"
    }
    $
    ```

    If you don't get the data, login using:

    ```bash
    ttn-lw-cli login --callback
    ```

22. Do an apply:

    ```shell
    make TTN_ORG=../org-ttn-ithaca-gateways TARGET=${NEWHOSTS//[[:space:]]/,} apply
    ```

23. Reboot:

    ```shell
    for i in $NEWHOSTS ; do PORT=$(grep "$i" ../conduit-mfg/mfg/systems-20190108b/ConduitDB.txt | cut -f 8) ; echo $PORT ; ssh -A jumphost.ttni.tech "ssh -p $PORT -o StrictHostKeyChecking=no root@localhost 'shutdown -r now'" ;  done
    ```

24. Wait a minute or two for the reboot, then do a make ping again:

    ```shell
    make TTN_ORG=../org-ttn-ithaca-gateways TARGET=${NEWHOSTS//[[:space:]]/,} ping
    ```

25. Shutdown all the hosts.

    ```shell
    for i in $NEWHOSTS ; do PORT=$(grep "$i" ../conduit-mfg/mfg/systems-20190108b/ConduitDB.txt | cut -f 8) ; echo $PORT ; ssh -A jumphost.ttni.tech "ssh -p $PORT -o StrictHostKeyChecking=no root@localhost 'shutdown -h now'" ;  done
    ```

26. Commit changes in all the repos you used.
