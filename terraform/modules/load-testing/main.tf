# ===============================================================================
# LOAD TESTING MODULE - MAIN CONFIGURATION
# ===============================================================================
# Módulo responsável por configurar ambiente de load testing para 600k RPS
# Inclui: K6, Artillery, Custom Load Generators, Monitoring
# ===============================================================================

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

# ===============================================================================
# PROVIDER CONFIGURATION
# ===============================================================================

provider "kubernetes" {
  host                   = var.cluster.host
  client_certificate     = base64decode(var.cluster.client_certificate)
  client_key            = base64decode(var.cluster.client_key)
  cluster_ca_certificate = base64decode(var.cluster.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = var.cluster.host
    client_certificate     = base64decode(var.cluster.client_certificate)
    client_key            = base64decode(var.cluster.client_key)
    cluster_ca_certificate = base64decode(var.cluster.cluster_ca_certificate)
  }
}

provider "kubectl" {
  host                   = var.cluster.host
  client_certificate     = base64decode(var.cluster.client_certificate)
  client_key            = base64decode(var.cluster.client_key)
  cluster_ca_certificate = base64decode(var.cluster.cluster_ca_certificate)
  load_config_file       = false
}

# ===============================================================================
# LOCAL VALUES
# ===============================================================================

locals {
  # Load testing configuration
  namespace = "load-testing"
  
  # K6 configuration for 600k RPS
  k6_config = {
    replicas = 50
    vus      = 1000  # Virtual Users per pod
    duration = var.test_duration
    ramp_up  = var.ramp_up_duration
    target_rps = var.target_rps
  }
  
  # Artillery configuration
  artillery_config = {
    replicas = 30
    phases = [
      {
        duration = 120
        arrivalRate = 1000
      },
      {
        duration = 300
        arrivalRate = 5000
      },
      {
        duration = 600
        arrivalRate = 20000
      }
    ]
  }
  
  # Custom load generator configuration
  custom_config = {
    replicas = 20
    connections_per_pod = 1000
    requests_per_connection = 100
  }
  
  # Common labels
  common_labels = {
    "app.kubernetes.io/part-of" = "load-testing"
    "app.kubernetes.io/version" = "1.0.0"
  }
}

# ===============================================================================
# NAMESPACE
# ===============================================================================

resource "kubernetes_namespace" "load_testing" {
  metadata {
    name = local.namespace
    labels = merge(local.common_labels, {
      "name" = local.namespace
      "istio-injection" = "disabled"  # Disable Istio for load testing tools
    })
  }
}

# ===============================================================================
# CONFIGMAPS FOR LOAD TESTING SCRIPTS
# ===============================================================================

# K6 Test Script
resource "kubernetes_config_map" "k6_script" {
  metadata {
    name      = "k6-test-script"
    namespace = kubernetes_namespace.load_testing.metadata[0].name
    labels    = local.common_labels
  }
  
  data = {
    "test.js" = <<-EOT
      import http from 'k6/http';
      import { check, sleep } from 'k6';
      import { Rate, Trend } from 'k6/metrics';
      
      // Custom metrics
      const errorRate = new Rate('errors');
      const responseTime = new Trend('response_time');
      
      // Test configuration
      export const options = {
        stages: [
          { duration: '${var.ramp_up_duration}', target: ${local.k6_config.vus} },
          { duration: '${var.test_duration}', target: ${local.k6_config.vus} },
          { duration: '2m', target: 0 },
        ],
        thresholds: {
          http_req_duration: ['p(95)<500'],
          http_req_failed: ['rate<0.01'],
          errors: ['rate<0.01'],
        },
      };
      
      // Test endpoints
      const endpoints = [
        '${var.target_endpoints.primary_gateway}',
        '${var.target_endpoints.secondary_gateway}',
        '${var.target_endpoints.apim_gateway}',
      ];
      
      // Test scenarios
      const scenarios = [
        { method: 'GET', path: '/api/v1/products' },
        { method: 'GET', path: '/api/v1/orders' },
        { method: 'POST', path: '/api/v1/orders', body: JSON.stringify({
          customerId: 'test-customer',
          items: [{ productId: 'test-product', quantity: 1, price: 10.99 }]
        })},
        { method: 'GET', path: '/users/v1/profile' },
        { method: 'POST', path: '/payments/v1/process', body: JSON.stringify({
          orderId: 'test-order',
          amount: 10.99,
          currency: 'USD'
        })},
      ];
      
      export default function() {
        // Select random endpoint and scenario
        const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];
        const scenario = scenarios[Math.floor(Math.random() * scenarios.length)];
        
        const url = `https://$${endpoint}$${scenario.path}`;
        const params = {
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'K6-LoadTest/1.0',
            'X-Test-Run': __ENV.TEST_RUN_ID || 'default',
          },
          timeout: '30s',
        };
        
        let response;
        const startTime = Date.now();
        
        if (scenario.method === 'GET') {
          response = http.get(url, params);
        } else {
          response = http.post(url, scenario.body, params);
        }
        
        const duration = Date.now() - startTime;
        responseTime.add(duration);
        
        // Check response
        const success = check(response, {
          'status is 200-299': (r) => r.status >= 200 && r.status < 300,
          'response time < 1000ms': (r) => r.timings.duration < 1000,
        });
        
        errorRate.add(!success);
        
        // Small sleep to prevent overwhelming
        sleep(0.1);
      }
    EOT
  }
}

