# Provisioning

Netsoc servers run Alpine Linux as their base OS. This is loaded over the
network from the boot server and runs from RAM. Packages are installed from the
internet. Configuration is downloaded over HTTP from the boot server and
overlayed on the base system.

## iPXE

iPXE is an advanced bootloader designed for use with network booting. This is
used to boot Alpine over the network. The version used on Netsoc is the current
revision of the submodule in `boot/ipxe` (built from source).

To update and build the latest iPXE EFI binary (all our servers boot with UEFI):

1. Clone iPXE: `git submodule update --init`
2. Update to the latest version:
    ```
    git -C boot/ipxe pull
    git commit -am "Update iPXE version"
    ```
3. Build the latest EFI binary: `make -C boot/ipxe/src -j$(nproc) bin-x86_64-efi/ipxe.efi`
4. Copy `boot/ipxe/src/bin-x86_64-efi/ipxe.efi` to the boot server
   (`/srv/tftp/ipxe.efi`)

## Alpine Linux setup

Make sure the server to be provisioned is set to UEFI mode and boot over PXE
(IPv4). To install:

1. Boot over PXE, the correct flavor should be pre-selected (`lts` for bare
   metal, `virt` for a VM).
2. Log in as `root` and run:
    1. `apk add vlan` (to pre-install VLAN support for `ifupdown`)
    2. `mkdir /etc/udhcpc && echo 'NO_GATEWAY="lan"' > /etc/udhcpc/udhcpc.conf`
       (to prevent using the LAN interface for internet access)
3. Run `setup-alpine` and follow the prompts:
    1. Choose `ie` as the keyboard layout and then `ie` as the variant
    2. Enter the name of the server for the hostname, e.g. `napalm`
    3. When asked which network interface you'd like to initialize, say `done`.
    4. Say `yes` to do manual network config and paste the following (after the
       section configuring the loopback interface):

        !!! note
            Make sure to change the MAC address to match the LAN interface's MAC,
            set the `hostname` appropriately and the public IP address.

        ```hl_lines="4 5 11"
        auto lan
        iface lan inet dhcp
            pre-up [ -e /sys/class/net/eth0 ] && (ip addr flush dev eth0 && ip link set dev eth0 down) || true
            pre-up nameif $IFACE 52:54:00:12:34:57
            hostname myserver

        auto wan
        iface wan inet static
            vlan-raw-device lan
            vlan-id 420
            address 134.226.83.xxx
            netmask 255.255.0.0
            broadcast 134.226.83.255
            gateway 134.226.83.1
        ```

    5. Enter `Europe/Dublin` for the timezone
    6. Use `none` for the HTTP proxy
    7. `chrony` is fine for the NTP client
    8. The default mirror (dl-cdn.alpinelinux.org) is fine
    9. Use `openssh` for the SSH server
    10. Enter `none` for the disk
    11. `none` for where to store configs and `apk` cache directory

5. Replace the contents of `/etc/apk/repositories` with:
    ```
    https://uk.alpinelinux.org/alpine/v3.12/main
    https://uk.alpinelinux.org/alpine/v3.12/community
    @edge https://uk.alpinelinux.org/alpine/edge/main
    @edge https://uk.alpinelinux.org/alpine/edge/community
    @testing https://uk.alpinelinux.org/alpine/edge/testing
    ```

    Note the mirror name and Alpine branch (`v3.12` in this case). Run
    `apk update` after to update the package lists.

6. Run `apk add nfs-utils` and `rc-update add nfsclient` to install NFS and
   start the client on boot. _Run `rc-service nfsclient start` to start the
   client now_

7. Install and enable `autofs` (`apk add autofs`, `rc-update add autofs`) and
   configure the `apkovl` NFS share:
    1. Replace the contents of `/etc/autofs/auto.master` with the following:

        ```
        /mnt /etc/autofs/auto.shoe --timeout 5
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

8. Set up LBU (Alpine Local Backup):

    When running in diskless mode, Alpine Linux overlays configuration from a
    `tar` stored on a remote server. In order to update configuration, the
    system must be configured. In this case the configs will be stored on the
    boot server via the NFS share set up above.

    Now that the share is set up and accessible, edit `/etc/lbu/lbu.conf` and:

      - Uncomment and set `LBU_BACKUPDIR` to `/mnt/lbu`
      - (Optional but **recommended**) Uncomment and set `BACKUP_LIMIT` to some
      value (e.g. 5) in order to keep a number of backups

    !!! tip
        If you make a mistake in any of the above steps, just reboot to start
        over! All changes up to this point exist only in memory!

9. Save the configuration:

    1. Run `lbu status` (or `lbu st` for short) - a big list of files should
       appear; this is the list of modified files compared to the existing
       overlay archive
    2. Do `lbu commit` to save the changes (a file `myserver.apkovl.tar.gz`
       should now be present in `/mnt/lbu`)
    3. Re-run `lbu status` - nothing should be listed, this means `lbu` is
       reading the saved archive and detecting there are no changed files.
    4. Run `ln -sf myserver.apkovl.tar.gz /mnt/lbu/52:54:00:12:34:57.tar.gz`
       (ensuring to insert the correct hostname and MAC address). This will
       enable the Alpine Linux init script to locate the overlay archive without
       the hostname on boot.

!!! danger
    Make **sure** to commit _any_ filesystem changes with `lbu commit` in
    future!
