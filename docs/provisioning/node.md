# Node

## Basic Alpine Linux setup

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

## Upgrading Alpine

Upgrading Alpine Linux on nodes is actually quite easy:

On each node, edit `/etc/apk/repositories` and replace the branch in the mirror
URL's (e.g. `http://uk.alpinelinux.org/alpine/v3.12/main` would become
`http://uk.alpinelinux.org/alpine/v3.13/main` in an upgrade from 3.12 to 3.13).
Don't forget to `lbu commit`!

Following this, edit `/srv/http/boot.ipxe` on the boot server and replace the
values of the `branch` and `version` variables with the latest release. Once
that's done, simply reboot the nodes.

## VM host

### Setup

1. Add `tun` to `/etc/modules` (and do `modprobe tun`)
2. Create an LV to store non-essential `libvirt` state such as OS installation images
   (e.g. `lvcreate --type raid0 -L 64GiB -n libvirt raid`)
3. Format the LV (e.g. `mkfs.ext4 -L libvirt /dev/raid/libvirt`)
4. Add the LV to `/etc/fstab`:

    ```
    /dev/raid/libvirt	/var/lib/libvirt	ext4	rw,relatime	0 2
    ```

5. Mount `/dev/raid/libvirt` to `/var/lib/libvirt` (you might need to `mkdir -p /var/lib/libvirt` first)
6. Install libvirt, QEMU and UEFI firmware: `apk add qemu-system-x86_64 libvirt-daemon`
7. Enable and start `libvirtd` and `libvirt-domains`: `rc-service libvirtd start && rc-update add libvirtd && rc-service libvirt-guests start && rc-update add libvirt-guests`
8. Set up network bridges by replacing `/etc/network/interfaces` with (changing the MAC address to match the interface):

    ```hl_lines="7"
    auto lo
    iface lo inet loopback

    auto lan
    iface lan inet manual
    	pre-up [ -e /sys/class/net/eth0 ] && (ip addr flush dev eth0 && ip link set dev eth0 down) || true
    	pre-up nameif $IFACE 40:a8:f0:30:3a:d4

    auto lan-bridge
    iface lan-bridge inet dhcp
    	bridge-ports lan

    auto wan
    iface wan inet manual
    	vlan-raw-device lan
    	vlan-id 420

    auto wan-bridge
    iface wan-bridge inet manual
    	bridge-ports wan
    	up sysctl -w net.ipv6.conf.$IFACE.disable_ipv6=1
    ```
9. Set up libvirt domains to be shut down gracefully along with the host by setting `LIBVIRT_SHUTDOWN="shutdown"`
   and `LIBVIRT_MAXWAIT="300"` In `/etc/conf.d/libvirt-guests`

!!! warning
    VM configuration is stored in `/etc/libvirt`, so be sure to `lbu commit` whenever making changes via `virsh` or
    `virt-manager`!

### Creating VMs

Once libvirt is installed, VMs (or "domains") can be created. There are a number
of ways to do this. `virsh` can be used to define a domain from XML,
`virt-install` can be installed to create a domain with many command line
options and `virt-manager` can be used on a remote machine to manage VMs with a
nice GUI (similar to VirtualBox).

As an example, this is a template to create a domain from XML with `virsh define`
(for use as an Alpine machine):

```xml
<domain type="kvm">
  <name>test</name>
  <memory unit="GiB">8</memory>
  <vcpu>4</vcpu>
  <os>
    <type arch="x86_64" machine="q35">hvm</type>
    <loader readonly="yes" type="pflash">/usr/share/qemu/edk2-x86_64-code.fd</loader>
    <boot dev="network"/>
  </os>
  <features>
    <acpi/>
    <apic/>
	<vmport state="off"/>
  </features>
  <cpu mode="host-passthrough"/>
  <clock offset="utc">
    <timer name="rtc" tickpolicy="catchup"/>
    <timer name="pit" tickpolicy="delay"/>
    <timer name="hpet" present="no"/>
  </clock>
  <devices>
    <disk type="block" device="disk">
      <driver name="qemu" type="raw" cache="none" io="native"/>
      <source dev="/dev/raid/my-lv"/>
      <target dev="vda" bus="virtio"/>
    </disk>
    <interface type="bridge">
      <source bridge="lan-bridge"/>
      <model type="virtio"/>
    </interface>
    <interface type="bridge">
      <source bridge="wan-bridge"/>
      <model type="virtio"/>
    </interface>
    <console type="pty"/>
  </devices>
</domain>
```

!!! tip
    `virsh autostart test` can be used to set the VM to run on boot.

!!! tip
    Adding a second NIC on the `wan-bridge` can be used to simplify network configuration inside the VM. Instead of
    needing to create a VLAN interface, the virtual one can be used directly.

## mailcow setup

1. Set up persistent storage for Docker:
    1. Format the device, e.g. in a VM with a host-managed LV: `mkfs.ext4 -L docker /dev/vda`
    2. Add the mount to `/etc/fstab`:

        ```
        /dev/vda	/var/lib/docker	ext4	rw,relatime 0 2
        ```

    3. Create the mountpoint `/var/lib/docker` and mount the partition (just do `mount -a`)

