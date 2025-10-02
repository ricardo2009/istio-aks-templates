package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/monitor/azquery"
	"github.com/prometheus/client_golang/api"
	v1 "github.com/prometheus/client_golang/api/prometheus/v1"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/prometheus/common/model"
	"gopkg.in/yaml.v2"
	istionetworking "istio.io/client-go/pkg/apis/networking/v1beta1"
	istioclient "istio.io/client-go/pkg/clientset/versioned"
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/watch"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/cache"
)

// 🎯 Estruturas de Configuração
type Config struct {
	SLOs          map[string]SLOConfig          `yaml:"slos"`
	Strategies    map[string]StrategyConfig     `yaml:"strategies"`
	CrossCluster  CrossClusterConfig            `yaml:"cross_cluster"`
	AzureMonitor  AzureMonitorConfig            `yaml:"azure_monitor"`
}

type SLOConfig struct {
	Threshold           float64 `yaml:"threshold"`
	MeasurementWindow   string  `yaml:"measurement_window"`
	EvaluationInterval  string  `yaml:"evaluation_interval"`
	ConsecutiveFailures int     `yaml:"consecutive_failures"`
}

type StrategyConfig struct {
	InitialWeight     int                    `yaml:"initial_weight"`
	Increment         int                    `yaml:"increment"`
	MaxWeight         int                    `yaml:"max_weight"`
	PromotionInterval string                 `yaml:"promotion_interval"`
	SuccessCriteria   map[string]interface{} `yaml:"success_criteria"`
}

type CrossClusterConfig struct {
	PrimaryCluster      string `yaml:"primary_cluster"`
	SecondaryCluster    string `yaml:"secondary_cluster"`
	FailoverThreshold   int    `yaml:"failover_threshold"`
	FailbackThreshold   int    `yaml:"failback_threshold"`
	HealthCheckInterval string `yaml:"health_check_interval"`
}

type AzureMonitorConfig struct {
	WorkspaceID        string `yaml:"workspace_id"`
	PrometheusEndpoint string `yaml:"prometheus_endpoint"`
	QueryTimeout       string `yaml:"query_timeout"`
	RetryAttempts      int    `yaml:"retry_attempts"`
}

// 🤖 Controlador Autônomo Principal
type AutonomousController struct {
	config           Config
	kubeClient       kubernetes.Interface
	istioClient      istioclient.Interface
	prometheusClient v1.API
	azureClient      *azquery.MetricsClient
	
	// 📊 Métricas Prometheus
	rollbacksTotal       prometheus.Counter
	deploymentsTotal     prometheus.Counter
	sloViolationsTotal   prometheus.Counter
	crossClusterLatency  prometheus.Histogram
	deploymentDuration   prometheus.Histogram
	
	// 🔄 Estado do Controlador
	deploymentStates map[string]*DeploymentState
	mutex           sync.RWMutex
	stopCh          chan struct{}
}

type DeploymentState struct {
	Name                string
	Namespace           string
	CurrentVersion      string
	TargetVersion       string
	Strategy            string
	Phase               string
	TrafficSplit        map[string]int
	SLOViolations       map[string]int
	LastRollback        time.Time
	ConsecutiveFailures int
	HealthStatus        string
	CrossClusterActive  bool
}