# Artillery Test Configuration
resource "kubernetes_config_map" "artillery_config" {
  metadata {
    name      = "artillery-config"
    namespace = kubernetes_namespace.load_testing.metadata[0].name
    labels    = local.common_labels
  }
  
  data = {
    "artillery.yml" = <<-EOT
      config:
        target: 'https://${var.target_endpoints.primary_gateway}'
        phases:
          - duration: 120
            arrivalRate: 1000
            name: "Warm up"
          - duration: 300
            arrivalRate: 5000
            name: "Ramp up load"
          - duration: 600
            arrivalRate: 20000
            name: "Sustained high load"
        defaults:
          headers:
            User-Agent: "Artillery-LoadTest/1.0"
            Content-Type: "application/json"
        processor: "./processor.js"
        
      scenarios:
        - name: "E-commerce API Load Test"
          weight: 100
          flow:
            - get:
                url: "/api/v1/products"
                capture:
                  - json: "$[0].id"
                    as: "productId"
            - think: 1
            - post:
                url: "/api/v1/orders"
                json:
                  customerId: "{{ $randomString() }}"
                  items:
                    - productId: "{{ productId }}"
                      quantity: "{{ $randomInt(1, 5) }}"
                      price: "{{ $randomInt(10, 100) }}.99"
            - think: 2
            - get:
                url: "/users/v1/profile"
                headers:
                  Authorization: "Bearer fake-token"
    EOT
    
    "processor.js" = <<-EOT
      module.exports = {
        setRandomData: setRandomData
      };
      
      function setRandomData(requestParams, context, ee, next) {
        context.vars.customerId = 'customer_' + Math.random().toString(36).substr(2, 9);
        context.vars.productId = 'product_' + Math.random().toString(36).substr(2, 9);
        return next();
      }
    EOT
  }
}

