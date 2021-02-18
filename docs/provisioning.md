# Provisioning

Netsoc servers run Alpine Linux as their base OS. This is loaded over the
network from the boot server and runs from RAM. Packages are installed from the
internet. Configuration is downloaded over HTTP from the boot server and
overlayed on the base system.

## Boot server

These instructions assume a working Arch Linux installation (and should be run
as `root`).

Make sure packages are up to date with `pacman -Syu` (reboot if kernel was
upgraded). Once all of the sections below are completed, reboot.

### dnsmasq
Set up `dnsmasq`, the DNS and DHCP server

1. Install `dnsmasq`
2. Replace the contents of `/etc/dnsmasq.conf` with:

    ```hl_lines="18"
    --8<-- "docs/infrastructure/boot/dnsmasq.conf"
    ```

    This configuration sets up

      - A forwarding DNS server
      - DHCP server (with static leases, **add a new `dhcp-host` line for
        each new server that should get the same IP**)
      - DNS resolution for clients by hostname (`*.netsoc.internal`)
      - TFTP server for loading iPXE over PXE (and then chain loading to
        the boot script over HTTP)

3. Create the TFTP directory `/srv/tftp`
4. Replace `/etc/hosts` with:

    ```
    --8<-- "docs/infrastructure/boot/hosts"
    ```

5. Enable `dnsmasq` (`systemctl enable dnsmasq`)

### Network interfaces

1. Install `netctl`
2. Remove any existing network configuration

3. Paste the following into `/etc/netctl/mgmt`:

    ```hl_lines="2"
    --8<-- "docs/infrastructure/boot/netctl-mgmt"
    ```

    This sets up the `mgmt` interface with a static IP address. _Make sure to
    replace `eth0` with the name of the ethernet interface!_

4. Enable the `mgmt` config (`netctl enable mgmt`)

5. Paste the following into `/etc/netctl/lan`:

    ```hl_lines="4"
    --8<-- "docs/infrastructure/boot/netctl-lan"
    ```

    This sets up the `lan` interface with a static IP address. _Make sure to
    replace `eth0` with the name of the ethernet interface!_

6. Enable the `lan` config (`netctl enable lan`)
7. Write the following into `/etc/netctl/wan`:

    ```hl_lines="4 7"
    --8<--- "docs/infrastructure/boot/netctl-wan"
    ```

    This sets up the `wan` interface with a static IP address. _Make sure to
    replace `eth0` with the name of the ethernet interface and `xxx` with the
    desired public IP!_

9. Enable the `wan` config (`netctl enable wan`)
10. Ensure `systemd-resolved` is stopped and disabled
   (`systemctl disable --now systemd-resolved`)
11. Replace `/etc/resolv.conf` with:

    ```hl_lines="4 7"
    --8<--- "docs/infrastructure/boot/resolv.conf"
    ```

    !!! warning
        Make sure `/etc/resolv.conf` isn't a symlink to a volatile generated
        file (`rm` it first to be safe)


### nginx

1. Install `nginx`
2. Replace `/etc/nginx/nginx.conf` with:

    ```
    --8<--- "docs/infrastructure/boot/nginx.conf"
    ```

3. Enable `nginx` (`systemctl enable nginx`)
4. Create the apk overlay directory `/srv/http/apkovl`

### iPXE

iPXE is an advanced bootloader designed for use with network booting. This is
used to boot Alpine over the network. The version used on Netsoc is the current
revision of the submodule in `boot/ipxe` (built from source).

To update and build iPXE:

1. Clone this repo and then iPXE: `git submodule update --init`
2. Update to the latest version:
    ```
    git -C boot/ipxe pull
    git commit -am "Update iPXE version"
    ```
3. Build the latest EFI binary:
   `make -C boot/ipxe/src -j$(nproc) bin-x86_64-efi/ipxe.efi bin/unionly.kpxe`
4. Copy `boot/ipxe/src/bin-x86_64-efi/ipxe.efi` (for UEFI boot) and
   `boot/ipxe/src/bin/undionly.kpxe` (for BIOS ) to the boot server
   (`/srv/tftp/ipxe.efi`, `/srv/tftp/ipxe.kpxe`)
5. Create the iPXE boot script:

    ```ipxe
    --8<--- "docs/infrastructure/boot/boot.ipxe"
    ```
6. Copy an SSH public key to `/srv/http/netsoc.pub`

### NFS

NFS allows the booted systems to update their apkovl archives.

1. Install `nfs-utils`
2. Put `/srv/http/apkovl 10.69.0.0/16(rw,sync,no_subtree_check,no_root_squash,fsid=0)`
   into `/etc/exports` (any machine on the LAN will have access as `root`)
3. Enable `nfs-server` (`systemctl enable nfs-server`)

### Firewall (nftables)

1. Install `nftables`
2. Replace the contents of `/etc/nftables.conf` with:

    ```
    --8<--- "docs/infrastructure/boot/nftables.conf"
    ```

3. Enable `nftables` (`systemctl enable nftables`)
4. Write `net.ipv4.ip_forward=1` into `/etc/sysctl.d/forwarding.conf`

### WireGuard

1. Install `wireguard-tools` and `wireguard-dkms` (you'll also need the kernel
   headers, e.g. `linux-headers` for regular Arch, `linux-raspberrypi-headers`
   for ARMv7 Raspberry Pis)
2. Generate private and public key (as root): `wg genkey | sudo tee /etc/wireguard/privkey | wg pubkey > /etc/wireguard/pubkey`
3. Change private key permissions `chmod 600 /etc/wireguard/privkey`
4. Create `/etc/wireguard/vpn.conf`:

    ```hl_lines="2 7"
    --8<-- "docs/infrastructure/boot/vpn.conf"
    ```

    Replace the private key with the contents of `/etc/wireguard/privkey`! For
    each user, create a `[Peer]` section with their public key and a new IP.