// 🚀 Inicialização do Controlador
func NewAutonomousController() (*AutonomousController, error) {
	// Carregar configuração
	config, err := loadConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to load config: %v", err)
	}

	// Cliente Kubernetes
	kubeConfig, err := rest.InClusterConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to get kube config: %v", err)
	}

	kubeClient, err := kubernetes.NewForConfig(kubeConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to create kube client: %v", err)
	}

	// Cliente Istio
	istioClient, err := istioclient.NewForConfig(kubeConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to create istio client: %v", err)
	}

	// Cliente Prometheus (Azure Monitor)
	promClient, err := api.NewClient(api.Config{
		Address: config.AzureMonitor.PrometheusEndpoint,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create prometheus client: %v", err)
	}

	// Cliente Azure Monitor
	cred, err := azidentity.NewDefaultAzureCredential(nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create azure credential: %v", err)
	}

	azureClient, err := azquery.NewMetricsClient(cred, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create azure client: %v", err)
	}

	// Métricas Prometheus
	rollbacksTotal := prometheus.NewCounter(prometheus.CounterOpts{
		Name: "autonomous_rollbacks_total",
		Help: "Total number of autonomous rollbacks performed",
	})

	deploymentsTotal := prometheus.NewCounter(prometheus.CounterOpts{
		Name: "autonomous_deployments_total",
		Help: "Total number of autonomous deployments managed",
	})

	sloViolationsTotal := prometheus.NewCounter(prometheus.CounterOpts{
		Name: "autonomous_slo_violations_total",
		Help: "Total number of SLO violations detected",
	})

	crossClusterLatency := prometheus.NewHistogram(prometheus.HistogramOpts{
		Name:    "autonomous_cross_cluster_latency_seconds",
		Help:    "Cross-cluster communication latency",
		Buckets: prometheus.DefBuckets,
	})

	deploymentDuration := prometheus.NewHistogram(prometheus.HistogramOpts{
		Name:    "autonomous_deployment_duration_seconds",
		Help:    "Duration of autonomous deployment operations",
		Buckets: []float64{1, 5, 10, 30, 60, 120, 300, 600},
	})

	// Registrar métricas
	prometheus.MustRegister(rollbacksTotal, deploymentsTotal, sloViolationsTotal, crossClusterLatency, deploymentDuration)

	return &AutonomousController{
		config:              config,
		kubeClient:          kubeClient,
		istioClient:         istioClient,
		prometheusClient:    v1.NewAPI(promClient),
		azureClient:         azureClient,
		rollbacksTotal:      rollbacksTotal,
		deploymentsTotal:    deploymentsTotal,
		sloViolationsTotal:  sloViolationsTotal,
		crossClusterLatency: crossClusterLatency,
		deploymentDuration:  deploymentDuration,
		deploymentStates:    make(map[string]*DeploymentState),
		stopCh:              make(chan struct{}),
	}, nil
}

// 📊 Monitoramento de SLOs com Azure Monitor
func (c *AutonomousController) evaluateSLOs(ctx context.Context, deployment string) (map[string]bool, error) {
	violations := make(map[string]bool)
	
	// 📈 Success Rate SLO
	successRateQuery := fmt.Sprintf(`
		(sum(rate(istio_requests_total{destination_service_name="%s",response_code!~"5.*"}[%s])) /
		 sum(rate(istio_requests_total{destination_service_name="%s"}[%s]))) * 100`,
		deployment, c.config.SLOs["success_rate"].MeasurementWindow,
		deployment, c.config.SLOs["success_rate"].MeasurementWindow)

	successRate, err := c.queryPrometheus(ctx, successRateQuery)
	if err != nil {
		log.Printf("Failed to query success rate: %v", err)
	} else if successRate < c.config.SLOs["success_rate"].Threshold {
		violations["success_rate"] = true
		c.sloViolationsTotal.Inc()
		log.Printf("🚨 SLO Violation: Success rate %.2f%% < %.2f%%", successRate, c.config.SLOs["success_rate"].Threshold)
	}

	// ⚡ Latency P95 SLO
	latencyQuery := fmt.Sprintf(`
		histogram_quantile(0.95,
			sum(rate(istio_request_duration_milliseconds_bucket{destination_service_name="%s"}[%s])) by (le)
		)`, deployment, c.config.SLOs["latency_p95"].MeasurementWindow)

	latencyP95, err := c.queryPrometheus(ctx, latencyQuery)
	if err != nil {
		log.Printf("Failed to query latency: %v", err)
	} else if latencyP95 > c.config.SLOs["latency_p95"].Threshold {
		violations["latency_p95"] = true
		c.sloViolationsTotal.Inc()
		log.Printf("🚨 SLO Violation: P95 latency %.2fms > %.2fms", latencyP95, c.config.SLOs["latency_p95"].Threshold)
	}

	// 🚨 Error Rate SLO
	errorRateQuery := fmt.Sprintf(`
		(sum(rate(istio_requests_total{destination_service_name="%s",response_code=~"5.*"}[%s])) /
		 sum(rate(istio_requests_total{destination_service_name="%s"}[%s]))) * 100`,
		deployment, c.config.SLOs["error_rate"].MeasurementWindow,
		deployment, c.config.SLOs["error_rate"].MeasurementWindow)

	errorRate, err := c.queryPrometheus(ctx, errorRateQuery)
	if err != nil {
		log.Printf("Failed to query error rate: %v", err)
	} else if errorRate > c.config.SLOs["error_rate"].Threshold {
		violations["error_rate"] = true
		c.sloViolationsTotal.Inc()
		log.Printf("🚨 SLO Violation: Error rate %.2f%% > %.2f%%", errorRate, c.config.SLOs["error_rate"].Threshold)
	}

	return violations, nil
}

