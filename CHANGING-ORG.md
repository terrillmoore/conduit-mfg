# Changing the Organization of a Gateway

The first steps are easy.

- Delete the gateway from [console.thethingsnetwork.org](https://console.thethingsnetwork.org)
- Move the gateway's provisioning file to the new organization
- Remove from the old organizations's `inventory/hosts`
- Rename the file as needed
- Edit the hostname in the file
- Add the hostname to the new organization's `inventory/hosts`

If a gateway is not provisioned using a jumphost, the next step is also easy.

- do `make TTN_ORG={neworg} TAGS=hostname,ssh_tunnel,ttn apply TARGET={name}`

If using a jumphost we have several more steps, because we need to maintain connectivity throughout this process.

1. change to this directory.
2. run `create-jumphost-user.sh -Q {oldname}`.
3. run `create-jumphost-user.sh -U {uid} -k {key} {newname} {newgroup}`, cutting and pasting the -U and -k params output by the previous command.
4. switch back to the `ttn-multitech-cm` directory
5. `make TTN_ORG={neworg} TARGET={newname} ping` to check connectivity.
6. `make TTN_ORG={neworg} TARGET={newname} apply TAGS=hostname`.
7. Log into the target using the jumphost (would be nice to have `make shell` for this).
8. Edit `/etc/default/ssh_tunnel` to set the new host name. (You might think that you could use Ansible for this, but because of connectivity issues, this is )
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

If you want to change the jumphost, I think you can use steps 8 through 13 in a similar way. But I've not tested this.
