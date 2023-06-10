# Connectivity info for Linux VM
NIXADDR ?= unset
NIXPORT ?= 22
NIXUSER ?= mitchellh

# Get the path to this Makefile and directory
MAKEFILE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# The name of the nixosConfiguration in the flake
NIXNAME ?= vm-aarch64-prl

# SSH options that are used. These aren't meant to be overridden but are
# reused a lot so we just store them up here.
SSH_OPTIONS=-o PubkeyAuthentication=no -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no

# We need to do some OS switching below.
UNAME := $(shell uname)

switch:
ifeq ($(UNAME), Darwin)
	nix build ".#darwinConfigurations.${NIXNAME}.system"
	./result/sw/bin/darwin-rebuild switch --flake "$$(pwd)#${NIXNAME}"
else
	sudo NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nixos-rebuild switch --flake ".#${NIXNAME}"
endif

test:
ifeq ($(UNAME), Darwin)
	nix build ".#darwinConfigurations.${NIXNAME}.system"
	./result/sw/bin/darwin-rebuild test --flake "$$(pwd)#${NIXNAME}"
else
	sudo NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nixos-rebuild test --flake ".#$(NIXNAME)"
endif

# bootstrap a brand new VM. The VM should have NixOS ISO on the CD drive
# and just set the password of the root user to "root". This will install
# NixOS. After installing NixOS, you must reboot and set the root password
# for the next step.
#
# NOTE(mitchellh): I'm sure there is a way to do this and bootstrap all
# in one step but when I tried to merge them I got errors. One day.
vm/bootstrap0:
	parted /dev/sda -- mklabel gpt; \
	parted /dev/sda -- mkpart primary 512MiB -8GiB; \
	parted /dev/sda -- mkpart primary linux-swap -8GiB 100\%; \
	parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB; \
	parted /dev/sda -- set 3 esp on; \
	sleep 1; \
	mkfs.ext4 -L nixos /dev/sda1; \
	mkswap -L swap /dev/sda2; \
	mkfs.fat -F 32 -n boot /dev/sda3; \
	sleep 1; \
	mount /dev/disk/by-label/nixos /mnt; \
	mkdir -p /mnt/boot; \
	mount /dev/disk/by-label/boot /mnt/boot; \
	nixos-generate-config --root /mnt; \
	sed --in-place '/system\.stateVersion = .*/a \
		nix.package = pkgs.nixUnstable;\n \
		nix.extraOptions = \"experimental-features = nix-command flakes\";\n \
		users.users.root.initialPassword = \"root\";\n \
	' /mnt/etc/nixos/configuration.nix; \
	nixos-install --no-root-passwd; \
	reboot;

# after bootstrap0, run this to finalize. After this, do everything else
# in the VM unless secrets change.
vm/bootstrap:
	NIXUSER=root $(MAKE) vm/switch
	sudo reboot;

# copy the Nix configurations into the VM.
vm/copy:
	rsync -av -e 'ssh $(SSH_OPTIONS) -p$(NIXPORT)' \
		--exclude='vendor/' \
		--exclude='.git/' \
		--exclude='.git-crypt/' \
		--exclude='iso/' \
		--rsync-path="sudo rsync" \
		$(MAKEFILE_DIR)/ $(NIXUSER)@$(NIXADDR):/nix-config

# run the nixos-rebuild switch command. This does NOT copy files so you
# have to run vm/copy before.
vm/switch:
	sudo NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nixos-rebuild switch --flake "/nix-config#${NIXNAME}" 

# Build an ISO image
iso/nixos.iso:
	cd iso; ./build.sh