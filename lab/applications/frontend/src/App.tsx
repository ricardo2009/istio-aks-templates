import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Link } from 'react-router-dom';
import axios from 'axios';
import './App.css';

// 🎯 Interfaces
interface User {
  id: string;
  name: string;
  email: string;
  tier: 'basic' | 'premium' | 'enterprise';
}

interface Order {
  id: string;
  userId: string;
  items: OrderItem[];
  total: number;
  status: 'pending' | 'processing' | 'completed' | 'failed';
  createdAt: string;
}

interface OrderItem {
  id: string;
  name: string;
  price: number;
  quantity: number;
}

interface ServiceHealth {
  service: string;
  status: 'healthy' | 'degraded' | 'unhealthy';
  cluster: string;
  responseTime: number;
  lastCheck: string;
}

// 🏠 Home Component
const Home: React.FC = () => {
  const [services, setServices] = useState<ServiceHealth[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchServiceHealth();
    const interval = setInterval(fetchServiceHealth, 10000); // Update every 10s
    return () => clearInterval(interval);
  }, []);

  const fetchServiceHealth = async () => {
    try {
      const response = await axios.get('/api/health/services');
      setServices(response.data);
    } catch (error) {
      console.error('Failed to fetch service health:', error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="home">
      <div className="hero">
        <h1>🚀 Multi-Cluster E-Commerce Platform</h1>
        <p>Demonstração de Service Mesh com Istio gerenciado no AKS</p>
        <div className="features">
          <div className="feature">
            <h3>🔒 Zero Trust Security</h3>
            <p>mTLS STRICT entre todos os serviços</p>
          </div>
          <div className="feature">
            <h3>🌐 Cross-Cluster Communication</h3>
            <p>Serviços distribuídos em múltiplos clusters</p>
          </div>
          <div className="feature">
            <h3>📊 Observabilidade Completa</h3>
            <p>Prometheus, Grafana e Application Insights</p>
          </div>
          <div className="feature">
            <h3>🚀 Progressive Delivery</h3>
            <p>Canary, Blue/Green e A/B Testing</p>
          </div>
        </div>
      </div>

      <div className="service-health">
        <h2>🏥 Service Health Dashboard</h2>
        {loading ? (
          <div className="loading">Loading service health...</div>
        ) : (
          <div className="health-grid">
            {services.map((service) => (
              <div key={service.service} className={`health-card ${service.status}`}>
                <h3>{service.service}</h3>
                <div className="status">{service.status.toUpperCase()}</div>
                <div className="cluster">Cluster: {service.cluster}</div>
                <div className="response-time">{service.responseTime}ms</div>
                <div className="last-check">
                  Last check: {new Date(service.lastCheck).toLocaleTimeString()}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

// 👤 Users Component
const Users: React.FC = () => {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [newUser, setNewUser] = useState({ name: '', email: '', tier: 'basic' as const });

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    try {
      const response = await axios.get('/api/users');
      setUsers(response.data);
    } catch (error) {
      console.error('Failed to fetch users:', error);
    } finally {
      setLoading(false);
    }
  };

  const createUser = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await axios.post('/api/users', newUser, {
        headers: {
          'X-User-Type': 'admin',
          'X-Trace-ID': generateTraceId(),
        }
      });
      setNewUser({ name: '', email: '', tier: 'basic' });
      fetchUsers();
    } catch (error) {
      console.error('Failed to create user:', error);
    }
  };

  const generateTraceId = () => {
    return Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
  };

  return (
    <div className="users">
      <h2>👤 User Management</h2>
      
      <form onSubmit={createUser} className="user-form">
        <h3>Create New User</h3>
        <input
          type="text"
          placeholder="Name"
          value={newUser.name}
          onChange={(e) => setNewUser({ ...newUser, name: e.target.value })}
          required
        />
        <input
          type="email"
          placeholder="Email"
          value={newUser.email}
          onChange={(e) => setNewUser({ ...newUser, email: e.target.value })}
          required
        />
        <select
          value={newUser.tier}
          onChange={(e) => setNewUser({ ...newUser, tier: e.target.value as any })}
        >
          <option value="basic">Basic</option>
          <option value="premium">Premium</option>
          <option value="enterprise">Enterprise</option>
        </select>
        <button type="submit">Create User</button>
      </form>

      {loading ? (
        <div className="loading">Loading users...</div>
      ) : (
        <div className="users-list">
          <h3>Existing Users</h3>
          {users.map((user) => (
            <div key={user.id} className={`user-card ${user.tier}`}>
              <h4>{user.name}</h4>
              <p>{user.email}</p>
              <span className="tier">{user.tier.toUpperCase()}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

// 🛒 Orders Component
const Orders: React.FC = () => {
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchOrders();
  }, []);

  const fetchOrders = async () => {
    try {
      const response = await axios.get('/api/orders', {
        headers: {
          'X-User-Type': 'premium',
          'X-Trace-ID': generateTraceId(),
        }
      });
      setOrders(response.data);
    } catch (error) {
      console.error('Failed to fetch orders:', error);
    } finally {
      setLoading(false);
    }
  };

  const createTestOrder = async () => {
    try {
      const testOrder = {
        userId: 'test-user-' + Date.now(),
        items: [
          { id: '1', name: 'Test Product', price: 99.99, quantity: 1 }
        ]
      };
      
      await axios.post('/api/orders', testOrder, {
        headers: {
          'X-User-Type': 'premium',
          'X-Trace-ID': generateTraceId(),
          'X-AB-Test-Group': Math.random() > 0.5 ? 'A' : 'B',
        }
      });
      
      fetchOrders();
    } catch (error) {
      console.error('Failed to create order:', error);
    }
  };

  const generateTraceId = () => {
    return Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
  };

  return (
    <div className="orders">
      <h2>🛒 Order Management</h2>
      
      <button onClick={createTestOrder} className="create-order-btn">
        Create Test Order
      </button>

      {loading ? (
        <div className="loading">Loading orders...</div>
      ) : (
        <div className="orders-list">
          {orders.map((order) => (
            <div key={order.id} className={`order-card ${order.status}`}>
              <h4>Order #{order.id.substring(0, 8)}</h4>
              <p>User: {order.userId}</p>
              <p>Total: ${order.total.toFixed(2)}</p>
              <p>Status: {order.status.toUpperCase()}</p>
              <p>Created: {new Date(order.createdAt).toLocaleString()}</p>
              <div className="order-items">
                {order.items.map((item) => (
                  <div key={item.id} className="order-item">
                    {item.name} x{item.quantity} - ${item.price.toFixed(2)}
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

// 🧪 Chaos Testing Component
const ChaosEngineering: React.FC = () => {
  const [chaosTests, setChaosTests] = useState<any[]>([]);
  const [activeTest, setActiveTest] = useState<string | null>(null);

  const runChaosTest = async (testType: string) => {
    setActiveTest(testType);
    try {
      await axios.post(`/api/chaos/${testType}`, {}, {
        headers: {
          'X-User-Type': 'admin',
          'X-Chaos-Test': testType,
        }
      });
      
      // Simulate test duration
      setTimeout(() => {
        setActiveTest(null);
        fetchChaosResults();
      }, 30000);
      
    } catch (error) {
      console.error('Chaos test failed:', error);
      setActiveTest(null);
    }
  };

  const fetchChaosResults = async () => {
    try {
      const response = await axios.get('/api/chaos/results');
      setChaosTests(response.data);
    } catch (error) {
      console.error('Failed to fetch chaos results:', error);
    }
  };

  useEffect(() => {
    fetchChaosResults();
  }, []);

  return (
    <div className="chaos">
      <h2>🧪 Chaos Engineering</h2>
      <p>Test the resilience of your multi-cluster setup</p>
      
      <div className="chaos-controls">
        <button 
          onClick={() => runChaosTest('network-delay')}
          disabled={activeTest !== null}
          className="chaos-btn"
        >
          {activeTest === 'network-delay' ? 'Running...' : 'Network Delay Test'}
        </button>
        
        <button 
          onClick={() => runChaosTest('service-failure')}
          disabled={activeTest !== null}
          className="chaos-btn"
        >
          {activeTest === 'service-failure' ? 'Running...' : 'Service Failure Test'}
        </button>
        
        <button 
          onClick={() => runChaosTest('high-load')}
          disabled={activeTest !== null}
          className="chaos-btn"
        >
          {activeTest === 'high-load' ? 'Running...' : 'High Load Test'}
        </button>
        
        <button 
          onClick={() => runChaosTest('circuit-breaker')}
          disabled={activeTest !== null}
          className="chaos-btn"
        >
          {activeTest === 'circuit-breaker' ? 'Running...' : 'Circuit Breaker Test'}
        </button>
      </div>

      {activeTest && (
        <div className="active-test">
          <h3>🔄 Running: {activeTest}</h3>
          <div className="progress-bar">
            <div className="progress"></div>
          </div>
        </div>
      )}

      <div className="chaos-results">
        <h3>Recent Test Results</h3>
        {chaosTests.map((test, index) => (
          <div key={index} className={`test-result ${test.status}`}>
            <h4>{test.type}</h4>
            <p>Status: {test.status}</p>
            <p>Duration: {test.duration}s</p>
            <p>Impact: {test.impact}</p>
            <p>Recovery Time: {test.recoveryTime}s</p>
          </div>
        ))}
      </div>
    </div>
  );
};

// 🎯 Main App Component
const App: React.FC = () => {
  return (
    <Router>
      <div className="App">
        <nav className="navbar">
          <div className="nav-brand">
            <h1>🚀 Multi-Cluster E-Commerce</h1>
          </div>
          <div className="nav-links">
            <Link to="/">Home</Link>
            <Link to="/users">Users</Link>
            <Link to="/orders">Orders</Link>
            <Link to="/chaos">Chaos Testing</Link>
          </div>
        </nav>

        <main className="main-content">
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/users" element={<Users />} />
            <Route path="/orders" element={<Orders />} />
            <Route path="/chaos" element={<ChaosEngineering />} />
          </Routes>
        </main>

        <footer className="footer">
          <p>🔒 Secured with Istio mTLS | 📊 Monitored with Prometheus | 🌐 Multi-Cluster Architecture</p>
        </footer>
      </div>
    </Router>
  );
};

export default App;
