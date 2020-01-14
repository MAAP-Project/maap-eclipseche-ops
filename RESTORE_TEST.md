# Steps to test the MAAP ADE restoration procedure

When restoring the MAAP ADE from a snapshot, the following operational steps, along with testing requirements, are to be taken. These steps ensure that data is properly restored both within the persisted volumes of the ADE workspaces, which are backed up externally, as well as any ephemeral data outside the persistent volumes within ADE workspaces. 

This guide includes two separate roles for performing the steps, `Administrator` and `Tester`.

### Step 1) Create workspace files in Che (`Tester`)

- a) Log in to the MAAP ADE instance to be restored and create a new workspace.
- b) Open the new workspace. In the Launcher tab, open a 'Terminal' session.
- c) In the new terminal window, run the following commands:

```bash
touch test_project_file.txt
cd ..
test_root_file.txt
```

- d) Run `ls` and `ls projects` to verify your root level file and project file were created.

### Step 2) Save a VM Snapshot (`Tester`)

- a) Using the AWS console, locate the volume for the EC2 instance running the MAAP ADE on which you just created a test workspace. The 'Volumes' page can be found in the EC2 Dashboard under the 'ELASTIC BLOCK STORE' menu.
- b) Select the appropriate volume. Then open the 'ACTIONS' menu and select 'Create Snapshot'
- c) Wait for the snapshot operation to complete, then proceed to step 3).

### Step 3) Shutdown the VM (`Tester`)

In the EC2 Dashboard 'INSTANCES' menu, select the test ADE VM. Then open the Actions menu and select 'Instance State' > 'Stop'

### Step 4) Restore the VM (`Administrator`)

Use the [Restore](RESTORE_TEST.md) guide to run the recovery process.

### Step 5) Verify the workspace files have been restored (`Tester`)

Repeat Step 1, parts a), b), and d) to verify your root level and project level files are still present.


