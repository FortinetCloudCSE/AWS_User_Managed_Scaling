---
title: "FortiManager Configuration"
chapter: true
menuTitle: "FortiManager Configuration"
weight: 40
---

# FortiManager Configuration

UMS is driven from FortiManager. Configure FortiFlex and FortiManager **after** `existing_vpc_resources` has built FortiManager and **before** `ums_template` launches the FortiGates: each FortiGate registers once, at first boot, with the API key and the auto-onboarding rule configured here.

1. [FortiFlex](4_1_fortiflex/): FortiFlex configuration, API user and permission profile
2. [FortiManager Setup](4_2_fortimanager_setup/): API administrator, AWS SDN connector, UMS connector, FortiFlex connector, auto-onboarding rule

The CLI template and policy package of the UMS group are applied after `ums_template`, because the CLI template holds the addresses of the Gateway Load Balancer that `ums_template` creates. See [Apply Configuration](../5_deployment/5_3_apply_configuration/).
