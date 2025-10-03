#!/usr/bin/env python3
"""
High-Performance Load Testing Tool
Custom Python-based load testing tool for 600k RPS testing
Optimized for maximum performance and detailed metrics collection
"""

import asyncio
import aiohttp
import argparse
import json
import logging
import random
import signal
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import statistics
import ssl
import certifi

# ===============================================================================
# CONFIGURATION
# ===============================================================================

@dataclass
class TestConfig:
    """Test configuration parameters"""
    target_url: str
    target_rps: int
    duration: str  # e.g., "30m", "1h"
    users: int
    output_dir: str
    test_id: str
    timeout: int = 30
    max_connections: int = 1000
    max_connections_per_host: int = 100
    keepalive_timeout: int = 30
    enable_ssl_verify: bool = False

@dataclass
class RequestResult:
    """Individual request result"""
    timestamp: float
    url: str
    method: str
    status_code: int
    response_time: float
    success: bool
    error: Optional[str] = None
    size: int = 0

@dataclass
class TestMetrics:
    """Aggregated test metrics"""
    total_requests: int = 0
    successful_requests: int = 0
    failed_requests: int = 0
    total_bytes: int = 0
    min_response_time: float = float('inf')
    max_response_time: float = 0.0
    avg_response_time: float = 0.0
    p50_response_time: float = 0.0
    p95_response_time: float = 0.0
    p99_response_time: float = 0.0
    rps: float = 0.0
    error_rate: float = 0.0
    start_time: float = 0.0
    end_time: float = 0.0

# ===============================================================================
# LOAD TESTING ENGINE
# ===============================================================================

