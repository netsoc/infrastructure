# Boot server

Netsoc servers run Alpine Linux as their base OS. This is loaded over the
network from the boot server and runs from RAM. Packages are installed from the
internet. Configuration is downloaded over HTTP from the boot server and
overlayed on the base system.

## Main components

These instructions assume a working Arch Linux installation (and should be run
as `root` **unless otherwise specified**).

Make sure packages are up to date with `pacman -Syu` (reboot if kernel was
upgraded). Once all of the sections below are completed, reboot.

To get started, clone the infrastructure repo into `/var/lib/infrastructure`,
ensuring it's owned by the unprivileged user (assumed to be `netsoc`) _and_ is
world-readable. This can be done by running (as `netsoc`):

```
sudo install -dm 755 -o netsoc -g netsoc /var/lib/infrastructure
git clone git@github.com:netsoc/infrastructure.git /var/lib/infrastructure
```

Any time a step is given to symlink a configuration file out of this repo, _the
provided inline configuration matches 1:1 with what is actually deployed on the
current boot server!_

### dnsmasq
Set up `dnsmasq`, the DNS and DHCP server

1. Install `dnsmasq`
2. Replace `/etc/dnsmasq.conf` with a symlink to `config/dnsmasq.conf` (i.e.
   `ln -sf /var/lib/infrastructure/boot/config/dnsmasq.conf /etc/dnsmasq.conf`).
   Current **live** configuration:

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
4. Replace `/etc/hosts` with a symlink to `boot/config/hosts`. Current **live**
   configuration:

    ```
    --8<-- "docs/infrastructure/boot/hosts"
    ```

5. Enable `dnsmasq` (`systemctl enable dnsmasq`)

### Network interfaces

1. Install `netctl`
2. Remove any existing network configuration

3. Create a symlink to `boot/config/netctl/mgmt` at `/etc/netctl/mgmt`. Current
   **live** configuration:

    ```hl_lines="2"
    --8<-- "docs/infrastructure/boot/netctl-mgmt"
    ```

    This sets up the `mgmt` interface with a static IP address. _Make sure to
    replace `eth0` with the name of the ethernet interface!_

4. Enable the `mgmt` config (`netctl enable mgmt`)

    !!! warning
        If the configuration ever changes, be sure to `netctl re-enable` it!

5. Create a symlink to `boot/config/netctl/lan` at `/etc/netctl/lan`. Current
   **live** configuration:

    ```hl_lines="4"
    --8<-- "docs/infrastructure/boot/netctl-lan"
    ```

    This sets up the `lan` interface with a static IP address. _Make sure to
    replace `eth0` with the name of the ethernet interface!_

6. Enable the `lan` config (`netctl enable lan`)
7. Create a symlink to `boot/config/netctl/wan` at `/etc/netctl/wan`. Current
   **live** configuration:

    ```hl_lines="4 7"
    --8<--- "docs/infrastructure/boot/netctl-wan"
    ```

    This sets up the `wan` interface with a static IP address. _Make sure to
    replace `eth0` with the name of the ethernet interface and use the desired
    public IP!_

9. Enable the `wan` config (`netctl enable wan`)
10. Ensure `systemd-resolved` is stopped and disabled
   (`systemctl disable --now systemd-resolved`)
11. Replace `/etc/resolv.conf` with a symlink to `boot/config/resolv.conf`.
    Current **live** configuration:

    ```hl_lines="4 7"
    --8<--- "docs/infrastructure/boot/resolv.conf"
    ```

### nginx

1. Install `nginx`
2. Replace `/etc/nginx/nginx.conf` with a symlink to `boot/config/nginx.conf`.
   Current **live** configuration:

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
   `boot/ipxe/src/bin/undionly.kpxe` (for BIOS) to the boot server
   (`/srv/tftp/ipxe.efi`, `/srv/tftp/ipxe.kpxe`)
5. Create a symlink to `boot/config/boot.ipxe` at `/srv/http/boot.ipxe` (the
   boot script). Current **live** configuration:

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
2. Replace `/etc/nftables.conf` with a symlink to `boot/config/nftables.conf`.
   Current **live** configuration:

    ```
    --8<--- "docs/infrastructure/boot/nftables.conf"
    ```

3. Enable `nftables` (`systemctl enable nftables`)
4. Write `net.ipv4.ip_forward=1` into `/etc/sysctl.d/forwarding.conf`

### WireGuard

1. Install `wireguard-tools` and `wireguard-dkms` (you'll also need the kernel
   headers, e.g. `linux-headers` for regular Arch, `linux-raspberrypi4-headers`
   for a Raspberry Pi 4)
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

### APKOVL backup

1. Import the Netsoc PGP secret key. To back up Alpine configurations stored on
   the boot server, they first must be encrypted. You can transfer the PGP key
   from a machine which already has it by running the following:

    ```
    gpg --export-secret-keys --armor DB2E28B13D53C8DD62FE560B408F6E592A12DF74 | ssh netsoc@my.boot.server -- gpg --import
    ```

2. Mark the key as trusted. Run
   `gpg --edit DB2E28B13D53C8DD62FE560B408F6E592A12DF74`. Type `trust`, set the
   level to 5 ("I trust ultimately") and accept, before quitting `gpg`.

3. Install the backup service by symlinking `boot/scripts/backup-apkovl.service`
   into `/etc/systemd/system/backup-apkovl.service`. Current **live** service:

    ```
    --8<-- "docs/infrastructure/boot/apkovl/backup.service"
    ```

4. Install the backup timer by symlinking `boot/scripts/backup-apkovl.timer`
   into `/etc/systemd/system/backup-apkovl.timer`. Current **live** timer:

    ```
    --8<-- "docs/infrastructure/boot/apkovl/backup.timer"
    ```

5. Enable and start the timer (`systemctl enable --now backup-apkovl.timer`)

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

    _Be sure to replace `/dev/sda1` with the actual device name!_

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
