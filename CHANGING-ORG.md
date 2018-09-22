# Changing the Organization of a Gateway


<!-- TOC depthFrom:2 -->

- [Preliminaries](#preliminaries)
- [If no jumphost](#if-no-jumphost)
- [If using a jumphost](#if-using-a-jumphost)
- [Moving to a new jumphost](#moving-to-a-new-jumphost)

<!-- /TOC -->

## Preliminaries

The first steps are easy.

- Delete the gateway from [console.thethingsnetwork.org](https://console.thethingsnetwork.org)
- Move the gateway's provisioning file to the new organization
- Remove from the old organizations's `inventory/hosts`
- Rename the file as needed
- Edit the hostname in the file
- Add the hostname to the new organization's `inventory/hosts`

At this point you must have ssh connectivity to the gateway. If using a jumphost, you also need connectivity to the jumphost, and the gateway must be connected to the jumphost (under its old name).

## If no jumphost

If a gateway is not provisioned using a jumphost, the next step is also easy.

- do `make TTN_ORG={neworg} TAGS=hostname,ttn apply TARGET={name}`

## If using a jumphost

If using a jumphost we have several more steps, because we need to maintain connectivity throughout this process.

1. change to this directory.
2. run `create-jumphost-user.sh -Q {oldname}`.
3. run `create-jumphost-user.sh -U {uid} -k {key} {newname} {newgroup}`, cutting and pasting the -U and -k params output by the previous command.
4. switch back to the `ttn-multitech-cm` directory
5. `make TTN_ORG={neworg} TARGET={newname} ping` to check connectivity.
6. `make TTN_ORG={neworg} TARGET={newname} apply TAGS=hostname`.
7. Log into the target using the jumphost (would be nice to have `make shell` for this).
8. Edit `/etc/default/ssh_tunnel` to set the new host name. (You might think that you could use Ansible for this, but because of connectivity issues, this must be done by hand.)
9. Verify that the gateway can log in

    ```console
    # source /etc/default/ssh_tunnel
    # ssh -o StrictHostKeyChecking=no -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST

           __|  __|_  )
           _|  (     /   Amazon Linux AMI
          ___|\___|___|

    https://aws.amazon.com/amazon-linux-ami/2018.03-release-notes/
    [$REMOTE_USER ~]$
    ```

10. Reboot the gateway (so it picks up its hostname completely and logs in as the new ID).

    ```console
    {NEWNAME}# reboot
    The system is going down for reboot NOW!{NEWNAME} (pts/0) (Sat Sep 22  17:
    root@{NEWNAME}:~# Connection to localhost closed by remote host.
    Connection to localhost closed.
    [somebody@${JUMPHOST} ~]$
    ```

11. Wait a minute for the gateway to come up; return to your dev system.
12. Verify that it's up: `make TTN_ORG={neworg} TARGET={newname} ping`
13. Set up for TTN: `make TTN_ORG={neworg} TARGET={newname} apply TAGS=ttn`

## Moving to a new jumphost

This process is similar. _(I've not yet tested this!)_

1. change to this directory.
2. run `create-jumphost-user.sh -j{oldjumphost} -Q {oldname}`.
3. run `create-jumphost-user.sh -j{newjumphost} -k {key} {newname} {newgroup}`. Cut and paste the -k param output by the previous command, but don't include the `-U` param!
4. Note the user ID and keepalive ID output by the previous command. Update the `{newhost}.yml` file to use these new values, and also update the `{newhost}.yml` file to include the new jumphost instead of the old jumphost (or confirm that the new organization's jumphost matches what you used at step 3).
5. Log into the target using the _**old**_ jumphost.
6. On the gateway, `/etc/default/ssh_tunnel` to set the new host name, SSH port and keepalive port. (You might think that you could use Ansible for this, but because of connectivity issues, this must be done by hand.)
7. Verify that the gateway can log in to the new jumphost.

    ```console
    # source /etc/default/ssh_tunnel
    # ssh -o StrictHostKeyChecking=no -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST

           __|  __|_  )
           _|  (     /   Amazon Linux AMI
          ___|\___|___|

    https://aws.amazon.com/amazon-linux-ami/2018.03-release-notes/
    [$REMOTE_USER ~]$
    ```

    Look very carefully at the output and make sure you're on the _**new*__ jumphost.
8. Reboot the gateway (so it picks up its hostname completely and logs in as the new ID).

    ```console
    {NEWNAME}# reboot
    The system is going down for reboot NOW!{NEWNAME} (pts/0) (Sat Sep 22  17:
    root@{NEWNAME}:~# Connection to localhost closed by remote host.
    Connection to localhost closed.
    [somebody@${JUMPHOST} ~]$
    ```

9. Wait a minute for the gateway to come up; return to your dev system.
10. Verify that it's up: `make TTN_ORG={neworg} TARGET={newname} ping`
11. Set up for TTN: `make TTN_ORG={neworg} TARGET={newname} apply TAGS=ttn`
