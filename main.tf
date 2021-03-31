############################################################
# REQUIRED PROVIDERS
############################################################
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.2"
    }
  }
}


############################################################
# CREATE BASIC ELEMENTS FOR APPDYNAMICS
############################################################
resource "kubernetes_secret" "cluster-agent-secret" {
  metadata {
    name      = "cluster-agent-secret"
    namespace = var.namespace
  }

  data = {
    "controller-key" = var.controller_key
    "api-user"       = "${var.username}@${var.account_name}:${var.password}"
  }
}


resource "kubernetes_service_account" "appdynamics-operator" {
  metadata {
    name      = "appdynamics-operator"
    namespace = var.namespace
  }
}


resource "kubernetes_role" "appdynamics-operator" {
  metadata {
    name      = "appdynamics-operator"
    namespace = var.namespace
  }

  rule {
    api_groups     = [""]
    resources      = ["pods", "pods/log", "endpoints", "persistentvolumeclaims", "resourcequotas", "nodes", "events", "namespaces"]
    verbs          = ["get", "list", "watch"]
  }
  
  rule {
    api_groups     = [""]
    resources      = ["pods", "services", "configmaps", "secrets"]
    verbs          = ["*"]
  }
  
  rule {
    api_groups     = ["apps"]
    resources      = ["statefulsets"]
    verbs          = ["get", "list", "watch"]
  }
  
  rule {
    api_groups     = ["apps"]
    resources      = ["deployments", "replicasets", "daemonsets"]
    verbs          = ["*"]
  }
  
  rule {
    api_groups     = ["batch", "extensions"]
    resources      = ["jobs"]
    verbs          = ["get", "list", "watch"]
  }
  
  rule {
    api_groups     = ["metrics.k8s.io"]
    resources      = ["pods", "nodes"]
    verbs          = ["get", "list", "watch"]
  }
  
  rule {
    api_groups     = ["appdynamics.com"]
    resources      = ["*", "clusteragents", "infravizs", "adams", "clustercollectors"]
    verbs          = ["*"]
  }
}


resource "kubernetes_role_binding" "appdynamics-operator" {
  metadata {
    name      = "appdynamics-operator"
    namespace = var.namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "appdynamics-operator"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "appdynamics-operator"
    api_group = "rbac.authorization.k8s.io"
  }
}


resource "kubernetes_deployment" "appdynamics-operator" {
  metadata {
    name      = "appdynamics-operator"
    namespace = var.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        name = "appdynamics-operator"
      }
    }

    template {
      metadata {
        labels = {
          name = "appdynamics-operator"
        }
      }

      spec {
        service_account_name = "appdynamics-operator"
        
        container {
          image = "docker.io/appdynamics/cluster-agent-operator:0.6.3"
          name  = "appdynamics-operator"
          
          port {
            container_port = 60000
            name = "metrics"
          }
          
          command = ["appdynamics-operator"]
          
          resources {
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "64Mi"
            }
          }
          
          env {
            name = "WATCH_NAMESPACE"
            value_from {
              field_ref = {
                field_path = "metadata.namespace"
              }
            }
          }
          
          env {
            name = "POD_NAME"
            value_from {
              field_ref = {
                field_path = "metadata.name"
              }
            }
          }
         
          env {
            name  = "OPERATOR_NAME"
            value = "appdynamics-operator"
          }
        }
      }
    }
  }
}


resource "kubernetes_service_account" "appdynamics-cluster-agent" {
  metadata {
    name      = "appdynamics-cluster-agent"
    namespace = var.namespace
  }
}


