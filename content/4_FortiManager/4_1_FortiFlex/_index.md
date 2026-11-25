---
title: "FortiFlex"
menuTitle: "FortiFlex"
weight: 41
---

FortiManager licenses each FortiGate of the UMS group through its FortiFlex connector. The connector uses a FortiCloud **API user** whose permission profile gives it FortiFlex access, and a FortiFlex **configuration** that defines what each FortiGate-VM gets.

## Create the FortiFlex configuration

1. Log in to [FortiFlex](https://fortiflex.fortinet.com) (FortiCloud > Services > FortiFlex) and select the program (program serial number).
2. **Configurations** > **Add**:
   - **Product type**: FortiGate Virtual Machine
   - **Number of CPUs**: the vCPU count of `fgt_instance_type` (4 for `c6i.xlarge` or `c7gn.xlarge`)
   - **Service package** and add-ons: as needed
3. Save, and note the **Configuration ID**.

{{% notice warning %}}
The CPU count of the configuration must match the instance type. A FortiGate-VM licensed for fewer CPUs than the instance has uses only the licensed CPUs.
{{% /notice %}}

## Create the permission profile

In FortiCloud, as the master user (or an IAM user with administrator rights):

1. **Services** > **IAM** > **Permission Profiles** > **Add New**.
2. Enter a **Permission Profile Name**, for example `fortiflex-ums`.
3. **Add Portal** > select **FortiFlex** > **Add**.
4. Turn **Access** on and set the access type to **Admin**.
5. **Submit**.

## Create the API user

1. **Services** > **IAM** > **Users** > **Add New** > **API User**.
2. Enter a **Description**, select the **Permission Profile** created above, and check that it shows FortiFlex with Access enabled and Access Type Admin.
3. **Add**.
4. On the user page, select **Download Credentials**. The download is a zip file with a text file that holds the API user name (API ID) and password.

Keep the credentials safe: FortiManager's FortiFlex connector uses them. They are not used by the Terraform templates.