// 🔄 Rollback Automático
func (c *AutonomousController) performAutonomousRollback(ctx context.Context, deployment string, violations map[string]bool) error {
	start := time.Now()
	defer func() {
		c.deploymentDuration.Observe(time.Since(start).Seconds())
	}()

	c.mutex.Lock()
	state := c.deploymentStates[deployment]
	if state == nil {
		state = &DeploymentState{
			Name:         deployment,
			Namespace:    "ecommerce",
			SLOViolations: make(map[string]int),
		}
		c.deploymentStates[deployment] = state
	}
	c.mutex.Unlock()

	// Incrementar contadores de violação
	for violation := range violations {
		state.SLOViolations[violation]++
	}

	// Verificar se deve fazer rollback
	shouldRollback := false
	for violation, count := range state.SLOViolations {
		threshold := c.config.SLOs[violation].ConsecutiveFailures
		if count >= threshold {
			shouldRollback = true
			log.Printf("🔄 Rollback triggered by %s: %d consecutive violations >= %d threshold", violation, count, threshold)
			break
		}
	}

	if !shouldRollback {
		return nil
	}

	// Cooldown period check
	if time.Since(state.LastRollback) < 10*time.Minute {
		log.Printf("⏳ Rollback cooldown active for %s", deployment)
		return nil
	}

	log.Printf("🚨 Performing autonomous rollback for %s", deployment)

	// 1. Rollback VirtualService traffic routing
	if err := c.rollbackTrafficRouting(ctx, deployment); err != nil {
		return fmt.Errorf("failed to rollback traffic routing: %v", err)
	}

	// 2. Rollback Deployment
	if err := c.rollbackDeployment(ctx, deployment); err != nil {
		return fmt.Errorf("failed to rollback deployment: %v", err)
	}

	// 3. Cross-cluster failover if needed
	if state.CrossClusterActive {
		if err := c.performCrossClusterFailover(ctx, deployment); err != nil {
			log.Printf("Cross-cluster failover failed: %v", err)
		}
	}

	// Update state
	state.LastRollback = time.Now()
	state.ConsecutiveFailures++
	state.Phase = "rolled-back"
	
	// Reset SLO violation counters
	for k := range state.SLOViolations {
		state.SLOViolations[k] = 0
	}

	c.rollbacksTotal.Inc()
	log.Printf("✅ Autonomous rollback completed for %s", deployment)

	// Create Kubernetes event
	c.createEvent(deployment, "Warning", "AutonomousRollback", "Autonomous rollback performed due to SLO violations")

	return nil
}

// 🌐 Cross-Cluster Failover
func (c *AutonomousController) performCrossClusterFailover(ctx context.Context, deployment string) error {
	log.Printf("🌐 Performing cross-cluster failover for %s", deployment)

	// Update VirtualService to route traffic to secondary cluster
	vs, err := c.istioClient.NetworkingV1beta1().VirtualServices("ecommerce").Get(ctx, "ecommerce-unified-routing", metav1.GetOptions{})
	if err != nil {
		return fmt.Errorf("failed to get VirtualService: %v", err)
	}

	// Modify routing to prefer secondary cluster
	for i := range vs.Spec.Http {
		for j := range vs.Spec.Http[i].Route {
			if vs.Spec.Http[i].Route[j].Destination.Host == "ecommerce-app" {
				// Add cross-cluster routing
				vs.Spec.Http[i].Route[j].Headers = &istionetworking.Headers{
					Request: &istionetworking.Headers_HeaderOperations{
						Add: map[string]string{
							"x-failover-active": "true",
							"x-target-cluster":  c.config.CrossCluster.SecondaryCluster,
						},
					},
				}
			}
		}
	}

	_, err = c.istioClient.NetworkingV1beta1().VirtualServices("ecommerce").Update(ctx, vs, metav1.UpdateOptions{})
	if err != nil {
		return fmt.Errorf("failed to update VirtualService for failover: %v", err)
	}

	log.Printf("✅ Cross-cluster failover completed")
	return nil
}

