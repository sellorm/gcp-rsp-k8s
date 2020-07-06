# gcp-rsp-k8s


The goal of this repo is to provide a minimally functional guide to implementing a Kubernetes backed RStudio Server Pro instance on GCP.

**Note:** The keys/tokens in this repo are shown as examples only. None of them actually work. I'm not that stupid ;)


## Target Architecture

![](gcp_rsp_k8s.png)

The target architecture breaks down into two distinct components; the RSP instance and the Kubernetes cluster.

The RSP instance will also host our NFS share as well as authenticating users with the standard Linux username and password.

On the Kubernetes side we'll stand up a cluster and use that to host sessions of both RStudio Server as well as Jupyter notebooks and jupyter lab.

RSP acts as a controller for the sessions launched on the cluster and also proxies user traffic to the relevant session on the cluster. The same server also shares home directories with client on the cluster.

Pods will be launched on the K8s cluster from a [stock RStudio docker image](https://hub.docker.com/layers/rstudio/r-session-complete/bionic-1.3.959-1/images/sha256-080ed50124ce2f4c62aa8aafd4f94cbf83371a3dc8ed8f3ae16719007afe13d5?context=explore), the repo for which [is here](https://github.com/rstudio/docker-r-session-complete).

In this model, no jobs are run on the RStudio Server Pro system at all. Instead, work is handed off to the kubernetes cluster to run.


## Stand up cluster

* Use the UI
* Give it a name (I called mine 'custard' after a couple of failed attemtps to use a cluster named "rhubarb".)

## Configure cloud shell to use your cluster

You must generate a `kubeconfig` entry:

```
gcloud container clusters get-credentials rhubarb2 --zone europe-west2
```

Test with:

```
kubectl get nodes
```

Make sure it returns the expected nodes.

## Create the RStudio namespace

```
kubectl create namespace rstudio
```

Prove that it worked with:

```
kubectl get namespace
```

## Get the address of the cluster

```
kubectl config view
```

This will display a bunch of info about your configuration, the IP address is probably in here somewhere

## Add that to the launcher.kubernetes.conf file

eg

```
api-url = https://35.246.32.179:8443
```



## Sort out your accounts

```
kubectl create namespace rstudio
kubectl create serviceaccount job-launcher --namespace rstudio
kubectl create rolebinding job-launcher-admin \
   --clusterrole=cluster-admin \
   --group=system:serviceaccounts:rstudio \
   --namespace=rstudio
kubectl create clusterrole job-launcher-clusters \
   --verb=get,watch,list \
   --resource=nodes
kubectl create clusterrolebinding job-launcher-list-clusters \
  --clusterrole=job-launcher-clusters \
  --group=system:serviceaccounts:rstudio
```

## Get the auth-token value

```
KUBERNETES_AUTH_SECRET=$(kubectl get serviceaccount job-launcher --namespace=rstudio -o jsonpath='{.secrets[0].name}')
kubectl get secret $KUBERNETES_AUTH_SECRET --namespace=rstudio -o jsonpath='{.data.token}' | base64 -d
```

### Use this if you get stuck

This hits the API using your token via curl.

```
APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
SECRET_NAME=$(kubectl get serviceaccount job-launcher --namespace=rstudio -o jsonpath='{.secrets[0].name}')
TOKEN=$(kubectl get secret $SECRET_NAME --namespace=rstudio -o jsonpath='{.data.token}' | base64 --decode)

curl $APISERVER/api --header "Authorization: Bearer $TOKEN" --insecure
```

This should expand out to a command like this one:

```
curl https://35.246.32.179/api --header "Authorization: Bearer eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJyc3R1ZGlvIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6ImpvYi1sYXVuY2hlci10b2tlbi1qNTU1aiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJqb2ItbGF1bmNoZXIiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiIyNTZhNDEwZi1iNjI4LTExZWEtODViNy00MjAxMGE5YTBmY2QiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6cnN0dWRpbzpqb2ItbGF1bmNoZXIifQ.aN-BSdGi-rUc3eP_yUV7p4PmCALBMz7ePbURteA4bEsvunVQgNYf5I-eyGJZnWOl03Sdv8FAf6xf4ZcSUPg616j-Ljct2iW7b3EEror1NumM_V72OllNpIiH5o_Zq2eWUL4mSFc38kH1EdMPmBNTV-vEOXEk5n-FWveQOr8cSRfHfB3O-Y9E-ejRVJ4vxKvUGyLIa0KMrQRpMyBgUIzkfxvLewCwFZEKCvDTRJ8QpK4sO79gBQAsAb0orsQC0sL9st5tYuFhMMGcLe3_WhR_Tezh855PXc-11oCnJaWdrdhfXIZHT1efk4uhxPN4eyXYrFcuAX26pFsd8TA0Px0DAw" --insecure
```

The output should look something like this:

```
{
  "kind": "APIVersions",
  "versions": [
    "v1"
  ],
  "serverAddressByClientCIDRs": [
    {
      "clientCIDR": "0.0.0.0/0",
      "serverAddress": "35.246.32.179:443"
    }
  ]
}
```


## Get the certificate

```
kubectl config view --raw
```

Find the right cluster and add the 'certificate-authority-data' to your launcher config file.

It'll be a large base64 encoded string (I think it's a base64 encoded pem file, but I'm not sure).

The relevant launcher section is `certificate-authority = `


## Stand up a standard Compute Engine VM instance

Use the UI to create a new VM using Ubuntu 18.04 and then install RSP onto it.


## Server config files
 

### /etc/rstudio/launcher.conf

```
# This file contains sample configuration for the Job Launcher.
#
# There are two section types, [server] and [cluster]. There should be one [server] section for the config, and one
 [cluster] section for each cluster you want the Job Launcher to connect to.
#
# An example default configuration is below. You can uncomment any lines to use them. For more detailed documentati
on, please see the Job Launcher documentation.
#
[server]
address=localhost
port=5559
server-user=rstudio-server
admin-group=rstudio-server
enable-debug-logging=1
enable-ssl=0
#
# Kubernetes and Slurm plugins require more configuration. See the Job Launcher documentation for more details.
#
[cluster]
name=Custard
type=Kubernetes
```

### /etc/rstudio/launcher.kubernetes.conf

```
# The Kubernetes API base URL.
# This can be an HTTP or HTTPS URL.
# The URL should be up to, but not including the /api endpoint.
api-url = https://34.89.68.23


# The auth token for the job-launcher service account.
# This is used to authenticate with the Kubernetes API.
# This should be base-64 encoded.
# See docs for more information. https://docs.rstudio.com/job-launcher/1.3.959-1/index.html

auth-token = eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJyc3R1ZGlvIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6ImpvYi1sYXVuY2hlci10b2tlbi01YzJqMiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bwQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJqb2ItbGF1bmNoZXIiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiI0NGExZjU0Yy1iZDFhLTExZWEtYjVhYS00MjAxMGE5YTAwMWEiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQzcnN0dWRpbzpqb2ItbGF1bmNoZXIifQ.wGWjdaoo0FbjgzHtNdvuHlDiUpX_nihUOeGw5L4ZmUPAKpYDCee3y0PFNwzb6zjhFZ2zgJqieNvmjdEzIZjTQz2UTqfIlC2MIuT3N7GnZscHuXGaeiAii7vWXndPTAS1xL2ZnZ5g4KA4mZii8ZBYB-HLG0-FSmJvUM1IYVBrXUdD9QtT2m4x9Uqdbs2K1fJzBch1KszTWV0O28A26-kbtRjepandxZCUa8mMHBJO9t47V4jiYLeB6O0-4KG_l9YLLMcfvwooKXG1Od8UrOlTcvtRUWH1-NSI4OHtC7Vi7Gi146RdZIzdSBGXysUoThJZgMPa0tI3Ly-2SicxFn34vQ


# Certificate authority

certificate-authority = LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURDekNDQWZPZ0F3SUJBZ0lRRjNXWTB5UGJ6T1hNd1U2ZkJKbEdYVEFOQmdrcWhraUc5dzBCQVFzRkFEQXYKTVMwd0t3WURWUVFERXlRMk5XUXpNVGM1WWkxa01USmxMVFJqWkRNdE9UTmtNUzB3T0RsbVlUWmpPRFJtWW1ZdwpIaGNOTWpBd056QXpNRGt6TlRNd1doY05NalV3TnpBeU1UQXpOVE13V2pBdk1TMHdLd1lEVlFRREV5UTJOV1F6Ck1UYzVZaTFrTVRKbExUUmpaRE10T1ROa01TMHdPRGxtWVRaak9EUm1ZbVl3Z2dFaU1BMEdDU3FHU0liM0RRRUIWQVFVQUE0SUJEd0F3Z2dFS0FvSUJBUUM2QkczVzc4QkNHYnVGTDB5TzFUa1ZwUGxqZWNQYk50MlNzTGpxRzA3cwp3M0VaZ1VvOU04S3hYYTZFNWxjZ0kzU1VJRVRFT1M1eHZybUZBekRWSkNXUW9zUDhPay9UWTZJU010OUVucUQwClR0RjFTZkV0RG9BSVdUYmlsd0tnSjFjeEFMVk1zeEl0ek5SV1ZzUllzNi9qSk02cGRzOElwOUNiUUgvejBxaC8Ka0VOYzdwRjFtamNwWGVtQ01xeklzdkl0T256VE9zeXZRN2tWZ0N6ZTJPZVE5b1BtODkyZlhQcGNKTWlXTmhCUwp5VVM4K2JPTGxEdWJDci9wa1NWS3dCRkJIbTZibVVQNmRJUGp3cGp3KzNjNzZ5WFErUFhDVC9GN1NUNnR5NldCCkd0VEtNRlJMSzh4dkNPeVF4cDByU1BVYXpPY3M2dzI5ellzNmlXRXcwU3o1QWdNQkFBR2pJekFoTUE0R0ExVWQKRHdFQi93UUVBd0lDQkRBUEJnTlZIUk1CQWY4RUJUQURBUUgvTUEwR0NTcUdTSWIzRFFFQkN3VUFBNElCQVFDQQpUUDZkRFlqWFI1KzVubml4Qm5aSDFjczNzRWNUVkZXK3ROdmRjamRYLzk0ekdUVkc3bHV3VEasb2xnUnNMWjVKCm5jSkh0OHRFV3dSZlA4YW5nRlJ1NzM0TTZUK3Fhd2c5Z0xWa2tjQlJUbkIvMDJXZUUrVXhEOStUOUtFekIybzEKaDhRbWdSZmhiS01Ia2FEQnpPVWJYMGcvQzk3MytoS1FFUTU4NjVEMThCQ3FoSEppMWJOYjJUVFlEeGp0K3pDdAp0YVpmM0NnbExHK1FGSXIrQmtIMnpEVHU2N3UxWHJmYlNsdGVrVDdaYlorZHBCUmxXNElJOWcyZmc0M0k1cWtyCm9BZ3U0d3FmNU9OR2JCSVFuUVZLZkNKVkdEam8zOGZwencybnY1VjdvcmJmcFphcDJ0cXhKa0lUcHNNQTNIZS8KaFlmcFhNcXhUMGRvdk5wblhwMlcKLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
```

### /etc/rstudio/jupyter.conf

This enables both notebooks and labs.

```
jupyter-exe=jupyter
labs-enabled=1
notebooks-enabled=1
session-cull-minutes=240
default-session-cluster=Kubernetes
default-session-container-image=rstudio/r-session-complete:bionic-1.3.959-1
```

### /etc/rstudio/rserver.conf

```
# Server Configuration File
#
launcher-address=localhost
launcher-port=5559
launcher-sessions-enabled=1
launcher-default-cluster=custard

# the callback address that launcher sessions will reconnect to rserver on
# since our Kubernetes jobs run on a different network segment, this needs
# to be the routable IP address of the web server servicing RSP traffic
# (routable from the point of view of any Kubernetes nodes)
launcher-sessions-callback-address=http://10.154.0.16:8787
launcher-use-ssl=0
launcher-sessions-container-image=rstudio/r-session-complete:bionic-1.3.959-1
launcher-sessions-container-run-as-root=0
launcher-sessions-create-container-user=1

# Define the location of the RSP shared storage
server-shared-storage-path=/home/rsp-shared

# Enable the admin dashboard at /admin
admin-enabled=1

# Disable project sharing as it doesn't work with k8s anyway
server-project-sharing=0
```

### /etc/rstudio/launcher-mounts

The first of these two entries defines where the kubernetes sessions should look for their user homedirectories. The second defines the location of the RSP shared storage.

```
# User home mount - This is REQUIRED for the session to run
Host: 10.154.0.16
Path: /home/{USER}
MountPath: /home/{USER}
ReadOnly: false

Host: 10.154.0.16
Path: /home/rsp-shared
MountPath: /home/rsp-shared
ReadOnly: false
```

## Server config

### Share home directories via NFS

Install the NFS server components:

```
apt install nfs-kernel-server
```

Add the following to `/etc/exports`:

```
/home 10.154.0.0/24(rw,sync,no_root_squash,no_subtree_check)
```

Make sure to replace the IP address above with one appropriate for your environement.

Export the NFS share:

```
exportfs -a
systemctl restart nfs-kernel-server
```


### RSP shared directory

As root:

```
mkdir /home/rsp-shared
chown rstudio-server:rstudio-server /home/rsp-shared
chmod 777 /home/rsp-shared
chmod +t /home/rsp-shared
```

## Create a new user

This will create a new user and their home directory:

```
useradd -m -d /home/<USERNAME> -s /bin/bash -c "<OPTIONAL_COMMENT>" <USERNAME>
```

Set a password for the user:

```
passwd <USERNAME>
```

## Congratulations!

You can now log into your RSP instance using `http://<IP_ADDRESS>:8787`.