resource "kubernetes_cluster_role" "appdynamics-cluster-agent" {
  metadata {
    name = "appdynamics-cluster-agent"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log", "endpoints", "persistentvolumeclaims", "resourcequotas", "nodes", "events", "namespaces", "services", "configmaps", "secrets"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["apps"]
    resources  = ["daemonsets", "statefulsets", "deployments", "replicasets"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["batch", "extensions"]
    resources  = ["jobs"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["metrics.k8s.io"]
    resources  = ["pods", "nodes"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["appdynamics.com"]
    resources  = ["*", "clusteragents", "clustercollectors"]
    verbs      = ["get", "list", "watch"]
  }
}


resource "kubernetes_cluster_role" "appdynamics-cluster-agent-instrumentation" {
  metadata {
    name = "appdynamics-cluster-agent-instrumentation"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/exec", "secrets", "configmaps"]
    verbs      = ["create", "update", "delete"]
  }
  
  rule {
    api_groups = ["apps"]
    resources  = ["daemonsets", "statefulsets", "deployments", "replicasets"]
    verbs      = ["update"]
  }
}

resource "kubernetes_cluster_role_binding" "appdynamics-cluster-agent" {
  metadata {
    name = "appdynamics-cluster-agent"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "appdynamics-cluster-agent"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "appdynamics-cluster-agent"
    api_group = "rbac.authorization.k8s.io"
  }
}


resource "kubernetes_cluster_role_binding" "appdynamics-cluster-agent-instrumentation" {
  metadata {
    name = "appdynamics-cluster-agent-instrumentation"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "appdynamics-cluster-agent-instrumentation"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "appdynamics-cluster-agent"
    namespace = var.namespace
  }
}


resource "kubernetes_service_account" "appdynamics-infraviz" {
  metadata {
    name      = "appdynamics-infraviz"
    namespace = var.namespace
  }
}


resource "kubernetes_pod_security_policy" "appdynamics-infraviz" {
  metadata {
    name = "appdynamics-infraviz"
    annotations = {
      "seccomp.security.alpha.kubernetes.io/allowedProfileNames" = "*"
    }
  }
  spec {
    privileged                 = true
    allow_privilege_escalation = true
    
    allowed_capabilities = ["*"]
    
    host_network = true
    host_ipc     = true
    host_pid     = true
    host_ports   = {
      min = 0
      max = 65535
    }
    
    volumes = ["*"]

    run_as_user {
      rule = "RunAsAny"
    }

    se_linux {
      rule = "RunAsAny"
    }

    supplemental_groups {
      rule = "RunAsAny"
    }

    fs_group {
      rule = "RunAsAny"
    }
  }
}


resource "kubernetes_cluster_role" "appdynamics-infraviz" {
  metadata {
    name = "appdynamics-infraviz"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "nodes", "events", "namespaces"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["apps"]
    resources  = ["statefulsets", "deployments", "replicasets", "daemonsets"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["batch", "extensions"]
    resources  = ["jobs"]
    verbs      = ["get", "list", "watch"]
  }
}

 
resource "kubernetes_cluster_role_binding" "appdynamics-infraviz" {
  metadata {
    name = "appdynamics-infraviz"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "appdynamics-infraviz"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "appdynamics-infraviz"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_role" "appdynamics-infraviz" {
  metadata {
    name      = "appdynamics-infraviz"
    namespace = var.namespace
  }

  rule {
    api_groups     = ["extensions"]
    resources      = ["podsecuritypolicies"]
    resource_names = ["appdynamics-infraviz"]
    verbs          = ["use"]
  }
}


resource "kubernetes_role_binding" "appdynamics-infraviz" {
  metadata {
    name      = "appdynamics-infraviz"
    namespace = var.namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "appdynamics-infraviz"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "appdynamics-infraviz"
    namespace = var.namespace
  }
}


############################################################
# DEPLOY CRDS AND CUSTOM ELEMENTS
############################################################
resource "helm_release" "appd-crd" {
  name       = "appd-crd"

  chart      = "${path.module}/helm/"
  
  namespace  = var.namespace
  
  set {
    name  = "appd_account_name"
    value = var.account_name
  }
  
  set {
    name  = "appd_controller_url"
    value = var.controller_url
  }
  
  set {
    name  = "appname"
    value = var.app_name
  }
  
  set {
    name  = "proxy_url"
    value = var.proxy_url
  }
  
  set {
    name  = "ns_to_monitor"
    value = "{${join(",", var.ns_to_monitor)}}"
  }
  
  set {
    name  = "ns_to_instrument"
    value = var.ns_to_instrument
  }
  
  set {
    name  = "registry"
    value = var.registry
  }
  
  set {
    name  = "appd_global_account"
    value = var.global_account
  }
}
