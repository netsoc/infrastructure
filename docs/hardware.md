<!-- TODO: Add KVM ports -->

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
room (purchased new `some_time_ago`). It's mounted on sliding rails, complete
with a fancy cable management arm.

### Specs

  - 2x Intel Xeon X5670 @ 2.93GHz (6C12T each)
  - 64GiB DDR3 (in 8x 8GiB RDIMM's, running at 1600MHz)
  - Storage on built-in SATA controller (in each bay):

    - Seagate Enterprise ST6000NM0024-1HT17Z (6TB, 7200rpm SATA)
    - Western Digital Red WDC WD10EFRX-68FYTN0 (1TB, 5400rpm SATA)
    - Western Digital Blue WDC WD10EZEX-08WN4A0 (1TB, 7200rpm SATA)
    - Western Digital Red WDC WD10EFRX-68FYTN0 (1TB, 5400rpm SATA)

  - Dual redundant power supplies (2x 500W)

## napalm

`napalm` is a Dell PowerEdge R710, purchased from `dev` in 2020 (at a very
reasonable price 😛). It was previously used as his home server, where it had
been for 2 years (originally purchased from Bargain Hardware). It's mounted on
sliding rails.

### Specs

  - 2x Intel Xeon L5640 @ 2.27GHz (6C12T each)
  - 48GiB DDR3 (in 12x 4GiB RDIMM's, running at 1333MHz, actual hardware DIMM
    speed TBC)
  - Storage (on a Dell PERC H200 flashed with IT-mode firmware, in each bay):

    - Western Digital Blue WDC WD10EZEX-00KUWA0 (1TB, 7200rpm SATA)
    - HP MB6000JEQUV (6TB, 7200rpm SAS)
    - Western Digital Blue WDC WD5000AZLX-00CL5A0 (500GB, 7200rpm SATA)
    - Western Digital Blue WDC WD5000AZLX-00CL5A0 (500GB, 7200rpm SATA)
    - Western Digital Black WDC WD1003FZEX-00MK2A0 (1TB, 7200rpm SATA)

  - Single (of two possible) power supply (1x 570W)

## gandalf

`gandalf` is an HP ProLiant DL380p (Gen8), kindly purchased for us by the CSC to
host society websites. It's our "newest" server (being purchased in mid-December
2020). It's mounted on static rails.

### Specs

  - 2x Intel Xeon E5-2670 v1 @ 2.6GHz (8C16T each)
  - 128GiB DDR3 (in 8x 16GiB RDIMM's, running at 1600MHz)
  - Storage (on an HP P420i in "HBA" mode, in each bay):

    - HP MB4000JEFNC (4TB, 7200rpm SAS)
    - HP MB4000JEFNC (4TB, 7200rpm SAS)

  - Dual redundant power supplies (2x 750W)

## spoon

## shoe
