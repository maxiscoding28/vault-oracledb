
# Summary
Quick setup for testing the oracle database plugin for Hashicorp Vault on an M1 mac (using Docker)

# Prerequisites
- M1 mac
- Docker installed
- [Colima](https://github.com/abiosoft/colima#installation) installed (`brew install colima`)

# Instructions:
- Start a colima instance: 

`colima start --arch x86_64 --memory 4`
- Download and unzip the vault oracle database plugin, and the oracle client
      - Note: Perform this step on your local mac. The unzipped binaries will be passed to the docker container as volumes.

```
curl -O https://download.oracle.com/otn_software/linux/instantclient/1917000/instantclient-basic-linux.x64-19.17.0.0.0dbru.zip
mv instantclient-basic-linux.x64-19.17.0.0.0dbru.zip client/
unzip client/instantclient-basic-linux.x64-19.17.0.0.0dbru.zip -d client/
rm client/instantclient-basic-linux.x64-19.17.0.0.0dbru.zip

curl -O https://releases.hashicorp.com/vault-plugin-database-oracle/0.7.0/vault-plugin-database-oracle_0.7.0_linux_amd64.zip
mv vault-plugin-database-oracle_0.7.0_linux_amd64.zip plugin/
unzip plugin/vault-plugin-database-oracle_0.7.0_linux_amd64.zip -d plugin/
rm plugin/vault-plugin-database-oracle_0.7.0_linux_amd64.zip
```
- Add your vault enterprise license to a file called `license.env` in the root directory:

`echo "VAULT_LICENSE=${VAULT_LICENSE}" > license.env`
- Start the containers with docker-compose:

`docker-compose up`
- Shell into vault:

`docker exec -it vault /bin/bash`

- Verify shared libraries are linked correctly by manually executing the plugin:
```
export LD_LIBRARY_PATH=/vault/client/instantclient_19_17
/vault/plugin/vault-plugin-database-oracle
```
 - If you see the following message, the plugin was linked successfully:
```
This binary is a plugin. These are not meant to be executed directly.
Please execute the program that consumes these plugins, which will
load any plugins automatically
```
- Initialize vault, unseal and login:
```
vault operator init -key-shares=1 -key-threshold=1 -format=json > /vault/init.json

cat /vault/init.json

vault operator unseal <UNSEAL_KEY>

vault login <ROOT_TOKEN>

exit
```
- Shell into the oracle-xe container and run the `create-user.sql` statement:

`docker exec -it oracle-xe /bin/bash`

```
tee create_user.sql <<EOF
alter session set container=XEPDB1;
CREATE USER vault IDENTIFIED BY vaultpasswd;
ALTER USER vault DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
GRANT CREATE SESSION, RESOURCE , UNLIMITED TABLESPACE, DBA TO vault;
exit;
EOF
sqlplus sys/rootpassword as sysdba @create_user.sql
exit
```
- Shell into the vault container and register the plugin:

`docker exec -it vault /bin/bash`

```
sha256sum /vault/plugin/vault-plugin-database-oracle
vault plugin register -sha256=<SHASUM256> -version=v0.7.0 database vault-plugin-database-oracle
vault plugin list database | grep oracle
vault secrets enable database
vault write database/roles/my-role \
    db_name=my-oracle-database \
    creation_statements='CREATE USER {{username}} IDENTIFIED BY "{{password}}"; GRANT CONNECT TO {{username}}; GRANT CREATE SESSION TO {{username}};' \
    default_ttl="1h" \
    max_ttl="24h"
vault write database/config/my-oracle-database \
     plugin_name=vault-plugin-database-oracle \
     connection_url="{{username}}/{{password}}@oracle-xe:1521/XEPDB1" \
     username="vault" \
     password="vaultpasswd" \
     allowed_roles=my-role \
     max_connection_lifetime=60s
```
- Verify the plugin is working by generating credentials:

`vault read database/creds/my-role`