curl -LO -k https://github.com/prometheus/node_exporter/releases/download/v1.0.1/node_exporter-1.0.1.linux-amd64.tar.gz
gunzip -c node_exporter-1.0.1.linux-amd64.tar.gz | tar xopf -
./node_exporter-1.0.1.linux-amd64/node_exporter &

sudo /bin/sh -c 'cat > /etc/rc.local <<EOF
#!/bin/sh
echo "Starting up node_exporter at :9100!"

/home/cirros/node_exporter-1.0.1.linux-amd64/node_exporter 2>&1 > /dev/null &
EOF'
sudo chmod +x /etc/rc.local