# pimcore-contribute-assistant

The script prepares the development environment for Pimcore contributions by forking, cloning and configuring specific bundles in composer.

## Usage
 - Download the `fork.sh` and `pimcore-contribute-assistant.env.dist` file to you pimcore project root
 - Optional (If the variables are needed, you will additionally be asked in the script runtime):
    - Copy `pimcore-contribute-assistant.env.dist` to `pimcore-contribute-assistant.env`
    - Enter all necessary environment variables in the `pimcore-contribute-assistant.env` file
    - The GitHub API-Key is only necessary if you want to create fork repositories or delete them
 - Run `fork.sh` and follow the question
