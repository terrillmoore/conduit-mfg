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
- Ansible
- The other pre-requisites from https://github.com/IthacaThings/ttn-multitech-cm
