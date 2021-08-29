# Alpine Linux node

## Basic setup

Make sure the server to be provisioned is set to UEFI mode and boot over PXE
(IPv4). To install:

### Main install

1. Boot over PXE, the correct flavor should be pre-selected (`lts` for bare
   metal, `virt` for a VM).
2. Log in as `root` and run:

    1. `apk add vlan` (to pre-install VLAN support for `ifupdown`). _This can be
       skipped if installing a VM with a host-created `wan-bridge`._
    2. Paste the following into `/etc/iproute2/rt_tables`:

        ```
        1	tcd
        ```

3. Run `setup-alpine` and follow the prompts:

    1. Choose `ie` as the keyboard layout and then `ie` as the variant
    2. Enter the name of the server for the hostname, e.g. `napalm`
    3. When asked which network interface you'd like to initialize, say `done`.
    4. Say `yes` to do manual network config and paste the following (after the
       section configuring the loopback interface):

        !!! note
            Make sure to change the MAC address to match the LAN interface's MAC,
            set the `hostname` appropriately and the public IP address.

        !!! note
            Remove the `vlan-*` lines if using a host-created `wan-bridge`. A `pre-up nameif $IFACE MAC_ADDRESS` line
            should be added to the `wan` config in this case (with the MAC address of the virtual interface).

        ```hl_lines="3 4 11"
        auto lan
        iface lan inet dhcp
        	pre-up [ -e /sys/class/net/eth0 ] && (ip addr flush dev eth0 && ip link set dev eth0 down) || true
        	pre-up nameif $IFACE 52:54:00:12:34:57

        auto wan
        iface wan inet static
        	vlan-raw-device lan
        	vlan-id 420
        	up sysctl -w net.ipv6.conf.$IFACE.disable_ipv6=1
        	address 134.226.83.xxx
        	netmask 255.255.255.0
        	broadcast 134.226.83.255
        	post-up ip rule add from 134.226.83.0/24 table tcd
        	post-up ip route add default via 134.226.83.1 table tcd
        	post-down ip rule del from 134.226.83.0/24 table tcd
        ```

    5. Enter `Europe/Dublin` for the timezone
    6. Use `none` for the HTTP proxy
    7. `chrony` is fine for the NTP client
    8. Press `e` to edit `/etc/apk/repositories` and replace the contents with:

        ```
        http://dl-cdn.alpinelinux.org/alpine/v3.14/main
        http://dl-cdn.alpinelinux.org/alpine/v3.14/community
        @edge http://dl-cdn.alpinelinux.org/alpine/edge/main
        @edge http://dl-cdn.alpinelinux.org/alpine/edge/community
        @testing http://dl-cdn.alpinelinux.org/alpine/edge/testing
        ```

        Note the mirror name and Alpine branch (`v3.14` in this case).

    9. Use `openssh` for the SSH server
    10. Enter `none` for the disk
    11. `none` for where to store configs and `apk` cache directory

4. Blacklist the `tiny-power-button` module by writing the following into `/etc/modprobe.d/button.conf`:

    ```
    # Conflicts with `button` for ACPI shutdown
    blacklist tiny-power-button
    ```

5. If KVM is needed on the node, add `kvm_intel` or `kvm_amd` to `/etc/modules`
6. If nested KVM is needed, put `options kvm_intel nested=Y` or
   `options kvm_amd nested=1` (*note the use of `1` vs `Y`*)

### NFS

1. Run `apk add nfs-utils` and `rc-update add nfsclient` to install NFS and
   start the client on boot. _Run `rc-service nfsclient start` to start the
   client now_

2. Install and enable `autofs` (`apk add autofs`, `rc-update add autofs`) and
   configure the `apkovl` NFS share:

    1. Replace the contents of `/etc/autofs/auto.master` with the following:

        ```
        /media/autofs /etc/autofs/auto.shoe --timeout 5
        ```

    2. Paste the following into `/etc/autofs/auto.shoe`:

        ```
        lbu -rw shoe.netsoc.internal:/srv/http/apkovl
        ```

        !!! note
            `autofs` is used instead of just putting the mount into `/etc/fstab`
            to only mount the share when required and more gracefully handle
            disconnects

        _Run `rc-service autofs start` to start `autofs` now._

### LBU (Alpine Local Backup)

When running in diskless mode, Alpine Linux overlays configuration from a
`tar` stored on a remote server. In order to update configuration, the
system must be configured. In this case the configs will be stored on the
boot server via the NFS share set up above.

1. Configure LBU by editing `/etc/lbu/lbu.conf` and:

    - Uncomment and set `LBU_BACKUPDIR` to `/media/autofs/lbu/myserver`
    - (Optional but **recommended**) Uncomment and set `BACKUP_LIMIT` to some
    value (e.g. 5) in order to keep a number of backups

    !!! tip
        If you make a mistake in any of the above steps, just reboot to start
        over! All changes up to this point exist only in memory!

2. Save the configuration:

    1. Run `lbu status` (or `lbu st` for short) - a big list of files should
       appear; this is the list of modified files compared to the existing
       overlay archive
    2. Run `lbu include /root/.ssh/authorized_keys` to save the SSH public
       key that was put in place automatically on boot
    3. Do `lbu commit` to save the changes (a file `myserver.apkovl.tar.gz`
       should now be present in `/media/autofs/lbu/myserver`). You might need to
       `mkdir /media/autofs/lbu/myserver` first.
    4. Re-run `lbu status` - nothing should be listed, this means `lbu` is
       reading the saved archive and detecting there are no changed files.
    5. Run `ln -s myserver/myserver.apkovl.tar.gz "/media/autofs/lbu/52:54:00:12:34:57.tar.gz"`
       (ensuring to insert the correct hostname and MAC address). This will
       enable the Alpine Linux init script to locate the overlay archive without
       the hostname on boot.

    !!! danger
        Make **sure** to commit _any_ filesystem changes with `lbu commit` in
        future!

### LVM

1. Install `lvm2`, `lvm2-dmeventd` and `util-linux`
2. Start the `lvm` service and enable `lvm` at runlevel `boot` (`rc-service lvm start && rc-update add lvm boot`)
3. Start the `dmeventd` service and enable `dmeventd` at runlevel `boot` (`rc-service dmeventd start && rc-update add dmeventd boot`)

You can then:

- Create PVs (e.g. `pvcreate /dev/sda`); `wipefs` from `util-linux` can
    be used to allow previously partitioned disks to be used
- Create a volume group (e.g. `vgcreate myvg /dev/sda /dev/sdb /dev/sdc`)
- Create LVs, e.g. `lvcreate -L 256GiB myvg -n mylv`
- Create RAID LVs, e.g. `lvcreate --type raid0 -n mystripes myvg`
- View hidden SubLVs (for striping / mirroring): `lvs -a -o name,segtype,devices`

## Upgrading

Upgrading Alpine Linux on nodes is actually quite easy:

On each node, edit `/etc/apk/repositories` and replace the branch in the mirror
URL's (e.g. `http://uk.alpinelinux.org/alpine/v3.12/main` would become
`http://uk.alpinelinux.org/alpine/v3.13/main` in an upgrade from 3.12 to 3.13).
Don't forget to `lbu commit`!

Following this, edit `/srv/http/boot.ipxe` on the boot server and replace the
values of the `branch` and `version` variables with the latest release. Once
that's done, simply reboot the nodes.
