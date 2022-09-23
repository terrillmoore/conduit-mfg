# HOW TO SETUP STATIC IP

Problem statement: 

- our provisioning network uses DHCP but some users want static.
- after provisioning, the Conduit won't be locally accessible.

Solution:

- Provision everything except networking
- Confirm that things are working
- Provision the user's target

Optional for extra credit:

- set up a test network that is provisioned like the user's network and check the gateway there.

## Provision Everything Except Networking

Go through the provisioning process, but leave the following settings in place:

```yaml
# Uncomment the following to force network configuration to DHCP (this
# is the default config )
eth0_type: dhcp

# Uncomment and set the following info to set a static address
## eth0_type: static
## eth0_address: 10.90.209.190
## eth0_netmask: 255.255.252.0
## eth0_gateway: 10.90.209.1

# By default we'll configure google nameservers, if you want to
# specify, use:
##static_domain:   TinyTown.int
##static_nameservers:
##  - 10.90.209.10
#  - 192.168.1.5
```

Note that we've added double `##` at the front of the static-IP-related lines, and we've changed the content to match the user's network.

Run all the portions of `make apply` that are needed. Normally, all you need if a unit has already been provisioned and there's a `ttn-ORG-EUI.yml` file, is `make apply TAGS=ttn TARGET=ttn-ORG-EUI`.

## Set the static addresses

Comment out the `dhcp` line, and uncomment the lines with `##`.

```yaml
# Uncomment the following to force network configuration to DHCP (this
# is the default config )
## eth0_type: dhcp

# Uncomment and set the following info to set a static address
eth0_type: static
eth0_address: 10.90.209.190
eth0_netmask: 255.255.252.0
eth0_gateway: 10.90.209.1

# By default we'll configure google nameservers, if you want to
# specify, use:
static_domain:   TinyTown.int
static_nameservers:
  - 10.90.209.10
#  - 192.168.1.5
```

_**Save Your File!**_

Now apply the changes.

```shell
make apply TAGS=networking ORG=../ttn-ORG-gateways TARGET=ttn-ORG-EUI
```

Here's what tit will look like:

```console
$ make TTN_ORG=../org-ttn-ithaca-gateways TARGET="ttn-ithaca-00-08-00-4a-3d-04" TAGS=networking apply
ANSIBLE_CACHE_PLUGIN_CONNECTION=../org-ttn-ithaca-gateways/catalog ansible-playbook -T 60 --inventory ../org-ttn-ithaca-gateways/inventory ${TAGS:+-t ${TAGS}} ${TARGET:+-l ${TARGET}}  site.yml

PLAY [conduits] ****************************************************************

TASK [Gathering Facts] *********************************************************
ok: [ttn-ithaca-00-08-00-4a-3d-04]

TASK [conduit : Check that wlan0 exists if we are configuring it as only interface] ***
skipping: [ttn-ithaca-00-08-00-4a-3d-04]

TASK [conduit : WiFi firmware dirs] ********************************************
skipping: [ttn-ithaca-00-08-00-4a-3d-04] => (item=rtlwifi) 

TASK [conduit : Check if rtl8192cu firmware is downloaded] *********************
skipping: [ttn-ithaca-00-08-00-4a-3d-04]

TASK [conduit : Download rtl8192cu firmware] ***********************************
skipping: [ttn-ithaca-00-08-00-4a-3d-04]

TASK [conduit : Install rtl8192cu firmware] ************************************
skipping: [ttn-ithaca-00-08-00-4a-3d-04]

TASK [conduit : Static /etc/resolv.conf] ***************************************
changed: [ttn-ithaca-00-08-00-4a-3d-04]

TASK [conduit : Set up dhcp /etc/resolv.conf] **********************************
skipping: [ttn-ithaca-00-08-00-4a-3d-04]

TASK [conduit : Delete static /etc/resolv.conf if not used] ********************
skipping: [ttn-ithaca-00-08-00-4a-3d-04]

TASK [conduit : Set up /var/config/network/interfaces] *************************
changed: [ttn-ithaca-00-08-00-4a-3d-04]

TASK [conduit : Set up /var/config/wpa_supplicant.conf] ************************
skipping: [ttn-ithaca-00-08-00-4a-3d-04]

TASK [conduit : Delete /var/config/wpa_supplicant.conf if no wireless keys] ****
ok: [ttn-ithaca-00-08-00-4a-3d-04]

TASK [conduit : Install support scripts] ***************************************
ok: [ttn-ithaca-00-08-00-4a-3d-04] => (item=udhcpc_restart)
ok: [ttn-ithaca-00-08-00-4a-3d-04] => (item=ifup_restart)

TASK [conduit : Link /etc/udhcpc.d/60restart] **********************************
ok: [ttn-ithaca-00-08-00-4a-3d-04]

TASK [conduit : Link /etc/network/if-up.d/restart] *****************************
ok: [ttn-ithaca-00-08-00-4a-3d-04]

RUNNING HANDLER [conduit : interface reboot] ***********************************
ok: [ttn-ithaca-00-08-00-4a-3d-04] => {
    "msg": "Interface configuration changed, remember to reboot"
}

PLAY [jumphost.example.com] ****************************************************
skipping: no hosts matched

PLAY RECAP *********************************************************************
ttn-ithaca-00-08-00-4a-3d-04 : ok=8    changed=2    unreachable=0    failed=0   

tmm@Ubuntu16-04-02-64:~/sandbox/ttn-multitech-cm$ make TTN_ORG=../org-ttn-ithaca-gateways TARGET="ttn-ithaca-00-08-00-4a-3d-04" ping
ANSIBLE_CACHE_PLUGIN_CONNECTION=../org-ttn-ithaca-gateways/catalog ansible --inventory ../org-ttn-ithaca-gateways/inventory -o -m ping  ttn-ithaca-00-08-00-4a-3d-04
ttn-ithaca-00-08-00-4a-3d-04 | SUCCESS => {"changed": false, "ping": "pong"}
$
```

At this point, the device will still be connected with its old IP address:

```console
$ make TTN_ORG=../org-ttn-ithaca-gateways TARGET="ttn-ithaca-00-08-00-4a-3d-04" ping
ANSIBLE_CACHE_PLUGIN_CONNECTION=../org-ttn-ithaca-gateways/catalog ansible --inventory ../org-ttn-ithaca-gateways/inventory -o -m ping  ttn-ithaca-00-08-00-4a-3d-04
ttn-ithaca-00-08-00-4a-3d-04 | SUCCESS => {"changed": false, "ping": "pong"}
$ 
```

Now, you need to shutdown the target cleanly so that the flash updates really take.

Ideally we'd have a shell script, but for now, we'll look in the target YML to get the remote port. Then we'll use the jumphost to reboot the device.

```shell
TARGET=ttn-ithaca-00-08-00-4a-3d-04
ORG="$(echo $TARGET | sed -e 's/-..-..-..-..-..-..-..-..$//')"
PORT="$(grep '^ssh_tunnel_remote_port:' "../org-${ORG}-gateways/inventory/host_vars/${TARGET}.yml" | awk '{ print $2 }')"
echo $PORT
ssh -A jumphost.ttni.tech "ssh -p $PORT -o StrictHostKeyChecking=no root@localhost 'shutdown -h now'"
done
```
