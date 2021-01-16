This script can be used to to promote a windows server to an additional domain controller.

 

First it will perform some pre checks and get the server configuration details like CPU, Memory, Hard Disk details. Once it gets the information, it will prompt to proceed with promotion or cancel the operation.

Once this is done, it will check whether the required roles, active directory and DNS roles are installed or not. If it's not installed it will install the required roles.

 

Next thing, it will ask some required details. Details include:

1) Domain FQDN where the DC promotion needs to be done.

2) AD site where the DC will reside

3) Replication partner name

4) Credentials of the account having rights to do DC promotion 

5) DSRM password

Above provided details will be verified. If it's incorrect, it won't allow you to proceed further.

Once the proper details are entered it will ask for a confirmation. Once you confirm, DC promotion process will begin and server will be restarted once DC promotion is completed.

 

IMPORTANT NOTES:

Kindly see at the beginning of the script.
