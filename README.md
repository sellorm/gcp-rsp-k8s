# gcp-rsp-k8s


## Stand up cluster

* Use the UI
* Give it a name

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

## Add that to the luancher.kubernetes.conf file

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

## Use this if you get stuck

This hits the API using your token via curl.

```
APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
SECRET_NAME=$(kubectl get serviceaccount job-launcher --namespace=rstudio -o jsonpath='{.secrets[0].name}')
TOKEN=$(kubectl get secret $SECRET_NAME --namespace=rstudio -o jsonpath='{.data.token}' | base64 --decode)

curl $APISERVER/api --header "Authorization: Bearer $TOKEN" --insecure
```

This should expand out to a command like this one:

```
curl https://35.246.32.179/api --header "Authorization: Bearer eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJyc3R1ZGlvIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6ImpvYi1sYXVuY2hlci10b2tlbi1qNTU1aiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJqb2ItbGF1bmNoZXIiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiIyNTZhNDEwZi1iNjI4LTExZWEtODViNy00MjAxMGE5YTBmY2QiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6cnN0dWRpbzpqb2ItbGF1bmNoZXIifQ.aN-BSdGi-rUc3eP_yUV7p4PmCALBMz7ePbURteA4bEsvunVQgNYf5I-eyGJZnWOl03Sdv8FAf6xf4ZcSUPg616j-Ljct2iW7b3EEror1NumM_V72OllNpIiH5o_Zf2eWUL4mSFc38kH1EdMPmBNTV-vEOXEk5n-FWveQOr8cSRfHfB3O-Y9E-ejRVJ4vxKvUGyLIa0KMrQRpMyBgUIzkfxvLewCwFZEKCvDTRJ8QpK4sO79gBQAsAb0opsQC0sL9st5tYuFhMMGcLe3_WhR_Tezh855PXc-11oCnJaWdrdhfXIZHT1efk4uhxPN4eyXYrFcuAX26pFsd8TA0Px0DAw" --insecure
```

The output should looks something like this:

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
