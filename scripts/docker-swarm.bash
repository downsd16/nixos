# Run on manager server once docker is up
docker swarm join-token -q worker > ./secrets/swarm-worker-token

# Copy Docker-Swarm secret over to pis
scp ./secrets/swarm-worker-token devin@rpi-workerX:/tmp/swarm-worker-token
ssh devin@rpi-workerX 'sudo install -m 0400 -o root -g root /tmp/swarm-worker-token /etc/docker-swarm/worker-token'
ssh devin@rpi-workerX 'sudo systemctl start docker-swarm-bootstrap'

# Label nodes in Docker
docker node update --label-add role=manager rpi-manager
docker node update --label-add role=worker  rpi-workerX