2. Install Docker and Docker Compose (`apk add docker docker-compose`)
3. Enable and start Docker: `rc-update add docker && rc-service docker start`
4. Install `bash`, `grep`, `coreutils` and `curl`
5. Clone https://github.com/mailcow/mailcow-dockerized into `/var/lib/docker`
6. Run `generate_config.sh` and make the following modifications to `mailcow.conf`:

    - Add `mail.netsoc.tcd.ie` to `ADDITIONAL_SERVER_NAMES`
    - Disable LetsEncrypt certificates (`SKIP_LETS_ENCRYPT=y`)

7. Run `docker-compose up -d` to boot mailcow
8. Replace `data/assets/ssl/cert.pem` and `data/assets/ssl/key.pem` with the `*.netsoc.tcd.ie` certificate. Make sure to
   restart mailcow following this.
9. Add the following to `data/conf/unbound/unbound.conf`:

    ```
    forward-zone:
    name: "."
    forward-addr: 10.69.0.1
    ```

    Run `docker-compose restart unbound-mailcow` to restart Unbound when done.

## Kubernetes node

### Network setup

The `wan` interface needs some extra config to set it up for use with MetalLB, replace the `wan` config with:

```
auto wan
iface wan inet manual
	vlan-raw-device lan
	vlan-id 420
	up sysctl -w net.ipv6.conf.$IFACE.disable_ipv6=1
	up ip link set dev $IFACE up
	post-up ip rule add from 134.226.83.0/24 table tcd
	post-up ip rule add from 134.226.83.0/24 to 10.42.0.0/16 lookup main
	post-up ip route add 134.226.83.0/24 dev $IFACE table tcd
	post-up ip route add default via 134.226.83.1 table tcd
	post-down ip rule del from 134.226.83.0/24 to 10.42.0.0/16 lookup main
	post-down ip rule del from 134.226.83.0/24 table tcd
```

Note: In the above config `10.42.0.0/16` is the cluster network.

### Storage setup

1. Create logical volumes:

    - One to store cluster data, `/mnt/k3s` (e.g. `lvcreate -L 256GiB sata -n k3s`)
    - Another to store persistent volumes with Longhorn (`/var/lib/longhorn`,
      e.g. `lvcreate -L 7.5TiB sata -n longhorn`

    !!! note
        If the Kubernetes node will be in a VM, it would make more sense to create the LVs on the host and format the
        devices directly in the VM

2. Format each LV as `ext4`, e.g. `mkfs.ext4 -L k3s /dev/sata/k3s` (requires
   `e2fsprogs`)
3. Add the volumes to `/etc/fstab` using the following lines:

    ```
    /dev/sata/k3s		/mnt/k3s			ext4	rw,relatime 0 2
    /dev/sata/longhorn	/var/lib/longhorn	ext4	rw,relatime 0 2
    ```

4. Create symlinks for `k3s` data directories:

    - `/var/lib/rancher -> /mnt/k3s/rancher`
    - `/var/lib/kubelet -> /mnt/k3s/kubelet`
    - `/var/lib/cni -> /mnt/k3s/cni`

    !!! warning
        Make sure to `lbu include` each of the symlinks!

5. Mount the `k3s` LV to `/mnt/k3s` and create the target directories of the
   symlinks in the previous step
6. Install `bash` and `curl` (required by Longhorn)
7. Install `open-iscsi` and enable `iscsid` (`rc-update add iscsid`)
8. Exclude `/etc/iscsi` from LBU (`lbu exclude /etc/iscsi`)
9. Commit changes with `lbu commit` and reboot

### k3s setup

1. Write the following into `/etc/init.d/make-rshared`:

    ```
    #!/sbin/openrc-run
    description="Make all mounts shared"

    depend() {
        need localmount
    }

    start() {
        mount --make-rshared /
    }
    ```

    Shared mounts are required for host mounts in Kubernetes to work. _Be sure
    to make the script executable and `lbu include` it!_

2. Enable and start `make-rshared` (`rc-service make-rshared start && rc-update add make-rshared boot`)
3. Install `k3s`
4. Edit `/etc/conf.d/k3s` and set `K3S_OPTS` to:
    - On server nodes: `--node-ip=<Netsoc private IP> --node-external-ip=<Netsoc private IP> --flannel-backend=host-gw --kube-proxy-arg=proxy-mode=ipvs --kube-proxy-arg=ipvs-strict-arp --disable=traefik --disable=servicelb --disable=local-storage --server=https://cluster-api-loadbalancer:6443 --token=<k3s token>`.
    **On the first run of the first server node only**, add `--cluster-init`. There will also not be any `--server` node
    to start with. Once the cluster has settled, _be sure to remove `--cluster-init`_.
    - On agent nodes (don't forget to change `K3S_EXEC` to `agent`!): `--node-ip=<Netsoc private IP> --node-external-ip=<Netsoc private IP> --kube-proxy-arg=proxy-mode=ipvs --kube-proxy-arg=ipvs-strict-arp --server=https://cluster-api-loadbalancer:6443 --token=<k3s token>`
5. Enable and start the `k3s` service (`rc-update add k3s && rc-service k3s start`)

!!! info
    The `cluster-api-loadbalancer` refers to a load balancer configured on another machine which facilitates HA
    deployment of the Kubernetes API server. See [here](../boot/#k3s-kubernetes-api-load-balancer) for setup details.

!!! tip
    A ready to use `kubeconfig` file will be available at
    `/etc/rancher/k3s/k3s.yaml` (on a server node). The token to join nodes to
    the cluster can be found at
    `/var/lib/rancher/k3s/server/token` (also on a server node).