5. Create a client configuration file:

    ```hl_lines="2 7"
    --8<-- "docs/infrastructure/boot/vpn-client.conf"
    ```

    A private key for the client can be generated with `wg genkey` as before.

5. Enable and start the WireGuard service: `systemctl enable --now wg-quick@vpn`

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

        ```hl_lines="3 4 10"
        auto lan
        iface lan inet dhcp
            pre-up [ -e /sys/class/net/eth0 ] && (ip addr flush dev eth0 && ip link set dev eth0 down) || true
            pre-up nameif $IFACE 52:54:00:12:34:57

        auto wan
        iface wan inet static
            vlan-raw-device lan
            vlan-id 420
            address 134.226.83.xxx
            netmask 255.255.255.0
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
    http://uk.alpinelinux.org/alpine/v3.12/main
    http://uk.alpinelinux.org/alpine/v3.12/community
    @edge http://uk.alpinelinux.org/alpine/edge/main
    @edge http://uk.alpinelinux.org/alpine/edge/community
    @testing http://uk.alpinelinux.org/alpine/edge/testing
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

      - Uncomment and set `LBU_BACKUPDIR` to `/mnt/lbu/myserver`
      - (Optional but **recommended**) Uncomment and set `BACKUP_LIMIT` to some
      value (e.g. 5) in order to keep a number of backups

    !!! tip
        If you make a mistake in any of the above steps, just reboot to start
        over! All changes up to this point exist only in memory!

9. Save the configuration:

    1. Run `lbu status` (or `lbu st` for short) - a big list of files should
       appear; this is the list of modified files compared to the existing
       overlay archive
    2. Run `lbu include /root/.ssh/authorized_keys` to save the SSH public
       key put in place automatically on boot
    3. Do `lbu commit` to save the changes (a file `myserver.apkovl.tar.gz`
       should now be present in `/mnt/lbu/myserver`)
    4. Re-run `lbu status` - nothing should be listed, this means `lbu` is
       reading the saved archive and detecting there are no changed files.
    5. Run `ln -sf /mnt/lbu/myserver/myserver.apkovl.tar.gz /mnt/lbu/52:54:00:12:34:57.tar.gz`
       (ensuring to insert the correct hostname and MAC address). This will
       enable the Alpine Linux init script to locate the overlay archive without
       the hostname on boot.

!!! danger
    Make **sure** to commit _any_ filesystem changes with `lbu commit` in
    future!

## Pi-KVM

Pi-KVM is a neat software solution adding a sort of software BMC with a
Raspberry Pi 4.

### Disable auditing

Add `audit=0` to `/boot/cmdline.txt`.

### pikvm pacman repo

Pi-KVM provides pre-built packages for the Raspberry Pi via their own repo.

1. Import the Pi-KVM PGP key (run `pacman-key -r 912C773ABBD1B584 && pacman-key --lsign-key 912C773ABBD1B584`)
2. Add the following to `/etc/pacman.conf`:

    ```
    [pikvm]
    Server = https://pikvm.org/repos/rpi4-arm
    SigLevel = Required DatabaseOptional
    ```

### watchdog

The Linux watchdog will attempt to reset the machine if the system locks up.

1. Install `watchdog`
2. Replace `/etc/watchdog.conf` with:

    ```
    --8<-- "docs/infrastructure/boot/watchdog.conf"
    ```

3. Enable `watchdog` (`systemctl enable watchdog`)

*[BMC]: Baseband Management Controller

### kvmd

kvmd is the main Pi-KVM component.

1. Add a USB drive (or additional SD card partition) for storing virtual media
   images. Format the partition as `ext4` and add the following to `/etc/fstab`:

   ```
   /dev/sda1 /var/lib/kvmd/msd ext4 nodev,nosuid,noexec,ro,errors=remount-ro,data=journal,X-kvmd.otgmsd-root=/var/lib/kvmd/msd,X-kvmd.otgmsd-user=kvmd  0 0
   ```

   _Be sure to replace `/dev/sda1` with the actual device name!

2. Install `kvmd-platform-v2-rpi4` and `kvmd-webterm`

    !!! warning
        `nginx` may be replaced by `nginx-mainline` (a dependency of kvmd). If this
        is the case, `/etc/nginx/nginx.conf` will be backed up to
        `/etc/nginx/nginx.conf.pacsave`. Be sure to move this file back to
        `/etc/nginx/nginx.conf` once the install is complete.

3. Disable kvmd's nginx on port 80 (in `/etc/kvmd/nginx/nginx.conf`)
4. Enable `kvmd`, `kvmd-nginx`, `kvmd-webterm` and `kvmd-otg`.
5. Add `tcp dport https accept` to the `wan-tcp` chain in `/etc/nftables`
   (and reload `nftables`)
6. Add the following to `/boot/config.txt`:

    ```
    hdmi_force_hotplug=1
    gpu_mem=16
    enable_uart=1
    dtoverlay=disable-bt
    dtoverlay=dwc2,dr_mode=peripheral
    ```

7. Check the USB port for the capture card. Once plugged in, kvmd uses a udev
   rule to create a symlink `/dev/kvmd-video -> /dev/video0`. This is only done
   if the `/dev/video0` is connected to a hardcoded USB port, however. The
   script `/usr/bin/kvmd-udev-hdmiusb-check` will perform this check. Edit the
   script and replace the `rpi4` port with the output of the following command:
   `sudo udevadm info -q path -n /dev/video0 | sed 's|/| |g' | awk '{ print $11 }'`
