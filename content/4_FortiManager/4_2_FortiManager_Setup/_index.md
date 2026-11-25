---
title: "FortiManager Setup"
menuTitle: "FortiManager Setup"
weight: 42
---

Log in to FortiManager as `admin` with `fortimanager_admin_password`, at `https://<fortimanager_public_ip>` (or through the jump box). Do these steps in the **root** ADOM unless noted.

## 1. Check the global settings

```
get system global | grep fgfm-allow-vm
```

It must show `fgfm-allow-vm: enable`. The FortiManager that `existing_vpc_resources` builds sets it at boot. On another FortiManager:

```
config system global
    set fgfm-allow-vm enable
end
```

Note the serial number for `fortimanager_sn`:

```
get system status
```

## 2. Create the REST API administrator

The FortiGates present this administrator's API key when they register (`execute central-mgmt register-device-by-ip`), and the auto-onboarding rule matches on it.

1. **System Settings** > **Administrators** > **Create New** > **REST API Admin**.
2. **User Name**: for example `ums-api`. **Description**: optional.
3. **Admin Profile**: `Super_User` (or a profile with device management rights).
4. Turn on **Automatic Register**. This lets the auto-onboarding rule select this administrator.
5. **OK**, then generate the **API key** and copy it. This is `fortimanager_api_key` in `ums_template`.

## 3. Create the AWS SDN connector

1. **Fabric View** > **Fabric Connectors** > **Create New** > **Amazon Web Services (AWS)** (FortiManager Administration Guide: *Creating AWS fabric connectors*).
2. Enter a **Name**, the **Region** of the deployment, and the credentials (access key and secret key) of the AWS identity described in [Prerequisites](../../3_prerequisites/#fortimanager-requirements).
3. **OK**.

Test the connector: create a dynamic address object that uses it (**Policy & Objects** > **Object Configurations** > **Firewall Objects** > **Addresses** > **Create New** > **Dynamic** > the AWS connector). The filter list shows what the credentials can read.

## 4. Enable the SDN connector for UMS

1. **Policy & Objects** > **Policy Packages** > **Tools** > **Feature Visibility**, and turn on **User Managed Scaling**.
2. **Policy & Objects** > **Security Fabric** > **User Managed Scaling** tab > **Create New**:
   - **Name**: for example `aws-ums`
   - **Type**: Amazon Web Services (AWS)
   - **SDN Connector**: the AWS connector from step 3
3. **OK**.

## 5. Create the FortiFlex connector

1. **Fabric View** > **External Connectors** > **Create New** > **FortiFlex**.
2. Enter the API user name and password from the credentials downloaded in [FortiFlex](../4_1_fortiflex/).
3. **OK**.
4. Edit the connector, enter the FortiFlex **program serial number**, **Apply**, refresh, and select the **configuration** created for the UMS group as the default configuration of the connector.

## 6. Create the auto-onboarding rule

The auto-onboarding rule decides what happens to each FortiGate that registers with the API key.

1. **Device Manager** > **Device & Groups** > **Add Device** drop-down > **Auto Onboarding**, and select **Allow Auto Onboarding**.
2. **Onboarding Rule** tab > **Create New**.
3. **Rules**:
   - **Type**: Administrator
   - **Administrator**: the REST API administrator from step 2
   - **Platform**: all platforms
   - **Device Name Prefix**: optional, for example `ums-` (the serial number is used when empty)
4. **Actions**:
   - **ADOM**: root, or the ADOM of the UMS group
   - **Device Group**: the device group of the UMS group (for example `Managed FortiGates`)
   - **Install License**: **Flex VM** (uses the FortiFlex connector)
   - **Install Configuration**: **Manual Configuration**, with the template group and policy package of the UMS group (created in [Apply Configuration](../../5_deployment/5_3_apply_configuration/); edit the rule then to select them)
5. **OK**.

{{% notice info %}}
Write down `fortimanager_ip`, `fortimanager_sn` and `fortimanager_api_key` for `ums_template`. The FortiManager configuration is now ready for the FortiGates to register.
{{% /notice %}}

## Troubleshooting registration

On FortiManager:

```
diagnose debug reset
diagnose debug application fgfmsd 255
diagnose debug service sys 255
diagnose debug timestamp enable
diagnose debug enable
```

On a FortiGate (SSH with `keypair` through the jump box, or its public address):

```
get system central-management
diagnose debug application fgfmd -1
diagnose debug enable
```

| Symptom | Check |
|---|---|
| The FortiGate never shows in Device Manager | TCP 541 from the FortiGate to `fortimanager_ip` (security groups, routes), `fortimanager_sn`, `fortimanager_api_key` |
| The FortiGate shows as unauthorized | Auto-onboarding rule: administrator and platform |
| The UMS group shows no instance counts | AWS SDN connector credentials and permissions |
| HTTPS management conflicts with IPsec over TCP 443 | Add `config system settings` / `set ike-tcp-port 10443` / `end` to a CLI template |