// 🔄 Rollback Traffic Routing
func (c *AutonomousController) rollbackTrafficRouting(ctx context.Context, deployment string) error {
	vs, err := c.istioClient.NetworkingV1beta1().VirtualServices("ecommerce").Get(ctx, "ecommerce-unified-routing", metav1.GetOptions{})
	if err != nil {
		return fmt.Errorf("failed to get VirtualService: %v", err)
	}

	// Reset traffic to stable version
	for i := range vs.Spec.Http {
		for j := range vs.Spec.Http[i].Route {
			if vs.Spec.Http[i].Route[j].Destination.Subset == "canary" || vs.Spec.Http[i].Route[j].Destination.Subset == "green" {
				vs.Spec.Http[i].Route[j].Weight = 0
			}
			if vs.Spec.Http[i].Route[j].Destination.Subset == "stable" || vs.Spec.Http[i].Route[j].Destination.Subset == "blue" {
				vs.Spec.Http[i].Route[j].Weight = 100
			}
		}
	}

	_, err = c.istioClient.NetworkingV1beta1().VirtualServices("ecommerce").Update(ctx, vs, metav1.UpdateOptions{})
	return err
}

// 🔄 Rollback Deployment
func (c *AutonomousController) rollbackDeployment(ctx context.Context, deployment string) error {
	deploy, err := c.kubeClient.AppsV1().Deployments("ecommerce").Get(ctx, deployment, metav1.GetOptions{})
	if err != nil {
		return fmt.Errorf("failed to get deployment: %v", err)
	}

	// Get previous revision
	if deploy.Annotations == nil {
		deploy.Annotations = make(map[string]string)
	}

	currentRevision := deploy.Annotations["deployment.kubernetes.io/revision"]
	if currentRevision == "" {
		return fmt.Errorf("no revision found for rollback")
	}

	revision, err := strconv.Atoi(currentRevision)
	if err != nil {
		return fmt.Errorf("invalid revision format: %v", err)
	}

	if revision <= 1 {
		return fmt.Errorf("no previous revision available for rollback")
	}

	// Rollback to previous revision
	previousRevision := fmt.Sprintf("%d", revision-1)
	deploy.Annotations["deployment.kubernetes.io/revision"] = previousRevision

	// Update image to previous version (simplified logic)
	for i := range deploy.Spec.Template.Spec.Containers {
		if strings.Contains(deploy.Spec.Template.Spec.Containers[i].Image, ":v") {
			// Extract and decrement version
			parts := strings.Split(deploy.Spec.Template.Spec.Containers[i].Image, ":v")
			if len(parts) == 2 {
				versionParts := strings.Split(parts[1], ".")
				if len(versionParts) >= 2 {
					minor, err := strconv.Atoi(versionParts[1])
					if err == nil && minor > 0 {
						versionParts[1] = fmt.Sprintf("%d", minor-1)
						deploy.Spec.Template.Spec.Containers[i].Image = parts[0] + ":v" + strings.Join(versionParts, ".")
					}
				}
			}
		}
	}

	_, err = c.kubeClient.AppsV1().Deployments("ecommerce").Update(ctx, deploy, metav1.UpdateOptions{})
	return err
}

// 📊 Query Prometheus
func (c *AutonomousController) queryPrometheus(ctx context.Context, query string) (float64, error) {
	result, warnings, err := c.prometheusClient.Query(ctx, query, time.Now())
	if err != nil {
		return 0, err
	}

	if len(warnings) > 0 {
		log.Printf("Prometheus query warnings: %v", warnings)
	}

	switch result.Type() {
	case model.ValVector:
		vector := result.(model.Vector)
		if len(vector) > 0 {
			return float64(vector[0].Value), nil
		}
	case model.ValScalar:
		scalar := result.(*model.Scalar)
		return float64(scalar.Value), nil
	}

	return 0, fmt.Errorf("no data returned from query")
}

// 📝 Create Kubernetes Event
func (c *AutonomousController) createEvent(deployment, eventType, reason, message string) {
	event := &corev1.Event{
		ObjectMeta: metav1.ObjectMeta{
			Name:      fmt.Sprintf("%s-%d", deployment, time.Now().Unix()),
			Namespace: "ecommerce",
		},
		InvolvedObject: corev1.ObjectReference{
			Kind:      "Deployment",
			Name:      deployment,
			Namespace: "ecommerce",
		},
		Reason:  reason,
		Message: message,
		Type:    eventType,
		Source: corev1.EventSource{
			Component: "autonomous-deployment-controller",
		},
		FirstTimestamp: metav1.NewTime(time.Now()),
		LastTimestamp:  metav1.NewTime(time.Now()),
		Count:          1,
	}

	_, err := c.kubeClient.CoreV1().Events("ecommerce").Create(context.Background(), event, metav1.CreateOptions{})
	if err != nil {
		log.Printf("Failed to create event: %v", err)
	}
}

