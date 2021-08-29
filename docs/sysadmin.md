# Sysadmin guides

## Getting started

In order to get started as a sysadmin for Netsoc, you'll need:

- A good level of Linux system administration knowledge (and ideally experience with
  [Alpine Linux](https://alpinelinux.org/))
- A strong knowledge of [Kubernetes](https://kubernetes.io/)
- An understanding of [GitOps](https://www.gitops.tech/) (specifically how [Flux2](https://fluxcd.io/docs/concepts/))
  works
- Ideally some experience in [Go](https://golang.org/) programming and REST APIs

To connect to Netsoc you'll need a few things (provided by an existing sysadmin!):

- A copy of the Netsoc SSH key (`~/.ssh/id_rsa` on `shoe`) to connect to machines
- A copy of the Netsoc PGP key (can be exported from `shoe` via `gpg --export-secret-keys --armor {{ pgp_key }}` and
  imported with `gpg --import`)
- An account for [our password manager](https://pass.netsoc.tcd.ie), see
  [here](../../gitops/deployments/apps/vaultwarden/#adding-users) for details
- A VPN config file, see [here](../provisioning/boot/#wireguard) for details on how to create one
- A kubeconfig to access the Kubernetes cluster. A copy of `/etc/rancher/k3s/k3s.yaml` from a Kubernetes node will work,
  _but the `server` **must** be changed to `https://shoe:6443`_

Once you have all of these pieces, you can connect to `shoe` by `ssh netsoc@shoe.netsoc.tcd.ie`. If you connect to the
VPN, you can access other machines, e.g. `ssh root@cube`. You must be on the VPN to access the Kubernetes cluster.

## Accessing BMCs

Each of our main servers has a BMC that features some sort of remote management that includes power on / off and virtual
KVM capabilities. _All of the BMCs require VPN connectivity to access._

### `spoon`

`shoe` hosts PiKVM for access to `spoon`. Once connected to the VPN, simply visit [https://shoe](https://shoe). The
credentials are `root:hunter22`.

### `gandalf`

`gandalf` features a HP iLO 4 with an "Advanced" license. Visit [https://gandalf-ilo](https://gandalf-ilo) and click on
"HTML5" under "Integrated Remote console" once logged in. The credentials are `Administrator:hunter22`.

### `napalm` / `cube`

Both `napalm` and `cube` feature a Dell iDRAC 6 Enterprise. Once logged in, you'll need to use the Java Web Start
console. Click the "Launch" button under the "Virtual Console Preview" section on the "System Summary" page. The
credentials are `root:hunter22` and you can connect via [https://napalm-idrac](https://napalm-idrac) and
[https://cube-idrac](https://cube-idrac).

!!! warning
    The iDRAC web UI is a bit old and finicky. Although it works in modern browsers (as of Q3 2021), you might need to
    reload the page a few times to see all UI elements... You might also need Java 8 to get the console to work.

## Maintenance

### netsoc.ie domain

Needs to be renewed with our registrar. See [the DNS docs](../../gitops/deployments/infrastructure/dns/#netsocie) for
details.

### `*.netsoc.tcd.ie` TLS certificate

This certificate is issued to us by IT Services and must be manually renewed. Once obtained, the cert and key should be
updated in both `gitops/infrastructure/common/` **and** on the mailcow VM. See [here](../provisioning/mailcow/) for more
details about updating the mailcow cert.

### GitHub Actions tokens

There are currently to Personal Access Tokens (PATs) in use by many of our repos on GitHub. The `CI_PAT` is set in the
[Netsoc GitHub organisation's settings](https://github.com/organizations/netsoc/settings/secrets/actions) and needs the
`public_repo` scope. This allows repos to push charts and documentation to their respective central repos. Additionally,
a PAT with the `repo:status` scope is needed for
[Flux2 notifications](../../gitops/deployments/infrastructure/notifications/) (stored at
`infrastructure/monitoring/notifications/secrets/github-token.bin`).

See
[here](https://docs.github.com/en/github/authenticating-to-github/keeping-your-account-and-data-secure/creating-a-personal-access-token)
for details on creating GitHub Personal Access Tokens. _These tokens **must** be renewed regularly by the primary
sysadmin._
