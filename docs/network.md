# Network

## Architecture

Netsoc uses three subnets:

- `10.69.0.0/16`: Netsoc private LAN
- `10.79.0.0/24`: Netsoc private VPN
- `134.226.0.0/16`: TCD main allocation, Netsoc is permitted _only_ to use `134.226.83.3-254`
- `192.168.69.0/24`: Maths server room management network

`shoe` acts as a NAT router for all boxes on the private VLAN. Additionally, due to limitations placed on most IPs
in `134.226.83.0/24`, `shoe` forwards mail and DNS traffic.

## IP address allocation

### Management VLAN

- `192.168.69.1`: Maths room boot server
- `192.168.69.10`: `nintendo` (maths room switch)

### Netsoc VLAN

!!! note
    LAN IP addresses are handed out over DHCP (IP addresses fixed in
    `dnsmasq.conf`)

#### Physical machines

- `10.16.0.1`: `shoe` (Maths room boot server)
- `10.16.1.1`: `napalm` (Kubernetes node)
- `10.16.1.2`: `spoon` (Kubernetes node)
- `10.16.1.3`: `cube` (Kubernetes node)
- `10.16.1.4`: `gandalf` (VM host)

#### BMCs

- `10.16.10.1`: `napalm-idrac`
- `10.16.10.3`: `cube-idrac`
- `10.16.10.4`: `gandalf-ilo`

#### VMs

- `10.69.2.1`: `mail` (mail server)
- `10.69.2.2`: `saruman` (Kubernetes node)

### TCD WAN

VIP in this case refers to a "floating" IP that is dynamically assigned to a Kubernetes node in order to forward traffic
to a Kubernetes server. See [the MetalLB deployment](../../gitops/deployments/infrastructure/metallb/) for details.

- `134.226.83.42`: `shoe` (boot server and mail / DNS proxy)
- `134.226.83.27`: DNS VIP
- `134.226.83.100`: HTTP(S) load balancer VIP
- `134.226.83.101`: Webspaces port forwarding VIP
- `134.226.83.102`: [SHH](../../shh/) VIP
- `134.226.83.103`: [Gitea](../../gitops/deployments/apps/gitea/) VIP

!!! note
    Traffic on 134.226.83.101 is forwarded directly to Netsoc members' webspaces and is therefore not managed by us.
    Webspaces are entirely isolated from internal networks and use of the port forwarding service is subject to our
    [ToS](https://www.netsoc.ie/tos/).

There are a few known externally imposed firewall rules on IPs in `134.226.83.0/24`:

- Most IPs are completely shut from both internal and external traffic
- `134.226.83.42` has no (known) limits
- `134.226.83.100-107` have all UDP and TCP ports open _except_ for DNS and SMTP
- `134.226.83.27` has DNS ports open (and possibly a few others, such as SSH and HTTP)

## Firewall rules

### shoe

Since shoe acts as a router, it has a set of nftables rules to accommodate this. The current **live configuration**
(synced through Git) is:


```
--8<--- "docs/infrastructure/boot/nftables.conf"
```

### Kubernetes VIPs

Since traffic for Kubernetes public IPs can enter the cluster on any Kubernetes node, each hosts the same set of
nftables rules. Here's the current **live configuration**:

```
--8<--- "docs/gitops/conf/kubewall-rules.nft"
```

## Maths server room

All our hardware in maths' server room is connected to `nintendo` (our switch,
see the [hardware docs](../hardware/)).

### VLANs

In order to isolate traffic from each subnet (particularly the TCD public
network!), VLAN's are configured on `nintendo`.

- VLAN 1 (management)

    This VLAN exists just to configure `nintendo`. It's untagged on all ports
    (since it's the default VLAN) and the PVID on ports 1, 2, 47 and 48
    (leftmost 2 and rightmost 2 ports respectively).

- VLAN 69 (Netsoc private LAN)

    Untagged on all ports (except for management and TCD uplink 3, 4, 5 and 6),
    tagged on management ports. Also the PVID for all ports except management
    and TCD uplink ports.

- VLAN 420 (TCD public network)

    Untagged and PVID on ports 3, 4, 5, and 6 (for uplink to maths' switches).
    Tagged only on all others to avoid accidentally connecting to the public
    network!

*[PVID]: While a VLAN being untagged on a port tells the switch that a packet on that VLAN should be stripped of VLAN headers when going out on that port, the PVID sets the VLAN that should be assigned to packets coming into the port.
