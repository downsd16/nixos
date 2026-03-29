# Rebuilding on a running pi worker
sudo PI_HOSTNAME=rpi-workerX nixos-rebuild switch --flake .#pi --impure

# Building single swarm manager
sudo nixos-rebuild switch --flake .#manager