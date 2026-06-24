# Shared Actions

This repo contains github actions that can be shared across the org.
The original impetus was for syncing actions to keep the mirrors updated,
but I'm sure that more uses will crop up soon.

## Actions:

### Syncing / mirroring actions:

- These actions will automatically sync an upstream repo of the same name once a day.
- The actual code of the upstream repo will be visible as branches and the plumbing branch should be set to default, with the sync action and documentation on how to use it.
- Branches and tags are all mirrored
- Backup branches are created with dates each time the sync runs. This makes sure that we still have a ref to commits even if upstream forcibly deletes things.

The two actions do things a little bit differently.

- `/.github/workflows/mirror.yml`
  - Designed to be used in a template repo that clones and mirrors a repo all on its own based on its name.
  - To use it, simply create a new repository with the appropriate name. eg, `overlookinfra/foo` will mirror `puppetlabs/foo`.
  - This one doesn't work well because github doesn't like it when actions create/modify workflows. There's a permission to allow this, but I couldn't get it to work properly.
  - Because of ☝️, workflow files are deleted with each sync, which makes the repo get out of sync easily.
- `/.github/workflows/sync.yml`
  - This one is far simpler. It relies on the user to have manually cloned each repo and set up the plumbing branch.
  - It basically just does a `git fetch` and a `git push` and creates the backup branches.

### Beaker Acceptance action:

The `/.github/workflows/beaker_acceptance.yml` is a reusable workflow
for [Beaker](https://github.com/voxpupuli/beaker) acceptance of
OpenVox projects.

It:

* checks out the given project-name@ref
* runs the [nested_vms](https://github.com/jpartlow/nested_vms) action
  to generate a set of test target vms using the
  [kvm_automation_tooling](https://github.com/jpartlow/kvm_automation_tooling)
  Bolt module.
* installs the selected openvox components, either from collections
  served from the apt and yum voxpupuli repositories, or from the
  artifacts-url server for pre-release builds.
* generates a Beaker hosts.yaml from the test target inventory
* configures and executes Beaker with the given beaker-options,
  acceptance-pre-suite and acceptance-tests.

#### Usage

Some example usages can be found in the openvox, openvox-agent and
openvox-server repositories in the `.github/workflows` directory.

See [beaker_acceptance.yml](.github/workflows/beaker_acceptance.yml)
for parameter details.

#### Arm64 Support

You can run the `beaker_acceptance` workflow on arm64 guests in gha by
setting `guest_arch` to `arm64`. Currently though this has serious
limitations due to the lack of kvm support on the gha arm64 runners.

* https://github.com/actions/runner-images/issues/14062

Consequently, the kvm_automation_tooling module runs the arm64 guests
emulated with qemu instead, and they are *very* slow. Many of the
suites hit the gha 6 hour job timeout if run without special
provisions.

The workflow makes several adjustments when it detects that it will be
running the guests in qemu.

For openvox it reduces the os platforms to DEFAULT_OS_ARM64_PLATFORMS
and adds acceptance-shard-tags to the the job matrix to limit the
number of tests executed per runner. With these two concessions, the
openvox suite completes in about 4 hours (at least on the couple of
platforms in that default matrix).

The openvox-agent suite runs normally, albeit slowly. Except that
rocky10 fails currently because `which` is not installed on the arm64
image for unknown reasons, and this breaks the
openvox/packaging/acceptance/tests/validate_vendored_ruby.rb test.

For openvox-server, all the ubuntu platforms are removed from the
matrix, as they are by far the slowest. Alma9/rocky9 are known to
complete successfully at the moment. The other platforms have
scattered but consistent timing failures, mostly related to ssh?
Except el10 which has a postgresql repo gpg key issue that I did not
run down.

For openvoxdb, ubuntu platforms are removed as well, but no work has
been done in the openvoxdb suite to accomodate timeouts and such, and
it generally fails in the presuite.

In general, the workflow adds additional timeouts to the .beaker.yml
configuration, though again, those are only helpful if the beaker
suite being run makes use of them. Currently openvox and
openvox-server suites do, but openvoxdb does not.

I don't know why ubuntu qemu arm64 runs 2-4x slower than el/debian,
but it does and was consistently hitting the 6 hour gha job timeout on
all the suites except openvox-agent, which is why it's excluded
everywhere but there.
