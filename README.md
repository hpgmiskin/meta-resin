# Resin.io layers for Yocto

## Description
This repository enables building resin.io for various devices.

## Layers Structure
* meta-resin-common : layer which contains common recipes for all our supported platforms.
* meta-resin-* : layers which contain recipes specific to yocto versions.
* other files : README, COPYING, etc.

## Dependencies

* http://www.yoctoproject.org/docs/latest/yocto-project-qs/yocto-project-qs.html#packages
* docker
* jq

## Versioning

`meta-resin` version is kept in `DISTRO_VERSION` variable. `resin-<board>` version is kept in the file called VERSION located in the root of the `resin-<board>` repository and read in the build as variable HOSTOS_VERSION.

* The version of `meta-resin` is in the format is 3 numbers separated by a dot. The patch number can have a `beta` label. e.g. 1.2.3, 1.2.3-beta1, 2.0.0-beta1.
* The version of `resin-<board>` is constructed by appending to the `meta-resin` version a `rev` label. This will have the semantics of a board revision which adapts a specific `meta-resin` version for a targeted board. For example a meta-resin 1.2.3 can go through 3 board revisions at the end of which the final version will be 1.2.3+rev3 .
* The first `resin-board` release based on a specific `meta-resin` release X.Y.Z, will be X.Y.Z+rev1 . Example: the first `resin-board` version based on `meta-resin` 1.2.3 will be 1.2.3+rev1 .
* When updating `meta-resin` version in `resin-board`, the revision will reset to 1. Ex: 1.2.3+rev4 will be updated to 1.2.4+rev1 .
* Note that the final OS version is NOT based on semver specification so parsing of such a version needs to be handled in a custom way.
* e.g. For `meta-resin` release 1.2.3 there can be `resin-<board>` releases 1.2.3+rev`X`.
* e.g. For `meta-resin` release 2.0.0-beta0 there can be `resin-<board>` releases 2.0.0-beta0+rev`X`.

We define host OS version as the `resin-<board>` version and we use this version as HOSTOS_VERSION.

## Build flags

Before bitbake-ing with meta-resin support, a few flags can be changed in the conf/local.conf from the build directory.
Editing of local.conf is to be done after source-ing.
See below for explanation on such build flags.

### Development Images

The DEVELOPMENT_IMAGE variable gets injected into DISTRO_FEATURES. If DEVELOPMENT_IMAGE = "1" then 'development-image' distro feature is added.
Based on this, recipes can decide what development specific changes are needed. By default DEVELOPMENT_IMAGE = "0" which corresponds to a normal (non-development) build (development-image won't be appended to DISTRO_FEATURE).
If user wants a build which creates development images (to use the serial console for example), DEVELOPMENT_IMAGE = "1" needs to be added to local.conf.

To make it short:

* If DEVELOPMENT_IMAGE is not present in your local.conf or it is not "1" : Non-development images will be generated (default behavior)
* If DEVELOPMENT_IMAGE is defined local.conf and its value is "1" : Development images will be generated

### Generation of host OS update bundles

In order to generate update resin host OS bundles, edit the build's local.conf adding:

RESINHUP = "yes"

### Configure custom network manager

By default resin uses NetworkManager on host OS to provide connectivity. If you want to change and use other providers, list your packages using NETWORK_MANAGER_PACKAGES. You can add this variable to local.conf. Here is an example:

NETWORK_MANAGER_PACKAGES = "mynetworkmanager mynetworkmanager-client"

### Customizing splash

We configure all of our initial images to produce a resin logo at boot, shutdown or reboot. But we encourage any user to go and replace that logo with their own.
All you have to do is replace the splash/resin-logo.png file that you will find in the first partition of our images (boot partition) with your own image.
NOTE: As it currently stands plymouth expects the image to be named resin-logo.png.

### Docker storage driver

By the default the build system will set all the bits needed for the docker to be able to use the `aufs` storage driver. This can be changed by defining `BALENA_STORAGE` in your local.conf. It supports `aufs` and `overlay2`.

## Devices support

### WiFi Adapters

We currently tested and provide explicit support for the following WiFi adapters:

* bcm43143 based adapters
    * Example: Official RPI WiFi adapter [link](http://thepihut.com/collections/new-products/products/official-raspberry-pi-wifi-adapter)

## Contributing

To contribute send github pull requests targeting [this](https://github.com/resin-os/meta-resin) repository.

Please refer to: [Yocto Contribution Guidelines](https://wiki.yoctoproject.org/wiki/Contribution_Guidelines#General_Information) and try to use the commit log format as stated there. Example:
```
test.bb: I added a test

[Issue #01]

I'm going to explain here what my commit does in a way that history
would be useful.

Signed-off-by: Joe Developer <joe.developer@example.com>
```

We take advantage of a change log file to keep track of what was changed in a specific version. We used to handle that file manually by adding entries to it at every pull request. In order to avoid racing issues when pushing multiple PRs, we started to use versionist which will generate the change log at every release. This tool uses two footers from commit log: `Change-type` and `Changelog-entry`. Each PR needs to have at least one commit which will specify both of these two commit log footers. In this way, when a new release is handled, the next version will be computed based on `Change-type` and the entries in the change log file will be generated based on `Changelog-entry`.

In the common case where each PR addresses one specific task (issue, bug, feature etc.) the PR will contain a commit which will include `Change-type` and `Changelog-entry` in its commit log. Usually, but not necessary, this commit is the last one in the branch.

`Change-type` is mandatory and, because meta-resin follows semver, can take one of the following values: patch, minor or major. `Changelog-entry` defaults to the subject line.


## How to fix various build errors

* Supervisor fails with a log similar to:
```
Step 3 : RUN chmod 700 /entry.sh
---> Running in 445fe69866f9
operation not supported
```
This is probably because of a docker bug where, if you update kernel and don't reboot, docker gets confused. The fix is to reboot your system.
More info: http://stackoverflow.com/questions/29546388/getting-an-operation-not-supported-error-when-trying-to-run-something-while-bu

## config.json

The behaviour of resinOS can be configured by setting the following keys in the config.json file in the boot partition. This configuration file is also used by the supervisor.

### hostname

String. The configured hostname of this device, otherwise the UUID is used.

### persistentLogging

Boolean. Enable or disable persistent logging on this device.

### country

String. The country in which the device is operating. This is used for setting with WiFi regulatory domain.

### ntpServers

String. A space-separated list of NTP servers to use for time synchronization. Defaults to resinio.pool.ntp.org servers.

### dnsServers

String. A space-separated list of preferred DNS servers to use for name resolution. Falls back to DHCP provided servers and Google DNS.

## Yocto version support

The following Yocto versions are supported:
 * Morty (2.2)
  * **TESTED**
 * Krogoth (2.1)
  * **TESTED**
 * Jethro (2.0)
  * **TESTED**
 * Fido (1.8)
  * **UNTESTED**
