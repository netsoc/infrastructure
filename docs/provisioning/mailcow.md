# mailcow

This page assumes that you have a an existing [Alpine Linux node](../node/) inside a virtual machine (not strictly
necessary but a mail server should really run in its own VM).

## Setup

1. Set up persistent storage for Docker:
    1. Format the device, e.g. in a VM with a host-managed LV: `mkfs.ext4 -L docker /dev/vda`
    2. Add the mount to `/etc/fstab`:

        ```
        /dev/vda	/var/lib/docker	ext4	rw,relatime 0 2
        ```

    3. Create the mountpoint `/var/lib/docker` and mount the partition (just do `mount -a`)

2. Install Docker and Docker Compose (`apk add docker docker-compose`)
3. Enable and start Docker: `rc-update add docker && rc-service docker start`
4. Install `bash`, `grep`, `sed`, `less`, `coreutils` and `curl`
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

## Upgrading

mailcow provides an update script, see [here](https://mailcow.github.io/mailcow-dockerized-docs/i_u_m_update/) for
details.
