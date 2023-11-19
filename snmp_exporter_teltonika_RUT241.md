# Creating a Grafana Dashboard for Teltonika RUTxxx routers
<img width="1633" alt="teltonica-dashboard" src="https://github.com/brendanbank/devops/assets/63699049/7bad970e-b61b-4df6-9bf0-4507ce1d2674">

## Instalation and Configuration
1. First, install [snmp_exporter](https://github.com/prometheus/snmp_exporter) and build the the source code. Or run snmp_exporter in a docker container.
2. [Install the SNMP package](https://wiki.teltonika-networks.com/view/RUT241_SNMP) on the Teltonika RUT241 router
3. Enable the SNMP  Teltonika RUT241 router: Services -> SNMP -> SNMP Settings -> **Toggle Enable**
4. Changing the default community (SNMP password) from **"public"** to something more appropriate is recommended: Services -> SNMP -> **Communities** 
5. Download the MIB from the Teltonika RUT241 router. You can find mib on the SNMP configuration page of the router. Services -> SNMP -> SNMP Settings -> click **Download**

<img width="600" alt="teltonica-snmp-config" src="https://github.com/brendanbank/devops/assets/63699049/b20ad0a7-89bb-4dea-b8d5-26ee0cb988b5">

6. Go into the snmp_exporter/generator directory and type
   
       make generate
7. Copy the MIB you downloaded from the router into the generator mibs directory snmp_exporter/generator/mibs of the [snmp_exporter](https://github.com/prometheus/snmp_exporter) package.
8. Add the Teltonika RUT241 router configuration to the generator.yml file in the snmp_exporter/generator directory. 

  \# add this to the generator.yml file
  
     teltonika:
       walk:
         - hrSystem
         - sysUpTime
         - interfaces
         - ifXTable
         - ssCpuUser
         - ssCpuSystem
         - ssCpuIdle
         - 1.3.6.1.4.1.48690 # Teltonika
         - 1.3.6.1.4.1.2021.4 # memory
         - 1.3.6.1.4.1.2021.10 # Load
         - 1.3.6.1.4.1.2021.11 # systemStats
         - hrStorage
       lookups:
         - source_indexes: [hrStorageIndex]
           lookup: hrStorageDescr
           drop_source_indexes: true
         - source_indexes: [ifIndex]
           lookup: ifAlias
           drop_source_indexes: true
         - source_indexes: [ifIndex]
           # Uis OID to avoid conflict with PaloAlto PAN-COMMON-MIB.
           lookup: 1.3.6.1.2.1.2.2.1.2 # ifDescr
           drop_source_indexes: true
         - source_indexes: [ifIndex]
           # Use OID to avoid conflict with Netscaler NS-ROOT-MIB.
           lookup: 1.3.6.1.2.1.31.1.1.1.1 # ifName
           drop_source_indexes: true
         - source_indexes: [laIndex]
           lookup: laNames
           drop_source_indexes: true
         - source_indexes: [mIndex]
           lookup: mDescr
           drop_source_indexes: true
         - source_indexes: [ioIndex]
           lookup: ioName
           drop_source_indexes: true
         - source_indexes: [ioIndex]
           lookup: ioType
           drop_source_indexes: true
         - source_indexes: [pIndex]
           lookup: pName
           drop_source_indexes: true
   
       overrides:
         mRSRQ:
           type: Float
         mSINR:
           type: Float
         mRSRP:
           type: Float
         mTemperature:
           type: Float
         ifAlias:
           ignore: true # Lookup metric
         ifDescr:
           ignore: true # Lookup metric
         ifName:
           ignore: true # Lookup metric
         ifType:
           type: EnumAsInfo

8. Then type make generate again and copy the snmp.yml file in the snmp_exporter/generator directory to /etc/prometheus/snmp.yml and restart the snmp_exporter service.
      
       make generate
9. Add the scraper configuration to the /etc/prometheus/prometheus.yml file.

        - job_name: 'snmp'
          static_configs:
            - targets:
              - **<your hostname/ip address>**  # SNMP device.
          metrics_path: /snmp
          params:
            #auth: [public]
            module: [teltonika]
          relabel_configs:
            - source_labels: [__address__]
              target_label: __param_target
            - source_labels: [__param_target]
              target_label: instance
            - target_label: __address__
              replacement: 127.0.0.1:9116  # The SNMP exporter's real hostname:port.
10. Restart the Prometheus daemon with a "kill -HUP" signal to tell the daemon to reread its config.
11. Start/Restart the snmp_exporter daemon.
    
