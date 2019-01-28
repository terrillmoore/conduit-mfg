# How To Mass Provision

1. go to the router, and download a list of mac address => IP address mappings. You may need to reboot the router if there's a huge list. (We may also need to switch to a PI-based raouter for this.)

2. If the router is not able to deal,

   a. Ping all the addresses:

      ```shell
      for i in $(seq 1 255); do
                ( ping -c2 -W1 192.168.1.$i |& grep -q '0 received' || echo 192.168.1.$i ; ) &
      done
      ```

   b. If using a Windows machine to route to the network, use `arp` to get a list of matching devices, and match to the Multitech network address.

      ```shell
      arp -a | grep 192.168.1 | grep 00-08-00
      ```

      Put result in a file and get it to Linux system.  Count the number of lines and ma sure it matches, etc.

3. Create a directory:  mfg/systems-{date}.

4. In that directory, create ConduitProvisioning.txt, and set the first line, e.g.:

   ```shell
   cd mfg/systems-{date}
   printf "Device Type\tClient IP address\tClients MAC Address\n" > ConduitProvisioning.txt
   ```

5. Fill in the data, separated by tabs. Device types are "Conduit 210L", "Conduit 246L", "Conduit AP", e.g.:

   ```provisioning
   Device Type	Client IP address	Clients MAC Address
   Conduit 246L	192.168.1.19	00-08-00-4a-45-16
   Conduit 246L	192.168.1.20	00-08-00-4a-45-17
   Conduit 246L	192.168.1.28	00-08-00-4a-45-1f
   Conduit 246L	192.168.1.29	00-08-00-4a-45-20
   ```

6. Sort this by mac address:

   ```shell
   LC_ALL=c sort -t \t -k3 ConduitProvisioning.txt -o ConduitProvisioning.txt
   ```

   You'll have to move the heading back to the top manually.

7. We'll use `expand-mfg-gateways.sh` to expand the gateway last, but first, we need to get some info

   - If some gateways are being used for MCCI purposes, then use the '-mi' switch to reserve some gateways for our use.

   - Set the org to the default org, "Tompkins County" (-I ttn-ithaca-gateways).

   - find out the next available number for gateways. (`grep 'Tompkins County' ../../../org-ttn-ithaca-gateways/inventory/hosts` and see the next available numbers for infrastructure and personal). Looks like 27.

8. Run `expand-mfg-gateways.sh` in scan mode:

   ```shell
   ../../expand-mfg-gateways.sh -s -I ttn-ithaca -O 'Tompkins County' -mi1 -ii27 ConduitProvisioning.txt
   ```

9. You'll may get some errors from known_hosts.  Fix things until that's resolved.

10. Run `expand-mfg-gateways.sh` in scan mode, but put info into a file.

    ```shell
    ../../expand-mfg-gateways.sh -s -I ttn-ithaca -O 'Tompkins County' -mi1 -ii27 ConduitProvisioning.txt > ConduitDB.txt
    ```

    There shouuld be no error messages and no warnings.

11. Examine the file and correct anything that needs to be corrected.

12. Run `expand-mfg-gateways.sh` in deploy mode, capturing the output.

    ```shell
    ../../expand-mfg-gateways.sh -I ttn-ithaca -O 'Tompkins County' -mi1 -ii27 ConduitDB.txt > ConduitDB2.txt
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

    Make sure the new gateways are in the list.

15. Rename the new database ontop of the old database.

    ```shell
    mv ConduitDB2.txt ConduitDB.txt
    ```

16. Do a dry run of `create-ansible-mfg-gateways` for each of your target organizations, using a suitable input pattern.

    ```console
    $ ../../create-ansible-mfg-gateways.sh -I 'ttn-nyc' -O ../../../org-ttn-nyc-gateways -d ConduitDB.txt
    Would write gateway file: ../../../org-ttn-nyc-gateways/inventory/host_vars/ttn-nyc-00-08-00-4a-44-f9.yml
    Would write host file: ../../../org-ttn-nyc-gateways/inventory/hosts_new
    $ ../../create-ansible-mfg-gateways.sh -I 'ttn-ithaca' -O ../../../org-ttn-ithaca-gateways -d ConduitDB.txt
    Would write gateway file: ../../../org-ttn-nyc-gateways/inventory/host_vars/ttn-ithaca-00-08-00-4a-44-fa.yml
    Would write gateway file: ../../../org-ttn-nyc-gateways/inventory/host_vars/ttn-ithaca-00-08-00-4a-44-fc.yml
    Would write gateway file: ../../../org-ttn-nyc-gateways/inventory/host_vars/ttn-ithaca-00-08-00-4a-44-fd.yml
    ...
    Would write host file: ../../../org-ttn-nyc-gateways/inventory/hosts_new
    ```

17. Write the host files.

    ```shell
    ../../create-ansible-mfg-gateways.sh -I 'ttn-nyc' -O ../../../org-ttn-nyc-gateways ConduitDB.txt
    ../../create-ansible-mfg-gateways.sh -I 'ttn-ithaca' -O ../../../org-ttn-ithaca-gateways ConduitDB.txt
    ```

18. Edit the `hosts` file(s) to merge in the `hosts_new` info.

19. Get the list of hosts to be provisioned into a variable:

    ```shell
    NEWHOSTS=$(cut -f1 ../org-ttn-ithaca-gateways/inventory/hosts_new)
    ```

20. Change directory to the `ttn-multitech-cm` repo, and do a ping:

    ```shell
    make TTN_ORG=../org-ttn-ithaca-gateways TARGET=${NEWHOSTS//[[:space:]]/,} ping
    ```

21. Do an apply:

    ```shell
    make TTN_ORG=../org-ttn-ithaca-gateways TARGET=${NEWHOSTS//[[:space:]]/,} apply
    ```

22. Reboot:

    ```shell
    for i in $NEWHOSTS ; do PORT=$(grep "$i" ../conduit-mfg/mfg/systems-20190108b/ConduitDB.txt | cut -f 8) ; echo $PORT ; ssh -A ec2-54-221-216-139.compute-1.amazonaws.com "ssh -p $PORT -o StrictHostKeyChecking=no root@localhost 'shutdown -r now'" ;  done
    ```

23. Wait a minute or two for the reboot, then do a make ping again:

    ```shell
    make TTN_ORG=../org-ttn-ithaca-gateways TARGET=${NEWHOSTS//[[:space:]]/,} ping
    ```

24. Shutdown all the hosts.

    ```shell
    for i in $NEWHOSTS ; do PORT=$(grep "$i" ../conduit-mfg/mfg/systems-20190108a/ConduitDB.txt | cut -f 8) ; echo $PORT ; ssh -A ec2-54-221-216-139.compute-1.amazonaws.com "ssh -p $PORT -o StrictHostKeyChecking=no root@localhost 'shutdown -h now'" ;  done
    ```

25. Commit changes in all the repos you used.
