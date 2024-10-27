# router_make.sh
#!/bin/bash
# code modified from pancho.dev

# create the /var/run/netns/ path if it doesn't already exist
sudo mkdir -p /var/run/netns/

docker run --privileged -d -t --net none --name c1 fcastello/ubuntu-network bash
sleep 1
docker run --privileged -d -t --net none --name r1 fcastello/ubuntu-network bash
sleep 1
docker run --privileged -d -t --net none --name c2 fcastello/ubuntu-network bash
sleep 1

# Get the container id for each container (will be needed later)
c1_id=$(docker ps --format '{{.ID}}' --filter name=c1)
r1_id=$(docker ps --format '{{.ID}}' --filter name=r1)
c2_id=$(docker ps --format '{{.ID}}' --filter name=c2)


# Get the containers pids which will be used to find their network namespace
c1_pid=$(docker inspect -f '{{.State.Pid}}' ${c1_id})
r1_pid=$(docker inspect -f '{{.State.Pid}}' ${r1_id})
c2_pid=$(docker inspect -f '{{.State.Pid}}' ${c2_id})

# create the /var/run/netns/ path if it doesn't already exist
# sudo mkdir -p /var/run/netns/


# Create a soft link to the containers network namespace to /var/run/netns/
sudo ln -sfT /proc/$c1_pid/ns/net /var/run/netns/$c1_id
sudo ln -sfT /proc/$r1_pid/ns/net /var/run/netns/$r1_id
sudo ln -sfT /proc/$c2_pid/ns/net /var/run/netns/$c2_id


# Now lets show the ip addresses in each contaier namespace
# C1
sudo ip netns exec $c1_id ip a
sudo ip netns exec $r1_id ip a
sudo ip netns exec $c2_id ip a

#!/bin/bash
# router_test_pt2.sh
# Create the virtual ethernet devices for conecting C1 to R1
sudo ip link add 'c1-eth0' type veth peer name 'r1-eth0'

# Create the virtual ethernet devices for conecting C2 to R1
sudo ip link add 'c2-eth0' type veth peer name 'r1-eth1'

# We created the virtual ethernet pairs but they are still in the host network namespace
# we need to move each virtual interface now to the corresponding containers namespace

# move c1 interface to c1 container
sudo ip link set 'c1-eth0' netns $c1_id

# move r1 interfaces to r1 container
# note that r1 is a router which will
# need at least 2 interfaces
sudo ip link set 'r1-eth0' netns $r1_id
sudo ip link set 'r1-eth1' netns $r1_id

# move c2 interface to c2 container
sudo ip link set 'c2-eth0' netns $c2_id

# Next step is not needed but it is nice to have more standard interface names
# so we will rename interfaces inside the containers

# rename c1 container interface from c1-eth0 to eth0
sudo ip netns exec $c1_id ip link set 'c1-eth0' name 'eth0'

# rename r1 container interfaces from r1-eth0 to eth0 and r1-eth1 to eth1
sudo ip netns exec $r1_id ip link set 'r1-eth0' name 'eth0'
sudo ip netns exec $r1_id ip link set 'r1-eth1' name 'eth1'

# rename c2 container interface form c2-eth0 to eth0
sudo ip netns exec $c2_id ip link set 'c2-eth0' name 'eth0'


# bring up all interfaces in containers
sudo ip netns exec $c1_id ip link set 'eth0' up
sudo ip netns exec $c1_id ip link set 'lo' up
sudo ip netns exec $r1_id ip link set 'eth0' up
sudo ip netns exec $r1_id ip link set 'eth1' up
sudo ip netns exec $r1_id ip link set 'lo' up
sudo ip netns exec $c2_id ip link set 'eth0' up
sudo ip netns exec $c2_id ip link set 'lo' up

# lets set c1 container ip to 192.168.10.2
sudo ip netns exec $c1_id ip addr add 192.168.10.2/24 dev eth0

# lets set r1 ips to 192.168.10.1 and 192.168.11.1
sudo ip netns exec $r1_id ip addr add 192.168.10.1/24 dev eth0
sudo ip netns exec $r1_id ip addr add 192.168.11.1/24 dev eth1

# lets set c2 container ip to 192.168.11.2
sudo ip netns exec $c2_id ip addr add 192.168.11.2/24 dev eth0