# Custom Load Generator Script
resource "kubernetes_config_map" "custom_load_generator" {
  metadata {
    name      = "custom-load-generator"
    namespace = kubernetes_namespace.load_testing.metadata[0].name
    labels    = local.common_labels
  }
  
  data = {
    "load_generator.py" = <<-EOT
      #!/usr/bin/env python3
      import asyncio
      import aiohttp
      import time
      import json
      import random
      import os
      from datetime import datetime
      
      class LoadGenerator:
          def __init__(self):
              self.target_endpoints = [
                  '${var.target_endpoints.primary_gateway}',
                  '${var.target_endpoints.secondary_gateway}',
                  '${var.target_endpoints.apim_gateway}',
              ]
              self.target_rps = int(os.getenv('TARGET_RPS', '${var.target_rps}'))
              self.duration = int(os.getenv('DURATION_SECONDS', '600'))
              self.connections = int(os.getenv('CONNECTIONS', '1000'))
              
              self.stats = {
                  'requests_sent': 0,
                  'responses_received': 0,
                  'errors': 0,
                  'start_time': None,
                  'response_times': []
              }
          
          async def make_request(self, session, endpoint, scenario):
              url = f"https://{endpoint}{scenario['path']}"
              headers = {
                  'Content-Type': 'application/json',
                  'User-Agent': 'CustomLoadGenerator/1.0',
                  'X-Test-Run': os.getenv('TEST_RUN_ID', 'default'),
              }
              
              start_time = time.time()
              try:
                  if scenario['method'] == 'GET':
                      async with session.get(url, headers=headers) as response:
                          await response.text()
                          self.stats['responses_received'] += 1
                  else:
                      async with session.post(url, headers=headers, json=scenario.get('body', {})) as response:
                          await response.text()
                          self.stats['responses_received'] += 1
                  
                  response_time = (time.time() - start_time) * 1000
                  self.stats['response_times'].append(response_time)
                  
              except Exception as e:
                  self.stats['errors'] += 1
                  print(f"Request error: {e}")
          
          async def worker(self, session, worker_id):
              scenarios = [
                  {'method': 'GET', 'path': '/api/v1/products'},
                  {'method': 'GET', 'path': '/api/v1/orders'},
                  {'method': 'POST', 'path': '/api/v1/orders', 'body': {
                      'customerId': f'test-customer-{worker_id}',
                      'items': [{'productId': 'test-product', 'quantity': 1, 'price': 10.99}]
                  }},
                  {'method': 'GET', 'path': '/users/v1/profile'},
                  {'method': 'POST', 'path': '/payments/v1/process', 'body': {
                      'orderId': f'test-order-{worker_id}',
                      'amount': 10.99,
                      'currency': 'USD'
                  }},
              ]
              
              end_time = time.time() + self.duration
              
              while time.time() < end_time:
                  endpoint = random.choice(self.target_endpoints)
                  scenario = random.choice(scenarios)
                  
                  await self.make_request(session, endpoint, scenario)
                  self.stats['requests_sent'] += 1
                  
                  # Rate limiting
                  await asyncio.sleep(1.0 / (self.target_rps / self.connections))
          
          async def run_load_test(self):
              self.stats['start_time'] = time.time()
              
              connector = aiohttp.TCPConnector(
                  limit=self.connections,
                  limit_per_host=self.connections,
                  keepalive_timeout=30,
                  enable_cleanup_closed=True
              )
              
              timeout = aiohttp.ClientTimeout(total=30)
              
              async with aiohttp.ClientSession(
                  connector=connector,
                  timeout=timeout,
                  trust_env=True
              ) as session:
                  
                  tasks = []
                  for i in range(self.connections):
                      task = asyncio.create_task(self.worker(session, i))
                      tasks.append(task)
                  
                  # Monitor progress
                  monitor_task = asyncio.create_task(self.monitor_progress())
                  
                  await asyncio.gather(*tasks)
                  monitor_task.cancel()
                  
                  self.print_final_stats()
          
          async def monitor_progress(self):
              while True:
                  await asyncio.sleep(10)
                  elapsed = time.time() - self.stats['start_time']
                  rps = self.stats['requests_sent'] / elapsed if elapsed > 0 else 0
                  
                  avg_response_time = sum(self.stats['response_times']) / len(self.stats['response_times']) if self.stats['response_times'] else 0
                  
                  print(f"[{datetime.now()}] Elapsed: {elapsed:.1f}s, RPS: {rps:.1f}, "
                        f"Requests: {self.stats['requests_sent']}, "
                        f"Responses: {self.stats['responses_received']}, "
                        f"Errors: {self.stats['errors']}, "
                        f"Avg Response Time: {avg_response_time:.2f}ms")
          
          def print_final_stats(self):
              elapsed = time.time() - self.stats['start_time']
              rps = self.stats['requests_sent'] / elapsed
              
              response_times = sorted(self.stats['response_times'])
              p50 = response_times[len(response_times)//2] if response_times else 0
              p95 = response_times[int(len(response_times)*0.95)] if response_times else 0
              p99 = response_times[int(len(response_times)*0.99)] if response_times else 0
              
              print("\n" + "="*50)
              print("FINAL LOAD TEST RESULTS")
              print("="*50)
              print(f"Duration: {elapsed:.1f} seconds")
              print(f"Requests Sent: {self.stats['requests_sent']}")
              print(f"Responses Received: {self.stats['responses_received']}")
              print(f"Errors: {self.stats['errors']}")
              print(f"Average RPS: {rps:.1f}")
              print(f"Success Rate: {(self.stats['responses_received']/self.stats['requests_sent']*100):.2f}%")
              print(f"Response Time P50: {p50:.2f}ms")
              print(f"Response Time P95: {p95:.2f}ms")
              print(f"Response Time P99: {p99:.2f}ms")
              print("="*50)
      
      if __name__ == "__main__":
          generator = LoadGenerator()
          asyncio.run(generator.run_load_test())
    EOT
  }
}

# ===============================================================================
# K6 DEPLOYMENT
# ===============================================================================

resource "kubernetes_deployment" "k6" {
  count = var.enable_k6 ? 1 : 0
  
  metadata {
    name      = "k6-load-test"
    namespace = kubernetes_namespace.load_testing.metadata[0].name
    labels = merge(local.common_labels, {
      "app.kubernetes.io/name" = "k6"
    })
  }
  
  spec {
    replicas = local.k6_config.replicas
    
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "k6"
      }
    }
    
    template {
      metadata {
        labels = merge(local.common_labels, {
          "app.kubernetes.io/name" = "k6"
        })
      }
      
      spec {
        container {
          name  = "k6"
          image = "grafana/k6:latest"
          
          command = ["k6", "run", "--out", "prometheus", "/scripts/test.js"]
          
          env {
            name  = "K6_PROMETHEUS_RW_SERVER_URL"
            value = var.prometheus_endpoint
          }
          
          env {
            name  = "TEST_RUN_ID"
            value = "k6-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
          }
          
          resources {
            requests = {
              cpu    = "500m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "2000m"
              memory = "2Gi"
            }
          }
          
          volume_mount {
            name       = "test-script"
            mount_path = "/scripts"
          }
        }
        
        volume {
          name = "test-script"
          config_map {
            name = kubernetes_config_map.k6_script.metadata[0].name
          }
        }
        
        restart_policy = "Never"
      }
    }
  }
}

