# Problem 6 - Part 1  

## Deployment.yml
This defines a Deployment named "webapp-nginx-python" with 3 replicas.  
It uses label selectors to identify the pods controlled by this Deployment.  
The pod template specifies a container named "webapp" using the specified Docker image (change image name as per your preference).  
The container exposes port 80 and sets the working directory to "/app".  

## services.yml
This Service resource is named "webapp-nginx-service".
It selects pods with the label "app: webapp".
It exposes the service externally using a LoadBalancer, mapping external port 80 to the pods' port 80.


## ingress.yml
This Ingress resource is named "my-app-ingress".  
It defines an HTTP rule with a path of "/" and specifies a backend service named "webapp-nginx-service" on port 80.  
The Ingress class is set to "nginx".  
