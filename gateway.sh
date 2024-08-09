#!/bin/sh

/home/brendan/gateway_prom.php > /tmp/gateway_prom.php.$$
sudo mv /tmp/gateway_prom.php.$$ /var/tmp/node_exporter/opnsense.prom