// 🔄 Main Control Loop
func (c *AutonomousController) Run(ctx context.Context) error {
	log.Println("🚀 Starting Autonomous Deployment Controller")

	// Start deployment watcher
	go c.watchDeployments(ctx)

	// Start SLO evaluation loop
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			log.Println("🛑 Shutting down controller")
			return ctx.Err()
		case <-ticker.C:
			c.evaluateAllDeployments(ctx)
		case <-c.stopCh:
			return nil
		}
	}
}

// 👀 Watch Deployments
func (c *AutonomousController) watchDeployments(ctx context.Context) {
	watchlist := cache.NewListWatchFromClient(
		c.kubeClient.AppsV1().RESTClient(),
		"deployments",
		"ecommerce",
		metav1.ListOptions{
			LabelSelector: "autonomous-deployment=enabled",
		},
	)

	_, controller := cache.NewInformer(
		watchlist,
		&appsv1.Deployment{},
		time.Second*10,
		cache.ResourceEventHandlerFuncs{
			AddFunc: func(obj interface{}) {
				deployment := obj.(*appsv1.Deployment)
				log.Printf("📦 New deployment detected: %s", deployment.Name)
				c.deploymentsTotal.Inc()
			},
			UpdateFunc: func(oldObj, newObj interface{}) {
				deployment := newObj.(*appsv1.Deployment)
				log.Printf("🔄 Deployment updated: %s", deployment.Name)
			},
			DeleteFunc: func(obj interface{}) {
				deployment := obj.(*appsv1.Deployment)
				log.Printf("🗑️ Deployment deleted: %s", deployment.Name)
				c.mutex.Lock()
				delete(c.deploymentStates, deployment.Name)
				c.mutex.Unlock()
			},
		},
	)

	go controller.Run(ctx.Done())
}

// 🔍 Evaluate All Deployments
func (c *AutonomousController) evaluateAllDeployments(ctx context.Context) {
	deployments, err := c.kubeClient.AppsV1().Deployments("ecommerce").List(ctx, metav1.ListOptions{
		LabelSelector: "autonomous-deployment=enabled",
	})
	if err != nil {
		log.Printf("Failed to list deployments: %v", err)
		return
	}

	for _, deployment := range deployments.Items {
		violations, err := c.evaluateSLOs(ctx, deployment.Name)
		if err != nil {
			log.Printf("Failed to evaluate SLOs for %s: %v", deployment.Name, err)
			continue
		}

		if len(violations) > 0 {
			if err := c.performAutonomousRollback(ctx, deployment.Name, violations); err != nil {
				log.Printf("Failed to perform rollback for %s: %v", deployment.Name, err)
			}
		}
	}
}

// 🏥 Health Check Handlers
func (c *AutonomousController) healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"status":    "healthy",
		"timestamp": time.Now().Format(time.RFC3339),
		"version":   "v1.0.0",
	})
}

func (c *AutonomousController) readinessHandler(w http.ResponseWriter, r *http.Request) {
	// Check if we can connect to Prometheus
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err := c.prometheusClient.Query(ctx, "up", time.Now())
	if err != nil {
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(map[string]string{
			"status": "not ready",
			"error":  err.Error(),
		})
		return
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"status":    "ready",
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

// 📁 Load Configuration
func loadConfig() (Config, error) {
	var config Config
	
	configPath := os.Getenv("CONTROLLER_CONFIG_PATH")
	if configPath == "" {
		configPath = "/etc/config/config.yaml"
	}

	data, err := os.ReadFile(configPath)
	if err != nil {
		return config, err
	}

	// Expand environment variables
	configStr := os.ExpandEnv(string(data))
	
	err = yaml.Unmarshal([]byte(configStr), &config)
	return config, err
}

// 🚀 Main Function
func main() {
	controller, err := NewAutonomousController()
	if err != nil {
		log.Fatalf("Failed to create controller: %v", err)
	}

	// Setup HTTP handlers
	http.HandleFunc("/health/live", controller.healthHandler)
	http.HandleFunc("/health/ready", controller.readinessHandler)
	http.Handle("/metrics", promhttp.Handler())

	// Start HTTP server
	go func() {
		log.Println("🌐 Starting HTTP server on :8081")
		if err := http.ListenAndServe(":8081", nil); err != nil {
			log.Fatalf("HTTP server failed: %v", err)
		}
	}()

	// Start controller
	ctx := context.Background()
	if err := controller.Run(ctx); err != nil {
		log.Fatalf("Controller failed: %v", err)
	}
}
