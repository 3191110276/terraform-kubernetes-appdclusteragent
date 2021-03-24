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





############################################################
# DEPLOY CRDS AND CUSTOM ELEMENTS
############################################################
resource "helm_release" "appd-crd" {
  name       = "appd-crd"

  chart      = "${path.module}/helm/"
  
  namespace  = var.appd_namespace
  
  set {
    name  = "appd_account_name"
    value = var.appd_account_name
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
    value = "{${join(",", var.appd_ns_to_monitor)}}"
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
    value = var.appd_global_account
  }
}
