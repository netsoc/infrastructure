# Hardware

As of 2021, Netsoc has expanded its operations and now operates a fairly
significant amount of hardware, almost all of which is active in the Maths
department's server room in the Hamilton building.

<figure>
    <img src="../assets/maths_rack.small.jpg" alt="Maths room server rack" />
    <figcaption>
        Maths room server rack. From top to bottom: Maths' KVM, cube, nintendo,
        napalm, gandalf.
    </figcaption>
</figure>

## nintendo

`nintendo` is our switch in the Maths server room rack for handling all
traffic, both internal and external. It's a Netgear GS748TS (48 port gigabit;
managed), donated by `dev`. See [the network docs](../network/) for details on
its configuration.

## cube

`cube` is a Dell PowerEdge R410, the longest-running server in the Maths server
room (purchased new `some_time_ago`).

### Specs

  - 2x Intel Xeon X5670 @ 2.93GHz (6C12T)
  - 64GiB DDR3 (in 8x 8GiB DIMM's, running at 1600MHz)
  - Storage on built-in SATA controller (in each bay):

    - Seagate Enterprise ST6000NM0024-1HT17Z (6TB, 7200rpm SATA)
    - Western Digital Red WDC WD10EFRX-68FYTN0 (1TB, 5400rpm SATA)
    - Western Digital Blue WDC WD10EZEX-08WN4A0 (1TB, 7200rpm SATA)
    - Western Digital Red WDC WD10EFRX-68FYTN0 (1TB, 5400rpm SATA)

  - Dual redundant power supplies (2x 500W)

## napalm

`napalm` is a Dell PowerEdge R710, purchased from `dev` in 2020 (at a very
reasonable price 😛). It was previously used as his home server, where it had
been for 2 years (originally purchased from Bargain Hardware).

### Specs

  - 2x Intel Xeon L5640 @ 2.27GHz (6C12T)
  - 48GiB DDR3 (in 12x 4GiB DIMM's, running at 1333MHz, actual hardware DIMM
    speed TBC)
  - Storage (on a Dell PERC H200 flashed with IT-mode firmware, in each bay):

    - Western Digital Blue WDC WD10EZEX-00KUWA0 (1TB, 7200rpm SATA)
    - HP MB6000JEQUV (6TB, 7200rpm SAS)
    - Western Digital Blue WDC WD5000AZLX-00CL5A0 (500GB, 7200rpm SATA)
    - Western Digital Blue WDC WD5000AZLX-00CL5A0 (500GB, 7200rpm SATA)
    - Western Digital Black WDC WD1003FZEX-00MK2A0 (1TB, 7200rpm SATA)

  - Single (of two possible) power supply (1x 570W)

## gandalf

## spoon

## shoe
