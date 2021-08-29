# Kubernetes node

This page assumes you have an existing [Alpine Linux node](../node/) (bare metal or VM) with LVM and would like to use
it as a Kubernetes cluster node.

## Networking

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

## Storage

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

## k3s

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
    - On server nodes:

        ```
        --node-ip=<Netsoc private IP> --node-external-ip=<Netsoc private IP> --flannel-backend=host-gw --kube-proxy-arg=proxy-mode=ipvs --kube-proxy-arg=ipvs-strict-arp --disable=traefik --disable=servicelb --disable=local-storage --server=https://cluster-api-loadbalancer:6443 --token=<k3s token>
        ```

        **On the first run of the first server node only**, add `--cluster-init`. There will also not be any `--server` node
        to start with. Once the cluster has settled, _be sure to remove `--cluster-init`_ and restart `k3s`.

    - On agent nodes (don't forget to change `K3S_EXEC` to `agent`!):

        ```
        --node-ip=<Netsoc private IP> --node-external-ip=<Netsoc private IP> --kube-proxy-arg=proxy-mode=ipvs --kube-proxy-arg=ipvs-strict-arp --server=https://cluster-api-loadbalancer:6443 --token=<k3s token>
        ```

5. Enable and start the `k3s` service (`rc-update add k3s && rc-service k3s start`)

!!! info
    The `cluster-api-loadbalancer` refers to a load balancer configured on another machine which facilitates HA
    deployment of the Kubernetes API server. See [here](../boot/#k3s-kubernetes-api-load-balancer) for setup details.

!!! tip
    A ready to use `kubeconfig` file will be available at
    `/etc/rancher/k3s/k3s.yaml` (on a server node). The token to join nodes to
    the cluster can be found at
    `/var/lib/rancher/k3s/server/token` (also on a server node).