class HighPerformanceLoadTester:
    """High-performance async load testing engine"""
    
    def __init__(self, config: TestConfig):
        self.config = config
        self.results: List[RequestResult] = []
        self.metrics = TestMetrics()
        self.running = False
        self.session: Optional[aiohttp.ClientSession] = None
        
        # Setup logging
        self.setup_logging()
        
        # Test scenarios and endpoints
        self.endpoints = self.setup_endpoints()
        self.scenarios = self.setup_scenarios()
        
        # Performance tracking
        self.request_times: List[float] = []
        self.error_counts: Dict[str, int] = {}
        
    def setup_logging(self):
        """Setup logging configuration"""
        log_format = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        logging.basicConfig(
            level=logging.INFO,
            format=log_format,
            handlers=[
                logging.FileHandler(f"{self.config.output_dir}/test.log"),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)
        
    def setup_endpoints(self) -> List[Dict]:
        """Setup test endpoints with weights"""
        base_url = self.config.target_url
        api_url = f"{base_url}/api/v1"
        
        return [
            # Homepage and static content (15%)
            {"url": base_url, "method": "GET", "weight": 15, "name": "homepage"},
            
            # Product catalog browsing (35%)
            {"url": f"{api_url}/products", "method": "GET", "weight": 20, "name": "products_list"},
            {"url": f"{api_url}/products/categories", "method": "GET", "weight": 8, "name": "categories"},
            {"url": f"{api_url}/products/featured", "method": "GET", "weight": 7, "name": "featured_products"},
            
            # Product search (25%)
            {"url": f"{api_url}/products/search", "method": "GET", "weight": 15, "name": "product_search"},
            {"url": f"{api_url}/products/search/suggestions", "method": "GET", "weight": 10, "name": "search_suggestions"},
            
            # User operations (15%)
            {"url": f"{api_url}/auth/login", "method": "POST", "weight": 8, "name": "user_login"},
            {"url": f"{api_url}/users/profile", "method": "GET", "weight": 4, "name": "user_profile"},
            {"url": f"{api_url}/users/preferences", "method": "GET", "weight": 3, "name": "user_preferences"},
            
            # Order operations (7%)
            {"url": f"{api_url}/orders", "method": "GET", "weight": 4, "name": "orders_list"},
            {"url": f"{api_url}/orders", "method": "POST", "weight": 2, "name": "create_order"},
            {"url": f"{api_url}/cart", "method": "GET", "weight": 1, "name": "cart_view"},
            
            # Payment operations (3%)
            {"url": f"{api_url}/payments/methods", "method": "GET", "weight": 2, "name": "payment_methods"},
            {"url": f"{api_url}/payments/process", "method": "POST", "weight": 1, "name": "process_payment"},
        ]
    
    def setup_scenarios(self) -> Dict:
        """Setup test scenarios with realistic data"""
        return {
            "search_terms": [
                "laptop", "smartphone", "tablet", "headphones", "camera",
                "watch", "book", "shoes", "clothing", "electronics"
            ],
            "categories": [
                "electronics", "clothing", "books", "home", "sports",
                "beauty", "automotive", "toys", "health", "garden"
            ],
            "user_agents": [
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
                "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
                "Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X)",
                "Mozilla/5.0 (Android 11; Mobile; rv:68.0) Gecko/68.0"
            ]
        }
    
    async def create_session(self) -> aiohttp.ClientSession:
        """Create optimized aiohttp session"""
        # SSL context
        ssl_context = ssl.create_default_context(cafile=certifi.where())
        if not self.config.enable_ssl_verify:
            ssl_context.check_hostname = False
            ssl_context.verify_mode = ssl.CERT_NONE
        
        # Connection configuration
        connector = aiohttp.TCPConnector(
            limit=self.config.max_connections,
            limit_per_host=self.config.max_connections_per_host,
            keepalive_timeout=self.config.keepalive_timeout,
            enable_cleanup_closed=True,
            ssl=ssl_context
        )
        
        # Timeout configuration
        timeout = aiohttp.ClientTimeout(
            total=self.config.timeout,
            connect=10,
            sock_read=self.config.timeout
        )
        
        # Session headers
        headers = {
            "User-Agent": "HighPerformanceLoadTester/1.0",
            "Accept": "application/json, text/html, */*",
            "Accept-Encoding": "gzip, deflate",
            "Connection": "keep-alive",
            "Cache-Control": "no-cache"
        }
        
        return aiohttp.ClientSession(
            connector=connector,
            timeout=timeout,
            headers=headers
        )
    
    def select_endpoint(self) -> Dict:
        """Select endpoint based on weight distribution"""
        total_weight = sum(endpoint["weight"] for endpoint in self.endpoints)
        random_value = random.randint(1, total_weight)
        
        current_weight = 0
        for endpoint in self.endpoints:
            current_weight += endpoint["weight"]
            if random_value <= current_weight:
                return endpoint
        
        return self.endpoints[0]  # Fallback
    
    def generate_request_data(self, endpoint: Dict) -> Tuple[str, Dict, Dict]:
        """Generate request URL, headers, and data"""
        url = endpoint["url"]
        headers = {}
        data = None
        
        # Add query parameters for GET requests
        if endpoint["method"] == "GET":
            if "search" in endpoint["name"]:
                search_term = random.choice(self.scenarios["search_terms"])
                url += f"?q={search_term}&limit=20"
            elif "products" in endpoint["name"] and endpoint["name"] != "product_search":
                page = random.randint(1, 10)
                url += f"?page={page}&limit=20"
            elif "categories" in endpoint["name"]:
                category = random.choice(self.scenarios["categories"])
                url += f"?category={category}"
        
        # Add request body for POST requests
        elif endpoint["method"] == "POST":
            headers["Content-Type"] = "application/json"
            
            if "login" in endpoint["name"]:
                data = {
                    "email": f"user{random.randint(1, 1000)}@example.com",
                    "password": "password123"
                }
            elif "order" in endpoint["name"]:
                data = {
                    "items": [
                        {
                            "productId": f"product_{random.randint(1, 500)}",
                            "quantity": random.randint(1, 3),
                            "price": random.randint(10, 500)
                        }
                    ],
                    "shippingAddress": {
                        "street": "123 Test Street",
                        "city": "Test City",
                        "state": "TS",
                        "zipCode": "12345"
                    }
                }
            elif "payment" in endpoint["name"]:
                data = {
                    "amount": random.randint(10, 500),
                    "currency": "USD",
                    "method": "credit_card",
                    "cardToken": f"tok_test_{random.randint(100000, 999999)}"
                }
        
        # Add random user agent
        headers["User-Agent"] = random.choice(self.scenarios["user_agents"])
        
        return url, headers, data
    
    async def make_request(self, endpoint: Dict) -> RequestResult:
        """Make individual HTTP request"""
        start_time = time.time()
        url, headers, data = self.generate_request_data(endpoint)
        
        try:
            if endpoint["method"] == "GET":
                async with self.session.get(url, headers=headers) as response:
                    content = await response.read()
                    end_time = time.time()
                    
                    return RequestResult(
                        timestamp=start_time,
                        url=url,
                        method=endpoint["method"],
                        status_code=response.status,
                        response_time=(end_time - start_time) * 1000,  # Convert to ms
                        success=200 <= response.status < 400,
                        size=len(content)
                    )
            
            elif endpoint["method"] == "POST":
                async with self.session.post(url, headers=headers, json=data) as response:
                    content = await response.read()
                    end_time = time.time()
                    
                    return RequestResult(
                        timestamp=start_time,
                        url=url,
                        method=endpoint["method"],
                        status_code=response.status,
                        response_time=(end_time - start_time) * 1000,
                        success=200 <= response.status < 400,
                        size=len(content)
                    )
        
        except Exception as e:
            end_time = time.time()
            error_msg = str(e)
            
            return RequestResult(
                timestamp=start_time,
                url=url,
                method=endpoint["method"],
                status_code=0,
                response_time=(end_time - start_time) * 1000,
                success=False,
                error=error_msg
            )
    
    async def worker(self, worker_id: int, requests_per_second: float):
        """Worker coroutine for generating load"""
        self.logger.info(f"Worker {worker_id} started - Target RPS: {requests_per_second}")
        
        request_interval = 1.0 / requests_per_second if requests_per_second > 0 else 0
        last_request_time = time.time()
        
        while self.running:
            try:
                # Rate limiting
                current_time = time.time()
                time_since_last = current_time - last_request_time
                
                if time_since_last < request_interval:
                    await asyncio.sleep(request_interval - time_since_last)
                
                # Select and execute request
                endpoint = self.select_endpoint()
                result = await self.make_request(endpoint)
                
                # Store result
                self.results.append(result)
                self.request_times.append(result.response_time)
                
                # Track errors
                if not result.success:
                    error_key = f"{result.status_code}_{result.error or 'unknown'}"
                    self.error_counts[error_key] = self.error_counts.get(error_key, 0) + 1
                
                last_request_time = time.time()
                
            except Exception as e:
                self.logger.error(f"Worker {worker_id} error: {e}")
                await asyncio.sleep(0.1)  # Brief pause on error
    
    def parse_duration(self, duration_str: str) -> int:
        """Parse duration string to seconds"""
        if duration_str.endswith('s'):
            return int(duration_str[:-1])
        elif duration_str.endswith('m'):
            return int(duration_str[:-1]) * 60
        elif duration_str.endswith('h'):
            return int(duration_str[:-1]) * 3600
        else:
            return int(duration_str)  # Assume seconds
    
    async def run_test(self):
        """Run the load test"""
        self.logger.info(f"Starting high-performance load test - Target: {self.config.target_rps} RPS")
        
        # Create session
        self.session = await self.create_session()
        
        # Calculate test parameters
        duration_seconds = self.parse_duration(self.config.duration)
        workers = min(self.config.users, self.config.target_rps)
        requests_per_worker = self.config.target_rps / workers
        
        self.logger.info(f"Test configuration:")
        self.logger.info(f"  Duration: {duration_seconds} seconds")
        self.logger.info(f"  Workers: {workers}")
        self.logger.info(f"  RPS per worker: {requests_per_worker:.2f}")
        
        # Start test
        self.running = True
        self.metrics.start_time = time.time()
        
        # Create worker tasks
        tasks = []
        for i in range(workers):
            task = asyncio.create_task(self.worker(i, requests_per_worker))
            tasks.append(task)
        
        # Run for specified duration
        try:
            await asyncio.sleep(duration_seconds)
        except KeyboardInterrupt:
            self.logger.info("Test interrupted by user")
        
        # Stop workers
        self.running = False
        self.metrics.end_time = time.time()
        
        # Wait for workers to finish
        self.logger.info("Stopping workers...")
        for task in tasks:
            task.cancel()
        
        await asyncio.gather(*tasks, return_exceptions=True)
        
        # Close session
        await self.session.close()
        
        self.logger.info("Load test completed")
    
    def calculate_metrics(self):
        """Calculate test metrics"""
        if not self.results:
            return
        
        # Basic counts
        self.metrics.total_requests = len(self.results)
        self.metrics.successful_requests = sum(1 for r in self.results if r.success)
        self.metrics.failed_requests = self.metrics.total_requests - self.metrics.successful_requests
        self.metrics.total_bytes = sum(r.size for r in self.results)
        
        # Response times
        if self.request_times:
            self.metrics.min_response_time = min(self.request_times)
            self.metrics.max_response_time = max(self.request_times)
            self.metrics.avg_response_time = statistics.mean(self.request_times)
            
            # Percentiles
            sorted_times = sorted(self.request_times)
            self.metrics.p50_response_time = statistics.median(sorted_times)
            self.metrics.p95_response_time = sorted_times[int(len(sorted_times) * 0.95)]
            self.metrics.p99_response_time = sorted_times[int(len(sorted_times) * 0.99)]
        
        # Rates
        test_duration = self.metrics.end_time - self.metrics.start_time
        if test_duration > 0:
            self.metrics.rps = self.metrics.total_requests / test_duration
            self.metrics.error_rate = self.metrics.failed_requests / self.metrics.total_requests * 100
    
    def save_results(self):
        """Save test results to files"""
        output_dir = Path(self.config.output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
        
        # Calculate metrics
        self.calculate_metrics()
        
        # Save detailed results
        results_file = output_dir / "custom-results.json"
        with open(results_file, 'w') as f:
            json.dump({
                "config": asdict(self.config),
                "metrics": asdict(self.metrics),
                "error_counts": self.error_counts,
                "results": [asdict(r) for r in self.results[-1000:]]  # Last 1000 results
            }, f, indent=2)
        
        # Save summary
        summary_file = output_dir / "custom-summary.txt"
        with open(summary_file, 'w') as f:
            f.write(f"High-Performance Load Test Summary\n")
            f.write(f"==================================\n\n")
            f.write(f"Test ID: {self.config.test_id}\n")
            f.write(f"Target URL: {self.config.target_url}\n")
            f.write(f"Target RPS: {self.config.target_rps:,}\n")
            f.write(f"Duration: {self.config.duration}\n")
            f.write(f"Users: {self.config.users:,}\n\n")
            
            f.write(f"Results:\n")
            f.write(f"--------\n")
            f.write(f"Total Requests: {self.metrics.total_requests:,}\n")
            f.write(f"Successful Requests: {self.metrics.successful_requests:,}\n")
            f.write(f"Failed Requests: {self.metrics.failed_requests:,}\n")
            f.write(f"Actual RPS: {self.metrics.rps:,.2f}\n")
            f.write(f"Error Rate: {self.metrics.error_rate:.2f}%\n")
            f.write(f"Total Data: {self.metrics.total_bytes / 1024 / 1024:.2f} MB\n\n")
            
            f.write(f"Response Times (ms):\n")
            f.write(f"-------------------\n")
            f.write(f"Min: {self.metrics.min_response_time:.2f}\n")
            f.write(f"Max: {self.metrics.max_response_time:.2f}\n")
            f.write(f"Avg: {self.metrics.avg_response_time:.2f}\n")
            f.write(f"P50: {self.metrics.p50_response_time:.2f}\n")
            f.write(f"P95: {self.metrics.p95_response_time:.2f}\n")
            f.write(f"P99: {self.metrics.p99_response_time:.2f}\n\n")
            
            if self.error_counts:
                f.write(f"Error Breakdown:\n")
                f.write(f"---------------\n")
                for error, count in sorted(self.error_counts.items(), key=lambda x: x[1], reverse=True):
                    f.write(f"{error}: {count:,}\n")
        
        self.logger.info(f"Results saved to {output_dir}")

# ===============================================================================
# MAIN EXECUTION
# ===============================================================================

async def main():
    """Main execution function"""
    parser = argparse.ArgumentParser(description="High-Performance Load Testing Tool")
    parser.add_argument("--target-url", required=True, help="Target URL for testing")
    parser.add_argument("--target-rps", type=int, required=True, help="Target requests per second")
    parser.add_argument("--duration", required=True, help="Test duration (e.g., 30m, 1h)")
    parser.add_argument("--users", type=int, required=True, help="Number of virtual users")
    parser.add_argument("--output-dir", required=True, help="Output directory for results")
    parser.add_argument("--test-id", required=True, help="Test identifier")
    parser.add_argument("--timeout", type=int, default=30, help="Request timeout in seconds")
    parser.add_argument("--max-connections", type=int, default=1000, help="Maximum connections")
    parser.add_argument("--disable-ssl-verify", action="store_true", help="Disable SSL verification")
    
    args = parser.parse_args()
    
    # Create configuration
    config = TestConfig(
        target_url=args.target_url,
        target_rps=args.target_rps,
        duration=args.duration,
        users=args.users,
        output_dir=args.output_dir,
        test_id=args.test_id,
        timeout=args.timeout,
        max_connections=args.max_connections,
        enable_ssl_verify=not args.disable_ssl_verify
    )
    
    # Create and run load tester
    tester = HighPerformanceLoadTester(config)
    
    # Setup signal handlers
    def signal_handler(signum, frame):
        tester.logger.info("Received interrupt signal, stopping test...")
        tester.running = False
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        # Run test
        await tester.run_test()
        
        # Save results
        tester.save_results()
        
        # Print summary
        print(f"\nTest completed successfully!")
        print(f"Total requests: {tester.metrics.total_requests:,}")
        print(f"Actual RPS: {tester.metrics.rps:,.2f}")
        print(f"Success rate: {(1 - tester.metrics.error_rate/100)*100:.2f}%")
        print(f"P95 response time: {tester.metrics.p95_response_time:.2f}ms")
        
    except Exception as e:
        print(f"Test failed with error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
