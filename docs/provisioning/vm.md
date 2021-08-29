# VM host

This page assumes you want to set up an existing [Alpine Linux node](../node/) with LVM to be a
[libvirt](https://libvirt.org/) VM host.

## Setup

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

## Creating VMs

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