# ===============================================================================
# ARTILLERY DEPLOYMENT
# ===============================================================================

resource "kubernetes_deployment" "artillery" {
  count = var.enable_artillery ? 1 : 0
  
  metadata {
    name      = "artillery-load-test"
    namespace = kubernetes_namespace.load_testing.metadata[0].name
    labels = merge(local.common_labels, {
      "app.kubernetes.io/name" = "artillery"
    })
  }
  
  spec {
    replicas = local.artillery_config.replicas
    
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "artillery"
      }
    }
    
    template {
      metadata {
        labels = merge(local.common_labels, {
          "app.kubernetes.io/name" = "artillery"
        })
      }
      
      spec {
        container {
          name  = "artillery"
          image = "artilleryio/artillery:latest"
          
          command = ["artillery", "run", "/config/artillery.yml"]
          
          env {
            name  = "TEST_RUN_ID"
            value = "artillery-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
          }
          
          resources {
            requests = {
              cpu    = "300m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "1000m"
              memory = "1Gi"
            }
          }
          
          volume_mount {
            name       = "artillery-config"
            mount_path = "/config"
          }
        }
        
        volume {
          name = "artillery-config"
          config_map {
            name = kubernetes_config_map.artillery_config.metadata[0].name
          }
        }
        
        restart_policy = "Never"
      }
    }
  }
}

# ===============================================================================
# CUSTOM LOAD GENERATOR DEPLOYMENT
# ===============================================================================

