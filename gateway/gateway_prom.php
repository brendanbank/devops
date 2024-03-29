#!/usr/local/bin/php
<?php

/*
 * Copyright (C) 2018 Deciso B.V.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * This Monit check script script will check if the status of a opnsense gateway.
 * The gateway needs to configured as default gateway a in the
 * Opnsense Menu -> System -> Gateways -> single.
 * This is done by selecting 'Upstream Gateway' This will select the gateway as a
 * default gateway candidate.
 *
 * To use the Monit check script copy it to the Monit script directory.
 *
 * cp <file path> /usr/local/opnsense/scripts/OPNsense/Monit/gateway_alert_v2.php
 * directory. And ensure the executiable bit is set. On the command line execute
 *
 * chmod +x /usr/local/opnsense/scripts/OPNsense/Monit/gateway_alert_v2.php
 *
 * Now go the Opnsense GUI. Navigate to Services -> Monit-> Settings
 * click on the red + sign.
 *
 * 1. check "Enable service checks"
 * 2. add a 'gateway_alert_v2' as a 'Name' of the service checks
 * 3. As a type select 'Custom'
 * 4. past the script path in Path /usr/local/opnsense/scripts/OPNsense/Monit/gateway_alert_v2.php
 * 5. As 'Test' select 'NonZeroStatus'
 * 6. as a description add "gateway_alert_v2" - Or any other descriptin you feel
 * 7. Click 'Save' and 'Apply' and you are done.
 * 8. In the Services -> Monit -> Status menu you can check the status/output of the
 * gateway_alert_v2.php scipt.
 */
require_once ('config.inc');
require_once ('interfaces.inc');
require_once ('util.inc');

/*
 *
 * @param string $status
 * @param string $gwname
 * @return A string detailing the status of the gateway.
 */

function get_gateway_error_msg(string $status)
{
    if (stristr($status, 'down') !== false) {
        return sprintf(gettext('down'));
    } elseif (stristr($status, 'loss') !== false) {
        return sprintf(gettext('packet loss'));
    } elseif (stristr($status, 'delay') !== false) {
        return sprintf(gettext('high latency'), $gwname);
    } elseif (stristr($status, 'none') !== false) {
        return sprintf(gettext('up'), $gwname);
    } else {
        return sprintf(gettext('unknown status: %s'), $status);
    }
}

function get_status(string $status)
{
    if (stristr($status, 'down') !== false) {
        return (0);
    } elseif (stristr($status, 'loss') !== false) {
        return (2);
    } elseif (stristr($status, 'delay') !== false) {
        return (3);
    } elseif (stristr($status, 'none') !== false) {
        return (1);
    } else {
        return (4);
    }
}

// Fetch the stateway status (this must rus as a privileged user!
$gateways_status = return_gateways_status();


$clean = true;
$prom_status =  "# HELP opnsense_gateway_status Information about the gateways" . PHP_EOL;
$prom_status = $prom_status .  "# TYPE opnsense_gateway_status gauge" . PHP_EOL;
  
$prom_delay =  "# HELP opnsense_gateway_delay Information about the gateways" . PHP_EOL;
$prom_delay = $prom_delay .  "# TYPE opnsense_gateway_delay gauge" . PHP_EOL;
  
$prom_loss =  "# HELP opnsense_gateway_loss Information about the gateways" . PHP_EOL;
$prom_loss = $prom_loss .  "# TYPE opnsense_gateway_loss gauge" . PHP_EOL;

$prom_info =  "# HELP opnsense_gateway_info Information about the gateways" . PHP_EOL;
$prom_info = $prom_info .  "# TYPE opnsense_gateway_info gauge" . PHP_EOL;

foreach ($config['OPNsense']['Gateways']['gateway_item'] as $gateway_array) {
    $gwname = $gateway_array['name'];
    if ($gateways_status[$gwname]['monitor'] == '~') {
	continue;
    }
    if (isset($gateways_status[$gwname]['status'])) {
 	$status = $gateways_status[$gwname]['status'];
        $prom_status = $prom_status .  sprintf ('opnsense_gateway_status{gateway="%s"} %d', $gwname, get_status($status)) . PHP_EOL;
    }
 
    if ($gateways_status[$gwname]['delay'] != '~') {
        $delay = trim($gateways_status[$gwname]['delay']," ms");
        #$prom_delay = $prom_delay .  sprintf ('opnsense_gateway_delay{gateway="%s",status="%s",monitor="%s"} %.2f', $gwname, get_gateway_error_msg($status), $monitor, $delay ) . PHP_EOL;
        $prom_delay = $prom_delay .  sprintf ('opnsense_gateway_delay{gateway="%s"} %.2f', $gwname, $delay ) . PHP_EOL;
    }
    if ($gateways_status[$gwname]['loss'] != '~') {
        $loss = trim($gateways_status[$gwname]['loss']," %");
        $prom_loss = $prom_loss .  sprintf ('opnsense_gateway_loss{gateway="%s"} %.2f', $gwname, $loss ) . PHP_EOL;
    }
    if (isset($gateways_status[$gwname]['status'])) {
        $status = $gateways_status[$gwname]['status'];
        $monitor = $gateways_status[$gwname]['monitor'];
        $prom_info = $prom_info .  sprintf ('opnsense_gateway_info{gateway="%s",status="%s",monitor="%s"} %s', $gwname, get_gateway_error_msg($status), $monitor, get_status($status)) . PHP_EOL;
    }
}

echo $prom_status;
echo $prom_delay;
echo $prom_loss;
echo $prom_info;

