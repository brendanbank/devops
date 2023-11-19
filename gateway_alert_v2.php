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
function get_gateway_error_msg(string $status, string $gwname)
{
    if (stristr($status, 'down') !== false) {
        return sprintf(gettext('>>>>> GATEWAY MONITOR: %s is down'), $gwname);
    } elseif (stristr($status, 'loss') !== false) {
        return sprintf(gettext('>>>>> GATEWAY MONITOR: %s has packet loss'), $gwname);
    } elseif (stristr($status, 'delay') !== false) {
        return sprintf(gettext('>>>>> GATEWAY MONITOR: %s has high latency'), $gwname);
    } elseif (stristr($status, 'none') !== false) {
        return sprintf(gettext('GATEWAY MONITOR: %s is up and healthy'), $gwname);
    } else {
        return sprintf(gettext('>>>>> GATEWAY MONITOR: %s unknown status: %s'), $gwname, $status);
    }
}

// Fetch the stateway status (this must rus as a privileged user!
$gateways_status = return_gateways_status();

$clean = true;

// Print a empty line before the output to make the Monit email a bit more readable.
echo "..." . PHP_EOL;

// Run through the gateways configuraion and find entries were the status is set.
foreach ($config['gateways']['gateway_item'] as $gateway_array) {
    $gwname = $gateway_array['name'];
    if (isset($gateways_status[$gwname]['status'])) {
        // fetch name, status and if the gateway is also a default gateway (Upstream Gateway)
        $defaultgw = $gateway_array['defaultgw'];
        $status = $gateways_status[$gwname]['status'];

        // if a the gateway is also a default gateway print the status
        if (stristr($defaultgw, '1') !== false) {
            echo get_gateway_error_msg($status, $gwname) . PHP_EOL;

            // if the status is not 'none' ensure that the exit status is Non Zero.
            if (stristr($status, 'none') == false and stristr($status, 'loss') == false) {
                $clean = false;
            }
        }
    }
}

if ($clean) {
    exit(0);
} else {
    exit(1);
}