resource "kubernetes_deployment" "custom_load_generator" {
  count = var.enable_custom ? 1 : 0
  
  metadata {
    name      = "custom-load-generator"
    namespace = kubernetes_namespace.load_testing.metadata[0].name
    labels = merge(local.common_labels, {
      "app.kubernetes.io/name" = "custom-load-generator"
    })
  }
  
  spec {
    replicas = local.custom_config.replicas
    
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "custom-load-generator"
      }
    }
    
    template {
      metadata {
        labels = merge(local.common_labels, {
          "app.kubernetes.io/name" = "custom-load-generator"
        })
      }
      
      spec {
        container {
          name  = "load-generator"
          image = "python:3.11-slim"
          
          command = ["python", "/scripts/load_generator.py"]
          
          env {
            name  = "TARGET_RPS"
            value = tostring(var.target_rps / local.custom_config.replicas)
          }
          
          env {
            name  = "DURATION_SECONDS"
            value = "600"
          }
          
          env {
            name  = "CONNECTIONS"
            value = tostring(local.custom_config.connections_per_pod)
          }
          
          env {
            name  = "TEST_RUN_ID"
            value = "custom-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
          }
          
          resources {
            requests = {
              cpu    = "1000m"
              memory = "1Gi"
            }
            limits = {
              cpu    = "4000m"
              memory = "4Gi"
            }
          }
          
          volume_mount {
            name       = "load-generator-script"
            mount_path = "/scripts"
          }
        }
        
        init_container {
          name  = "install-deps"
          image = "python:3.11-slim"
          
          command = ["pip", "install", "aiohttp", "asyncio"]
          
          volume_mount {
            name       = "pip-cache"
            mount_path = "/root/.cache/pip"
          }
        }
        
        volume {
          name = "load-generator-script"
          config_map {
            name         = kubernetes_config_map.custom_load_generator.metadata[0].name
            default_mode = "0755"
          }
        }
        
        volume {
          name = "pip-cache"
          empty_dir {}
        }
        
        restart_policy = "Never"
      }
    }
  }
}

# ===============================================================================
# LOAD TEST JOBS
# ===============================================================================

# High-intensity load test job
resource "kubectl_manifest" "load_test_600k_job" {
  yaml_body = <<-YAML
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: load-test-600k-rps
      namespace: ${kubernetes_namespace.load_testing.metadata[0].name}
      labels:
        app.kubernetes.io/name: load-test-600k
        app.kubernetes.io/part-of: load-testing
    spec:
      parallelism: 100
      completions: 100
      backoffLimit: 3
      template:
        metadata:
          labels:
            app.kubernetes.io/name: load-test-600k
        spec:
          restartPolicy: Never
          containers:
          - name: load-generator
            image: python:3.11-slim
            command: ["python", "/scripts/load_generator.py"]
            env:
            - name: TARGET_RPS
              value: "6000"  # 6k RPS per pod * 100 pods = 600k RPS
            - name: DURATION_SECONDS
              value: "600"
            - name: CONNECTIONS
              value: "100"
            - name: TEST_RUN_ID
              value: "600k-test-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
            resources:
              requests:
                cpu: "2000m"
                memory: "2Gi"
              limits:
                cpu: "4000m"
                memory: "4Gi"
            volumeMounts:
            - name: load-generator-script
              mountPath: /scripts
          initContainers:
          - name: install-deps
            image: python:3.11-slim
            command: ["sh", "-c", "pip install aiohttp asyncio"]
          volumes:
          - name: load-generator-script
            configMap:
              name: ${kubernetes_config_map.custom_load_generator.metadata[0].name}
              defaultMode: 0755
  YAML
}

# ===============================================================================
# MONITORING AND METRICS
# ===============================================================================

# Service Monitor for Prometheus
resource "kubectl_manifest" "load_test_service_monitor" {
  yaml_body = <<-YAML
    apiVersion: monitoring.coreos.com/v1
    kind: ServiceMonitor
    metadata:
      name: load-test-metrics
      namespace: ${kubernetes_namespace.load_testing.metadata[0].name}
      labels:
        app.kubernetes.io/name: load-test-metrics
        app.kubernetes.io/part-of: load-testing
    spec:
      selector:
        matchLabels:
          app.kubernetes.io/name: load-test-metrics
      endpoints:
      - port: metrics
        interval: 15s
        path: /metrics
  YAML
}

# Metrics service
resource "kubernetes_service" "load_test_metrics" {
  metadata {
    name      = "load-test-metrics"
    namespace = kubernetes_namespace.load_testing.metadata[0].name
    labels = merge(local.common_labels, {
      "app.kubernetes.io/name" = "load-test-metrics"
    })
  }
  
  spec {
    selector = {
      "app.kubernetes.io/name" = "load-test-metrics"
    }
    
    port {
      name        = "metrics"
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }
    
    type = "ClusterIP"
  }
}
