/**
 * K6 Stress Test Script - 600k RPS E-commerce Platform
 * 
 * This script is designed to generate high-performance load testing
 * targeting 600,000 requests per second across multiple endpoints
 * of the e-commerce platform.
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';
import { randomString, randomIntBetween } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';

// ===============================================================================
// CONFIGURATION
// ===============================================================================

// Environment variables
const BASE_URL = __ENV.BASE_URL || 'https://localhost';
const API_BASE_URL = __ENV.API_BASE_URL || `${BASE_URL}/api/v1`;
const TEST_ID = __ENV.TEST_ID || 'k6-stress-test';

// Test configuration
const config = {
    // Performance thresholds
    thresholds: {
        'http_req_duration': ['p(95)<100', 'p(99)<200'],
        'http_req_failed': ['rate<0.01'],
        'http_reqs': ['rate>590000'], // Allow 10k RPS margin
        'custom_success_rate': ['rate>0.99'],
        'custom_response_time_p95': ['value<100'],
    },
    
    // Request configuration
    requests: {
        timeout: '30s',
        headers: {
            'User-Agent': 'K6-LoadTest/1.0',
            'Accept': 'application/json',
            'Accept-Encoding': 'gzip, deflate',
            'Connection': 'keep-alive',
        },
    },
    
    // Test data
    testData: {
        users: generateTestUsers(1000),
        products: generateTestProducts(500),
        searchTerms: ['laptop', 'phone', 'tablet', 'headphones', 'camera', 'watch', 'book', 'shoes'],
        categories: ['electronics', 'clothing', 'books', 'home', 'sports', 'beauty'],
    },
};

// ===============================================================================
// CUSTOM METRICS
// ===============================================================================

const customSuccessRate = new Rate('custom_success_rate');
const customResponseTime = new Trend('custom_response_time_p95');
const endpointCounter = new Counter('endpoint_requests');
const errorCounter = new Counter('error_count');

// ===============================================================================
// TEST DATA GENERATORS
// ===============================================================================

function generateTestUsers(count) {
    const users = [];
    for (let i = 0; i < count; i++) {
        users.push({
            id: `user_${i}`,
            email: `user${i}@example.com`,
            password: 'password123',
            name: `Test User ${i}`,
            token: null, // Will be populated during login
        });
    }
    return users;
}

function generateTestProducts(count) {
    const products = [];
    const categories = config.testData.categories;
    
    for (let i = 0; i < count; i++) {
        products.push({
            id: `product_${i}`,
            name: `Test Product ${i}`,
            category: categories[i % categories.length],
            price: randomIntBetween(10, 1000),
            sku: `SKU${i.toString().padStart(6, '0')}`,
        });
    }
    return products;
}

// ===============================================================================
// UTILITY FUNCTIONS
// ===============================================================================

function getRandomUser() {
    return config.testData.users[randomIntBetween(0, config.testData.users.length - 1)];
}

function getRandomProduct() {
    return config.testData.products[randomIntBetween(0, config.testData.products.length - 1)];
}

function getRandomSearchTerm() {
    return config.testData.searchTerms[randomIntBetween(0, config.testData.searchTerms.length - 1)];
}

function getRandomCategory() {
    return config.testData.categories[randomIntBetween(0, config.testData.categories.length - 1)];
}

function makeRequest(method, url, payload = null, headers = {}) {
    const startTime = Date.now();
    
    const params = {
        headers: { ...config.requests.headers, ...headers },
        timeout: config.requests.timeout,
    };
    
    let response;
    if (method === 'GET') {
        response = http.get(url, params);
    } else if (method === 'POST') {
        response = http.post(url, JSON.stringify(payload), params);
    } else if (method === 'PUT') {
        response = http.put(url, JSON.stringify(payload), params);
    } else if (method === 'DELETE') {
        response = http.del(url, null, params);
    }
    
    const endTime = Date.now();
    const responseTime = endTime - startTime;
    
    // Record custom metrics
    customResponseTime.add(responseTime);
    endpointCounter.add(1, { endpoint: url });
    
    const success = response.status >= 200 && response.status < 400;
    customSuccessRate.add(success);
    
    if (!success) {
        errorCounter.add(1, { 
            status: response.status, 
            endpoint: url,
            error: response.error || 'Unknown error'
        });
    }
    
    return response;
}

// ===============================================================================
// TEST SCENARIOS
// ===============================================================================

export function homepageLoad() {
    const response = makeRequest('GET', BASE_URL);
    
    check(response, {
        'homepage status is 200': (r) => r.status === 200,
        'homepage response time < 100ms': (r) => r.timings.duration < 100,
        'homepage contains expected content': (r) => r.body.includes('E-commerce') || r.body.includes('<!DOCTYPE html>'),
    });
    
    return response.status === 200;
}

export function productCatalogBrowse() {
    // Get products list
    const productsResponse = makeRequest('GET', `${API_BASE_URL}/products?page=1&limit=20`);
    
    const success = check(productsResponse, {
        'products list status is 200': (r) => r.status === 200,
        'products list response time < 50ms': (r) => r.timings.duration < 50,
        'products list has data': (r) => {
            try {
                const data = JSON.parse(r.body);
                return Array.isArray(data.products) && data.products.length > 0;
            } catch (e) {
                return false;
            }
        },
    });
    
    if (success && productsResponse.status === 200) {
        // Get random product details
        const product = getRandomProduct();
        const productResponse = makeRequest('GET', `${API_BASE_URL}/products/${product.id}`);
        
        check(productResponse, {
            'product detail status is 200 or 404': (r) => r.status === 200 || r.status === 404,
            'product detail response time < 30ms': (r) => r.timings.duration < 30,
        });
    }
    
    return success;
}

export function productSearch() {
    const searchTerm = getRandomSearchTerm();
    const category = getRandomCategory();
    
    // Search by term
    const searchResponse = makeRequest('GET', 
        `${API_BASE_URL}/products/search?q=${searchTerm}&limit=10`);
    
    const searchSuccess = check(searchResponse, {
        'search status is 200': (r) => r.status === 200,
        'search response time < 80ms': (r) => r.timings.duration < 80,
        'search has results': (r) => {
            try {
                const data = JSON.parse(r.body);
                return data.total >= 0;
            } catch (e) {
                return false;
            }
        },
    });
    
    // Search by category
    const categoryResponse = makeRequest('GET', 
        `${API_BASE_URL}/products?category=${category}&limit=10`);
    
    const categorySuccess = check(categoryResponse, {
        'category search status is 200': (r) => r.status === 200,
        'category search response time < 60ms': (r) => r.timings.duration < 60,
    });
    
    return searchSuccess && categorySuccess;
}

export function userAuthentication() {
    const user = getRandomUser();
    
    // Login
    const loginResponse = makeRequest('POST', `${API_BASE_URL}/auth/login`, {
        email: user.email,
        password: user.password,
    }, {
        'Content-Type': 'application/json',
    });
    
    const loginSuccess = check(loginResponse, {
        'login status is 200 or 401': (r) => r.status === 200 || r.status === 401,
        'login response time < 150ms': (r) => r.timings.duration < 150,
    });
    
    if (loginResponse.status === 200) {
        try {
            const loginData = JSON.parse(loginResponse.body);
            user.token = loginData.token;
            
            // Get user profile
            const profileResponse = makeRequest('GET', `${API_BASE_URL}/users/profile`, null, {
                'Authorization': `Bearer ${user.token}`,
            });
            
            check(profileResponse, {
                'profile status is 200': (r) => r.status === 200,
                'profile response time < 100ms': (r) => r.timings.duration < 100,
                'profile has user data': (r) => {
                    try {
                        const data = JSON.parse(r.body);
                        return data.email === user.email;
                    } catch (e) {
                        return false;
                    }
                },
            });
        } catch (e) {
            // Handle JSON parse error
        }
    }
    
    return loginSuccess;
}

export function orderProcessing() {
    const user = getRandomUser();
    const product = getRandomProduct();
    
    // Create order (simulate)
    const orderData = {
        items: [
            {
                productId: product.id,
                quantity: randomIntBetween(1, 3),
                price: product.price,
            }
        ],
        shippingAddress: {
            street: '123 Test Street',
            city: 'Test City',
            state: 'TS',
            zipCode: '12345',
            country: 'US',
        },
    };
    
    const orderResponse = makeRequest('POST', `${API_BASE_URL}/orders`, orderData, {
        'Content-Type': 'application/json',
        'Authorization': user.token ? `Bearer ${user.token}` : '',
    });
    
    const success = check(orderResponse, {
        'order status is 200, 201, or 401': (r) => [200, 201, 401].includes(r.status),
        'order response time < 200ms': (r) => r.timings.duration < 200,
    });
    
    if ([200, 201].includes(orderResponse.status)) {
        try {
            const orderData = JSON.parse(orderResponse.body);
            
            // Get order details
            const orderDetailResponse = makeRequest('GET', 
                `${API_BASE_URL}/orders/${orderData.id}`, null, {
                'Authorization': user.token ? `Bearer ${user.token}` : '',
            });
            
            check(orderDetailResponse, {
                'order detail status is 200 or 401': (r) => r.status === 200 || r.status === 401,
                'order detail response time < 100ms': (r) => r.timings.duration < 100,
            });
        } catch (e) {
            // Handle JSON parse error
        }
    }
    
    return success;
}

export function paymentProcessing() {
    const user = getRandomUser();
    
    // Get payment methods
    const paymentMethodsResponse = makeRequest('GET', `${API_BASE_URL}/payments/methods`, null, {
        'Authorization': user.token ? `Bearer ${user.token}` : '',
    });
    
    const success = check(paymentMethodsResponse, {
        'payment methods status is 200 or 401': (r) => r.status === 200 || r.status === 401,
        'payment methods response time < 100ms': (r) => r.timings.duration < 100,
    });
    
    // Simulate payment processing
    const paymentData = {
        amount: randomIntBetween(10, 500),
        currency: 'USD',
        method: 'credit_card',
        cardToken: 'tok_test_' + randomString(16),
    };
    
    const paymentResponse = makeRequest('POST', `${API_BASE_URL}/payments/process`, paymentData, {
        'Content-Type': 'application/json',
        'Authorization': user.token ? `Bearer ${user.token}` : '',
    });
    
    const paymentSuccess = check(paymentResponse, {
        'payment status is 200, 201, or 401': (r) => [200, 201, 401].includes(r.status),
        'payment response time < 300ms': (r) => r.timings.duration < 300,
    });
    
    return success && paymentSuccess;
}

// ===============================================================================
// MAIN TEST FUNCTION
// ===============================================================================

export default function() {
    // Weighted scenario selection (realistic e-commerce traffic)
    const scenarios = [
        { func: homepageLoad, weight: 15 },           // 15% - Homepage visits
        { func: productCatalogBrowse, weight: 35 },   // 35% - Product browsing
        { func: productSearch, weight: 25 },          // 25% - Product search
        { func: userAuthentication, weight: 15 },     // 15% - User authentication
        { func: orderProcessing, weight: 7 },         // 7% - Order processing
        { func: paymentProcessing, weight: 3 },       // 3% - Payment processing
    ];
    
    // Select scenario based on weight
    const random = Math.random() * 100;
    let cumulativeWeight = 0;
    let selectedScenario = scenarios[0].func;
    
    for (const scenario of scenarios) {
        cumulativeWeight += scenario.weight;
        if (random <= cumulativeWeight) {
            selectedScenario = scenario.func;
            break;
        }
    }
    
    // Execute selected scenario
    try {
        const success = selectedScenario();
        
        // Add small random delay to simulate real user behavior
        // but keep it minimal for high RPS testing
        if (Math.random() < 0.1) { // Only 10% of requests have delay
            sleep(Math.random() * 0.1); // Max 100ms delay
        }
        
        return success;
    } catch (error) {
        console.error(`Scenario execution error: ${error.message}`);
        errorCounter.add(1, { error: error.message });
        return false;
    }
}

// ===============================================================================
// SETUP AND TEARDOWN
// ===============================================================================

export function setup() {
    console.log(`Starting K6 stress test - Target: 600k RPS`);
    console.log(`Base URL: ${BASE_URL}`);
    console.log(`API Base URL: ${API_BASE_URL}`);
    console.log(`Test ID: ${TEST_ID}`);
    
    // Warm-up request to ensure connectivity
    const warmupResponse = http.get(BASE_URL, {
        timeout: '10s',
    });
    
    if (warmupResponse.status !== 200) {
        console.warn(`Warmup request failed with status ${warmupResponse.status}`);
    } else {
        console.log('Warmup request successful');
    }
    
    return {
        baseUrl: BASE_URL,
        apiBaseUrl: API_BASE_URL,
        testId: TEST_ID,
        startTime: Date.now(),
    };
}

export function teardown(data) {
    const endTime = Date.now();
    const duration = (endTime - data.startTime) / 1000;
    
    console.log(`K6 stress test completed`);
    console.log(`Test duration: ${duration} seconds`);
    console.log(`Test ID: ${data.testId}`);
    
    // Final connectivity check
    const finalResponse = http.get(data.baseUrl, {
        timeout: '10s',
    });
    
    if (finalResponse.status === 200) {
        console.log('Final connectivity check: PASSED');
    } else {
        console.log(`Final connectivity check: FAILED (${finalResponse.status})`);
    }
}

// ===============================================================================
// EXPORT CONFIGURATION
// ===============================================================================

export { config as options };
